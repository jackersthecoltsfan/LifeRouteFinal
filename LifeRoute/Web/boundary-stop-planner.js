// Persistent before/after-day stop planner.
// This module owns the entire boundary-stop interaction: opening the chooser,
// Saved Places, route-ready To-Dos, nearby store search, persistence, metrics,
// and later navigation. Stable delegated events survive every Day rerender.
(() => {
  if (window.__lifeRouteBoundaryStopPlannerLoaded) return;
  window.__lifeRouteBoundaryStopPlannerLoaded = true;

  const STORAGE_KEY = "liferoute_boundary_stops_v2";
  const LEGACY_STORAGE_KEY = "liferoute_boundary_stops_v1";
  const requests = new Map();
  const metricRequests = new Map();
  let requestCounter = 0;
  let selections = {};

  const clean = value => String(value || "").trim();
  const safe = value => typeof window.esc === "function"
    ? window.esc(String(value || ""))
    : String(value || "").replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"})[ch]);
  const icon = (name, size = 15) => typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon(name, size) : "";
  const fmtMinutes = value => typeof window.fmt === "function" ? window.fmt(Number(value || 0)) : `${Math.max(0, Math.round(Number(value || 0)))}m`;
  const miles = meters => Number(meters || 0) / 1609.344;

  const prefsState = () => {
    if (window.prefs) return window.prefs;
    try { return prefs; } catch (_) { return {}; }
  };
  const placesState = () => {
    if (Array.isArray(window.places)) return window.places;
    try { return Array.isArray(places) ? places : []; } catch (_) { return []; }
  };
  const nativeStateValue = () => {
    if (window.nativeState) return window.nativeState;
    try { return nativeState; } catch (_) { return {}; }
  };
  const selectedDay = () => {
    if (clean(window.selectedDate)) return clean(window.selectedDate);
    try { return clean(selectedDate); } catch (_) { return ""; }
  };
  const todosState = () => Array.isArray(window.lifeRouteTodos) ? window.lifeRouteTodos : [];
  const dayEventsFor = date => typeof window.dayEvents === "function" ? window.dayEvents(date) : [];
  const homeAddress = () => clean(prefsState()?.homeAddress) || clean(placesState().find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const isToday = date => typeof window.localDateKey === "function" && date === window.localDateKey(new Date());
  const selectionKey = (date, mode) => `${date}|${mode}`;

  const load = () => {
    try {
      const current = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
      if (current && typeof current === "object" && !Array.isArray(current)) {
        selections = current;
        return;
      }
      const legacy = JSON.parse(localStorage.getItem(LEGACY_STORAGE_KEY) || "{}");
      selections = legacy && typeof legacy === "object" && !Array.isArray(legacy) ? legacy : {};
      localStorage.setItem(STORAGE_KEY, JSON.stringify(selections));
    } catch (_) { selections = {}; }
  };
  const save = () => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(selections)); } catch (_) {}
  };
  load();

  const contextFor = mode => {
    const date = selectedDay();
    const list = dayEventsFor(date);
    if (!date || !list.length) return null;
    const home = homeAddress();

    if (mode === "before") {
      const live = nativeStateValue()?.currentLocation;
      const useLive = isToday(date) && live?.latitude != null && live?.longitude != null;
      const origin = useLive
        ? { label: "Live location", address: "", latitude: Number(live.latitude), longitude: Number(live.longitude) }
        : home ? { label: "Home", address: home } : { label: "Live location", address: "" };
      const first = list[0];
      return {
        date,
        mode,
        origin,
        final: { label: clean(first?.title) || "First appointment", address: clean(first?.address) }
      };
    }

    const last = list.at(-1);
    return {
      date,
      mode,
      origin: { label: clean(last?.title) || "Last appointment", address: clean(last?.address) },
      final: home ? { label: "Home", address: home } : null
    };
  };

  const restoreScroll = (x, y) => {
    const apply = () => { try { window.scrollTo(x, y); } catch (_) {} };
    apply();
    requestAnimationFrame(() => { apply(); requestAnimationFrame(apply); });
    setTimeout(apply, 70);
    setTimeout(apply, 180);
  };

  const routeSelection = selection => {
    if (!selection?.address) return;
    const origin = clean(selection.originAddress);
    const final = clean(selection.finalAddress);
    if (final && typeof window.routeGapStop === "function") {
      window.routeGapStop(
        encodeURIComponent(selection.address),
        encodeURIComponent(final),
        encodeURIComponent(origin)
      );
      return;
    }
    if (origin && typeof window.lifeRouteLaunchDirections === "function") {
      window.lifeRouteLaunchDirections(selection.address, origin);
      return;
    }
    if (typeof window.lifeRouteChooseRouteOrigin === "function") {
      window.lifeRouteChooseRouteOrigin(selection.address, { destinationLabel: selection.label || selection.address });
      return;
    }
    if (typeof window.routeTo === "function") window.routeTo(encodeURIComponent(selection.address));
  };

  const plannedHTML = selection => {
    const travel = Number(selection.outMinutes || 0) + Number(selection.backMinutes || 0);
    const distance = Number(selection.outDistanceMeters || 0) + Number(selection.backDistanceMeters || 0);
    const stopMinutes = Number(selection.stopMinutes || 0);
    const routeText = [selection.originLabel, selection.label, selection.finalLabel].filter(Boolean).join(" → ");
    const metrics = [
      travel > 0 ? `${fmtMinutes(travel)} travel` : "Route ready",
      distance > 0 ? `${miles(distance).toFixed(distance < 16093 ? 1 : 0)} mi` : "",
      stopMinutes > 0 ? `${fmtMinutes(stopMinutes)} stop` : ""
    ].filter(Boolean).join(" · ");

    return `
      <div class="lrBoundaryPlannedTop">
        <div class="lrBoundaryPlannedIcon">${icon(selection.kind === "store" ? "cart" : "pin", 16)}</div>
        <div class="grow">
          <div class="small">${selection.mode === "before" ? "BEFORE FIRST" : "AFTER LAST"}</div>
          <div class="title">${safe(selection.label || "Planned stop")}</div>
          <div class="meta">${safe(selection.address || "")}</div>
        </div>
        <span class="badge green">Planned</span>
      </div>
      <div class="lrBoundaryPlanRoute">${icon("route", 13)}<span>${safe(routeText)}</span></div>
      <div class="tiny lrBoundaryPlanMetrics">${safe(metrics)}</div>
      <div class="lrBoundaryPlanActions">
        <button type="button" class="secondary" data-lr-boundary-route>${icon("navigation", 14)} Open route</button>
        <button type="button" class="secondary" data-lr-boundary-change>Change</button>
      </div>`;
  };

  const renderSelectionInto = card => {
    if (!card) return false;
    const mode = clean(card.dataset.boundaryMode);
    const selection = selections[selectionKey(selectedDay(), mode)];
    if (!mode || !selection) return false;
    card.classList.add("lrBoundaryPlanned");
    card.innerHTML = plannedHTML(selection);
    return true;
  };

  const decorateBoundaryCards = () => {
    document.querySelectorAll("#timeline .lrBoundaryGap[data-boundary-mode]").forEach(card => {
      const key = selectionKey(selectedDay(), clean(card.dataset.boundaryMode));
      if (selections[key]) renderSelectionInto(card);
    });
  };
  window.decorateLifeRouteBoundaryStops = decorateBoundaryCards;

  const requestMetrics = selection => {
    const post = window.postNative;
    if (typeof post !== "function" || !selection?.address) return;
    const token = `boundary-plan-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const segments = [];
    const out = {
      id: `${token}|out`,
      origin: selection.originAddress || selection.originLabel || "Current location",
      destination: selection.address
    };
    if (selection.originLatitude != null && selection.originLongitude != null) {
      out.originLatitude = Number(selection.originLatitude);
      out.originLongitude = Number(selection.originLongitude);
    }
    segments.push(out);
    if (selection.finalAddress) {
      segments.push({ id: `${token}|back`, origin: selection.address, destination: selection.finalAddress });
    }
    metricRequests.set(token, selectionKey(selection.date, selection.mode));
    post({ action: "requestRouteTimes", segments });
  };

  const saveBoundaryStop = (mode, stop) => {
    const context = contextFor(mode);
    const address = clean(stop?.address || stop?.name);
    if (!context || !address) return false;
    const selection = {
      date: context.date,
      dateKey: context.date,
      mode,
      kind: clean(stop?.kind) || "place",
      sourceId: clean(stop?.id),
      label: clean(stop?.name || stop?.label) || "Planned stop",
      address,
      stopMinutes: Number(stop?.stopMinutes || 0),
      originLabel: clean(context.origin?.label),
      originAddress: clean(context.origin?.address),
      originLatitude: context.origin?.latitude ?? null,
      originLongitude: context.origin?.longitude ?? null,
      finalLabel: clean(context.final?.label),
      finalAddress: clean(context.final?.address),
      outMinutes: Number(stop?.outMinutes || 0),
      backMinutes: Number(stop?.backMinutes || 0),
      outDistanceMeters: Number(stop?.outDistanceMeters || 0),
      backDistanceMeters: Number(stop?.backDistanceMeters || 0),
      savedAt: new Date().toISOString()
    };
    selections[selectionKey(context.date, mode)] = selection;
    save();

    const card = document.querySelector(`#timeline .lrBoundaryGap[data-boundary-mode="${mode}"]`);
    if (card) renderSelectionInto(card);
    if (!selection.outMinutes && !selection.backMinutes) requestMetrics(selection);
    try { window.setStatus?.(`Added to Day · ${selection.label}`); } catch (_) {}
    return true;
  };
  window.lifeRouteSaveBoundaryStop = saveBoundaryStop;

  const routeReadyPlaces = () => placesState()
    .filter(place => clean(place?.address))
    .slice()
    .sort((a, b) => {
      const preferred = Number(!!b?.useInGaps) - Number(!!a?.useInGaps);
      if (preferred) return preferred;
      return clean(a?.name).localeCompare(clean(b?.name));
    });

  const routeReadyTodos = () => todosState()
    .filter(todo => !todo?.completed)
    .filter(todo => clean(todo?.address) || (Array.isArray(todo?.storePreferences) && todo.storePreferences.some(Boolean)))
    .slice(0, 12);

  const plannerHTML = (mode, context) => {
    const places = routeReadyPlaces();
    const todos = routeReadyTodos();
    const heading = mode === "before" ? "Add a stop before your first appointment" : "Add a stop on the way home";
    const routeLine = [context?.origin?.label, "stop", context?.final?.label].filter(Boolean).join(" → ");

    const placeCards = places.length ? places.slice(0, 10).map(place => `
      <button type="button" class="lrBoundaryChoice" data-boundary-place="${safe(place.id)}">
        <span class="lrBoundaryChoiceIcon">${icon("pin", 15)}</span>
        <span class="grow"><strong>${safe(place.name || "Saved place")}</strong><small>${safe(place.type || "Place")} · ${safe(place.address)}</small></span>
        <span class="lrBoundaryChoiceMeta">${Number(place.minVisit || 60)}m</span>
      </button>`).join("") : '<div class="lrBoundaryEmpty">No Saved Places with addresses yet.</div>';

    const todoCards = todos.length ? todos.map(todo => {
      const prefs = Array.isArray(todo.storePreferences) ? todo.storePreferences.map(clean).filter(Boolean) : [];
      const located = clean(todo.address);
      if (prefs.length) {
        return `<div class="lrBoundaryTodoChoice"><div class="lrBoundaryTodoTop"><span class="lrBoundaryChoiceIcon">${icon("cart",15)}</span><span class="grow"><strong>${safe(todo.title || "Shopping")}</strong><small>${safe(prefs.join(" · "))}</small></span><span class="lrBoundaryChoiceMeta">${Number(todo.duration || 30)}m</span></div><button type="button" class="secondary lrBoundaryTodoAction" data-boundary-stores="${safe(todo.id)}">Search stores</button><div class="lrBoundaryStorePicker"></div></div>`;
      }
      return `<button type="button" class="lrBoundaryChoice" data-boundary-todo="${safe(todo.id)}"><span class="lrBoundaryChoiceIcon">${icon("check",15)}</span><span class="grow"><strong>${safe(todo.title || "Errand")}</strong><small>${safe(located)}</small></span><span class="lrBoundaryChoiceMeta">${Number(todo.duration || 30)}m</span></button>`;
    }).join("") : '<div class="lrBoundaryEmpty">No route-ready errands yet.</div>';

    return `
      <div class="lrBoundaryPickerHead">
        <div><div class="title">${safe(heading)}</div><div class="meta">${safe(routeLine)}</div></div>
        <button type="button" class="lrBoundaryClose" data-lr-boundary-close aria-label="Close">×</button>
      </div>
      <div class="lrBoundaryGroup"><div class="lrBoundaryGroupLabel">Saved places</div>${placeCards}</div>
      <div class="lrBoundaryGroup"><div class="lrBoundaryGroupLabel">Errands & shopping</div>${todoCards}</div>`;
  };

  const openPlanner = (mode, panelId, trigger = null) => {
    const card = trigger?.closest?.(".lrBoundaryGap") || document.querySelector(`#timeline .lrBoundaryGap[data-boundary-mode="${mode}"]`);
    const panel = document.getElementById(panelId) || card?.querySelector(".lrBoundaryPanel,.gapSuggest");
    const context = contextFor(mode);
    if (!card || !panel || !context) {
      try { window.setStatus?.("Add an appointment with a location first"); } catch (_) {}
      return false;
    }

    if (panel.style.display !== "none" && panel.dataset.lrBoundaryOpen === "1") {
      panel.style.display = "none";
      panel.dataset.lrBoundaryOpen = "0";
      trigger?.setAttribute?.("aria-expanded", "false");
      return true;
    }

    panel.innerHTML = plannerHTML(mode, context);
    panel.style.display = "block";
    panel.dataset.lrBoundaryOpen = "1";
    panel.dataset.boundaryMode = mode;
    trigger?.setAttribute?.("aria-expanded", "true");
    try { window.setStatus?.(mode === "before" ? "Choose a stop before your first appointment" : "Choose a stop on the way home"); } catch (_) {}
    return true;
  };
  window.lifeRouteOpenBoundaryPlanner = openPlanner;

  const requestHost = button => button.closest(".lrBoundaryTodoChoice")?.querySelector(".lrBoundaryStorePicker");

  const startStoreSearch = (button, todoID) => {
    const todo = todosState().find(item => String(item.id) === String(todoID));
    const queries = Array.isArray(todo?.storePreferences) ? todo.storePreferences.map(clean).filter(Boolean) : [];
    const card = button.closest(".lrBoundaryGap");
    const mode = clean(card?.dataset.boundaryMode);
    const context = contextFor(mode);
    const host = requestHost(button);
    if (!todo || !queries.length || !context || !host) return;

    requestCounter += 1;
    const requestID = `boundary-${requestCounter}-${Date.now()}`;
    const request = { requestID, mode, todo, context, host, button, locations: [], routes: new Map(), finished: false, timer: null };
    requests.set(requestID, request);

    button.disabled = true;
    button.textContent = "Searching…";
    host.innerHTML = `<div class="lrBoundaryStoreStatus"><b>Finding nearby branches…</b><span>${safe(queries.join(" · "))}</span></div>`;

    const nearAddresses = [context.origin?.address, context.final?.address].map(clean).filter(Boolean);
    const handled = typeof window.postNative === "function" && window.postNative({
      action: "searchStoreLocations",
      requestID,
      queries,
      nearAddresses,
      limitPerQuery: 5
    });

    if (!handled) {
      request.finished = true;
      host.innerHTML = '<div class="lrBoundaryStoreStatus"><b>Store search unavailable</b><span>Route services are not available right now.</span></div>';
      button.disabled = false;
      button.textContent = "Try again";
      return;
    }

    request.timer = setTimeout(() => {
      if (request.finished) return;
      host.innerHTML = '<div class="lrBoundaryStoreStatus"><b>Still searching…</b><span>Checking a second nearby-store source.</span></div>';
    }, 6500);

    setTimeout(() => {
      if (request.finished) return;
      request.finished = true;
      button.disabled = false;
      button.textContent = "Try again";
      host.innerHTML = '<div class="lrBoundaryStoreStatus"><b>Search timed out</b><span>Tap Try again.</span></div>';
    }, 26000);
  };

  const renderStoreLocations = request => {
    if (!request?.host) return;
    if (!request.locations.length) {
      request.host.innerHTML = '<div class="lrBoundaryStoreStatus"><b>No nearby branches found</b><span>Try again or choose a Saved Place.</span></div>';
      return;
    }

    const ranked = request.locations.map((location, index) => {
      const out = request.routes.get(`${location.id}|out`);
      const back = request.routes.get(`${location.id}|back`);
      const travel = Number(out?.minutes || 0) + Number(back?.minutes || 0);
      const distance = Number(out?.distanceMeters || 0) + Number(back?.distanceMeters || 0);
      return { location, index, out, back, travel, distance };
    }).sort((a, b) => {
      if (a.travel && b.travel) return a.travel - b.travel;
      if (a.travel) return -1;
      if (b.travel) return 1;
      return a.index - b.index;
    });

    request.host.innerHTML = `<div class="lrBoundaryStoreResults"><div class="lrBoundaryStoreResultsHead"><b>Nearby branches</b><span>${ranked.length}</span></div>${ranked.slice(0, 10).map(item => `
      <button type="button" class="lrBoundaryStoreChoice" data-lr-boundary-request="${safe(request.requestID)}" data-lr-boundary-location="${safe(request.locations.indexOf(item.location))}">
        <span class="grow"><strong>${safe(item.location.name || item.location.brand || "Store")}</strong><small>${safe(item.location.address || "")}</small></span>
        <span class="lrBoundaryChoiceMeta">${item.travel ? `${fmtMinutes(item.travel)}${item.distance ? ` · ${miles(item.distance).toFixed(1)} mi` : ""}` : "Choose"}</span>
      </button>`).join("")}</div>`;
  };

  const requestStoreRoutes = request => {
    const segments = [];
    request.locations.forEach(location => {
      const out = {
        id: `${location.id}|out`,
        origin: request.context.origin?.address || request.context.origin?.label || "Current location",
        destination: location.address || location.name,
        destinationLatitude: location.latitude,
        destinationLongitude: location.longitude
      };
      if (request.context.origin?.latitude != null && request.context.origin?.longitude != null) {
        out.originLatitude = Number(request.context.origin.latitude);
        out.originLongitude = Number(request.context.origin.longitude);
      }
      segments.push(out);
      if (request.context.final?.address) {
        segments.push({
          id: `${location.id}|back`,
          origin: location.address || location.name,
          originLatitude: location.latitude,
          originLongitude: location.longitude,
          destination: request.context.final.address
        });
      }
    });
    if (segments.length && typeof window.postNative === "function") {
      window.postNative({ action: "requestRouteTimes", segments });
    }
  };

  const handleStoreLocations = evt => {
    const request = requests.get(clean(evt?.requestID));
    if (!request) return;
    clearTimeout(request.timer);
    request.finished = true;
    request.button.disabled = false;
    request.button.textContent = "Search again";
    request.locations = (Array.isArray(evt.locations) ? evt.locations : []).slice(0, 18).map((location, index) => ({
      ...location,
      id: `${request.requestID}|loc-${index}`
    }));
    renderStoreLocations(request);
    if (request.locations.length) requestStoreRoutes(request);
  };

  const handleRouteTimes = evt => {
    const results = Array.isArray(evt?.results) ? evt.results : [];

    for (const [token, key] of metricRequests.entries()) {
      const matches = results.filter(result => String(result.id || "").startsWith(`${token}|`));
      if (!matches.length) continue;
      metricRequests.delete(token);
      const selection = selections[key];
      if (!selection) continue;
      const out = matches.find(result => String(result.id || "").endsWith("|out") && !result.error);
      const back = matches.find(result => String(result.id || "").endsWith("|back") && !result.error);
      if (out) {
        selection.outMinutes = Number(out.minutes || 0);
        selection.outDistanceMeters = Number(out.distanceMeters || 0);
      }
      if (back) {
        selection.backMinutes = Number(back.minutes || 0);
        selection.backDistanceMeters = Number(back.distanceMeters || 0);
      }
      save();
      decorateBoundaryCards();
    }

    requests.forEach(request => {
      const matches = results.filter(result => String(result.id || "").startsWith(`${request.requestID}|`));
      if (!matches.length) return;
      matches.forEach(result => request.routes.set(String(result.id || ""), result));
      renderStoreLocations(request);
    });
  };

  const installEventHook = () => {
    const current = window.lifeRouteNativeEvent;
    if (current?.__lifeRouteBoundaryPlannerWrapped) return;
    const wrapped = function lifeRouteNativeEventWithBoundaryPlanner(evt) {
      if (typeof current === "function") current(evt);
      if (evt?.type === "storeLocations") handleStoreLocations(evt);
      if (evt?.type === "routeTimes") handleRouteTimes(evt);
    };
    wrapped.__lifeRouteBoundaryPlannerWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const handleClick = event => {
    const openButton = event.target.closest?.("[data-lr-boundary-open]");
    if (openButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = openButton.closest(".lrBoundaryGap");
      const mode = clean(openButton.dataset.lrBoundaryOpen || card?.dataset.boundaryMode);
      const panel = card?.querySelector(".lrBoundaryPanel,.gapSuggest");
      openPlanner(mode, panel?.id, openButton);
      return;
    }

    const closeButton = event.target.closest?.("[data-lr-boundary-close]");
    if (closeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = closeButton.closest(".lrBoundaryGap");
      const panel = card?.querySelector(".lrBoundaryPanel,.gapSuggest");
      if (panel) { panel.style.display = "none"; panel.dataset.lrBoundaryOpen = "0"; }
      card?.querySelector("[data-lr-boundary-open]")?.setAttribute("aria-expanded", "false");
      return;
    }

    const routeButton = event.target.closest?.("[data-lr-boundary-route]");
    if (routeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = routeButton.closest(".lrBoundaryGap");
      const selection = selections[selectionKey(selectedDay(), clean(card?.dataset.boundaryMode))];
      if (selection) routeSelection(selection);
      return;
    }

    const changeButton = event.target.closest?.("[data-lr-boundary-change]");
    if (changeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = changeButton.closest(".lrBoundaryGap");
      const mode = clean(card?.dataset.boundaryMode);
      const x = window.scrollX || 0;
      const y = window.scrollY || 0;
      delete selections[selectionKey(selectedDay(), mode)];
      save();
      if (typeof window.renderToday === "function") window.renderToday();
      restoreScroll(x, y);
      return;
    }

    const placeButton = event.target.closest?.("[data-boundary-place]");
    if (placeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = placeButton.closest(".lrBoundaryGap");
      const mode = clean(card?.dataset.boundaryMode);
      const place = placesState().find(item => String(item.id) === String(placeButton.dataset.boundaryPlace));
      if (mode && place?.address) saveBoundaryStop(mode, { kind: "place", id: place.id, name: place.name, address: place.address, stopMinutes: place.minVisit });
      return;
    }

    const todoButton = event.target.closest?.("[data-boundary-todo]");
    if (todoButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const card = todoButton.closest(".lrBoundaryGap");
      const mode = clean(card?.dataset.boundaryMode);
      const todo = todosState().find(item => String(item.id) === String(todoButton.dataset.boundaryTodo));
      if (mode && todo?.address) saveBoundaryStop(mode, { kind: "todo", id: todo.id, name: todo.title, address: todo.address, stopMinutes: todo.duration });
      return;
    }

    const storeButton = event.target.closest?.("[data-boundary-stores]");
    if (storeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      startStoreSearch(storeButton, storeButton.dataset.boundaryStores);
      return;
    }

    const branchButton = event.target.closest?.("[data-lr-boundary-request][data-lr-boundary-location]");
    if (branchButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      const request = requests.get(clean(branchButton.dataset.lrBoundaryRequest));
      const location = request?.locations?.[Number(branchButton.dataset.lrBoundaryLocation)];
      if (!request || !location) return;
      const out = request.routes.get(`${location.id}|out`);
      const back = request.routes.get(`${location.id}|back`);
      saveBoundaryStop(request.mode, {
        kind: "store",
        id: request.todo.id,
        name: location.name || location.brand || request.todo.title,
        address: location.address || location.name || location.brand,
        stopMinutes: request.todo.duration || 30,
        outMinutes: out?.minutes,
        backMinutes: back?.minutes,
        outDistanceMeters: out?.distanceMeters,
        backDistanceMeters: back?.distanceMeters
      });
      return;
    }

    const card = event.target.closest?.(".lrBoundaryGap:not(.lrBoundaryPlanned)");
    if (card && !event.target.closest("button,a,input,select")) {
      const mode = clean(card.dataset.boundaryMode);
      const panel = card.querySelector(".lrBoundaryPanel,.gapSuggest");
      openPlanner(mode, panel?.id, card.querySelector("[data-lr-boundary-open]"));
    }
  };

  const style = document.createElement("style");
  style.id = "lifeRouteBoundaryStopPlannerStyles";
  style.textContent = `
    .lrBoundaryPanel{margin-top:10px!important;padding-top:10px!important;border-top:1px solid color-mix(in srgb,var(--line) 70%,transparent)!important}.lrBoundaryPickerHead{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:10px}.lrBoundaryPickerHead .title{font-size:13px!important}.lrBoundaryPickerHead .meta{font-size:9px!important;margin-top:2px}.lrBoundaryClose{width:30px;height:30px;min-height:30px!important;padding:0!important;border-radius:999px!important;background:color-mix(in srgb,var(--panel2) 80%,transparent);border:1px solid var(--line);color:var(--muted);font-size:18px;font-weight:600}.lrBoundaryGroup{display:grid;gap:6px;margin-top:10px}.lrBoundaryGroupLabel{font-size:8px;font-weight:950;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:0 2px 1px}.lrBoundaryChoice,.lrBoundaryTodoChoice{width:100%;border:1px solid color-mix(in srgb,var(--line) 78%,transparent);border-radius:13px;background:color-mix(in srgb,var(--panel2) 62%,transparent);color:var(--text);padding:9px 10px}.lrBoundaryChoice{display:flex;align-items:center;gap:9px;text-align:left}.lrBoundaryChoiceIcon{width:25px;height:25px;display:grid;place-items:center;border-radius:8px;background:color-mix(in srgb,var(--blue) 6%,transparent);color:var(--blue);flex:0 0 auto}.lrBoundaryChoice strong,.lrBoundaryChoice small,.lrBoundaryTodoChoice strong,.lrBoundaryTodoChoice small{display:block}.lrBoundaryChoice strong,.lrBoundaryTodoChoice strong{font-size:11px}.lrBoundaryChoice small,.lrBoundaryTodoChoice small{font-size:8.5px;color:var(--muted);margin-top:2px;line-height:1.3;overflow:hidden;text-overflow:ellipsis}.lrBoundaryChoiceMeta{font-size:8.5px;color:var(--gold);white-space:nowrap}.lrBoundaryTodoTop{display:flex;align-items:center;gap:9px;text-align:left}.lrBoundaryTodoAction{margin-top:7px;width:100%;min-height:34px!important;padding:7px 9px!important;font-size:9px!important}.lrBoundaryEmpty{padding:10px;border:1px dashed var(--line);border-radius:12px;color:var(--muted);font-size:9px;text-align:center}.lrBoundaryStorePicker:empty{display:none}.lrBoundaryStorePicker{margin-top:7px}.lrBoundaryStoreStatus{padding:9px 10px;border-radius:11px;background:color-mix(in srgb,var(--panel) 58%,transparent);border:1px solid var(--line)}.lrBoundaryStoreStatus b,.lrBoundaryStoreStatus span{display:block}.lrBoundaryStoreStatus b{font-size:9.5px}.lrBoundaryStoreStatus span{font-size:8.5px;color:var(--muted);margin-top:2px}.lrBoundaryStoreResults{display:grid;gap:6px}.lrBoundaryStoreResultsHead{display:flex;justify-content:space-between;align-items:center;color:var(--muted);font-size:8.5px}.lrBoundaryStoreResultsHead b{color:var(--text);font-size:9.5px}.lrBoundaryStoreChoice{width:100%;display:flex;align-items:center;gap:9px;text-align:left;padding:9px 10px;border-radius:12px;background:color-mix(in srgb,var(--panel) 62%,transparent);border:1px solid var(--line);color:var(--text)}.lrBoundaryStoreChoice strong,.lrBoundaryStoreChoice small{display:block}.lrBoundaryStoreChoice strong{font-size:10.5px}.lrBoundaryStoreChoice small{font-size:8px;color:var(--muted);margin-top:2px;line-height:1.3}.lrBoundaryPlanned{border-color:color-mix(in srgb,var(--green) 30%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--green) 4%,transparent),transparent),var(--panel)!important}.lrBoundaryPlannedTop{display:flex;align-items:center;gap:9px}.lrBoundaryPlannedIcon{width:32px;height:32px;border-radius:10px;display:grid;place-items:center;background:color-mix(in srgb,var(--green) 7%,var(--panel2));border:1px solid color-mix(in srgb,var(--green) 18%,var(--line));color:var(--green)}.lrBoundaryPlanRoute{display:flex;align-items:center;gap:5px;margin-top:8px;font-size:9px;color:var(--muted)}.lrBoundaryPlanMetrics{margin-top:4px!important;font-size:8.5px!important}.lrBoundaryPlanActions{display:flex;gap:6px;margin-top:8px}.lrBoundaryPlanActions button{min-height:34px!important;padding:7px 9px!important;font-size:9px!important;display:inline-flex;align-items:center;gap:5px}
  `;
  document.head.appendChild(style);

  document.addEventListener("click", handleClick, true);

  const start = () => {
    installEventHook();
    decorateBoundaryCards();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      installEventHook();
      decorateBoundaryCards();
      if (attempts >= 30) clearInterval(timer);
    }, 350);
  };

  window.addEventListener("pageshow", () => { installEventHook(); decorateBoundaryCards(); });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();