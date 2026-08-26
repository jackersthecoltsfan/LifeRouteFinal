from pathlib import Path

path = Path("LifeRoute/Web/auth-gate.js")

stub = '''// LifeRoute v0.4.0 startup authentication policy.
//
// The legacy local username/PIN/biometric gate is intentionally disabled for
// this release because it proved unreliable on physical devices. The native
// Keychain/auth bridge remains available for a future authentication redesign,
// but this web module must never create a startup overlay, request auth status,
// poll the DOM, or intercept interaction.
(() => {
  const AUTH_GATE_ENABLED = false;
  window.__lifeRouteAuthGateLoaded = true;
  window.__lifeRouteAuthGateDisabledV040 = true;

  // Defensive cleanup protects upgrades from an older runtime that may have
  // left the legacy overlay or styles attached before this module executes.
  const cleanupLegacyGate = () => {
    document.getElementById("lifeRouteAuthGate")?.remove();
    document.getElementById("lifeRouteAuthStyles")?.remove();
  };

  cleanupLegacyGate();
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", cleanupLegacyGate, { once: true });
  }

  // Keep a compatibility surface so any stale internal caller cannot recreate
  // the old gate. Locking is deliberately a no-op in v0.4.0.
  window.LifeRouteAuth = Object.freeze({
    enabled: AUTH_GATE_ENABLED,
    lock() {
      cleanupLegacyGate();
      return false;
    }
  });
})();
'''

path.write_text(stub)
print("LifeRoute v0.4.0 local login gate disabled; native auth infrastructure preserved for future redesign.")
