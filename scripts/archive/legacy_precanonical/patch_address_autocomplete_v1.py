from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

# The route-time patch already imports MapKit. Extend the coordinator with the
# local search completer only after CoreLocation is present.
if "MKLocalSearchCompleterDelegate" not in text:
    anchor = "ASWebAuthenticationPresentationContextProviding, CLLocationManagerDelegate {"
    if anchor in text:
        text = text.replace(anchor, "ASWebAuthenticationPresentationContextProviding, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {", 1)
    else:
        fallback = "ASWebAuthenticationPresentationContextProviding {"
        if fallback not in text:
            raise SystemExit("Could not add MapKit autocomplete delegate conformance")
        text = text.replace(fallback, "ASWebAuthenticationPresentationContextProviding, MKLocalSearchCompleterDelegate {", 1)

storage_anchor = "        private let locationManager = CLLocationManager()\n"
storage = '''        private let addressCompleter = MKLocalSearchCompleter()\n        private var addressAutocompleteRequestID = ""\n        private var addressAutocompleteQuery = ""\n'''
if "private let addressCompleter = MKLocalSearchCompleter()" not in text:
    if storage_anchor not in text:
        raise SystemExit("Could not find location manager storage for address autocomplete")
    text = text.replace(storage_anchor, storage_anchor + storage, 1)

action_anchor = '''            case "stopLiveLocation":
                stopLiveLocation()
'''
action = action_anchor + '''            case "addressAutocomplete":
                let query = (body["query"] as? String) ?? ""
                let requestID = (body["requestID"] as? String) ?? ""
                requestAddressAutocomplete(query: query, requestID: requestID)
'''
if 'case "addressAutocomplete":' not in text:
    if action_anchor not in text:
        raise SystemExit("Could not find location action anchor for address autocomplete")
    text = text.replace(action_anchor, action, 1)

block = r'''
        // MARK: - Address autocomplete

        private func requestAddressAutocomplete(query rawQuery: String, requestID: String) {
            let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            addressAutocompleteRequestID = requestID
            addressAutocompleteQuery = query

            guard query.count >= 3 else {
                emit(type: "addressAutocompleteResults", payload: [
                    "requestID": requestID,
                    "query": query,
                    "results": []
                ])
                return
            }

            addressCompleter.delegate = self
            addressCompleter.resultTypes = [.address, .pointOfInterest]
            if let location = locationManager.location {
                addressCompleter.region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 80_000,
                    longitudinalMeters: 80_000
                )
            }
            addressCompleter.queryFragment = query
        }

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            let requestID = addressAutocompleteRequestID
            let query = addressAutocompleteQuery
            let results: [[String: Any]] = completer.results.prefix(6).map { completion in
                let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let address: String
                if subtitle.isEmpty || subtitle.localizedCaseInsensitiveContains(title) {
                    address = subtitle.isEmpty ? title : subtitle
                } else {
                    address = "\(title), \(subtitle)"
                }
                return [
                    "title": title,
                    "subtitle": subtitle,
                    "address": address
                ]
            }
            emit(type: "addressAutocompleteResults", payload: [
                "requestID": requestID,
                "query": query,
                "results": results
            ])
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            emit(type: "addressAutocompleteResults", payload: [
                "requestID": addressAutocompleteRequestID,
                "query": addressAutocompleteQuery,
                "results": [],
                "message": error.localizedDescription
            ])
        }

'''

marker = "        // MARK: - Current location\n"
if "// MARK: - Address autocomplete" not in text:
    if marker not in text:
        raise SystemExit("Could not find current-location marker for address autocomplete")
    text = text.replace(marker, block + marker, 1)

path.write_text(text)
print("Native MapKit address autocomplete bridge enabled.")
