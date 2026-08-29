from pathlib import Path

path = Path("LifeRoute/Web/auth-gate.js")
text = path.read_text()

marker = '''  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;
'''
block = '''  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;

  // LifeRoute v0.4.0 launches directly into the app. Keep the legacy local
  // authentication implementation below recoverable for a later redesign, but
  // return before it creates styles/UI, performs PIN work, polls Settings, or
  // requests native authentication state.
  const AUTH_GATE_ENABLED = 0;
  if (!AUTH_GATE_ENABLED) {
    const removeDisabledAuthUI = () => {
      document.getElementById("lifeRouteAuthGate")?.remove();
      document.getElementById("lifeRouteAuthStyles")?.remove();
      document.getElementById("lifeRouteAuthSettingsSection")?.remove();
      document.documentElement.removeAttribute("data-life-route-auth-locked");
      document.body?.removeAttribute("data-life-route-auth-locked");
    };
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", removeDisabledAuthUI, { once: true });
    } else {
      removeDisabledAuthUI();
    }
    window.__lifeRouteAuthGateDisabledV040 = true;
    window.LifeRouteAuth = { enabled: false, lock() { removeDisabledAuthUI(); return false; } };
    document.dispatchEvent(new CustomEvent("liferoute-auth-disabled"));
    return;
  }
'''

if "const AUTH_GATE_ENABLED = 0;" not in text:
    if marker not in text:
        raise SystemExit("Could not locate auth-gate bootstrap marker")
    text = text.replace(marker, block, 1)

path.write_text(text)
print("LifeRoute v0.4.0 login/PIN gate bypassed before auth startup work; recoverable implementation preserved.")
