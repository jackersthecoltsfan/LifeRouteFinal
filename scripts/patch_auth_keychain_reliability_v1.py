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

# Cross-platform PIN-entry reliability. Some browser/WKWebView combinations can
# swallow keystrokes in dynamically inserted password fields. Keep the PIN masked
# with WebKit text security while using a numeric telephone field that reliably
# accepts touch-keyboard input in both Safari/browser preview and WKWebView.
web_path = Path("LifeRoute/Web/auth-gate.js")
web = web_path.read_text()
web = web.replace(
    'class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4"',
    'class="lrAuthPin" type="tel" inputmode="numeric" pattern="[0-9]*" autocomplete="off" maxlength="4"'
)
web = web.replace(
    'class="lrAuthPin" type="password" inputmode="numeric" autocomplete="current-password" maxlength="4"',
    'class="lrAuthPin" type="tel" inputmode="numeric" pattern="[0-9]*" autocomplete="off" maxlength="4"'
)
old_pin_css = '.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important}'
new_pin_css = '.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important;-webkit-text-security:disc;caret-color:#fff;pointer-events:auto!important;touch-action:manipulation;-webkit-user-select:text!important;user-select:text!important}'
if old_pin_css in web:
    web = web.replace(old_pin_css, new_pin_css, 1)
elif new_pin_css not in web:
    raise SystemExit("Could not harden LifeRoute PIN input CSS")

web_path.write_text(web)
print("Local login now verifies every Keychain write, rolls back partial saves, and uses reliable masked numeric PIN inputs.")