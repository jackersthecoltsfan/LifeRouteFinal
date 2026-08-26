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

# Cross-platform PIN-entry reliability. WKWebView can be unreliable with dynamically
# inserted password/tel controls. Use a normal text control with a numeric keyboard,
# mask it with WebKit text security, and sanitize all input to four digits.
web_path = Path("LifeRoute/Web/auth-gate.js")
web = web_path.read_text()
for old in [
    'class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4"',
    'class="lrAuthPin" type="password" inputmode="numeric" autocomplete="current-password" maxlength="4"',
    'class="lrAuthPin" type="tel" inputmode="numeric" pattern="[0-9]*" autocomplete="off" maxlength="4"',
]:
    web = web.replace(old, 'class="lrAuthPin" type="text" inputmode="numeric" pattern="[0-9]*" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" maxlength="4"')

old_pin_css = '.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important}'
new_pin_css = '.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important;-webkit-text-security:disc;caret-color:#fff;pointer-events:auto!important;touch-action:manipulation;-webkit-user-select:text!important;user-select:text!important;-webkit-appearance:none!important;appearance:none!important}'
if old_pin_css in web:
    web = web.replace(old_pin_css, new_pin_css, 1)
elif new_pin_css not in web:
    prior = '.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important;-webkit-text-security:disc;caret-color:#fff;pointer-events:auto!important;touch-action:manipulation;-webkit-user-select:text!important;user-select:text!important}'
    if prior in web:
        web = web.replace(prior, new_pin_css, 1)
    else:
        raise SystemExit("Could not harden LifeRoute PIN input CSS")

anchor = '  const setBusy = busy => document.querySelectorAll("#lifeRouteAuthGate button").forEach(button => button.disabled = !!busy);\n'
helper = '''  const setBusy = busy => document.querySelectorAll("#lifeRouteAuthGate button").forEach(button => button.disabled = !!busy);\n\n  const hardenPinInputs = root => {\n    (root || document).querySelectorAll?.("#lifeRouteAuthGate .lrAuthPin").forEach(input => {\n      if (input.dataset.lrPinReady === "1") return;\n      input.dataset.lrPinReady = "1";\n      input.type = "text";\n      input.inputMode = "numeric";\n      input.setAttribute("pattern", "[0-9]*");\n      input.setAttribute("autocomplete", "off");\n      input.setAttribute("autocorrect", "off");\n      input.setAttribute("autocapitalize", "off");\n      input.setAttribute("spellcheck", "false");\n      input.maxLength = 4;\n      const clean = () => {\n        const next = String(input.value || "").replace(/\\D/g, "").slice(0, 4);\n        if (input.value !== next) input.value = next;\n      };\n      input.addEventListener("input", clean);\n      input.addEventListener("change", clean);\n      input.addEventListener("paste", () => setTimeout(clean, 0));\n      input.addEventListener("pointerdown", () => setTimeout(() => { try { input.focus({preventScroll:true}); } catch (_) { input.focus(); } }, 0));\n      input.addEventListener("touchend", () => setTimeout(() => { try { input.focus({preventScroll:true}); } catch (_) { input.focus(); } }, 0), {passive:true});\n    });\n  };\n'''
if 'const hardenPinInputs = root =>' not in web:
    if anchor not in web:
        raise SystemExit("Could not install PIN input hardening helper")
    web = web.replace(anchor, helper, 1)

for marker in [
    '    document.getElementById("lrAuthCreate").onclick = createLogin;\n',
    '    document.getElementById("lrAuthLoginPin")?.addEventListener("keydown", event => { if (event.key === "Enter") unlock(); });\n',
]:
    if marker in web:
        web = web.replace(marker, marker + '    hardenPinInputs(document.getElementById("lifeRouteAuthGate"));\n', 1)

web_path.write_text(web)
print("Local login now verifies every Keychain write and uses hardened masked text PIN inputs with explicit focus/input handling.")
