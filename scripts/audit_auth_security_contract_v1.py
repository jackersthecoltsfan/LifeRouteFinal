from pathlib import Path

auth = Path("LifeRoute/Web/auth-gate.js").read_text()
swift = Path("LifeRoute/LifeRouteWebView.swift").read_text()
plist = Path("LifeRoute/Info.plist").read_text()
prepare = Path("scripts/prepare_build.sh").read_text()
patch = Path("scripts/patch_auth_keychain_reliability_v1.py").read_text()
disable_patch = Path("scripts/patch_disable_auth_gate_v1.py").read_text()

checks = []
def require(condition, label): checks.append((bool(condition), label))

# v0.4.0 local app authentication is dormant. Keep the old implementation
# recoverable, but prove the bypass returns before any blocking/expensive work.
for marker in [
    '__lifeRouteAuthGateDisabledV040',
    'const AUTH_GATE_ENABLED = 0',
    'if (!AUTH_GATE_ENABLED)',
    'removeDisabledAuthUI',
    'window.LifeRouteAuth = { enabled: false',
]:
    require(marker in auth, f"disabled startup auth contains {marker}")

bypass_pos = auth.find('if (!AUTH_GATE_ENABLED)')
return_pos = auth.find('    return;', bypass_pos)
require(bypass_pos >= 0 and return_pos > bypass_pos, 'disabled auth returns before legacy implementation')
for marker, label in [
    ('const derivePin = async', 'PIN derivation'),
    ('const styles = document.createElement("style")', 'auth style construction'),
    ('const renderLoading =', 'auth loading UI'),
    ('const installSettings =', 'security settings installation'),
    ('const start = () =>', 'auth startup'),
]:
    position = auth.find(marker, bypass_pos)
    require(position > return_pos, f'disabled auth return precedes {label}')

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
require('runpy.run_path("scripts/patch_disable_auth_gate_v1.py"' in patch, "auth reliability patch applies bypass deterministically")
require('const AUTH_GATE_ENABLED = 0' in disable_patch, "bypass patch stays disabled for v0.4.0")
require('https://www.googleapis.com/auth/calendar.readonly' in swift, "Google Calendar OAuth remains read-only")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute v0.4.0 auth/startup contract audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Direct app startup, pre-render auth bypass, preserved Keychain/biometric infrastructure, recoverable legacy implementation, and unrelated Google OAuth scope passed.")
