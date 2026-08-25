// Prevent a slow empty web-store response from erasing branches that a faster
// fallback already found for the same request.
(() => {
  if (window.__lifeRouteWebStoreLateGuardLoaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebStoreLateGuardLoaded = true;

  const successful = new Map();
  const previous = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithStoreLateGuard(evt) {
    if (evt?.type === "storeLocations") {
      const id = String(evt.requestID || "");
      const locations = Array.isArray(evt.locations) ? evt.locations : [];
      if (id && locations.length) successful.set(id, Date.now());
      if (id && !locations.length) {
        const when = successful.get(id);
        if (when && Date.now() - when < 45000) return;
      }
    }
    if (typeof previous === "function") previous(evt);
  };
})();
