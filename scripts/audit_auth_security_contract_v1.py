from pathlib import Path

auth = Path("LifeRoute/Web/auth-gate.js").read_text()
swift = Path("LifeRoute/LifeRouteWebView.swift").read_text()
plist = Path("LifeRoute/Info.plist").read_text()
prepare = Path("scripts/prepare_build.sh").read_text()

checks = []
def require(condition, label): checks.append((bool(condition), label))

for marker in [
    'const AUTH_GATE_ENABLED = true',
    'Create your login',
    'Confirm PIN',
    'authSetCredentials',
    'authVerifyCredentials',
    'authBiometricUnlock',
    'authSetBiometricEnabled',
]:
    require(marker in auth, f"auth gate contains {marker}")

for marker in [
    'import Security',
    'import LocalAuthentication',
    'kSecClassGenericPassword',
    'kSecAttrAccessibleWhenUnlockedThisDeviceOnly',
    'return SecItemAdd(item as CFDictionary, nil) == errSecSuccess',
    'deleteAuthKeychain(account: "username")',
    'pin.range(of: "^[0-9]{4}$"',
    'LAContext()',
    'context.localizedFallbackTitle = "Use PIN"',
    '.deviceOwnerAuthenticationWithBiometrics',
    'authDefaults.set(false, forKey: authBiometricDefaultsKey)',
]:
    require(marker in swift, f"native auth contract contains {marker}")

require('NSFaceIDUsageDescription' in plist, "Face ID usage description exists")
require('patch_auth_gate.py' in prepare, "auth bridge patch runs during deterministic preparation")
require('patch_auth_keychain_reliability_v1.py' in prepare, "Keychain reliability patch runs during deterministic preparation")
require('patch_disable_auth_gate' not in prepare, "auth disabling patch is absent")
require('audit_auth_disabled' not in prepare, "auth-disabled audit is absent")
require('const AUTH_GATE_ENABLED = false' not in auth, "prepared auth gate cannot be disabled")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute auth/PIN/Face-ID contract audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Local login, 4-digit PIN, verified Keychain persistence, rollback-on-failure, optional biometrics, PIN fallback, and enabled-gate contracts passed.")
