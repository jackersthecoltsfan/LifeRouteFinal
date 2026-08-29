from pathlib import Path

swift_path = Path("LifeRoute/LifeRouteWebView.swift")
text = swift_path.read_text()

if "import LocalAuthentication\n" not in text:
    anchor = "import Security\n"
    if anchor not in text:
        raise SystemExit("Could not find Security import for LocalAuthentication")
    text = text.replace(anchor, anchor + "import LocalAuthentication\n", 1)

# Add auth actions immediately after the stable openPlace call. Other build
# patches can add switch cases around this block without changing the contract.
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
            case "authSetBiometricEnabled":
                let enabled = (body["enabled"] as? Bool) ?? false
                setAuthBiometricEnabled(enabled)
            case "authBiometricUnlock":
                authenticateWithBiometrics()
'''

if 'case "authStatus":' not in text:
    if action_anchor not in text:
        raise SystemExit("Could not find LifeRoute openPlace bridge action")
    text = text.replace(action_anchor, action_anchor + auth_actions, 1)

# Add LocalAuthentication cases if an older auth patch was already applied.
if 'case "authSetBiometricEnabled":' not in text:
    anchor = '''            case "authVerifyCredentials":
                let username = (body["username"] as? String) ?? ""
                let pin = (body["pin"] as? String) ?? ""
                verifyAuthCredentials(username: username, pin: pin)
'''
    addition = anchor + '''            case "authSetBiometricEnabled":
                let enabled = (body["enabled"] as? Bool) ?? false
                setAuthBiometricEnabled(enabled)
            case "authBiometricUnlock":
                authenticateWithBiometrics()
'''
    if anchor not in text:
        raise SystemExit("Could not extend existing auth actions with biometrics")
    text = text.replace(anchor, addition, 1)

auth_block = r'''
        // MARK: - LifeRoute local login / Keychain / biometrics

        private var authKeychainService: String {
            "\(Bundle.main.bundleIdentifier ?? "LifeRoute").auth.v2"
        }

        private var authDefaults: UserDefaults { .standard }
        private let authMaxAttempts = 5
        private let authLockSeconds: TimeInterval = 60
        private let authBiometricDefaultsKey = "LifeRouteAuthBiometricEnabledV1"

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

        private func authBiometricInfo() -> (available: Bool, label: String) {
            let context = LAContext()
            var error: NSError?
            let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            let label: String
            switch context.biometryType {
            case .faceID: label = "Face ID"
            case .touchID: label = "Touch ID"
            case .opticID: label = "Optic ID"
            default: label = "Biometrics"
            }
            return (available, label)
        }

        private var authBiometricEnabled: Bool {
            authDefaults.bool(forKey: authBiometricDefaultsKey)
        }

        private func emitAuthStatus() {
            let biometric = authBiometricInfo()
            emit(type: "authStatus", payload: [
                "configured": authConfigured,
                "usernameHint": readAuthKeychain(account: "username") ?? "",
                "biometricAvailable": biometric.available,
                "biometricEnabled": biometric.available && authBiometricEnabled,
                "biometricLabel": biometric.label
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
            authDefaults.set(false, forKey: authBiometricDefaultsKey)
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

        private func setAuthBiometricEnabled(_ enabled: Bool) {
            let info = authBiometricInfo()
            guard authConfigured else {
                emit(type: "authBiometricSettings", payload: [
                    "available": info.available,
                    "enabled": false,
                    "biometricLabel": info.label,
                    "success": false,
                    "message": "Create your LifeRoute login first."
                ])
                return
            }
            if enabled && !info.available {
                authDefaults.set(false, forKey: authBiometricDefaultsKey)
                emit(type: "authBiometricSettings", payload: [
                    "available": false,
                    "enabled": false,
                    "biometricLabel": info.label,
                    "success": false,
                    "message": "Biometric unlock is not available on this device."
                ])
                return
            }
            authDefaults.set(enabled, forKey: authBiometricDefaultsKey)
            emit(type: "authBiometricSettings", payload: [
                "available": info.available,
                "enabled": enabled,
                "biometricLabel": info.label,
                "success": true
            ])
        }

        private func authenticateWithBiometrics() {
            let info = authBiometricInfo()
            guard authConfigured, authBiometricEnabled, info.available else {
                emit(type: "authBiometricResult", payload: [
                    "success": false,
                    "message": "Biometric unlock is not enabled. Use your PIN instead."
                ])
                return
            }

            let context = LAContext()
            context.localizedFallbackTitle = "Use PIN"
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock LifeRoute"
            ) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if success {
                        self.emit(type: "authBiometricResult", payload: ["success": true])
                    } else {
                        let message = error?.localizedDescription ?? "Biometric authentication was not completed."
                        self.emit(type: "authBiometricResult", payload: [
                            "success": false,
                            "message": message
                        ])
                    }
                }
            }
        }

'''

marker = '        // MARK: - Native status / maps\n'
if '// MARK: - LifeRoute local login / Keychain / biometrics' not in text:
    # Remove the older local-login block if present so the enhanced implementation
    # can replace it deterministically.
    older = '// MARK: - LifeRoute local login / Keychain\n'
    if older in text:
        start = text.index('        ' + older)
        end = text.find(marker, start)
        if end == -1:
            raise SystemExit("Could not replace older auth block")
        text = text[:start] + text[end:]
    if marker not in text:
        raise SystemExit("Could not find native status insertion point")
    text = text.replace(marker, auth_block + marker, 1)

swift_path.write_text(text)

plist_path = Path("LifeRoute/Info.plist")
plist = plist_path.read_text()
if "NSFaceIDUsageDescription" not in plist:
    anchor = '''    <key>NSLocationWhenInUseUsageDescription</key>\n    <string>LifeRoute uses your location while the app is open to start commute and route estimates from where you actually are. Your live location is not stored in your calendar.</string>\n'''
    addition = anchor + '''    <key>NSFaceIDUsageDescription</key>\n    <string>LifeRoute can use Face ID when you choose it as a faster way to unlock your local LifeRoute login.</string>\n'''
    if anchor not in plist:
        raise SystemExit("Could not add Face ID usage description")
    plist = plist.replace(anchor, addition, 1)
    plist_path.write_text(plist)

print("LifeRoute username/PIN Keychain bridge and optional Face ID unlock enabled.")
