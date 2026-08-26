from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

old_helper = '''        private func saveAuthKeychain(account: String, value: String) {
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
'''
new_helper = '''        private func deleteAuthKeychain(account: String) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: authKeychainService,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }

        @discardableResult
        private func saveAuthKeychain(account: String, value: String) -> Bool {
            guard let data = value.data(using: .utf8) else { return false }
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: authKeychainService,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(base as CFDictionary)
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
'''
if new_helper not in text:
    if old_helper not in text:
        raise SystemExit("Could not harden Keychain write helper")
    text = text.replace(old_helper, new_helper, 1)

old_save = '''            let salt = randomAuthSalt()
            let hash = authHash(pin: pin, salt: salt)
            saveAuthKeychain(account: "username", value: username)
            saveAuthKeychain(account: "pinSalt", value: salt)
            saveAuthKeychain(account: "pinHash", value: hash)
            authDefaults.set(0, forKey: "LifeRouteAuthFailedAttemptsV2")
'''
new_save = '''            let salt = randomAuthSalt()
            let hash = authHash(pin: pin, salt: salt)
            let usernameSaved = saveAuthKeychain(account: "username", value: username)
            let saltSaved = saveAuthKeychain(account: "pinSalt", value: salt)
            let hashSaved = saveAuthKeychain(account: "pinHash", value: hash)
            guard usernameSaved && saltSaved && hashSaved else {
                deleteAuthKeychain(account: "username")
                deleteAuthKeychain(account: "pinSalt")
                deleteAuthKeychain(account: "pinHash")
                emit(type: "authCredentialSaved", payload: [
                    "success": false,
                    "message": "LifeRoute could not save the local login securely. Please try again."
                ])
                return
            }
            authDefaults.set(0, forKey: "LifeRouteAuthFailedAttemptsV2")
'''
if new_save not in text:
    if old_save not in text:
        raise SystemExit("Could not harden credential save transaction")
    text = text.replace(old_save, new_save, 1)

path.write_text(text)

# LifeRoute v0.4.0 deliberately removes the unreliable local login gate from
# startup. Keep the native Keychain/biometric bridge above for a future auth
# redesign, but make the bundled web module inert: no overlay, no auth-status
# request, no polling, no PBKDF2 work, and no interaction interception.
web_path = Path("LifeRoute/Web/auth-gate.js")
web_path.write_text('''// LifeRoute v0.4.0 startup authentication policy.\n// The legacy local login UI is intentionally disabled for this release.\n(() => {\n  const AUTH_GATE_ENABLED = 0;\n  window.__lifeRouteAuthGateLoaded = true;\n  window.__lifeRouteAuthGateDisabledV040 = true;\n\n  const cleanupLegacyGate = () => {\n    document.getElementById("lifeRouteAuthGate")?.remove();\n    document.getElementById("lifeRouteAuthStyles")?.remove();\n  };\n\n  cleanupLegacyGate();\n  if (document.readyState === "loading") {\n    document.addEventListener("DOMContentLoaded", cleanupLegacyGate, { once: true });\n  }\n\n  window.LifeRouteAuth = Object.freeze({\n    enabled: !!AUTH_GATE_ENABLED,\n    lock() {\n      cleanupLegacyGate();\n      return false;\n    }\n  });\n})();\n''')

print("Native auth Keychain reliability preserved; v0.4.0 web login gate disabled at startup.")
