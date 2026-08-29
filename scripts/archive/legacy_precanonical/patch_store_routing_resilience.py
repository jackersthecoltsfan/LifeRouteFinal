from pathlib import Path

# 1) Make native MapKit directions retry once without a departure date.
# Time-specific routing can occasionally fail even when a normal route exists.
swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()

old = '''                        let response = try await MKDirections(request: request).calculate()
                        guard let route = response.routes.min(by: {
                            $0.expectedTravelTime < $1.expectedTravelTime
                        }) else {
                            throw RouteTimeError.noRoute
                        }
'''
new = '''                        let route: MKRoute
                        do {
                            let response = try await MKDirections(request: request).calculate()
                            guard let best = response.routes.min(by: {
                                $0.expectedTravelTime < $1.expectedTravelTime
                            }) else {
                                throw RouteTimeError.noRoute
                            }
                            route = best
                        } catch {
                            // A time-specific request can fail transiently even when a
                            // normal route exists. Retry without traffic/departure timing
                            // before declaring the leg unavailable.
                            request.departureDate = nil
                            let retryResponse = try await MKDirections(request: request).calculate()
                            guard let fallback = retryResponse.routes.min(by: {
                                $0.expectedTravelTime < $1.expectedTravelTime
                            }) else {
                                throw error
                            }
                            route = fallback
                        }
'''
if new not in swift:
    if old not in swift:
        raise SystemExit("Could not patch MapKit fallback routing: marker not found")
    swift = swift.replace(old, new, 1)
    swift_path.write_text(swift)
    print("Added MapKit route retry fallback.")
else:
    print("MapKit route retry fallback already present.")

# 2) Reduce duplicate store candidates and avoid hammering MapKit with the same
# branch multiple times. This also makes the result list cleaner on iPhone.
js_path = Path("LifeRoute/Web/grocery-stores.js")
js = js_path.read_text()
old_locations = '''    request.locations = (Array.isArray(evt.locations) ? evt.locations : []).slice(0, 18).map((location, index) => ({
      ...location,
      id: `${request.requestID}|loc-${index}`
    }));
'''
new_locations = '''    const seenBranches = new Set();
    request.locations = (Array.isArray(evt.locations) ? evt.locations : [])
      .filter(location => {
        const normalizedAddress = String(location.address || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const normalizedName = String(location.name || location.brand || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const key = `${normalizedName}|${normalizedAddress}`;
        if (!normalizedAddress || seenBranches.has(key)) return false;
        seenBranches.add(key);
        return true;
      })
      .slice(0, 10)
      .map((location, index) => ({
        ...location,
        id: `${request.requestID}|loc-${index}`
      }));
'''
if new_locations not in js:
    if old_locations not in js:
        raise SystemExit("Could not patch store candidate de-duplication: marker not found")
    js = js.replace(old_locations, new_locations, 1)

# Improve the generic unavailable message with actual per-leg diagnostics when
# MapKit supplies them, while keeping the copy concise.
old_route_line = '''      const routeLine = item.routeComplete
        ? `${fmt(item.out.minutes)} there + ${fmt(item.duration)} shopping + ${fmt(item.back.minutes)} to next`
        : "Could not calculate both route legs";
'''
new_route_line = '''      const routeError = [item.out?.error, item.back?.error].filter(Boolean)[0] || "Could not calculate both route legs";
      const routeLine = item.routeComplete
        ? `${fmt(item.out.minutes)} there + ${fmt(item.duration)} shopping + ${fmt(item.back.minutes)} to next`
        : routeError;
'''
if new_route_line not in js:
    if old_route_line not in js:
        raise SystemExit("Could not patch store route diagnostics: marker not found")
    js = js.replace(old_route_line, new_route_line, 1)

js_path.write_text(js)
print("De-duplicated store branches and added route diagnostics.")
