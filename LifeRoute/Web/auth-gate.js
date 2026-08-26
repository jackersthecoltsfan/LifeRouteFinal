// LifeRoute v0.4.0 startup authentication policy.
// The legacy local login UI is intentionally disabled for this release.
(() => {
  const AUTH_GATE_ENABLED = 0;
  window.__lifeRouteAuthGateLoaded = true;
  window.__lifeRouteAuthGateDisabledV040 = true;

  // Defensive cleanup removes any stale legacy gate/style left by an older
  // runtime. This module never creates a replacement overlay.
  const cleanupLegacyGate = () => {
    document.getElementById("lifeRouteAuthGate")?.remove();
    document.getElementById("lifeRouteAuthStyles")?.remove();
  };

  cleanupLegacyGate();
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", cleanupLegacyGate, { once: true });
  }

  // Compatibility only. Locking cannot recreate the legacy v0.3.x gate.
  window.LifeRouteAuth = Object.freeze({
    enabled: !!AUTH_GATE_ENABLED,
    lock() {
      cleanupLegacyGate();
      return false;
    }
  });
})();
