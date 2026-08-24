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
                let username = (body["username"] as? String) ?? ""
                let pin = (body["pin"] as? String) ?? ""
                saveAuthCredentials(username: username, pin: pin)
            case "authVerifyCredentials":
                let username = (body["username"] as? String) ?? ""
                let pin = (body["pin"] as? String) ?? ""
                verifyAuthCredentials(username: username, pin: pin)
'''

if 'case "authStatus":' not in text:
    if action_anchor not in text:
        raise SystemExit("Could not find LifeRoute openPlace bridge action")
    text = text.replace(action_anchor, action_anchor + auth_actions, 1)

auth_block = r'''
        // MARK: - LifeRoute local login / Keychain

        private var authKeychainService: String {
            "\(Bundle.main.bundleIdentifier ?? "LifeRoute").auth.v2"
        }

        private var authDefaults: UserDefaults { .standard }
        private let authMaxAttempts = 5
        private let authLockSeconds: TimeInterval = 60

        private func normalizedAuthUsername(_ raw: String) -> String? {
            let username = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard username.range(of: "^[a-z0-9][a-z0-9._-]{2,23}$", options: .regularExpression) != nil else {
                return nil
            }
            return username
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
            readAuthKeychain(account: "username") != nil &&
            readAuthKeychain(account: "pinSalt") != nil &&
            readAuthKeychain(account: "pinHash") != nil
        }

        private func emitAuthStatus() {
            emit(type: "authStatus", payload: [
                "configured": authConfigured,
                "usernameHint": readAuthKeychain(account: "username") ?? ""
            ])
        }

        private func saveAuthCredentials(username rawUsername: String, pin: String) {
            guard let username = normalizedAuthUsername(rawUsername),
                  pin.range(of: "^[0-9]{4}$", options: .regularExpression) != nil else {
                emit(type: "authCredentialSaved", payload: [
                    "success": false,
                    "message": "A valid username and 4-digit PIN are required."
                ])
                return
            }

            let salt = randomAuthSalt()
            let hash = authHash(pin: pin, salt: salt)
            saveAuthKeychain(account: "username", value: username)
            saveAuthKeychain(account: "pinSalt", value: salt)
            saveAuthKeychain(account: "pinHash", value: hash)
            authDefaults.set(0, forKey: "LifeRouteAuthFailedAttemptsV2")
            authDefaults.removeObject(forKey: "LifeRouteAuthLockUntilV2")
            emit(type: "authCredentialSaved", payload: ["success": true])
        }

        private func verifyAuthCredentials(username rawUsername: String, pin: String) {
            let now = Date().timeIntervalSince1970
            let lockedUntil = authDefaults.double(forKey: "LifeRouteAuthLockUntilV2")
            if lockedUntil > now {
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "lockedForSeconds": max(1, Int(ceil(lockedUntil - now)))
                ])
                return
            }

            guard let username = normalizedAuthUsername(rawUsername),
                  pin.range(of: "^[0-9]{4}$", options: .regularExpression) != nil,
                  let savedUsername = readAuthKeychain(account: "username"),
                  let salt = readAuthKeychain(account: "pinSalt"),
                  let savedHash = readAuthKeychain(account: "pinHash") else {
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "message": "LifeRoute login has not been set up yet."
                ])
                return
            }

            let success = username == savedUsername && authHash(pin: pin, salt: salt) == savedHash
            if success {
                authDefaults.set(0, forKey: "LifeRouteAuthFailedAttemptsV2")
                authDefaults.removeObject(forKey: "LifeRouteAuthLockUntilV2")
                emit(type: "authVerifyResult", payload: ["success": true])
                return
            }

            var attempts = authDefaults.integer(forKey: "LifeRouteAuthFailedAttemptsV2") + 1
            if attempts >= authMaxAttempts {
                attempts = 0
                let until = now + authLockSeconds
                authDefaults.set(until, forKey: "LifeRouteAuthLockUntilV2")
                authDefaults.set(attempts, forKey: "LifeRouteAuthFailedAttemptsV2")
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "lockedForSeconds": Int(authLockSeconds),
                    "message": "Too many incorrect attempts."
                ])
            } else {
                authDefaults.set(attempts, forKey: "LifeRouteAuthFailedAttemptsV2")
                emit(type: "authVerifyResult", payload: [
                    "success": false,
                    "message": "Username or PIN is incorrect."
                ])
            }
        }

'''

marker = '        // MARK: - Native status / maps\n'
if '// MARK: - LifeRoute local login / Keychain' not in text:
    if marker not in text:
        raise SystemExit("Could not find native status insertion point")
    text = text.replace(marker, auth_block + marker, 1)

path.write_text(text)
print("LifeRoute username/PIN Keychain bridge enabled.")
