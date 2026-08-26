from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTH = ROOT / "LifeRoute" / "Web" / "auth-gate.js"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
PATCH = ROOT / "scripts" / "patch_auth_keychain_reliability_v1.py"

errors = []

def require(condition, message):
    if not condition:
        errors.append(message)


auth = AUTH.read_text()
swift = SWIFT.read_text()
prepare = PREPARE.read_text()
patch = PATCH.read_text()

# v0.4.0 must launch straight into the product. The web auth module may remain
# in the startup list only as an inert compatibility stub.
for marker in [
    "__lifeRouteAuthGateDisabledV040",
    "const AUTH_GATE_ENABLED = 0",
    "cleanupLegacyGate",
    "enabled: !!AUTH_GATE_ENABLED",
]:
    require(marker in auth, f"v0.4.0 disabled-auth marker missing: {marker}")

for forbidden in [
    "Create your login",
    "Welcome back",
    "renderLoading",
    "renderLogin",
    "renderSetup",
    "setInterval",
    "PBKDF2",
    "authStatus\" });",
    "lrAuthGate{position:fixed",
]:
    require(forbidden not in auth, f"Legacy startup auth behavior must be absent: {forbidden}")

# Defensive cleanup is allowed, but the stub must never create the overlay.
require('document.createElement("div")' not in auth, "Auth stub must not create a blocking overlay")
require('document.body.appendChild' not in auth, "Auth stub must not append a startup gate")
require('patch_auth_keychain_reliability_v1.py' in prepare, "Deterministic auth compatibility patch must run")
require('__lifeRouteAuthGateDisabledV040' in patch, "Build patch must deterministically disable the web auth gate")

# Preserve the dormant native security infrastructure for future redesign.
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

print("v0.4.0 auth audit passed: startup is ungated, no overlay can intercept taps, native auth infrastructure is preserved, and Google OAuth remains intact/read-only.")
