from pathlib import Path

auth = Path("LifeRoute/Web/auth-gate.js").read_text()
swift = Path("LifeRoute/LifeRouteWebView.swift").read_text()
plist = Path("LifeRoute/Info.plist").read_text()
prepare = Path("scripts/prepare_build.sh").read_text()
patch = Path("scripts/patch_auth_keychain_reliability_v1.py").read_text()

checks = []
def require(condition, label): checks.append((bool(condition), label))

# v0.4.0 local app authentication is intentionally dormant. The loaded web
# module must be inert and must not own startup, render a gate, or intercept UI.
for marker in [
    '__lifeRouteAuthGateDisabledV040',
    'const AUTH_GATE_ENABLED = 0',
    'cleanupLegacyGate',
    'return false;',
]:
    require(marker in auth, f"disabled startup auth contains {marker}")

for forbidden in [
    'Create your login',
    'Confirm PIN',
    'Welcome back',
    'const start = () =>',
    'renderLoading();',
    'renderLogin(',
    'renderSetup(',
    'setInterval(',
    'derivePin(',
    'crypto.subtle',
    'post({ action: "authStatus"',
    'document.body.appendChild',
]:
    require(forbidden not in auth, f"legacy auth startup behavior absent: {forbidden}")

# Keep the native security implementation intact for a future redesign, without
# invoking it on v0.4.0's startup path.
for marker in [
    'import Security',
    'import LocalAuthentication',
    'kSecClassGenericPassword',
    'kSecAttrAccessibleWhenUnlockedThisDeviceOnly',
    'return SecItemAdd(item as CFDictionary, nil) == errSecSuccess',
    'deleteAuthKeychain(account: "username")',
    'pin.range(of: "^[0-9]{4}$"',
    'LAContext()',
    '.deviceOwnerAuthenticationWithBiometrics',
]:
    require(marker in swift, f"preserved native auth contract contains {marker}")

require('NSFaceIDUsageDescription' in plist, "Existing Face ID usage description remains valid for dormant infrastructure")
require('patch_auth_gate.py' in prepare, "Native auth bridge patch remains deterministic")
require('patch_auth_keychain_reliability_v1.py' in prepare, "v0.4.0 compatibility patch runs during deterministic preparation")
require('__lifeRouteAuthGateDisabledV040' in patch, "compatibility patch disables web gate after preserving native bridge")
require('https://www.googleapis.com/auth/calendar.readonly' in swift, "Google Calendar OAuth remains read-only")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute v0.4.0 auth/startup contract audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Direct app startup, non-intercepting auth compatibility, preserved Keychain/biometric infrastructure, and unrelated Google OAuth scope passed.")
