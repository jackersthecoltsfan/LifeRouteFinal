import SwiftUI
import WebKit
import UIKit
import EventKit
import AuthenticationServices
import CryptoKit
import Security

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, ASWebAuthenticationPresentationContextProviding {
        weak var webView: WKWebView?
        private let eventStore = EKEventStore()
        private let isoFormatter = ISO8601DateFormatter()

        private var googleAuthSession: ASWebAuthenticationSession?
        private var googleAccessToken: String?
        private var googleAccessTokenExpiry: Date?

        private let googleScope = "https://www.googleapis.com/auth/calendar.readonly"
        private let googleAuthorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        private let googleTokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
        private let googleCalendarBaseURL = "https://www.googleapis.com/calendar/v3"

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
            case "requestGoogleCalendar":
                requestGoogleCalendarAccess()
            case "refreshGoogleCalendar":
                fetchGoogleCalendarEvents()
            case "disconnectGoogleCalendar":
                disconnectGoogleCalendar()
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
            if googleCalendarConnected {
                fetchGoogleCalendarEvents()
            }
        }

        // MARK: - Apple Calendar

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
            if #available(iOS 17.0, *) {
                switch status {
                case .fullAccess, .authorized: return "connected"
                case .writeOnly: return "write-only"
                case .denied: return "denied"
                case .restricted: return "restricted"
                case .notDetermined: return "not-determined"
                @unknown default: return "unknown"
                }
            } else {
                switch status {
                case .authorized: return "connected"
                case .denied: return "denied"
                case .restricted: return "restricted"
                case .notDetermined: return "not-determined"
                default: return "unknown"
                }
            }
        }

        // MARK: - Google Calendar

        private var googleClientID: String? {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_OAUTH_CLIENT_ID") as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private var googleRedirectScheme: String? {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_OAUTH_REDIRECT_SCHEME") as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private var googleRedirectURI: String? {
            guard let scheme = googleRedirectScheme else { return nil }
            return "\(scheme):/oauth2redirect"
        }

        private var googleCalendarConfigured: Bool {
            googleClientID != nil && googleRedirectScheme != nil
        }

        private var googleCalendarConnected: Bool {
            readGoogleRefreshToken() != nil || googleAccessToken != nil
        }

        private func requestGoogleCalendarAccess() {
            guard let clientID = googleClientID,
                  let redirectScheme = googleRedirectScheme,
                  let redirectURI = googleRedirectURI else {
                emit(type: "googleCalendarStatus", payload: [
                    "configured": false,
                    "connected": false,
                    "status": "setup-needed",
                    "message": "Google Calendar code is installed, but this build still needs the Google iOS OAuth client ID and redirect scheme."
                ])
                return
            }

            if readGoogleRefreshToken() != nil {
                fetchGoogleCalendarEvents()
                return
            }

            let codeVerifier = randomURLSafeString(byteCount: 32)
            let codeChallenge = base64URL(Data(SHA256.hash(data: Data(codeVerifier.utf8))))
            let state = randomURLSafeString(byteCount: 24)

            var components = URLComponents(url: googleAuthorizationEndpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: googleScope),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent")
            ]

            guard let authorizationURL = components.url else {
                emitGoogleError("Could not create the Google authorization URL.")
                return
            }

            googleAuthSession = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: redirectScheme
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                self.googleAuthSession = nil

                if let error {
                    let authError = error as NSError
                    if authError.domain == ASWebAuthenticationSessionError.errorDomain,
                       authError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.emit(type: "googleCalendarStatus", payload: [
                            "configured": true,
                            "connected": false,
                            "status": "cancelled"
                        ])
                    } else {
                        self.emitGoogleError(error.localizedDescription)
                    }
                    return
                }

                guard let callbackURL,
                      let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    self.emitGoogleError("Google sign-in returned an invalid response.")
                    return
                }

                let params = Dictionary(uniqueKeysWithValues: (callback.queryItems ?? []).compactMap { item in
                    item.value.map { (item.name, $0) }
                })

                if let oauthError = params["error"] {
                    self.emitGoogleError("Google authorization failed: \(oauthError)")
                    return
                }

                guard params["state"] == state else {
                    self.emitGoogleError("Google sign-in security validation failed. Please try again.")
                    return
                }

                guard let code = params["code"] else {
                    self.emitGoogleError("Google did not return an authorization code.")
                    return
                }

                Task {
                    do {
                        try await self.exchangeGoogleAuthorizationCode(
                            code,
                            clientID: clientID,
                            redirectURI: redirectURI,
                            codeVerifier: codeVerifier
                        )
                        await self.fetchGoogleCalendarEventsAsync()
                    } catch {
                        self.emitGoogleError(error.localizedDescription)
                    }
                }
            }

            googleAuthSession?.presentationContextProvider = self
            googleAuthSession?.prefersEphemeralWebBrowserSession = false
            if googleAuthSession?.start() != true {
                googleAuthSession = nil
                emitGoogleError("Could not start Google sign-in.")
            }
        }

        private func fetchGoogleCalendarEvents() {
            guard googleCalendarConfigured else {
                emit(type: "googleCalendarStatus", payload: [
                    "configured": false,
                    "connected": false,
                    "status": "setup-needed"
                ])
                return
            }

            Task {
                await fetchGoogleCalendarEventsAsync()
            }
        }

        private func fetchGoogleCalendarEventsAsync() async {
            do {
                let accessToken = try await validGoogleAccessToken()
                let calendars = try await fetchGoogleCalendars(accessToken: accessToken)
                let payloadEvents = try await fetchGoogleEvents(
                    calendars: calendars,
                    accessToken: accessToken
                )

                emit(type: "googleCalendarEvents", payload: [
                    "configured": true,
                    "connected": true,
                    "status": "connected",
                    "calendarCount": calendars.count,
                    "events": payloadEvents
                ])
            } catch {
                emitGoogleError(error.localizedDescription)
            }
        }

        private func disconnectGoogleCalendar() {
            googleAuthSession?.cancel()
            googleAuthSession = nil
            googleAccessToken = nil
            googleAccessTokenExpiry = nil
            deleteGoogleRefreshToken()
            emit(type: "googleCalendarStatus", payload: [
                "configured": googleCalendarConfigured,
                "connected": false,
                "status": "disconnected"
            ])
            emit(type: "googleCalendarEvents", payload: [
                "configured": googleCalendarConfigured,
                "connected": false,
                "status": "disconnected",
                "calendarCount": 0,
                "events": []
            ])
        }

        private func exchangeGoogleAuthorizationCode(
            _ code: String,
            clientID: String,
            redirectURI: String,
            codeVerifier: String
        ) async throws {
            let payload = try await postGoogleTokenForm([
                "code": code,
                "client_id": clientID,
                "redirect_uri": redirectURI,
                "grant_type": "authorization_code",
                "code_verifier": codeVerifier
            ])
            try applyGoogleTokenResponse(payload)
        }

        private func validGoogleAccessToken() async throws -> String {
            if let token = googleAccessToken,
               let expiry = googleAccessTokenExpiry,
               expiry.timeIntervalSinceNow > 90 {
                return token
            }

            guard let clientID = googleClientID,
                  let refreshToken = readGoogleRefreshToken() else {
                throw GoogleCalendarError.notConnected
            }

            do {
                let payload = try await postGoogleTokenForm([
                    "client_id": clientID,
                    "refresh_token": refreshToken,
                    "grant_type": "refresh_token"
                ])
                try applyGoogleTokenResponse(payload)
            } catch {
                if case GoogleCalendarError.oauth(let message) = error,
                   message.localizedCaseInsensitiveContains("invalid_grant") {
                    deleteGoogleRefreshToken()
                    googleAccessToken = nil
                    googleAccessTokenExpiry = nil
                }
                throw error
            }

            guard let token = googleAccessToken else {
                throw GoogleCalendarError.invalidTokenResponse
            }
            return token
        }

        private func postGoogleTokenForm(_ fields: [String: String]) async throws -> [String: Any] {
            var request = URLRequest(url: googleTokenEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formEncoded(fields).data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GoogleCalendarError.invalidServerResponse
            }

            let object = try JSONSerialization.jsonObject(with: data)
            let payload = object as? [String: Any] ?? [:]
            guard (200..<300).contains(http.statusCode) else {
                let detail = (payload["error_description"] as? String)
                    ?? (payload["error"] as? String)
                    ?? "HTTP \(http.statusCode)"
                throw GoogleCalendarError.oauth(detail)
            }
            return payload
        }

        private func applyGoogleTokenResponse(_ payload: [String: Any]) throws {
            guard let accessToken = payload["access_token"] as? String, !accessToken.isEmpty else {
                throw GoogleCalendarError.invalidTokenResponse
            }

            googleAccessToken = accessToken
            let expires = (payload["expires_in"] as? NSNumber)?.doubleValue ?? 3600
            googleAccessTokenExpiry = Date().addingTimeInterval(expires)

            if let refreshToken = payload["refresh_token"] as? String, !refreshToken.isEmpty {
                saveGoogleRefreshToken(refreshToken)
            }
        }

        private func fetchGoogleCalendars(accessToken: String) async throws -> [[String: Any]] {
            var components = URLComponents(string: "\(googleCalendarBaseURL)/users/me/calendarList")!
            components.queryItems = [
                URLQueryItem(name: "maxResults", value: "250"),
                URLQueryItem(name: "minAccessRole", value: "reader")
            ]

            let payload = try await googleGET(url: components.url!, accessToken: accessToken)
            let items = payload["items"] as? [[String: Any]] ?? []
            return items.filter { item in
                (item["deleted"] as? Bool) != true && (item["hidden"] as? Bool) != true
            }
        }

        private func fetchGoogleEvents(
            calendars: [[String: Any]],
            accessToken: String
        ) async throws -> [[String: Any]] {
            let now = Date()
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let end = calendar.date(byAdding: .day, value: 45, to: now) ?? now.addingTimeInterval(45 * 86_400)
            let formatter = ISO8601DateFormatter()

            var output: [[String: Any]] = []

            for calendarEntry in calendars {
                guard let calendarID = calendarEntry["id"] as? String else { continue }
                let calendarTitle = (calendarEntry["summaryOverride"] as? String)
                    ?? (calendarEntry["summary"] as? String)
                    ?? "Google Calendar"
                let calendarTimeZone = calendarEntry["timeZone"] as? String
                var pageToken: String?

                repeat {
                    var components = URLComponents(
                        string: "\(googleCalendarBaseURL)/calendars/\(calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID)/events"
                    )!
                    var queryItems = [
                        URLQueryItem(name: "singleEvents", value: "true"),
                        URLQueryItem(name: "orderBy", value: "startTime"),
                        URLQueryItem(name: "showDeleted", value: "false"),
                        URLQueryItem(name: "maxResults", value: "2500"),
                        URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
                        URLQueryItem(name: "timeMax", value: formatter.string(from: end))
                    ]
                    if let pageToken {
                        queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
                    }
                    components.queryItems = queryItems

                    let payload = try await googleGET(url: components.url!, accessToken: accessToken)
                    let items = payload["items"] as? [[String: Any]] ?? []

                    for item in items {
                        guard (item["status"] as? String) != "cancelled",
                              let id = item["id"] as? String,
                              let startValue = normalizedGoogleDate(
                                item["start"] as? [String: Any],
                                timeZoneID: calendarTimeZone
                              ),
                              let endValue = normalizedGoogleDate(
                                item["end"] as? [String: Any],
                                timeZoneID: calendarTimeZone
                              ) else { continue }

                        output.append([
                            "id": id,
                            "title": (item["summary"] as? String) ?? "Calendar event",
                            "start": startValue.iso,
                            "end": endValue.iso,
                            "location": (item["location"] as? String) ?? "",
                            "calendarTitle": calendarTitle,
                            "isAllDay": startValue.allDay,
                            "source": "google"
                        ])
                    }

                    pageToken = payload["nextPageToken"] as? String
                } while pageToken != nil
            }

            output.sort {
                (($0["start"] as? String) ?? "") < (($1["start"] as? String) ?? "")
            }
            return output
        }

        private func googleGET(url: URL, accessToken: String) async throws -> [String: Any] {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GoogleCalendarError.invalidServerResponse
            }

            let object = try JSONSerialization.jsonObject(with: data)
            let payload = object as? [String: Any] ?? [:]
            guard (200..<300).contains(http.statusCode) else {
                let apiError = payload["error"] as? [String: Any]
                let detail = (apiError?["message"] as? String) ?? "HTTP \(http.statusCode)"
                throw GoogleCalendarError.api(detail)
            }
            return payload
        }

        private func normalizedGoogleDate(
            _ value: [String: Any]?,
            timeZoneID: String?
        ) -> (iso: String, allDay: Bool)? {
            guard let value else { return nil }
            if let dateTime = value["dateTime"] as? String {
                return (dateTime, false)
            }

            guard let dateString = value["date"] as? String else { return nil }
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let timeZoneID, let zone = TimeZone(identifier: timeZoneID) {
                dateFormatter.timeZone = zone
            } else {
                dateFormatter.timeZone = .current
            }
            guard let date = dateFormatter.date(from: dateString) else { return nil }
            return (ISO8601DateFormatter().string(from: date), true)
        }

        private func emitGoogleError(_ message: String) {
            emit(type: "googleCalendarStatus", payload: [
                "configured": googleCalendarConfigured,
                "connected": googleCalendarConnected,
                "status": "error",
                "message": message
            ])
        }

        // MARK: - Google OAuth helpers / Keychain

        private func randomURLSafeString(byteCount: Int) -> String {
            var bytes = [UInt8](repeating: 0, count: byteCount)
            let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
            if status != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    + UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            return base64URL(Data(bytes))
        }

        private func base64URL(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        private func formEncoded(_ fields: [String: String]) -> String {
            var components = URLComponents()
            components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            return components.percentEncodedQuery ?? ""
        }

        private var googleKeychainService: String {
            "\(Bundle.main.bundleIdentifier ?? "LifeRoute").googleCalendar"
        }

        private func saveGoogleRefreshToken(_ token: String) {
            guard let data = token.data(using: .utf8) else { return }
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: googleKeychainService,
                kSecAttrAccount as String: "refreshToken"
            ]
            SecItemDelete(base as CFDictionary)
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }

        private func readGoogleRefreshToken() -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: googleKeychainService,
                kSecAttrAccount as String: "refreshToken",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }

        private func deleteGoogleRefreshToken() {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: googleKeychainService,
                kSecAttrAccount as String: "refreshToken"
            ]
            SecItemDelete(query as CFDictionary)
        }

        // MARK: - Native status / maps

        private func emitNativeStatus() {
            emit(type: "nativeStatus", payload: [
                "native": true,
                "appleCalendarConnected": hasAppleCalendarReadAccess,
                "appleCalendarStatus": authorizationLabel,
                "googleCalendarConfigured": googleCalendarConfigured,
                "googleCalendarConnected": googleCalendarConnected,
                "googleMapsHandoffAvailable": true,
                "appleMapsAvailable": true
            ])
        }

        private func openRoute(provider: String, origin: String?, destination: String) {
            guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedOrigin = origin?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/dir/")!
                var items = [
                    URLQueryItem(name: "api", value: "1"),
                    URLQueryItem(name: "destination", value: destination),
                    URLQueryItem(name: "travelmode", value: "driving")
                ]
                if let origin, !origin.isEmpty {
                    items.append(URLQueryItem(name: "origin", value: origin))
                }
                components.queryItems = items
                if let url = components.url { UIApplication.shared.open(url) }
            } else {
                var urlString = "https://maps.apple.com/directions?destination=\(encodedDestination)&mode=driving"
                if let encodedOrigin, !encodedOrigin.isEmpty {
                    urlString += "&source=\(encodedOrigin)"
                }
                if let url = URL(string: urlString) { UIApplication.shared.open(url) }
            }
        }

        private func openPlace(provider: String, query: String) {
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if provider.lowercased() == "google" {
                var components = URLComponents(string: "https://www.google.com/maps/search/")!
                components.queryItems = [
                    URLQueryItem(name: "api", value: "1"),
                    URLQueryItem(name: "query", value: query)
                ]
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

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            webView?.window ?? UIWindow()
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

private enum GoogleCalendarError: LocalizedError {
    case notConnected
    case invalidTokenResponse
    case invalidServerResponse
    case oauth(String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Google Calendar is not connected yet."
        case .invalidTokenResponse:
            return "Google returned an invalid sign-in token response."
        case .invalidServerResponse:
            return "Google returned an invalid server response."
        case .oauth(let message):
            return "Google sign-in error: \(message)"
        case .api(let message):
            return "Google Calendar error: \(message)"
        }
    }
}
