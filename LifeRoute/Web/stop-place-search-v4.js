// LifeRoute stop/place search v4.
// One interaction owner for Find a stop searches. The search UI lives outside
// the Day timeline so route/calendar rerenders cannot destroy it mid-request.
(() => {
  if (window.__lifeRouteStopPlaceSearchV4Loaded) return;
  window.__lifeRouteStopPlaceSearchV4Loaded = true;

  const isNative = !!window.webkit?.messageHandlers?.lifeRoute;
  const PHOTON_URL = "https://photon.komoot.io/api/";
  const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
  const clean = value => String(value || "").trim();
  const safe = value => clean(value).replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"})[ch]);
  const normalize = value => clean(value).toLowerCase().replace(/[^a-z0-9]+/g, "");
  const clamp = (value, min, max) => Math.max(min, Math.min(max, Number(value) || 0));
  const todosState = () => Array.isArray(window.lifeRouteTodos) ? window.lifeRouteTodos : [];
  const placesState = () => Array.isArray(window.places) ? window.places : [];
  const prefsState = () => window.prefs || {};
  const selectedDay = () => clean(window.selectedDate || "");
  const dayEvents = () => typeof window.dayEvents === "function" ? window.dayEvents(selectedDay()) : [];
  const homeAddress = () => clean(prefsState()?.homeAddress) || clean(placesState().find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const todayKey = () => typeof window.localDateKey === "function" ? window.localDateKey(new Date()) : "";

  let state = null;
  let runToken = 0;
  let nativeCounter = 0;
  const nativePending = new Map();

  const contextFor = mode => {
    const list = dayEvents();
    if (!list.length) return null;
    const home = homeAddress();
    if (mode === "before") {
      const live = window.nativeState?.currentLocation;
      const useLive = selectedDay() === todayKey() && live?.latitude != null && live?.longitude != null;
      return {
        origin: useLive
          ? { label: "Live location", latitude: Number(live.latitude), longitude: Number(live.longitude) }
          : home ? { label: "Home", address: home } : { label: "Live location" },
        final: { label: clean(list[0]?.title) || "First appointment", address: clean(list[0]?.address) }
      };
    }
    const last = list.at(-1);
    return {
      origin: { label: clean(last?.title) || "Last appointment", address: clean(last?.address) },
      final: home ? { label: "Home", address: home } : null
    };
  };

  const ensureSheet = () => {
    let overlay = document.getElementById("lifeRouteStopSearchV4");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteStopSearchV4";
    overlay.className = "lrStopSearchOverlay";
    overlay.innerHTML = `
      <div class="lrStopSearchSheet" role="dialog" aria-modal="true" aria-labelledby="lrStopSearchTitle">
        <div class="lrStopSearchHandle"></div>
        <div class="lrStopSearchHead">
          <div class="grow"><div class="small">FIND A STOP</div><div class="title" id="lrStopSearchTitle">Search nearby</div><div class="meta" id="lrStopSearchRoute"></div></div>
          <button type="button" class="lrStopSearchClose" data-lr-stop-search-close aria-label="Close">×</button>
        </div>
        <form class="lrStopSearchForm" data-lr-stop-search-form>
          <input id="lrStopSearchInput" type="search" autocomplete="off" enterkeyhint="search" placeholder="Coffee, gym, pharmacy, Walmart…">
          <button type="submit" class="goldButton">Search</button>
        </form>
        <div class="lrStopSearchQuick">
          <button type="button" data-lr-stop-query="Coffee">Coffee</button>
          <button type="button" data-lr-stop-query="Grocery">Grocery</button>
          <button type="button" data-lr-stop-query="Gym">Gym</button>
          <button type="button" data-lr-stop-query="Pharmacy">Pharmacy</button>
          <button type="button" data-lr-stop-query="Gas station">Gas</button>
          <button type="button" data-lr-stop-query="Park">Park</button>
        </div>
        <div class="lrStopSearchBody" id="lrStopSearchBody"></div>
      </div>`;
    document.body.appendChild(overlay);
    return overlay;
  };

  const styles = document.createElement("style");
  styles.id = "lifeRouteStopSearchV4Styles";
  styles.textContent = `
    .lrStopSearchOverlay{position:fixed;inset:0;z-index:65000;display:none;align-items:flex-end;justify-content:center;padding:10px;background:rgba(2,7,14,.72);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
    .lrStopSearchOverlay.show{display:flex}.lrStopSearchSheet{width:min(690px,100%);max-height:88vh;overflow:auto;padding:15px;border:1px solid var(--line);border-radius:24px 24px 18px 18px;background:color-mix(in srgb,var(--panel) 97%,#07111f);box-shadow:0 30px 90px rgba(0,0,0,.48)}
    .lrStopSearchHandle{width:42px;height:4px;border-radius:99px;background:var(--line);margin:0 auto 12px}.lrStopSearchHead{display:flex;align-items:flex-start;gap:10px}.lrStopSearchHead .small{font-size:8px!important;font-weight:950;letter-spacing:.1em;color:var(--gold)}.lrStopSearchHead .title{font-size:18px!important;margin-top:1px}.lrStopSearchHead .meta{font-size:9px!important;margin-top:2px;color:var(--muted)}
    .lrStopSearchClose{width:34px;height:34px;min-height:34px!important;padding:0!important;border-radius:999px!important;border:1px solid var(--line);background:var(--panel2);color:var(--text);font-size:20px}.lrStopSearchForm{display:grid;grid-template-columns:1fr auto;gap:7px;margin-top:13px}.lrStopSearchForm input{min-height:44px!important}.lrStopSearchForm button{min-width:88px}.lrStopSearchQuick{display:flex;gap:6px;overflow-x:auto;padding:9px 0 3px;scrollbar-width:none}.lrStopSearchQuick::-webkit-scrollbar{display:none}.lrStopSearchQuick button{flex:0 0 auto;min-height:32px;padding:6px 10px;border:1px solid var(--line);border-radius:999px;background:var(--panel2);color:var(--muted);font-size:9px}
    .lrStopSearchBody{display:grid;gap:7px;margin-top:10px}.lrStopSearchStatus{padding:12px;border-radius:13px;border:1px solid var(--line);background:color-mix(in srgb,var(--panel2) 68%,transparent)}.lrStopSearchStatus b,.lrStopSearchStatus span{display:block}.lrStopSearchStatus b{font-size:11px}.lrStopSearchStatus span{font-size:9px;color:var(--muted);margin-top:3px;line-height:1.35}.lrStopResult{width:100%;min-height:58px;padding:10px 11px;display:flex;align-items:center;gap:10px;text-align:left;border:1px solid var(--line);border-radius:13px;background:color-mix(in srgb,var(--panel2) 70%,transparent);color:var(--text)}.lrStopResultIcon{width:30px;height:30px;display:grid;place-items:center;border-radius:9px;background:color-mix(in srgb,var(--blue) 8%,var(--panel));border:1px solid var(--line);flex:0 0 auto}.lrStopResult strong,.lrStopResult small{display:block}.lrStopResult strong{font-size:11px}.lrStopResult small{font-size:8.5px;color:var(--muted);margin-top:2px;line-height:1.3}.lrStopResultMeta{font-size:8.5px;color:var(--gold);white-space:nowrap}.lrBoundaryPlaceSearchAction{width:100%;margin:0 0 8px;min-height:38px!important;padding:8px 10px!important;font-size:10px!important}
    @media(max-width:520px){.lrStopSearchOverlay{padding:7px}.lrStopSearchSheet{padding:13px;max-height:90vh}.lrStopSearchForm{grid-template-columns:1fr auto}.lrStopSearchForm button{min-width:76px}}
  `;
  document.head.appendChild(styles);

  const fetchJSON = async (url, timeout = 11000) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(url, { cache: "no-store", signal: controller.signal, headers: { "Accept": "application/json", "Accept-Language": "en-US,en;q=0.8" } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } finally { clearTimeout(timer); }
  };

  const currentPosition = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("Location unavailable"));
    navigator.geolocation.getCurrentPosition(
      position => resolve({ latitude: Number(position.coords.latitude), longitude: Number(position.coords.longitude) }),
      error => reject(new Error(error?.message || "Location unavailable")),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 120000 }
    );
  });

  const featurePoint = feature => {
    const c = feature?.geometry?.coordinates;
    const longitude = Number(Array.isArray(c) ? c[0] : NaN);
    const latitude = Number(Array.isArray(c) ? c[1] : NaN);
    return Number.isFinite(latitude) && Number.isFinite(longitude) ? { latitude, longitude } : null;
  };

  const photonAddress = p => {
    const street = [clean(p?.housenumber), clean(p?.street)].filter(Boolean).join(" ");
    const city = clean(p?.city || p?.town || p?.village || p?.county);
    const statePart = [clean(p?.state || p?.statecode), clean(p?.postcode)].filter(Boolean).join(" ");
    return [street, [city, statePart].filter(Boolean).join(", ")].filter(Boolean).join(", ");
  };

  const nominatimAddress = item => clean(item?.display_name);
  const radians = degrees => Number(degrees) * Math.PI / 180;
  const distanceMeters = (a, b) => {
    if (!a || !b) return 0;
    const earth = 6371000;
    const dLat = radians(b.latitude - a.latitude);
    const dLon = radians(b.longitude - a.longitude);
    const lat1 = radians(a.latitude);
    const lat2 = radians(b.latitude);
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
    return 2 * earth * Math.asin(Math.min(1, Math.sqrt(h)));
  };

  const photonSearch = async (query, center, limit = 10) => {
    const params = new URLSearchParams({ q: query, limit: String(clamp(limit, 1, 12)), lang: "en" });
    if (center) { params.set("lat", String(center.latitude)); params.set("lon", String(center.longitude)); }
    const data = await fetchJSON(`${PHOTON_URL}?${params}`);
    return (Array.isArray(data?.features) ? data.features : []).map(feature => {
      const point = featurePoint(feature);
      if (!point) return null;
      const p = feature.properties || {};
      const name = clean(p.name || p.brand || p.operator || query);
      return { name: name || query, address: photonAddress(p) || clean(p.city) || name || query, ...point, source: "photon" };
    }).filter(Boolean);
  };

  const nominatimSearch = async (query, center, limit = 10) => {
    const params = new URLSearchParams({ q: query, format: "jsonv2", addressdetails: "1", limit: String(clamp(limit, 1, 12)), countrycodes: "us" });
    if (center) {
      const lon = Number(center.longitude), lat = Number(center.latitude);
      params.set("viewbox", `${lon - .7},${lat + .55},${lon + .7},${lat - .55}`);
      params.set("bounded", "0");
    }
    const data = await fetchJSON(`${NOMINATIM_URL}?${params}`);
    return (Array.isArray(data) ? data : []).map(item => {
      const latitude = Number(item?.lat), longitude = Number(item?.lon);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
      const name = clean(item?.name || item?.display_name?.split(",")[0] || query);
      return { name: name || query, address: nominatimAddress(item) || name || query, latitude, longitude, source: "nominatim" };
    }).filter(Boolean);
  };

  const geocodeFirst = async address => {
    const raw = clean(address);
    if (!raw) return null;
    try {
      const data = await photonSearch(raw, null, 2);
      return data[0] ? { latitude: data[0].latitude, longitude: data[0].longitude } : null;
    } catch (_) { return null; }
  };

  const centerFor = async context => {
    if (context?.origin?.latitude != null && context?.origin?.longitude != null) {
      return { latitude: Number(context.origin.latitude), longitude: Number(context.origin.longitude) };
    }
    if (!isNative && /live location/i.test(clean(context?.origin?.label))) {
      try { return await currentPosition(); } catch (_) {}
    }
    const candidates = [context?.origin?.address, context?.final?.address].map(clean).filter(Boolean);
    for (const candidate of candidates) {
      const point = await geocodeFirst(candidate);
      if (point) return point;
    }
    if (!isNative) {
      try { return await currentPosition(); } catch (_) {}
    }
    return null;
  };

  const dedupeRank = (items, center) => {
    const seen = new Set();
    return items.map(item => ({ ...item, distanceFromCenter: center ? distanceMeters(center, item) : 0 }))
      .sort((a, b) => Number(a.distanceFromCenter || 0) - Number(b.distanceFromCenter || 0))
      .filter(item => {
        const key = `${normalize(item.name)}|${Number(item.latitude).toFixed(4)}|${Number(item.longitude).toFixed(4)}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      }).slice(0, 18);
  };

  const browserSearch = async (queries, context) => {
    const center = await centerFor(context);
    const uniqueQueries = Array.from(new Set(queries.map(clean).filter(Boolean))).slice(0, 5);
    const jobs = [];
    uniqueQueries.forEach(query => {
      jobs.push(photonSearch(query, center, 10));
      jobs.push(nominatimSearch(query, center, 8));
    });
    const settled = await Promise.allSettled(jobs);
    const results = settled.flatMap(result => result.status === "fulfilled" ? result.value : []);
    if (!results.length) throw new Error("No nearby matches found. Try a broader search.");
    return dedupeRank(results, center);
  };

  const installNativeHook = () => {
    if (!isNative) return;
    const current = window.lifeRouteNativeEvent;
    if (current?.__lifeRouteStopSearchV4Wrapped) return;
    const wrapped = function lifeRouteNativeEventWithStopSearchV4(evt) {
      if (typeof current === "function") current(evt);
      if (evt?.type !== "storeLocations") return;
      const pending = nativePending.get(clean(evt.requestID));
      if (!pending) return;
      nativePending.delete(clean(evt.requestID));
      clearTimeout(pending.timer);
      if (Array.isArray(evt.locations) && evt.locations.length) pending.resolve(evt.locations);
      else pending.reject(new Error(clean(evt.error) || "No nearby matches found."));
    };
    wrapped.__lifeRouteStopSearchV4Wrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const nativeSearch = (queries, context) => new Promise((resolve, reject) => {
    installNativeHook();
    const requestID = `stop-search-v4-${++nativeCounter}-${Date.now()}`;
    const nearAddresses = [context?.origin?.address, context?.final?.address].map(clean).filter(Boolean);
    const timer = setTimeout(() => {
      nativePending.delete(requestID);
      reject(new Error("Search timed out. Try again."));
    }, 18000);
    nativePending.set(requestID, { resolve, reject, timer });
    const handled = typeof window.postNative === "function" && window.postNative({ action: "searchStoreLocations", requestID, queries, nearAddresses, limitPerQuery: 8 });
    if (!handled) {
      clearTimeout(timer);
      nativePending.delete(requestID);
      reject(new Error("Search service is unavailable."));
    }
  });

  const renderResults = locations => {
    const body = document.getElementById("lrStopSearchBody");
    if (!body || !state) return;
    state.locations = locations;
    if (!locations.length) {
      body.innerHTML = '<div class="lrStopSearchStatus"><b>No nearby matches</b><span>Try another word or a broader category.</span></div>';
      return;
    }
    body.innerHTML = locations.map((location, index) => {
      const mi = Number(location.distanceFromCenter || 0) / 1609.344;
      return `<button type="button" class="lrStopResult" data-lr-stop-result="${index}"><span class="lrStopResultIcon">⌖</span><span class="grow"><strong>${safe(location.name || location.brand || "Place")}</strong><small>${safe(location.address || "Nearby")}</small></span><span class="lrStopResultMeta">${mi > .05 ? `${mi.toFixed(mi < 10 ? 1 : 0)} mi` : "Add"}</span></button>`;
    }).join("");
  };

  const runSearch = async queries => {
    if (!state) return;
    const token = ++runToken;
    const body = document.getElementById("lrStopSearchBody");
    const input = document.getElementById("lrStopSearchInput");
    const cleaned = Array.from(new Set((Array.isArray(queries) ? queries : [queries]).map(clean).filter(Boolean)));
    if (!cleaned.length) { input?.focus(); return; }
    if (input && cleaned.length === 1) input.value = cleaned[0];
    if (body) body.innerHTML = `<div class="lrStopSearchStatus"><b>Searching…</b><span>${safe(cleaned.join(" · "))}</span></div>`;
    try {
      const locations = isNative ? await nativeSearch(cleaned, state.context) : await browserSearch(cleaned, state.context);
      if (!state || token !== runToken) return;
      renderResults(Array.isArray(locations) ? locations : []);
    } catch (error) {
      if (!state || token !== runToken) return;
      if (body) body.innerHTML = `<div class="lrStopSearchStatus"><b>Search unavailable</b><span>${safe(error?.message || "Try again.")}</span></div>`;
    }
  };

  const openSheet = (mode, todo = null, autoQueries = []) => {
    const context = contextFor(mode);
    const overlay = ensureSheet();
    const route = overlay.querySelector("#lrStopSearchRoute");
    const input = overlay.querySelector("#lrStopSearchInput");
    const body = overlay.querySelector("#lrStopSearchBody");
    state = { mode, todo, context, locations: [] };
    if (route) route.textContent = [context?.origin?.label, "stop", context?.final?.label].filter(Boolean).join(" → ");
    if (input) input.value = autoQueries.length === 1 ? autoQueries[0] : "";
    if (body) body.innerHTML = '<div class="lrStopSearchStatus"><b>What do you need?</b><span>Search a place, category, or preferred store.</span></div>';
    overlay.classList.add("show");
    if (!context) {
      if (body) body.innerHTML = '<div class="lrStopSearchStatus"><b>Add a route first</b><span>This search needs a scheduled appointment with a location.</span></div>';
      return;
    }
    if (autoQueries.length) runSearch(autoQueries);
    else setTimeout(() => input?.focus(), 80);
  };

  const closeSheet = () => {
    ensureSheet().classList.remove("show");
    state = null;
    runToken += 1;
  };

  const decoratePanel = panel => {
    if (!panel || panel.querySelector("[data-lr-place-search-open]")) return;
    const mode = clean(panel.closest(".lrBoundaryGap")?.dataset.boundaryMode || panel.dataset.boundaryMode);
    if (!mode) return;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "secondary lrBoundaryPlaceSearchAction";
    button.dataset.lrPlaceSearchOpen = mode;
    button.textContent = "Search nearby places";
    const head = panel.querySelector(".lrBoundaryPickerHead");
    if (head?.nextSibling) panel.insertBefore(button, head.nextSibling); else panel.prepend(button);
  };

  const decorateOpenPanels = () => document.querySelectorAll("#timeline .lrBoundaryPanel,.gapSuggest").forEach(panel => {
    if (panel.dataset.lrBoundaryOpen === "1" || panel.style.display !== "none") decoratePanel(panel);
  });

  // Window capture is deliberately used: it fires before the older document
  // delegate and before browser-preview helper wrappers. Search has one owner.
  window.addEventListener("click", event => {
    const storeButton = event.target.closest?.("[data-boundary-stores]");
    if (storeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const todo = todosState().find(item => String(item.id) === String(storeButton.dataset.boundaryStores));
      const mode = clean(storeButton.closest(".lrBoundaryGap")?.dataset.boundaryMode);
      const queries = Array.isArray(todo?.storePreferences) ? todo.storePreferences.map(clean).filter(Boolean) : [];
      openSheet(mode, todo, queries.length ? queries : [clean(todo?.title) || "Grocery"]);
      return;
    }

    const openPlaceSearch = event.target.closest?.("[data-lr-place-search-open]");
    if (openPlaceSearch) {
      event.preventDefault();
      event.stopImmediatePropagation();
      openSheet(clean(openPlaceSearch.dataset.lrPlaceSearchOpen));
      return;
    }

    const close = event.target.closest?.("[data-lr-stop-search-close]");
    if (close) {
      event.preventDefault();
      event.stopImmediatePropagation();
      closeSheet();
      return;
    }

    const quick = event.target.closest?.("[data-lr-stop-query]");
    if (quick && state) {
      event.preventDefault();
      event.stopImmediatePropagation();
      runSearch([quick.dataset.lrStopQuery]);
      return;
    }

    const result = event.target.closest?.("[data-lr-stop-result]");
    if (result && state) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const location = state.locations[Number(result.dataset.lrStopResult)];
      if (!location) return;
      const saved = window.lifeRouteSaveBoundaryStop?.(state.mode, {
        kind: state.todo ? "store" : "place",
        id: state.todo?.id || `searched-${Date.now()}`,
        name: location.name || location.brand || state.todo?.title || "Stop",
        address: location.address || location.name || location.brand,
        stopMinutes: Number(state.todo?.duration || 30)
      });
      if (saved !== false) closeSheet();
      return;
    }

    const boundaryOpen = event.target.closest?.("[data-lr-boundary-open]");
    if (boundaryOpen) {
      setTimeout(decorateOpenPanels, 0);
      requestAnimationFrame(decorateOpenPanels);
    }
  }, true);

  document.addEventListener("submit", event => {
    const form = event.target.closest?.("[data-lr-stop-search-form]");
    if (!form || !state) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    runSearch([document.getElementById("lrStopSearchInput")?.value]);
  }, true);

  const observer = new MutationObserver(() => requestAnimationFrame(decorateOpenPanels));
  if (document.body) observer.observe(document.body, { childList: true, subtree: true });
  else document.addEventListener("DOMContentLoaded", () => observer.observe(document.body, { childList: true, subtree: true }), { once: true });

  if (isNative) {
    installNativeHook();
    [200, 700, 1800].forEach(delay => setTimeout(installNativeHook, delay));
  }
  setTimeout(decorateOpenPanels, 200);
  window.LifeRouteStopPlaceSearchV4 = { open: openSheet, search: runSearch, ready: true };
})();
