import Foundation
import Combine
import EventKit
import AuthenticationServices
import CryptoKit
import Security
import UIKit

enum GoogleCalendarProviderError: LocalizedError {
    case notConfigured
    case authorizationCancelled
    case invalidAuthorizationResponse
    case stateMismatch
    case notConnected
    case invalidServerResponse
    case invalidTokenResponse
    case oauth(String)
    case api(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google Calendar setup is incomplete for this build."
        case .authorizationCancelled: return "Google Calendar sign-in was cancelled."
        case .invalidAuthorizationResponse: return "Google sign-in returned an invalid response."
        case .stateMismatch: return "Google sign-in security validation failed. Please try again."
        case .notConnected: return "Google Calendar is not connected."
        case .invalidServerResponse: return "Google Calendar returned an invalid server response."
        case .invalidTokenResponse: return "Google Calendar returned an invalid token response."
        case .oauth(let message): return "Google authorization failed: \(message)"
        case .api(let message): return "Google Calendar request failed: \(message)"
        case .keychain(let status): return "Google Calendar credentials could not be stored securely (\(status))."
        }
    }
}

@MainActor
final class CalendarProviderCore: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var appleStatus = "Not connected"
    @Published private(set) var appleConnected = false
    @Published private(set) var appleBusy = false
    @Published private(set) var googleStatus = "Not connected"
    @Published private(set) var googleConnected = false
    @Published private(set) var googleBusy = false

    private let eventStore = EKEventStore()
    private var googleAuthSession: ASWebAuthenticationSession?
    private var googleAccessToken: String?
    private var googleAccessTokenExpiry: Date?

    private let googleScope = "https://www.googleapis.com/auth/calendar.readonly"
    private let googleAuthorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    private let googleTokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private let googleCalendarBaseURL = "https://www.googleapis.com/calendar/v3"

    override init() {
        super.init()
        refreshAppleAuthorizationLabel()
        if !googleCalendarConfigured {
            googleStatus = "Setup needed"
        } else if readGoogleRefreshToken() != nil {
            googleConnected = true
            googleStatus = "Connected · refresh when ready"
        }
    }

    func connectOrRefreshApple() async -> [LifeRouteCalendarEvent]? {
        guard !appleBusy else { return nil }
        appleBusy = true
        defer { appleBusy = false }

        if !hasAppleCalendarReadAccess {
            appleStatus = "Requesting calendar access…"
            let granted = await requestAppleCalendarAccess()
            guard granted else {
                appleConnected = false
                refreshAppleAuthorizationLabel()
                return nil
            }
        }

        let events = fetchAppleCalendarEvents()
        appleConnected = true
        appleStatus = "Connected · \(events.count) events"
        return events
    }

    func connectOrRefreshGoogle() async -> [LifeRouteCalendarEvent]? {
        guard !googleBusy else { return nil }
        guard googleCalendarConfigured else {
            googleConnected = false
            googleStatus = "Setup needed"
            return nil
        }

        googleBusy = true
        defer { googleBusy = false }

        do {
            if readGoogleRefreshToken() == nil && googleAccessToken == nil {
                googleStatus = "Opening Google sign-in…"
                try await authorizeGoogle()
            }
            googleStatus = "Refreshing Google Calendar…"
            let events = try await fetchGoogleCalendarEvents()
            googleConnected = true
            googleStatus = "Connected · \(events.count) events"
            return events
        } catch {
            if case GoogleCalendarProviderError.authorizationCancelled = error {
                googleStatus = "Sign-in cancelled"
            } else {
                googleStatus = error.localizedDescription
            }
            googleConnected = readGoogleRefreshToken() != nil || googleAccessToken != nil
            return nil
        }
    }

    func disconnectGoogle() {
        googleAuthSession?.cancel()
        googleAuthSession = nil
        googleAccessToken = nil
        googleAccessTokenExpiry = nil
        deleteGoogleRefreshToken()
        googleConnected = false
        googleStatus = "Not connected"
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
        }
        return UIWindow()
    }

    private func requestAppleCalendarAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func fetchAppleCalendarEvents() -> [LifeRouteCalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 45, to: now) ?? now.addingTimeInterval(45 * 86_400)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate).map { event in
            LifeRouteCalendarEvent(
                id: "apple-\(event.eventIdentifier ?? UUID().uuidString)",
                title: event.title ?? "Calendar event",
                start: event.startDate,
                end: event.endDate,
                location: event.location ?? "",
                calendarTitle: event.calendar.title,
                isAllDay: event.isAllDay,
                source: .apple
            )
        }
    }

    private var hasAppleCalendarReadAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private func refreshAppleAuthorizationLabel() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess, .authorized:
                appleConnected = true
                appleStatus = "Access granted · refresh when ready"
            case .writeOnly:
                appleConnected = false
                appleStatus = "Write-only access cannot be used"
            case .denied:
                appleConnected = false
                appleStatus = "Access denied"
            case .restricted:
                appleConnected = false
                appleStatus = "Access restricted"
            case .notDetermined:
                appleConnected = false
                appleStatus = "Not connected"
            @unknown default:
                appleConnected = false
                appleStatus = "Unknown status"
            }
        } else {
            switch status {
            case .authorized:
                appleConnected = true
                appleStatus = "Access granted · refresh when ready"
            case .denied:
                appleConnected = false
                appleStatus = "Access denied"
            case .restricted:
                appleConnected = false
                appleStatus = "Access restricted"
            case .notDetermined:
                appleConnected = false
                appleStatus = "Not connected"
            default:
                appleConnected = false
                appleStatus = "Unknown status"
            }
        }
    }

    private var googleClientID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_OAUTH_CLIENT_ID") as? String else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private var googleRedirectScheme: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_OAUTH_REDIRECT_SCHEME") as? String else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private var googleRedirectURI: String? {
        googleRedirectScheme.map { "\($0):/oauth2redirect" }
    }

    private var googleCalendarConfigured: Bool {
        googleClientID != nil && googleRedirectScheme != nil
    }

    private func authorizeGoogle() async throws {
        guard let clientID = googleClientID,
              let redirectScheme = googleRedirectScheme,
              let redirectURI = googleRedirectURI else {
            throw GoogleCalendarProviderError.notConfigured
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
            throw GoogleCalendarProviderError.invalidAuthorizationResponse
        }

        let code: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizationURL, callbackURLScheme: redirectScheme) { callbackURL, error in
                if let error {
                    let authError = error as NSError
                    if authError.domain == ASWebAuthenticationSessionError.errorDomain,
                       authError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleCalendarProviderError.authorizationCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL,
                      let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    continuation.resume(throwing: GoogleCalendarProviderError.invalidAuthorizationResponse)
                    return
                }
                let params = Dictionary(uniqueKeysWithValues: (callback.queryItems ?? []).compactMap { item in
                    item.value.map { (item.name, $0) }
                })
                if let oauthError = params["error"] {
                    continuation.resume(throwing: GoogleCalendarProviderError.oauth(oauthError))
                    return
                }
                guard params["state"] == state else {
                    continuation.resume(throwing: GoogleCalendarProviderError.stateMismatch)
                    return
                }
                guard let code = params["code"] else {
                    continuation.resume(throwing: GoogleCalendarProviderError.invalidAuthorizationResponse)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            googleAuthSession = session
            if !session.start() {
                googleAuthSession = nil
                continuation.resume(throwing: GoogleCalendarProviderError.invalidAuthorizationResponse)
            }
        }
        googleAuthSession = nil

        let payload = try await postGoogleTokenForm([
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ])
        try applyGoogleTokenResponse(payload)
    }

    private func fetchGoogleCalendarEvents() async throws -> [LifeRouteCalendarEvent] {
        let accessToken = try await validGoogleAccessToken()
        let calendars = try await fetchGoogleCalendars(accessToken: accessToken)
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 45, to: now) ?? now.addingTimeInterval(45 * 86_400)
        let iso = ISO8601DateFormatter()
        var output: [LifeRouteCalendarEvent] = []

        for calendarEntry in calendars {
            guard let calendarID = calendarEntry["id"] as? String else { continue }
            let calendarTitle = (calendarEntry["summaryOverride"] as? String)
                ?? (calendarEntry["summary"] as? String)
                ?? "Google Calendar"
            let calendarTimeZone = calendarEntry["timeZone"] as? String
            var pageToken: String?

            repeat {
                let encodedID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID
                var components = URLComponents(string: "\(googleCalendarBaseURL)/calendars/\(encodedID)/events")!
                var query = [
                    URLQueryItem(name: "singleEvents", value: "true"),
                    URLQueryItem(name: "orderBy", value: "startTime"),
                    URLQueryItem(name: "showDeleted", value: "false"),
                    URLQueryItem(name: "maxResults", value: "2500"),
                    URLQueryItem(name: "timeMin", value: iso.string(from: start)),
                    URLQueryItem(name: "timeMax", value: iso.string(from: end))
                ]
                if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
                components.queryItems = query

                let payload = try await googleGET(url: components.url!, accessToken: accessToken)
                for item in payload["items"] as? [[String: Any]] ?? [] {
                    guard (item["status"] as? String) != "cancelled",
                          let eventID = item["id"] as? String,
                          let startValue = googleDate(item["start"] as? [String: Any], timeZoneID: calendarTimeZone),
                          let endValue = googleDate(item["end"] as? [String: Any], timeZoneID: calendarTimeZone) else { continue }

                    output.append(
                        LifeRouteCalendarEvent(
                            id: "google-\(calendarID)-\(eventID)",
                            title: (item["summary"] as? String) ?? "Calendar event",
                            start: startValue.date,
                            end: endValue.date,
                            location: (item["location"] as? String) ?? "",
                            calendarTitle: calendarTitle,
                            isAllDay: startValue.allDay,
                            source: .google
                        )
                    )
                }
                pageToken = payload["nextPageToken"] as? String
            } while pageToken != nil
        }

        return output.sorted { $0.start < $1.start }
    }

    private func fetchGoogleCalendars(accessToken: String) async throws -> [[String: Any]] {
        var components = URLComponents(string: "\(googleCalendarBaseURL)/users/me/calendarList")!
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "minAccessRole", value: "reader")
        ]
        let payload = try await googleGET(url: components.url!, accessToken: accessToken)
        return (payload["items"] as? [[String: Any]] ?? []).filter {
            ($0["deleted"] as? Bool) != true && ($0["hidden"] as? Bool) != true
        }
    }

    private func validGoogleAccessToken() async throws -> String {
        if let token = googleAccessToken,
           let expiry = googleAccessTokenExpiry,
           expiry.timeIntervalSinceNow > 90 {
            return token
        }

        guard let clientID = googleClientID,
              let refreshToken = readGoogleRefreshToken() else {
            throw GoogleCalendarProviderError.notConnected
        }

        do {
            let payload = try await postGoogleTokenForm([
                "client_id": clientID,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ])
            try applyGoogleTokenResponse(payload)
        } catch {
            if case GoogleCalendarProviderError.oauth(let message) = error,
               message.localizedCaseInsensitiveContains("invalid_grant") {
                deleteGoogleRefreshToken()
                googleAccessToken = nil
                googleAccessTokenExpiry = nil
                googleConnected = false
            }
            throw error
        }

        guard let token = googleAccessToken else {
            throw GoogleCalendarProviderError.invalidTokenResponse
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
            throw GoogleCalendarProviderError.invalidServerResponse
        }
        let payload = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            let detail = (payload["error_description"] as? String)
                ?? (payload["error"] as? String)
                ?? "HTTP \(http.statusCode)"
            throw GoogleCalendarProviderError.oauth(detail)
        }
        return payload
    }

    private func applyGoogleTokenResponse(_ payload: [String: Any]) throws {
        guard let accessToken = payload["access_token"] as? String, !accessToken.isEmpty else {
            throw GoogleCalendarProviderError.invalidTokenResponse
        }
        googleAccessToken = accessToken
        let expires = (payload["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        googleAccessTokenExpiry = Date().addingTimeInterval(expires)
        if let refreshToken = payload["refresh_token"] as? String, !refreshToken.isEmpty {
            try saveGoogleRefreshToken(refreshToken)
        }
    }

    private func googleGET(url: URL, accessToken: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleCalendarProviderError.invalidServerResponse
        }
        let payload = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            let apiError = payload["error"] as? [String: Any]
            let detail = (apiError?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw GoogleCalendarProviderError.api(detail)
        }
        return payload
    }

    private func googleDate(_ value: [String: Any]?, timeZoneID: String?) -> (date: Date, allDay: Bool)? {
        guard let value else { return nil }
        if let dateTime = value["dateTime"] as? String {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: dateTime) { return (date, false) }
            if let date = ISO8601DateFormatter().date(from: dateTime) { return (date, false) }
            return nil
        }

        guard let dateString = value["date"] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        guard let date = formatter.date(from: dateString) else { return nil }
        return (date, true)
    }

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

    private func saveGoogleRefreshToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { throw GoogleCalendarProviderError.invalidTokenResponse }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: googleKeychainService,
            kSecAttrAccount as String: "refreshToken"
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw GoogleCalendarProviderError.keychain(status) }
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
}
