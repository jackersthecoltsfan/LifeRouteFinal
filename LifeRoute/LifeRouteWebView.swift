import SwiftUI
import WebKit
import UIKit
import EventKit

struct LifeRouteWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "lifeRoute")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        if let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Web"
        ) {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("""
            <html><body style="background:#07111f;color:white;font-family:-apple-system;padding:32px">
            <h2>LifeRoute couldn't load its interface.</h2>
            </body></html>
            """, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private let eventStore = EKEventStore()
        private let isoFormatter = ISO8601DateFormatter()

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "lifeRoute",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "requestNativeStatus":
                emitNativeStatus()
            case "requestAppleCalendar":
                requestAppleCalendarAccess()
            case "refreshAppleCalendar":
                fetchAppleCalendarEvents()
            case "openRoute":
                let provider = (body["provider"] as? String) ?? "apple"
                let destination = (body["destination"] as? String) ?? ""
                let origin = body["origin"] as? String
                openRoute(provider: provider, origin: origin, destination: destination)
            case "openPlace":
                let provider = (body["provider"] as? String) ?? "apple"
                let query = (body["query"] as? String) ?? ""
                openPlace(provider: provider, query: query)
            default:
                emit(type: "bridgeError", payload: ["message": "Unknown native action: \(action)"])
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            emitNativeStatus()
        }

        private func requestAppleCalendarAccess() {
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if granted {
                            self.fetchAppleCalendarEvents()
                        } else {
                            self.emit(type: "appleCalendarStatus", payload: [
                                "connected": false,
                                "status": "denied",
                                "message": error?.localizedDescription ?? "Calendar access was not granted."
                            ])
                        }
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if granted {
                            self.fetchAppleCalendarEvents()
                        } else {
                            self.emit(type: "appleCalendarStatus", payload: [
                                "connected": false,
                                "status": "denied",
                                "message": error?.localizedDescription ?? "Calendar access was not granted."
                            ])
                        }
                    }
                }
            }
        }

        private func fetchAppleCalendarEvents() {
            guard hasAppleCalendarReadAccess else {
                emit(type: "appleCalendarStatus", payload: [
                    "connected": false,
                    "status": authorizationLabel,
                    "message": "Calendar permission is required before events can be read."
                ])
                return
            }

            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let end = calendar.date(byAdding: .day, value: 45, to: Date()) ?? Date().addingTimeInterval(45 * 86_400)
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            let events = eventStore.events(matching: predicate)

            let payloadEvents: [[String: Any]] = events.map { event in
                [
                    "id": event.eventIdentifier ?? UUID().uuidString,
                    "title": event.title ?? "Calendar event",
                    "start": isoFormatter.string(from: event.startDate),
                    "end": isoFormatter.string(from: event.endDate),
                    "location": event.location ?? "",
                    "calendarTitle": event.calendar.title,
                    "isAllDay": event.isAllDay,
                    "source": "apple"
                ]
            }

            emit(type: "appleCalendarEvents", payload: [
                "connected": true,
                "status": "connected",
                "events": payloadEvents
            ])
        }

        private var hasAppleCalendarReadAccess: Bool {
            let status = EKEventStore.authorizationStatus(for: .event)
            if #available(iOS 17.0, *) {
                return status == .fullAccess
            }
            return status == .authorized
        }

        private var authorizationLabel: String {
            let status = EKEventStore.authorizationStatus(for: .event)
            if #available(iOS 17.0, *), status == .fullAccess { return "connected" }
            switch status {
            case .authorized: return "connected"
            case .denied: return "denied"
            case .restricted: return "restricted"
            case .notDetermined: return "not-determined"
            case .writeOnly: return "write-only"
            case .fullAccess: return "connected"
            @unknown default: return "unknown"
            }
        }

        private func emitNativeStatus() {
            emit(type: "nativeStatus", payload: [
                "native": true,
                "appleCalendarConnected": hasAppleCalendarReadAccess,
                "appleCalendarStatus": authorizationLabel,
                "appleMapsAvailable": true,
                "googleMapsHandoffAvailable": true
            ])
        }

        private func openRoute(provider: String, origin: String?, destination: String) {
            guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedOrigin = origin?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/dir/")!
                var items = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: destination), URLQueryItem(name: "travelmode", value: "driving")]
                if let origin, !origin.isEmpty { items.append(URLQueryItem(name: "origin", value: origin)) }
                components.queryItems = items
                if let url = components.url { UIApplication.shared.open(url) }
            } else {
                var urlString = "https://maps.apple.com/directions?destination=\(encodedDestination)&mode=driving"
                if let encodedOrigin, !encodedOrigin.isEmpty { urlString += "&source=\(encodedOrigin)" }
                if let url = URL(string: urlString) { UIApplication.shared.open(url) }
            }
        }

        private func openPlace(provider: String, query: String) {
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/search/")!
                components.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
                if let url = components.url { UIApplication.shared.open(url) }
            } else {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "https://maps.apple.com/place?address=\(encoded)") {
                    UIApplication.shared.open(url)
                }
            }
        }

        private func emit(type: String, payload: [String: Any]) {
            guard let webView else { return }
            var event = payload
            event["type"] = type
            guard JSONSerialization.isValidJSONObject(event),
                  let data = try? JSONSerialization.data(withJSONObject: event),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                webView.evaluateJavaScript("window.lifeRouteNativeEvent && window.lifeRouteNativeEvent(\(json));")
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            guard let viewController = webView.window?.rootViewController else {
                completionHandler()
                return
            }

            let alert = UIAlertController(title: "LifeRoute", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            viewController.present(alert, animated: true)
        }
    }
}
