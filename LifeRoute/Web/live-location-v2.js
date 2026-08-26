// Foreground live-location lifecycle for LifeRoute.
// Native iPhone builds stream CoreLocation updates while visible. A short watchdog
// starts the browser geolocation fallback only if native posting succeeds but no fix arrives.
(() => {
  if (window.__lifeRouteLiveLocationV2Loaded) return;
  window.__lifeRouteLiveLocationV2Loaded = true;

  const ENABLED_KEY = 'liferoute_live_location_enabled_v2';
  const NATIVE_FIX_TIMEOUT_MS = 6500;
  let webWatch = null;
  let nativeStreaming = false;
  let nativeWatchdog = 0;
  let lastFixAt = 0;

  const isEnabled = () => { try { return localStorage.getItem(ENABLED_KEY) === '1'; } catch (_) { return false; } };
  const rememberEnabled = () => { try { localStorage.setItem(ENABLED_KEY,'1'); } catch (_) {} };
  const nativeBridgeAvailable = () => !!window.webkit?.messageHandlers?.lifeRoute;

  const clearNativeWatchdog = () => {
    if (nativeWatchdog) clearTimeout(nativeWatchdog);
    nativeWatchdog = 0;
  };

  const emitWebLocation = position => {
    const coords = position?.coords;
    if (!coords) return;
    lastFixAt = Date.now();
    window.lifeRouteNativeEvent?.({
      type:'currentLocation',status:'live',latitude:Number(coords.latitude),longitude:Number(coords.longitude),
      accuracyMeters:Number(coords.accuracy || 0),timestamp:new Date(position.timestamp || Date.now()).toISOString(),
      streaming:true,engine:'browser-geolocation'
    });
  };

  const emitWebError = error => {
    const denied = Number(error?.code) === 1;
    window.lifeRouteNativeEvent?.({
      type:'currentLocationStatus',status:denied?'denied':'error',message:String(error?.message || 'Location unavailable')
    });
  };

  const startWebFallback = () => {
    if (!navigator.geolocation || webWatch != null || document.visibilityState === 'hidden') return false;
    try {
      webWatch = navigator.geolocation.watchPosition(emitWebLocation,emitWebError,{enableHighAccuracy:true,maximumAge:12000,timeout:15000});
      return true;
    } catch (_) { return false; }
  };

  const stopWebFallback = () => {
    if (webWatch == null || !navigator.geolocation) return;
    try { navigator.geolocation.clearWatch(webWatch); } catch (_) {}
    webWatch = null;
  };

  const armNativeWatchdog = () => {
    clearNativeWatchdog();
    const started = Date.now();
    nativeWatchdog = setTimeout(() => {
      nativeWatchdog = 0;
      if (!isEnabled() || document.visibilityState === 'hidden') return;
      if (lastFixAt >= started) return;
      startWebFallback();
      if (typeof nativeState !== 'undefined' && !nativeState.currentLocation) nativeState.locationStatus = 'locating';
    },NATIVE_FIX_TIMEOUT_MS);
  };

  const start = (remember=false) => {
    if (remember) rememberEnabled();
    if (!isEnabled() || document.visibilityState === 'hidden') return false;

    if (nativeBridgeAvailable() && typeof postNative === 'function') {
      const posted = postNative({action:'startLiveLocation'});
      if (posted) {
        nativeStreaming = true;
        if (typeof nativeState !== 'undefined') nativeState.locationStatus = nativeState.currentLocation ? 'live' : 'locating-live';
        armNativeWatchdog();
        return true;
      }
    }

    nativeStreaming = false;
    clearNativeWatchdog();
    return startWebFallback();
  };

  const stop = () => {
    clearNativeWatchdog();
    if (nativeStreaming && nativeBridgeAvailable() && typeof postNative === 'function') postNative({action:'stopLiveLocation'});
    nativeStreaming = false;
    stopWebFallback();
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithLiveLocationFreshness(evt) {
    if (typeof previousNativeEvent === 'function') previousNativeEvent(evt);
    if (!evt?.type || typeof nativeState === 'undefined') return;
    if (evt.type === 'currentLocation') {
      lastFixAt = Date.now();
      clearNativeWatchdog();
      if (evt.engine !== 'browser-geolocation') stopWebFallback();
      nativeState.locationStatus = evt.streaming ? 'live' : 'ready';
      nativeState.locationStreaming = !!evt.streaming;
      nativeState.locationUpdatedAt = lastFixAt;
      nativeState.locationAccuracyMeters = Number(evt.accuracyMeters || 0);
    } else if (evt.type === 'currentLocationStatus') {
      const status = String(evt.status || nativeState.locationStatus || 'unknown');
      nativeState.locationStatus = status;
      if (['paused','denied','restricted','error'].includes(status)) {
        nativeState.locationStreaming = false;
        clearNativeWatchdog();
      }
      if (status === 'live' && !nativeState.currentLocation) armNativeWatchdog();
    }
  };

  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')start(false);else stop();});
  window.addEventListener('pageshow',()=>start(false));
  window.addEventListener('pagehide',stop);

  window.LifeRouteLiveLocation = {
    start:()=>start(true),stop,enabled:isEnabled,
    freshnessMs:()=>typeof nativeState !== 'undefined' && nativeState.locationUpdatedAt ? Date.now()-nativeState.locationUpdatedAt : Infinity,
    diagnostics:()=>({nativeBridge:nativeBridgeAvailable(),nativeStreaming,webFallback:webWatch!=null,lastFixAt})
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',()=>start(false),{once:true});
  else start(false);
})();
