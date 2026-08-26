from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTH = ROOT / "LifeRoute" / "Web" / "auth-gate.js"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
PATCH = ROOT / "scripts" / "patch_auth_keychain_reliability_v1.py"
DISABLE_PATCH = ROOT / "scripts" / "patch_disable_auth_gate_v1.py"

errors = []

def require(condition, message):
    if not condition:
        errors.append(message)


auth = AUTH.read_text()
swift = SWIFT.read_text()
prepare = PREPARE.read_text()
patch = PATCH.read_text()
disable_patch = DISABLE_PATCH.read_text()

# v0.4.0 must launch straight into the product. The legacy implementation may
# remain recoverable below the bypass, but none of it may execute on startup.
for marker in [
    "__lifeRouteAuthGateDisabledV040",
    "const AUTH_GATE_ENABLED = 0",
    "if (!AUTH_GATE_ENABLED)",
    "removeDisabledAuthUI",
    "window.LifeRouteAuth = { enabled: false",
]:
    require(marker in auth, f"v0.4.0 startup-bypass marker missing: {marker}")

bypass_pos = auth.find("if (!AUTH_GATE_ENABLED)")
return_pos = auth.find("    return;", bypass_pos)
require(bypass_pos >= 0 and return_pos > bypass_pos, "Auth bypass returns before legacy implementation")
for marker, label in [
    ('const derivePin = async', "PIN derivation"),
    ('const styles = document.createElement("style")', "auth style creation"),
    ('const renderLoading =', "auth loading UI"),
    ('const start = () =>', "auth startup"),
    ('post({ action: "authStatus"', "native auth-status request"),
]:
    pos = auth.find(marker, bypass_pos)
    require(pos > return_pos, f"Auth bypass precedes {label}")

for marker in [
    'document.getElementById("lifeRouteAuthGate")?.remove()',
    'document.getElementById("lifeRouteAuthStyles")?.remove()',
    'document.getElementById("lifeRouteAuthSettingsSection")?.remove()',
]:
    require(marker in auth, f"Stale auth UI cleanup missing: {marker}")

require('patch_auth_keychain_reliability_v1.py' in prepare, "Deterministic auth compatibility patch must run")
require('runpy.run_path("scripts/patch_disable_auth_gate_v1.py"' in patch, "Keychain patch must apply the startup bypass deterministically")
require('const AUTH_GATE_ENABLED = 0' in disable_patch, "Startup-bypass patch must remain disabled for v0.4.0")

# Preserve dormant native security infrastructure for a later redesign.
for marker in [
    "import LocalAuthentication",
    "authKeychainService",
    "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
    "authSetCredentials",
    "authVerifyCredentials",
    "authBiometricUnlock",
]:
    require(marker in swift, f"Dormant native auth infrastructure missing: {marker}")

# Removing LifeRoute's local gate must not weaken provider authentication.
require('https://www.googleapis.com/auth/calendar.readonly' in swift, "Google Calendar OAuth must remain read-only")
require('ASWebAuthenticationSession' in swift, "Google OAuth native authentication session must remain intact")

if errors:
    print("v0.4.0 startup-auth audit failed:")
    for item in errors:
        print(f"- {item}")
    raise SystemExit(1)

print("v0.4.0 auth audit passed: legacy auth returns before startup work, no overlay can intercept taps, native auth infrastructure is preserved, and Google OAuth remains intact/read-only.")
