from pathlib import Path

path = Path("LifeRoute/Web/auth-gate.js")
text = path.read_text()

marker = '''  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;
'''
block = '''  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;

  // Login is intentionally disabled for this release. Keep the authentication
  // implementation below recoverable, but do not mount a gate or security row.
  const AUTH_GATE_ENABLED = false;
  if (!AUTH_GATE_ENABLED) {
    const removeDisabledAuthUI = () => {
      document.getElementById("lifeRouteAuthGate")?.remove();
      document.getElementById("lifeRouteAuthSettingsSection")?.remove();
      document.documentElement.removeAttribute("data-life-route-auth-locked");
      document.body?.removeAttribute("data-life-route-auth-locked");
    };
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", removeDisabledAuthUI, { once: true });
    } else {
      removeDisabledAuthUI();
    }
    window.LifeRouteAuth = { enabled: false, lock() { removeDisabledAuthUI(); } };
    document.dispatchEvent(new CustomEvent("liferoute-auth-disabled"));
    return;
  }
'''

if "const AUTH_GATE_ENABLED = false;" not in text:
    if marker not in text:
        raise SystemExit("Could not locate auth-gate bootstrap marker")
    text = text.replace(marker, block, 1)

path.write_text(text)
print("LifeRoute login/PIN gate disabled for this release; app opens directly.")
