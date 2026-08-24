// Browser-only resilient store search. The primary web-routing bridge uses
// Overpass; this helper falls back to bounded Nominatim brand searches if that
// service returns no branches or stalls on mobile Safari.
(() => {
  if (window.__lifeRouteWebStoreFallbackLoaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebStoreFallbackLoaded = true;

  const previousPostNative = window.postNative;
  const pending = new Map();
  const clean = value => String(value || "").trim();
  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  const N_URL = "https://nominatim.openstreetmap.org/search";

  const currentLocation = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("Browser location unavailable"));
    navigator.geolocation.getCurrentPosition(
      position => resolve({ latitude:Number(position.coords.latitude), longitude:Number(position.coords.longitude) }),
      error => reject(error),
      { enableHighAccuracy:true, timeout:10000, maximumAge:120000 }
    );
  });

  const centerFor = async payload => {
    const points = [];
    for (const address of (payload.nearAddresses || []).slice(0,3)) {
      try {
        const point = await window.LifeRouteWebRouting?.geocode?.(address);
        if (point?.latitude != null && point?.longitude != null) points.push(point);
      } catch (_) {}
    }
    if (!points.length) {
      try { points.push(await currentLocation()); } catch (_) {}
    }
    if (!points.length) throw new Error("Could not locate this part of the route");
    return {
      latitude: points.reduce((sum,p) => sum + Number(p.latitude),0) / points.length,
      longitude: points.reduce((sum,p) => sum + Number(p.longitude),0) / points.length
    };
  };

  const fetchBrand = async (brand, center, limit) => {
    const latSpan = .34;
    const lonSpan = .42;
    const left = center.longitude - lonSpan;
    const right = center.longitude + lonSpan;
    const top = center.latitude + latSpan;
    const bottom = center.latitude - latSpan;
    const params = new URLSearchParams({
      format:"jsonv2",
      q: brand,
      limit:String(Math.max(2,Math.min(6,limit || 4))),
      countrycodes:"us",
      addressdetails:"1",
      bounded:"1",
      viewbox:`${left},${top},${right},${bottom}`
    });
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(),14000);
    try {
      const response = await fetch(`${N_URL}?${params.toString()}`, {
        headers:{"Accept":"application/json","Accept-Language":"en-US,en;q=.8"},
        signal:controller.signal,
        cache:"no-store"
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return (Array.isArray(data) ? data : []).map(item => ({
        brand,
        name: clean(item.name) || clean(item.display_name).split(",")[0] || brand,
        address: clean(item.display_name) || brand,
        latitude:Number(item.lat),
        longitude:Number(item.lon)
      })).filter(item => Number.isFinite(item.latitude) && Number.isFinite(item.longitude));
    } finally { clearTimeout(timer); }
  };

  const deliver = evt => {
    const handler = window.lifeRouteNativeEvent;
    if (typeof handler === "function") setTimeout(() => handler(evt),0);
  };

  const fallback = async requestID => {
    const state = pending.get(requestID);
    if (!state || state.finished || state.fallbackRunning) return;
    state.fallbackRunning = true;
    clearTimeout(state.timer);
    try {
      const center = await centerFor(state.payload);
      const brands = Array.from(new Set((state.payload.queries || []).map(clean).filter(Boolean))).slice(0,5);
      const all = [];
      for (let i=0;i<brands.length;i+=1) {
        if (i) await wait(1050);
        try { all.push(...await fetchBrand(brands[i],center,state.payload.limitPerQuery || 4)); } catch (_) {}
      }
      const seen = new Set();
      const locations = all.filter(item => {
        const key = `${item.brand.toLowerCase()}|${item.latitude.toFixed(4)}|${item.longitude.toFixed(4)}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      }).slice(0,18);
      state.finished = true;
      pending.delete(requestID);
      deliver({ type:"storeLocations", requestID, locations, source:"web-nominatim-fallback", error:locations.length ? "" : "No nearby branches found" });
    } catch (error) {
      state.finished = true;
      pending.delete(requestID);
      deliver({ type:"storeLocations", requestID, locations:[], source:"web-nominatim-fallback", error:error?.message || "Store search unavailable" });
    }
  };

  // Intercept store results from the primary bridge. Successful results pass
  // through untouched. Empty/error results trigger the fallback instead of
  // immediately painting a dead "no branches" state.
  const installEventWrapper = () => {
    const existing = window.lifeRouteNativeEvent;
    if (existing?.__webStoreFallbackWrapped) return;
    const wrapped = function lifeRouteNativeEventWithWebStoreFallback(evt) {
      if (evt?.type === "storeLocations") {
        const id = String(evt.requestID || "");
        const state = pending.get(id);
        if (state && !state.finished) {
          const locations = Array.isArray(evt.locations) ? evt.locations : [];
          if (!locations.length || evt.error) {
            fallback(id);
            return;
          }
          state.finished = true;
          clearTimeout(state.timer);
          pending.delete(id);
        }
      }
      if (typeof existing === "function") existing(evt);
    };
    wrapped.__webStoreFallbackWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const wrappedPostNative = function lifeRouteWebPostNativeWithStoreFallback(payload) {
    if (clean(payload?.action) !== "searchStoreLocations") {
      return typeof previousPostNative === "function" ? previousPostNative(payload) : false;
    }
    installEventWrapper();
    const requestID = clean(payload?.requestID);
    if (!requestID) return typeof previousPostNative === "function" ? previousPostNative(payload) : false;
    const state = { payload, finished:false, fallbackRunning:false, timer:null };
    pending.set(requestID,state);
    state.timer = setTimeout(() => fallback(requestID),6500);
    const handled = typeof previousPostNative === "function" ? previousPostNative(payload) : false;
    if (!handled) setTimeout(() => fallback(requestID),0);
    return true;
  };

  window.postNative = wrappedPostNative;
  try { postNative = wrappedPostNative; } catch (_) {}
  installEventWrapper();
  [300,900,1800].forEach(delay => setTimeout(installEventWrapper,delay));
})();