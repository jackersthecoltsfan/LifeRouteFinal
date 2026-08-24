from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    text = text.replace(old, new, 1)


# MapKit should calculate the same travel mode the user selected in the UI.
replace_once(
    "                        request.transportType = .automobile\n",
    '                        request.transportType = routeTransportType(segment["transportMode"] as? String)\n',
    "MapKit transport mode",
)

helper_code = r'''
        private func normalizedTransportMode(_ value: String?) -> String {
            switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "walking": return "walking"
            case "transit": return "transit"
            default: return "driving"
            }
        }

        private func routeTransportType(_ value: String?) -> MKDirectionsTransportType {
            switch normalizedTransportMode(value) {
            case "walking": return .walking
            case "transit": return .transit
            default: return .automobile
            }
        }

        private func routeTravelModeName(_ value: String?) -> String {
            normalizedTransportMode(value)
        }

'''

replace_once(
    "        private func parseRouteDate(_ value: String) -> Date? {\n",
    helper_code + "        private func parseRouteDate(_ value: String) -> Date? {\n",
    "transport helpers",
)

replace_once(
    '            case "openRoute":\n                let provider = (body["provider"] as? String) ?? "apple"\n                let destination = (body["destination"] as? String) ?? ""\n                let origin = body["origin"] as? String\n                openRoute(provider: provider, origin: origin, destination: destination)\n',
    '            case "openRoute":\n                let provider = (body["provider"] as? String) ?? "apple"\n                let destination = (body["destination"] as? String) ?? ""\n                let origin = body["origin"] as? String\n                let transportMode = (body["transportMode"] as? String) ?? "driving"\n                openRoute(provider: provider, origin: origin, destination: destination, transportMode: transportMode)\n',
    "open-route bridge transport mode",
)

replace_once(
    "        private func openRoute(provider: String, origin: String?, destination: String) {\n",
    "        private func openRoute(provider: String, origin: String?, destination: String, transportMode: String) {\n",
    "openRoute signature",
)

replace_once(
    '                    URLQueryItem(name: "travelmode", value: "driving")\n',
    '                    URLQueryItem(name: "travelmode", value: routeTravelModeName(transportMode))\n',
    "Google Maps travel mode",
)

replace_once(
    '                var urlString = "https://maps.apple.com/directions?destination=\\(encodedDestination)&mode=driving"\n',
    '                var urlString = "https://maps.apple.com/directions?destination=\\(encodedDestination)&mode=\\(routeTravelModeName(transportMode))"\n',
    "Apple Maps travel mode",
)

text = text.replace(
    '            return "No driving route was returned."',
    '            return "No route was returned for the selected travel mode."'
)

path.write_text(text)
print("Patched LifeRoute native routing with Driving, Walking, and Transit modes.")
