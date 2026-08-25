// Web-only preferred-store picker v3.
// This loaded helper now owns Search stores at the window capture phase, before
// the core Day-card delegate can toggle or rebuild the boundary panel. Results
// live in a body-level sheet, so route-time rerenders cannot destroy the search.
(() => {
  if (window.__lifeRouteWebStoreSheetV3Loaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebStoreSheetV3Loaded = true;

  const clean = value => String(value || "").trim();
  const safe = value => clean(value).replace(/[&<>"']/g, ch => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  })[ch]);
  const miles = meters => Number(meters || 0) / 1609.344;
  const selectedDay = () => clean(window.selectedDate || "");
  const prefsState = () => window.prefs || {};
  const placesState = () => Array.isArray(window.places) ? window.places : [];
  const todosState = () => Array.isArray(window.lifeRouteTodos) ? window.lifeRouteTodos : [];
  const dayEvents = () => typeof window.dayEvents === "function" ? window.dayEvents(selectedDay()) : [];
  const homeAddress = () => clean(prefsState()?.homeAddress) || clean(placesState().find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const todayKey = () => typeof window.localDateKey === "function" ? window.localDateKey(new Date()) : "";

  let state = null;
  let searchToken = 0;

  const ensureSheet = () => {
    let overlay = document.getElementById("lifeRouteWebStoreSheetV3");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteWebStoreSheetV3";
    overlay.className = "lrWebStoreOverlay";
    overlay.innerHTML = `
      <div class="lrWebStoreSheet" role="dialog" aria-modal="true" aria-labelledby="lrWebStoreTitle">
        <div class="lrWebStoreHandle"></div>
        <div class="lrWebStoreHead">
          <div class="grow">
            <div class="small">STORE OPTIONS</div>
            <div class="title" id="lrWebStoreTitle">Nearby branches</div>
            <div class="meta" id="lrWebStoreSubtitle"></div>
          </div>
          <button type="button" class="lrWebStoreClose" data-web-store-close aria-label="Close">×</button>
        </div>
        <div class="lrWebStoreBody" id="lrWebStoreBody"></div>
      </div>`;
    document.body.appendChild(overlay);
    return overlay;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteWebStoreSheetV3Styles";
  style.textContent = `
    .lrWebStoreOverlay{position:fixed;inset:0;z-index:50000;display:none;align-items:flex-end;justify-content:center;padding:12px;background:rgba(2,7,14,.72);backdrop-filter:blur(15px);-webkit-backdrop-filter:blur(15px)}
    .lrWebStoreOverlay.show{display:flex}.lrWebStoreSheet{width:min(680px,100%);max-height:84vh;overflow:auto;border:1px solid var(--line);border-radius:25px 25px 18px 18px;padding:16px;background:color-mix(in srgb,var(--panel) 97%,#07111f);box-shadow:0 30px 90px rgba(0,0,0,.48)}
    .lrWebStoreHandle{width:42px;height:4px;border-radius:99px;background:var(--line);margin:0 auto 13px}.lrWebStoreHead{display:flex;align-items:flex-start;gap:10px}.lrWebStoreHead .small{font-size:8px!important;font-weight:950;letter-spacing:.09em;color:var(--gold)}.lrWebStoreHead .title{font-size:17px!important;margin-top:2px}.lrWebStoreHead .meta{font-size:9.5px!important;margin-top:3px;color:var(--muted)}
    .lrWebStoreClose{width:34px;height:34px;min-height:34px!important;border-radius:999px!important;padding:0!important;border:1px solid var(--line);background:var(--panel2);color:var(--muted);font-size:20px}.lrWebStoreBody{display:grid;gap:8px;margin-top:13px}.lrWebStoreStatus{padding:13px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel2) 68%,transparent)}.lrWebStoreStatus b,.lrWebStoreStatus span{display:block}.lrWebStoreStatus b{font-size:11px}.lrWebStoreStatus span{font-size:9px;color:var(--muted);margin-top:3px;line-height:1.35}
    .lrWebStoreChoice{width:100%;display:flex;align-items:center;gap:10px;text-align:left;padding:11px 12px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel2) 68%,transparent);color:var(--text);min-height:58px}.lrWebStoreChoice .grow{min-width:0}.lrWebStoreChoice strong,.lrWebStoreChoice small{display:block}.lrWebStoreChoice strong{font-size:11.5px}.lrWebStoreChoice small{font-size:8.8px;color:var(--muted);margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.lrWebStoreMetric{font-size:9px;color:var(--gold);white-space:nowrap;text-align:right}.lrWebStoreMetric small{font-size:8px!important;margin:2px 0 0!important}.lrWebStoreBrand{width:30px;height:30px;display:grid;place-items:center;border-radius:9px;background:color-mix(in srgb,var(--blue) 7%,var(--panel));border:1px solid var(--line);font-size:15px;flex:0 0 auto}
    @media(max-width:520px){.lrWebStoreOverlay{padding:8px}.lrWebStoreSheet{padding:14px;max-height:86vh}.lrWebStoreChoice{padding:10px}.lrWebStoreMetric{max-width:90px}}
  `;
  document.head.appendChild(style);

  const closeSheet = () => {
    ensureSheet().classList.remove("show");
    state = null;
  };

  const contextFor = mode => {
    const list = dayEvents();
    if (!list.length) return null;
    const home = homeAddress();
    if (mode === "before") {
      const live = window.nativeState?.currentLocation;
      const useLive = selectedDay() === todayKey() && live?.latitude != null && live?.longitude != null;
      return {
        origin: useLive
          ? { label:"Live location", latitude:Number(live.latitude), longitude:Number(live.longitude) }
          : home ? { label:"Home", address:home } : { label:"Live location" },
        final: { label:clean(list[0]?.title) || "First appointment", address:clean(list[0]?.address) }
      };
    }
    const last = list.at(-1);
    return {
      origin: { label:clean(last?.title) || "Last appointment", address:clean(last?.address) },
      final: home ? { label:"Home", address:home } : null
    };
  };

  const currentPosition = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("Location unavailable"));
    navigator.geolocation.getCurrentPosition(
      position => resolve({ latitude:Number(position.coords.latitude), longitude:Number(position.coords.longitude) }),
      reject,
      { enableHighAccuracy:true, timeout:9000, maximumAge:120000 }
    );
  });

  const pointFor = async item => {
    if (!item) return null;
    if (item.latitude != null && item.longitude != null) return { latitude:Number(item.latitude), longitude:Number(item.longitude) };
    if (!clean(item.address) && /live location/i.test(clean(item.label))) {
      try { return await currentPosition(); } catch (_) { return null; }
    }
    if (!clean(item.address)) return null;
    try {
      const point = await window.LifeRouteWebRouting?.geocode?.(item.address);
      return point?.latitude != null && point?.longitude != null
        ? { latitude:Number(point.latitude), longitude:Number(point.longitude) }
        : null;
    } catch (_) { return null; }
  };

  const fetchJSON = async (url, timeoutMs = 15000) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { cache:"no-store", signal:controller.signal });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } finally { clearTimeout(timer); }
  };

  const enrichRouteMetrics = async token => {
    if (!state || state.token !== token || !state.locations.length) return;
    const [origin, final] = await Promise.all([pointFor(state.context.origin), pointFor(state.context.final)]);
    if (!state || state.token !== token || !origin) return;

    const usable = state.locations.filter(location => Number.isFinite(Number(location.latitude)) && Number.isFinite(Number(location.longitude))).slice(0, 10);
    if (!usable.length) return;
    const points = [origin, ...usable.map(location => ({ latitude:Number(location.latitude), longitude:Number(location.longitude) }))];
    const finalIndex = final ? points.push(final) - 1 : null;
    const coords = points.map(point => `${point.longitude},${point.latitude}`).join(";");

    try {
      const data = await fetchJSON(`https://router.project-osrm.org/table/v1/driving/${coords}?annotations=duration,distance`, 18000);
      if (!state || state.token !== token || data?.code !== "Ok") return;
      usable.forEach((location, index) => {
        const pointIndex = index + 1;
        const outSeconds = Number(data.durations?.[0]?.[pointIndex]);
        const outMeters = Number(data.distances?.[0]?.[pointIndex]);
        const backSeconds = finalIndex != null ? Number(data.durations?.[pointIndex]?.[finalIndex]) : 0;
        const backMeters = finalIndex != null ? Number(data.distances?.[pointIndex]?.[finalIndex]) : 0;
        location.outMinutes = Number.isFinite(outSeconds) ? Math.max(1, Math.ceil(outSeconds / 60)) : 0;
        location.outDistanceMeters = Number.isFinite(outMeters) ? Math.max(0, Math.round(outMeters)) : 0;
        location.backMinutes = Number.isFinite(backSeconds) ? Math.max(1, Math.ceil(backSeconds / 60)) : 0;
        location.backDistanceMeters = Number.isFinite(backMeters) ? Math.max(0, Math.round(backMeters)) : 0;
      });
      renderResults();
    } catch (error) {
      console.warn("LifeRoute store sheet route metrics unavailable", error);
    }
  };

  const renderResults = () => {
    if (!state) return;
    const body = ensureSheet().querySelector("#lrWebStoreBody");
    if (!body) return;
    if (!state.locations.length) {
      body.innerHTML = '<div class="lrWebStoreStatus"><b>No nearby branches found</b><span>Try again after checking browser location access, or add a Saved Place for this errand.</span></div>';
      return;
    }

    const ranked = state.locations.slice().sort((a, b) => {
      const at = Number(a.outMinutes || 0) + Number(a.backMinutes || 0);
      const bt = Number(b.outMinutes || 0) + Number(b.backMinutes || 0);
      if (at && bt) return at - bt;
      if (at) return -1;
      if (bt) return 1;
      return Number(a.distanceFromCenter || 0) - Number(b.distanceFromCenter || 0);
    });

    body.innerHTML = ranked.slice(0, 10).map(location => {
      const travel = Number(location.outMinutes || 0) + Number(location.backMinutes || 0);
      const distance = Number(location.outDistanceMeters || 0) + Number(location.backDistanceMeters || 0);
      const metric = travel ? `${travel}m${distance ? ` · ${miles(distance).toFixed(1)} mi` : ""}` : "Choose";
      return `<button type="button" class="lrWebStoreChoice" data-web-store-choice="${safe(state.locations.indexOf(location))}">
        <span class="lrWebStoreBrand">🛒</span>
        <span class="grow"><strong>${safe(location.name || location.brand || "Store")}</strong><small>${safe(location.address || "Nearby branch")}</small></span>
        <span class="lrWebStoreMetric">${safe(metric)}${travel ? '<small>route</small>' : '<small>tap to add</small>'}</span>
      </button>`;
    }).join("");
  };

  const openSearch = async (button, todoID) => {
    const todo = todosState().find(item => String(item.id) === String(todoID));
    const mode = clean(button.closest(".lrBoundaryGap")?.dataset.boundaryMode);
    const queries = Array.isArray(todo?.storePreferences) ? todo.storePreferences.map(clean).filter(Boolean) : [];
    const context = contextFor(mode);
    const overlay = ensureSheet();
    const subtitle = overlay.querySelector("#lrWebStoreSubtitle");
    const body = overlay.querySelector("#lrWebStoreBody");
    const token = ++searchToken;

    state = { token, mode, todo, queries, context, locations:[] };
    if (subtitle) subtitle.textContent = queries.length ? queries.join(" · ") : clean(todo?.title) || "Preferred stores";
    if (body) body.innerHTML = `<div class="lrWebStoreStatus"><b>Searching nearby branches…</b><span>${safe(queries.join(" · "))}</span></div>`;
    overlay.classList.add("show");

    if (!todo || !mode || !queries.length || !context) {
      if (body) body.innerHTML = '<div class="lrWebStoreStatus"><b>Store search could not start</b><span>This errand needs at least one preferred store and a scheduled route.</span></div>';
      return;
    }

    const nearAddresses = [context.origin?.address, context.final?.address].map(clean).filter(Boolean);
    try {
      if (typeof window.LifeRouteWebStoreDirectV2?.search !== "function") throw new Error("Store engine is still loading. Close this sheet and tap Search stores again.");
      const locations = await window.LifeRouteWebStoreDirectV2.search({ queries, nearAddresses, limitPerQuery:5 });
      if (!state || state.token !== token) return;
      state.locations = (Array.isArray(locations) ? locations : []).slice(0, 18);
      renderResults();
      if (state.locations.length) enrichRouteMetrics(token);
    } catch (error) {
      if (!state || state.token !== token) return;
      if (body) body.innerHTML = `<div class="lrWebStoreStatus"><b>Store search failed</b><span>${safe(error?.message || "Please try again.")}</span></div>`;
    }
  };

  // Window capture fires before the core document capture listener. The web
  // sheet therefore owns this tap completely and the Day card cannot back out.
  window.addEventListener("click", event => {
    const close = event.target.closest?.("[data-web-store-close]");
    if (close) {
      event.preventDefault();
      event.stopImmediatePropagation();
      closeSheet();
      return;
    }

    const choice = event.target.closest?.("[data-web-store-choice]");
    if (choice && state) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const location = state.locations[Number(choice.dataset.webStoreChoice)];
      if (!location) return;
      const saved = window.lifeRouteSaveBoundaryStop?.(state.mode, {
        kind:"store",
        id:state.todo?.id,
        name:location.name || location.brand || state.todo?.title || "Store",
        address:location.address || location.name || location.brand,
        stopMinutes:Number(state.todo?.duration || 30),
        outMinutes:Number(location.outMinutes || 0),
        backMinutes:Number(location.backMinutes || 0),
        outDistanceMeters:Number(location.outDistanceMeters || 0),
        backDistanceMeters:Number(location.backDistanceMeters || 0)
      });
      if (saved !== false) closeSheet();
      return;
    }

    const storeButton = event.target.closest?.("[data-boundary-stores]");
    if (!storeButton) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    openSearch(storeButton, storeButton.dataset.boundaryStores);
  }, true);

  const overlay = ensureSheet();
  overlay.addEventListener("click", event => { if (event.target === overlay) closeSheet(); });
  window.LifeRouteWebStoreSheetV3 = { openSearch, close:closeSheet };
})();