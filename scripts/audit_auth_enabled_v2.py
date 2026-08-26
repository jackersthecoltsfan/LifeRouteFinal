from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTH = ROOT / "LifeRoute" / "Web" / "auth-gate.js"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PLIST = ROOT / "LifeRoute" / "Info.plist"
PREPARE = ROOT / "scripts" / "prepare_build.sh"

errors = []

def require(condition, message):
    if not condition:
        errors.append(message)


auth = AUTH.read_text()
swift = SWIFT.read_text()
plist = PLIST.read_text()
prepare = PREPARE.read_text()

require("const AUTH_GATE_ENABLED = false" not in auth, "Authentication gate must not be disabled")
require("patch_disable_auth_gate_v1.py" not in prepare, "Build prep must not disable authentication")
require("audit_auth_disabled_v1.py" not in prepare, "Disabled-auth audit must not run")
for marker in [
    "Create your login", "4-digit PIN", "PBKDF2", "liferoute_auth_browser_v2",
    "authBiometricUnlock", "authSetBiometricEnabled", "Face ID", "Use ${escapeHTML(biometricLabel)}",
]:
    require(marker in auth, f"Auth UI/runtime marker missing: {marker}")
for marker in [
    "import LocalAuthentication", "LAContext", "deviceOwnerAuthenticationWithBiometrics",
    "authBiometricUnlock", "authSetBiometricEnabled", "authKeychainService", "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
]:
    require(marker in swift, f"Native auth marker missing: {marker}")
require("NSFaceIDUsageDescription" in plist, "Face ID usage description missing")

if errors:
    print("Auth enabled audit failed:")
    for item in errors:
        print(f"- {item}")
    raise SystemExit(1)

print("Auth enabled audit passed: username/PIN + optional native biometrics are active.")
