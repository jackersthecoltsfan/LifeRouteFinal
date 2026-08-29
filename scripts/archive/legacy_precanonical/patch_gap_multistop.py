from pathlib import Path

# Gap-option navigation should preserve the user's whole immediate trip:
# current location -> chosen gap stop -> next calendar destination.
# Both Google Maps URLs and Apple's unified Maps URLs support intermediary
# waypoints, so the native bridge can hand off the same intent to either app.


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    return text.replace(old, new, 1)


# 1) Add a reusable web-side multi-stop route helper while preserving the
# existing single-destination routeTo() behavior for ordinary places/to-dos.
index_path = Path("LifeRoute/Web/index.html")
html = index_path.read_text()
old_route = '''function routeTo(encoded){let destination=decodeURIComponent(encoded),p=prefs.mapProvider;if(p==="ask"){let useGoogle=confirm("OK = Google Maps\\nCancel = Apple Maps");p=useGoogle?"google":"apple"};if(postNative({action:"openRoute",provider:p,destination}))return;let u=p==="google"?`https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(destination)}&travelmode=driving`:`https://maps.apple.com/directions?destination=${encodeURIComponent(destination)}&mode=driving`;location.href=u}
'''
new_route = '''function selectedMapProvider(){let p=prefs.mapProvider;if(p==="ask"){let useGoogle=confirm("OK = Google Maps\\nCancel = Apple Maps");p=useGoogle?"google":"apple"}return p}
function routeTo(encoded){let destination=decodeURIComponent(encoded),p=selectedMapProvider(),mode=prefs.transportMode||"driving";if(postNative({action:"openRoute",provider:p,destination}))return;let u=p==="google"?`https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(destination)}&travelmode=${encodeURIComponent(mode)}`:`https://maps.apple.com/directions?destination=${encodeURIComponent(destination)}&mode=${encodeURIComponent(mode)}`;location.href=u}
function routeGapStop(encodedStop,encodedFinal){let stop=decodeURIComponent(encodedStop||"").trim(),final=decodeURIComponent(encodedFinal||"").trim();if(!stop)return;if(!final){routeTo(encodedStop);return}let p=selectedMapProvider(),mode=prefs.transportMode||"driving";if(postNative({action:"openRoute",provider:p,destination:final,waypoints:[stop]}))return;let u;if(p==="google"){let q=new URLSearchParams({api:"1",destination:final,travelmode:mode,waypoints:stop});u=`https://www.google.com/maps/dir/?${q.toString()}`}else{let q=new URLSearchParams({destination:final,mode});q.append("waypoint",stop);u=`https://maps.apple.com/directions?${q.toString()}`}location.href=u}
'''
html = replace_once(html, old_route, new_route, "web multi-stop route helper")
index_path.write_text(html)


# 2) A regular gap suggestion should make the selected task the waypoint and
# the next scheduled event the final destination.
todos_path = Path("LifeRoute/Web/todos.js")
todos = todos_path.read_text()
old_todo_button = '''          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="routeTo('${encodeURIComponent(todo.address)}')">Route there</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
'''
new_todo_button = '''          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="routeGapStop('${encodeURIComponent(todo.address)}','${encodeURIComponent(context.next?.address || "")}')">${context.next?.address ? "Route + next" : "Route there"}</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
'''
todos = replace_once(todos, old_todo_button, new_todo_button, "gap to-do multi-stop button")
todos_path.write_text(todos)


# 3) Store branch comparisons are also gap options, so "Route here" should
# include the next calendar destination after the chosen store.
stores_path = Path("LifeRoute/Web/grocery-stores.js")
stores = stores_path.read_text()
old_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();routeTo('${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}')">Route here</button></div>
'''
new_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();routeGapStop('${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}','${encodeURIComponent(request.next?.address || "")}')">${request.next?.address ? "Route + next" : "Route here"}</button></div>
'''
stores = replace_once(stores, old_store_button, new_store_button, "store gap multi-stop button")
stores_path.write_text(stores)


