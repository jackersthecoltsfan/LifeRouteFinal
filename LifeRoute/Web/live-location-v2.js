// Foreground live-location lifecycle for LifeRoute.
// Native iPhone builds stream CoreLocation updates while the app is visible after the user enables location.
(() => {
  if (window.__lifeRouteLiveLocationV2Loaded) return;
  window.__lifeRouteLiveLocationV2Loaded = true;

  const ENABLED_KEY = "liferoute_live_location_enabled_v2";
  let webWatch = null;
  let nativeStreaming = false;

  const isEnabled = () => {
    try { return localStorage.getItem(ENABLED_KEY) === "1"; } catch (_) { return false; }
  };
  const rememberEnabled = () => {
    try { localStorage.setItem(ENABLED_KEY, "1"); } catch (_) {}
  };

  const emitWebLocation = position => {
    const coords = position?.coords;
    if (!coords) return;
    window.lifeRouteNativeEvent?.({
      type: "currentLocation",
      status: "live",
      latitude: Number(coords.latitude),
      longitude: Number(coords.longitude),
      accuracyMeters: Number(coords.accuracy || 0),
      timestamp: new Date(position.timestamp || Date.now()).toISOString(),
      streaming: true,
      engine: "browser-geolocation"
    });
  };

  const emitWebError = error => {
    const denied = Number(error?.code) === 1;
    window.lifeRouteNativeEvent?.({
      type: "currentLocationStatus",
      status: denied ? "denied" : "error",
      message: String(error?.message || "Location unavailable")
    });
  };

  const startWebFallback = () => {
    if (!navigator.geolocation || webWatch != null) return;
    try {
      webWatch = navigator.geolocation.watchPosition(emitWebLocation, emitWebError, {
        enableHighAccuracy: true,
        maximumAge: 12000,
        timeout: 15000
      });
    } catch (_) {}
  };

  const stopWebFallback = () => {
    if (webWatch == null || !navigator.geolocation) return;
    try { navigator.geolocation.clearWatch(webWatch); } catch (_) {}
    webWatch = null;
  };

  const start = (remember = false) => {
    if (remember) rememberEnabled();
    if (!isEnabled() || document.visibilityState === "hidden") return;
    const nativeAccepted = typeof postNative === "function" && postNative({ action: "startLiveLocation" });
    if (nativeAccepted) {
      nativeStreaming = true;
      stopWebFallback();
      if (typeof nativeState !== "undefined") nativeState.locationStatus = "live";
      return;
    }
    nativeStreaming = false;
    startWebFallback();
  };

  const stop = () => {
    if (nativeStreaming && typeof postNative === "function") postNative({ action: "stopLiveLocation" });
    nativeStreaming = false;
    stopWebFallback();
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithLiveLocationFreshness(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (!evt?.type || typeof nativeState === "undefined") return;
    if (evt.type === "currentLocation") {
      nativeState.locationStatus = evt.streaming ? "live" : "ready";
      nativeState.locationStreaming = !!evt.streaming;
      nativeState.locationUpdatedAt = Date.now();
      nativeState.locationAccuracyMeters = Number(evt.accuracyMeters || 0);
    } else if (evt.type === "currentLocationStatus") {
      nativeState.locationStatus = evt.status || nativeState.locationStatus || "unknown";
      if (["paused", "denied", "restricted", "error"].includes(String(evt.status || ""))) nativeState.locationStreaming = false;
    }
  };

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") start(false);
    else stop();
  });
  window.addEventListener("pageshow", () => start(false));
  window.addEventListener("pagehide", stop);

  window.LifeRouteLiveLocation = {
    start: () => start(true),
    stop,
    enabled: isEnabled,
    freshnessMs: () => typeof nativeState !== "undefined" && nativeState.locationUpdatedAt ? Date.now() - nativeState.locationUpdatedAt : Infinity
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => start(false), { once: true });
  else start(false);
})();
