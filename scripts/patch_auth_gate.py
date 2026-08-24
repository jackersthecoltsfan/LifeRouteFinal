from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

# Add auth actions immediately after the stable openPlace call. Other build
# patches may insert additional switch cases before `default`, so do not depend
# on the exact surrounding switch layout.
action_anchor = '                openPlace(provider: provider, query: query)\n'
auth_actions = '''            case "authStatus":
                emitAuthStatus()
            case "authSetCredentials":
                let phone = (body["phone"] as? String) ?? ""
                let pin = (body["pin"] as? String) ?? ""
                saveAuthCredentials(phone: phone, pin: pin)
            case "authVerifyCredentials":
                let phone = (body["phone"] as? String) ?? ""
                let pin = (body["pin"] as? String) ?? ""
                verifyAuthCredentials(phone: phone, pin: pin)
'''

if 'case "authStatus":' not in text:
    if action_anchor not in text:
        raise SystemExit("Could not find LifeRoute openPlace bridge action")
    text = text.replace(action_anchor, action_anchor + auth_actions, 1)

auth_block = r'''
        // MARK: - LifeRoute login / Keychain

        private var authKeychainService: String {
            "\(Bundle.main.bundleIdentifier ?? "LifeRoute").auth"
        }

        private var authDefaults: UserDefaults { .standard }
        private let authMaxAttempts = 5
        private let authLockSeconds: TimeInterval = 60

        private func normalizedAuthPhone(_ raw: String) -> String? {
            let digits = raw.filter(\.isNumber)
            if digits.count == 10 { return "+1\(digits)" }
            if (8...15).contains(digits.count) { return "+\(digits)" }
            return nil
        }

        private func authPhoneHint(_ phone: String?) -> String {
            guard let phone else { return "" }
            let digits = phone.filter(\.isNumber)
            guard digits.count >= 4 else { return "" }
            return "••• ••• \(digits.suffix(4))"
        }

        private func randomAuthSalt() -> String {
            var bytes = [UInt8](repeating: 0, count: 16)
            if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            return Data(bytes).base64EncodedString()
        }

        private func authHash(pin: String, salt: String) -> String {
            let saltData = Data(salt.utf8)
            var seed = Data()
            seed.append(saltData)
            seed.append(Data(pin.utf8))
            var digest = Data(SHA256.hash(data: seed))
            // Make brute-force attempts meaningfully more expensive while the
            // 4-digit PIN remains convenient. The PIN itself is never stored.
            for _ in 0..<50_000 {
                var round = Data()
                round.append(digest)
                round.append(saltData)
                digest = Data(SHA256.hash(data: round))
            }
            return digest.base64EncodedString()
        }

        private func saveAuthKeychain(account: String, value: String) {
            guard let data = value.data(using: .utf8) else { return }
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: authKeychainService,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(base as CFDictionary)
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }

        private func readAuthKeychain(account: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: authKeychainService,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }

        private var authConfigured: Bool {
            readAuthKeychain(account: "phone") != nil &&
            readAuthKeychain(account: "pinSalt") != nil &&
            readAuthKeychain(account: "pinHash") != nil
        }

        private func emitAuthStatus() {
            emit(type: "authStatus", payload: [
                "configured": authConfigured,
                "phoneHint": authPhoneHint(readAuthKeychain(account: "phone"))
            ])
        }

        private func saveAuthCredentials(phone rawPhone: String, pin: String) {
            guard let phone = normalizedAuthPhone(rawPhone),
                  pin.range(of: "^[0-9]{4}$", options: .regularExpression) != nil else {
                emit(type: "authCredentialSaved", payload: [
                    "success": false,
                    "message": "A valid mobile number and 4-digit PIN are required."
                ])
                return
            }

            let salt = randomAuthSalt()
            let hash = authHash(pin: pin, salt: salt)
            saveAuthKeychain(account: "phone", value: phone)
            saveAuthKeychain(account: "pinSalt", value: salt)
            saveAuthKeychain(account: "pinHash", value: hash)
            authDefaults.set(0, forKey: "LifeRouteAuthFailedAttempts")
            authDefaults.removeObject(forKey: "LifeRouteAuthLockUntil")
            emit(type: "authCredentialSaved", payload: ["success": true])
        }

        private func verifyAuthCredentials(phone rawPhone: String, pin: String) {
            let now = Date().timeIntervalSince1970
            let lockedUntil = authDefaults.double(forKey: "LifeRouteAuthLockUntil")
            if lockedUntil > now {
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "lockedForSeconds": max(1, Int(ceil(lockedUntil - now)))
                ])
                return
            }

            guard let phone = normalizedAuthPhone(rawPhone),
                  pin.range(of: "^[0-9]{4}$", options: .regularExpression) != nil,
                  let savedPhone = readAuthKeychain(account: "phone"),
                  let salt = readAuthKeychain(account: "pinSalt"),
                  let savedHash = readAuthKeychain(account: "pinHash") else {
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "message": "LifeRoute login has not been set up yet."
                ])
                return
            }

            let success = phone == savedPhone && authHash(pin: pin, salt: salt) == savedHash
            if success {
                authDefaults.set(0, forKey: "LifeRouteAuthFailedAttempts")
                authDefaults.removeObject(forKey: "LifeRouteAuthLockUntil")
                emit(type: "authVerifyResult", payload: ["success": true])
                return
            }

            var attempts = authDefaults.integer(forKey: "LifeRouteAuthFailedAttempts") + 1
            if attempts >= authMaxAttempts {
                attempts = 0
                let until = now + authLockSeconds
                authDefaults.set(until, forKey: "LifeRouteAuthLockUntil")
                authDefaults.set(attempts, forKey: "LifeRouteAuthFailedAttempts")
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "lockedForSeconds": Int(authLockSeconds),
                    "message": "Too many incorrect attempts."
                ])
            } else {
                authDefaults.set(attempts, forKey: "LifeRouteAuthFailedAttempts")
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "message": "Phone number or PIN is incorrect."
                ])
            }
        }

'''

marker = '        // MARK: - Native status / maps\n'
if '// MARK: - LifeRoute login / Keychain' not in text:
    if marker not in text:
        raise SystemExit("Could not find native status insertion point")
    text = text.replace(marker, auth_block + marker, 1)

path.write_text(text)
print("LifeRoute phone/PIN Keychain bridge enabled.")