# 4) Teach the native iPhone bridge to accept waypoint arrays and hand them to
# Google Maps / Apple Maps using their supported URL parameters. The transport
# patch runs earlier, so preserve its selected driving/walking/transit mode.
swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()
old_case = '''            case "openRoute":
                let provider = (body["provider"] as? String) ?? "apple"
                let destination = (body["destination"] as? String) ?? ""
                let origin = body["origin"] as? String
                let transportMode = (body["transportMode"] as? String) ?? "driving"
                openRoute(provider: provider, origin: origin, destination: destination, transportMode: transportMode)
'''
new_case = '''            case "openRoute":
                let provider = (body["provider"] as? String) ?? "apple"
                let destination = (body["destination"] as? String) ?? ""
                let origin = body["origin"] as? String
                let transportMode = (body["transportMode"] as? String) ?? "driving"
                let waypoints = (body["waypoints"] as? [String]) ?? []
                openRoute(provider: provider, origin: origin, destination: destination, transportMode: transportMode, waypoints: waypoints)
'''
swift = replace_once(swift, old_case, new_case, "native openRoute waypoint bridge")

old_native = '''        private func openRoute(provider: String, origin: String?, destination: String, transportMode: String) {
            guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedOrigin = origin?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/dir/")!
                var items = [
                    URLQueryItem(name: "api", value: "1"),
                    URLQueryItem(name: "destination", value: destination),
                    URLQueryItem(name: "travelmode", value: routeTravelModeName(transportMode))
                ]
                if let origin, !origin.isEmpty {
                    items.append(URLQueryItem(name: "origin", value: origin))
                }
                components.queryItems = items
                if let url = components.url { UIApplication.shared.open(url) }
            } else {
                var urlString = "https://maps.apple.com/directions?destination=\\(encodedDestination)&mode=\\(routeTravelModeName(transportMode))"
                if let encodedOrigin, !encodedOrigin.isEmpty {
                    urlString += "&source=\\(encodedOrigin)"
                }
                if let url = URL(string: urlString) { UIApplication.shared.open(url) }
            }
        }
'''
new_native = '''        private func openRoute(provider: String, origin: String?, destination: String, transportMode: String, waypoints: [String] = []) {
            let cleanDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanDestination.isEmpty else { return }
            let cleanWaypoints = waypoints
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let mode = routeTravelModeName(transportMode)

            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/dir/")!
                var items = [
                    URLQueryItem(name: "api", value: "1"),
                    URLQueryItem(name: "destination", value: cleanDestination),
                    URLQueryItem(name: "travelmode", value: mode)
                ]
                if let origin = origin?.trimmingCharacters(in: .whitespacesAndNewlines), !origin.isEmpty {
                    items.append(URLQueryItem(name: "origin", value: origin))
                }
                if !cleanWaypoints.isEmpty {
                    items.append(URLQueryItem(name: "waypoints", value: cleanWaypoints.joined(separator: "|")))
                }
                components.queryItems = items
                if let url = components.url { UIApplication.shared.open(url) }
            } else {
                var components = URLComponents(string: "https://maps.apple.com/directions")!
                var items = [
                    URLQueryItem(name: "destination", value: cleanDestination),
                    URLQueryItem(name: "mode", value: mode)
                ]
                if let origin = origin?.trimmingCharacters(in: .whitespacesAndNewlines), !origin.isEmpty {
                    items.append(URLQueryItem(name: "source", value: origin))
                }
                cleanWaypoints.forEach { waypoint in
                    items.append(URLQueryItem(name: "waypoint", value: waypoint))
                }
                components.queryItems = items
                if let url = components.url { UIApplication.shared.open(url) }
            }
        }
'''
swift = replace_once(swift, old_native, new_native, "native Google/Apple multi-stop handoff")
swift_path.write_text(swift)

print("Gap navigation now opens current location -> gap stop -> next event in Google Maps or Apple Maps.")
