from pathlib import Path

# Keep the selected navigation provider visually explicit.
sleek = Path("LifeRoute/Web/sleek-ui.js")
text = sleek.read_text()
old = "    .provider{padding:11px!important}.provider .icon{font-size:18px!important;margin-bottom:5px!important}.integrationIcon{border-radius:11px!important}.chip,.badge{padding:5px 7px!important;font-size:9.5px!important}.weekday{padding:10px 0!important}.bar{height:6px!important}.notice{border-radius:12px!important;font-size:10.5px!important}\n"
new = "    .provider{padding:11px!important;position:relative!important;overflow:hidden!important}.provider .icon{font-size:18px!important;margin-bottom:5px!important}.provider.active{border-color:color-mix(in srgb,var(--gold) 82%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 8%,transparent),color-mix(in srgb,var(--blue) 5%,transparent)),var(--panel)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 72%,transparent),0 10px 28px rgba(0,0,0,.10)!important}.provider.active:after{content:\"✓\";position:absolute;top:8px;right:9px;width:20px;height:20px;border-radius:999px;display:grid;place-items:center;background:var(--gold);color:var(--bg);font-size:11px;font-weight:950}.integrationIcon{border-radius:11px!important}.chip,.badge{padding:5px 7px!important;font-size:9.5px!important}.weekday{padding:10px 0!important}.bar{height:6px!important}.notice{border-radius:12px!important;font-size:10.5px!important}\n"
if new not in text:
    if old not in text:
        raise SystemExit("Could not patch provider selection styling: marker not found")
    sleek.write_text(text.replace(old, new, 1))
print("Provider selection styling ready.")

# Load the live-state bridge before the calendar hub.
index = Path("LifeRoute/Web/index.html")
html = index.read_text()
tags = [
    '<script src="global-bridge.js"></script>',
    '<script src="calendar-hub.js"></script>',
]
for filename in ["global-bridge.js", "calendar-hub.js"]:
    if not Path("LifeRoute/Web", filename).is_file():
        raise SystemExit(f"{filename} is missing")
for tag in tags:
    html = html.replace(tag, "")
if "</body>" not in html:
    raise SystemExit("Could not inject calendar feature scripts: </body> not found")
index.write_text(html.replace("</body>", "\n".join(tags) + "\n</body>", 1))
print("Calendar hub scripts ready.")

# Native read-only iCal/ICS fetching avoids sending private subscription URLs
# through a third-party proxy and bypasses browser CORS inside the iPhone app.
swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()

case_line = '            case "fetchReadOnlyCalendarFeed":'
if case_line not in swift:
    marker = '            case "disconnectGoogleCalendar":\n                disconnectGoogleCalendar()\n'
    replacement = marker + (
        '            case "fetchReadOnlyCalendarFeed":\n'
        '                let feedID = (body["feedID"] as? String) ?? ""\n'
        '                let url = (body["url"] as? String) ?? ""\n'
        '                fetchReadOnlyCalendarFeed(feedID: feedID, urlString: url)\n'
    )
    if marker not in swift:
        raise SystemExit("Could not add read-only calendar feed action")
    swift = swift.replace(marker, replacement, 1)

if "private func fetchReadOnlyCalendarFeed(" not in swift:
    marker = "        // MARK: - Google Calendar\n"
    method = r'''        // MARK: - Read-only calendar links

        private func fetchReadOnlyCalendarFeed(feedID: String, urlString: String) {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feedID.isEmpty, !trimmed.isEmpty else {
                emit(type: "readOnlyCalendarFeedError", payload: [
                    "feedID": feedID,
                    "message": "The calendar link is empty."
                ])
                return
            }

            let normalized: String
            if trimmed.lowercased().hasPrefix("webcal://") {
                normalized = "https://" + String(trimmed.dropFirst("webcal://".count))
            } else {
                normalized = trimmed
            }

            guard let url = URL(string: normalized),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                emit(type: "readOnlyCalendarFeedError", payload: [
                    "feedID": feedID,
                    "message": "Use an https:// or webcal:// calendar subscription link."
                ])
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 25
            request.setValue("text/calendar, text/plain;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let error {
                        self.emit(type: "readOnlyCalendarFeedError", payload: [
                            "feedID": feedID,
                            "message": error.localizedDescription
                        ])
                        return
                    }
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode),
                          let data,
                          let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                        self.emit(type: "readOnlyCalendarFeedError", payload: [
                            "feedID": feedID,
                            "message": status > 0 ? "Calendar server returned HTTP \(status)." : "Could not read this calendar feed."
                        ])
                        return
                    }
                    self.emit(type: "readOnlyCalendarFeed", payload: [
                        "feedID": feedID,
                        "text": text
                    ])
                }
            }.resume()
        }

'''
    if marker not in swift:
        raise SystemExit("Could not add read-only calendar feed method")
    swift = swift.replace(marker, method + marker, 1)

swift_path.write_text(swift)
print("Native read-only calendar feed loading ready.")
