from pathlib import Path
import runpy

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

# Keep the native security implementation hardened, then bypass the legacy web
# gate before any of its startup/UI work executes. The separate patches are
# invoked here so the existing deterministic prepare_build ordering stays stable.
runpy.run_path("scripts/patch_disable_auth_gate_v1.py", run_name="__main__")
runpy.run_path("scripts/patch_welcome_freeze_v040.py", run_name="__main__")

# Preserve the established Resources capability wording in the walkthrough while
# keeping the new lightweight startup architecture unchanged.
welcome_path = Path("LifeRoute/Web/welcome.js")
welcome = welcome_path.read_text()
old_copy = "Resources keeps common work portals together with search and live suggestions."
new_copy = "Resources keeps common work portals together with search and live web suggestions."
if new_copy not in welcome:
    if old_copy not in welcome:
        raise SystemExit("Could not preserve welcome live-web-suggestion copy")
    welcome = welcome.replace(old_copy, new_copy, 1)
    welcome_path.write_text(welcome)

runpy.run_path("scripts/audit_welcome_freeze_v040.py", run_name="__main__")

print("Native auth reliability preserved; v0.4.0 direct startup, welcome freeze fix, and Apple version contract applied.")
