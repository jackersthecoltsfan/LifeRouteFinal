from pathlib import Path

path = Path("LifeRoute/Web/auth-gate.js")
text = path.read_text()

old = '''    if (evt.type === "authCredentialSaved") {
      if (!evt.success) {
        setBusy(false);
        setStatus(evt.message || "Could not save the login.", "error");
        return;
      }
      if (pendingBiometricEnable) {
'''
new = '''    if (evt.type === "authCredentialSaved") {
      if (!evt.success) {
        setBusy(false);
        setStatus(evt.message || "Could not save the login.", "error");
        return;
      }
      nativeConfigured = true;
      if (pendingBiometricEnable) {
'''

if "nativeConfigured = true;\n      if (pendingBiometricEnable)" not in text:
    if old not in text:
        raise SystemExit("Could not locate first-time auth credential callback")
    text = text.replace(old, new, 1)

path.write_text(text)
print("First-time Face ID setup handoff hardened.")
