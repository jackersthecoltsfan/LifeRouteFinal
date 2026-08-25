// Persistent before/after-day stop planning for LifeRoute.
// Saved Places, located To-Dos, and store branches all use the same Day-plan state.
(() => {
  if (window.__lifeRouteBoundaryStopPlannerLoaded) return;
  window.__lifeRouteBoundaryStopPlannerLoaded = true;

  const STORAGE_KEY = "liferoute_boundary_stops_v1";
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

  const load = () => {
    try {
      const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      selections = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (_) { selections = {}; }
  };
  const save = () => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(selections)); } catch (_) {}
  };
  load();

  const dateKey = () => clean(window.selectedDate);
  const dayEvents = () => typeof window.dayEvents === "function" ? window.dayEvents(dateKey()) : [];
  const homeAddress = () => clean(window.prefs?.homeAddress) || clean((window.places || []).find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const isToday = () => typeof window.localDateKey === "function" && dateKey() === window.localDateKey(new Date());
  const selectionKey = (date, mode) => `${date}|${mode}`;

  const contextFor = mode => {
    const list = dayEvents();
    const home = homeAddress();
    if (!list.length) return null;
    if (mode === "before") {
      const live = window.nativeState?.currentLocation;
      const origin = isToday() && live?.latitude != null && live?.longitude != null
        ? { label: "Live location", address: "", latitude: Number(live.latitude), longitude: Number(live.longitude) }
        : home ? { label: "Home", address: home } : { label: "Live location", address: "" };
      const first = list[0];
      return {
        mode,
        dateKey: dateKey(),
        origin,
        final: { label: clean(first.title) || "First appointment", address: clean(first.address) }
      };
    }
    const last = list.at(-1);
    return {
      mode,
      dateKey: dateKey(),
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
    const before = selection.mode === "before";
    const routeText = [selection.originLabel, selection.label, selection.finalLabel].filter(Boolean).join(" → ");
    const travel = Number(selection.outMinutes || 0) + Number(selection.backMinutes || 0);
    const distance = Number(selection.outDistanceMeters || 0) + Number(selection.backDistanceMeters || 0);
    const stopMinutes = Number(selection.stopMinutes || 0);
    const metrics = [
      travel > 0 ? `${fmtMinutes(travel)} travel` : "Route ready",
      distance > 0 ? `${miles(distance).toFixed(distance < 16093 ? 1 : 0)} mi` : "",
      stopMinutes > 0 ? `${fmtMinutes(stopMinutes)} stop` : ""
    ].filter(Boolean).join(" · ");
    return `
      <div class="lrBoundaryPlannedTop">
        <div class="lrBoundaryPlannedIcon">${icon(selection.kind === "store" ? "cart" : "pin", 16)}</div>
        <div class="grow">
          <div class="small">${before ? "PLANNED BEFORE FIRST" : "PLANNED AFTER LAST"}</div>
          <div class="title">${safe(selection.label || "Planned stop")}</div>
          <div class="meta">${safe(selection.address || "")}</div>
        </div>
        <span class="badge green">Planned</span>
      </div>
      <div class="lrBoundaryPlanRoute">${icon("route", 13)} <span>${safe(routeText)}</span></div>
      ${metrics ? `<div class="tiny lrBoundaryPlanMetrics">${safe(metrics)}</div>` : ""}
      <div class="lrBoundaryPlanActions">
        <button type="button" class="secondary" data-lr-boundary-open>${icon("navigation", 14)} Open route</button>
        <button type="button" class="secondary" data-lr-boundary-change>Change</button>
      </div>`;
  };

  const renderSelectionInto = card => {
    const mode = clean(card?.dataset?.boundaryMode);
    const selection = selections[selectionKey(dateKey(), mode)];
    if (!card || !mode || !selection) return false;
    card.classList.add("lrBoundaryPlanned");
    card.innerHTML = plannedHTML(selection);
    card.querySelector("[data-lr-boundary-open]")?.addEventListener("click", event => {
      event.preventDefault();
      event.stopPropagation();
      routeSelection(selection);
    });
    card.querySelector("[data-lr-boundary-change]")?.addEventListener("click", event => {
      event.preventDefault();
      event.stopPropagation();
      const x = window.scrollX || 0;
      const y = window.scrollY || 0;
      delete selections[selectionKey(selection.dateKey, selection.mode)];
      save();
      if (typeof window.renderToday === "function") window.renderToday();
      restoreScroll(x, y);
    });
    return true;
  };

  const decorateBoundaryCards = () => {
    document.querySelectorAll("#timeline .lrBoundaryGap[data-boundary-mode]").forEach(renderSelectionInto);
  };
  window.decorateLifeRouteBoundaryStops = decorateBoundaryCards;

  const requestMetrics = selection => {
    if (typeof window.postNative !== "function") return;
    const token = `boundary-plan-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const segments = [];
    const origin = {
      id: `${token}|out`,
      origin: selection.originAddress || selection.originLabel || "Current location",
      destination: selection.address
    };
    if (selection.originLatitude != null && selection.originLongitude != null) {
      origin.originLatitude = Number(selection.originLatitude);
      origin.originLongitude = Number(selection.originLongitude);
    }
    segments.push(origin);
    if (selection.finalAddress) {
      segments.push({
        id: `${token}|back`,
        origin: selection.address,
        destination: selection.finalAddress
      });
    }
    metricRequests.set(token, selectionKey(selection.dateKey, selection.mode));
    window.postNative({ action: "requestRouteTimes", segments });
  };

  const saveBoundaryStop = (mode, stop) => {
    const context = contextFor(mode);
    const address = clean(stop?.address || stop?.name);
    if (!context || !address) return;
    const selection = {
      dateKey: context.dateKey,
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
    selections[selectionKey(context.dateKey, mode)] = selection;
    save();
    const card = document.querySelector(`#timeline .lrBoundaryGap[data-boundary-mode="${mode}"]`);
    if (card) renderSelectionInto(card);
    else decorateBoundaryCards();
    if (!selection.outMinutes && !selection.backMinutes) requestMetrics(selection);
    try { window.setStatus?.(`Added to Day · ${selection.label}`); } catch (_) {}
  };
  window.lifeRouteSaveBoundaryStop = saveBoundaryStop;

  const storeStatusHost = button => {
    const option = button.closest(".gapOption") || button.closest(".lrBoundaryGap");
    if (!option) return null;
    let host = option.querySelector(":scope > .lrBoundaryStorePicker");
    if (!host) {
      host = document.createElement("div");
      host.className = "lrBoundaryStorePicker";
      option.appendChild(host);
    }
    return host;
  };

  const startStoreSearch = (button, todoID) => {
    const todo = (window.lifeRouteTodos || []).find(item => String(item.id) === String(todoID));
    const queries = Array.isArray(todo?.storePreferences) ? todo.storePreferences.map(clean).filter(Boolean) : [];
    const card = button.closest(".lrBoundaryGap");
    const mode = clean(card?.dataset?.boundaryMode);
    const context = contextFor(mode);
    const host = storeStatusHost(button);
    if (!todo || !queries.length || !context || !host) return;

    requestCounter += 1;
    const requestID = `boundary-v2-${requestCounter}-${Date.now()}`;
    const request = {
      requestID,
      mode,
      todo,
      context,
      host,
      locations: [],
      routes: new Map(),
      finished: false,
      timeout: null
    };
    requests.set(requestID, request);
    button.disabled = true;
    button.textContent = "Searching…";
    host.innerHTML = `<div class="lrBoundaryStoreLoading"><b>Finding nearby branches…</b><div class="tiny">${safe(queries.join(" · "))} · searching along this route</div></div>`;

    const nearAddresses = [context.origin?.address, context.final?.address].map(clean).filter(Boolean);
    const handled = typeof window.postNative === "function" && window.postNative({
      action: "searchStoreLocations",
      requestID,
      queries,
      nearAddresses,
      limitPerQuery: 5
    });

    request.timeout = setTimeout(() => {
      if (request.finished) return;
      host.innerHTML = '<div class="lrBoundaryStoreLoading"><b>Still searching…</b><div class="tiny">The web fallback is checking nearby branches. This can take a few seconds on mobile Safari.</div></div>';
    }, 5000);

    if (!handled) {
      clearTimeout(request.timeout);
      request.finished = true;
      host.innerHTML = '<div class="lrBoundaryStoreLoading"><b>Branch search unavailable</b><div class="tiny">Route services are not available in this build.</div></div>';
      button.disabled = false;
      button.textContent = "Search stores";
    }
  };

  const renderStoreLocations = request => {
    if (!request?.host) return;
    if (!request.locations.length) {
      request.host.innerHTML = '<div class="lrBoundaryStoreLoading"><b>No nearby branches found</b><div class="tiny">Try another preferred chain or check that the route has locations.</div></div>';
      return;
    }
    request.host.innerHTML = `<div class="lrBoundaryStoreHead"><b>Nearby stores</b><span class="tiny">${request.locations.length} found</span></div><div class="lrBoundaryStoreList">${request.locations.slice(0, 10).map((location, index) => {
      const out = request.routes.get(`${location.id}|out`);
      const back = request.routes.get(`${location.id}|back`);
      const travel = Number(out?.minutes || 0) + Number(back?.minutes || 0);
      const routeLabel = travel > 0 ? `${fmtMinutes(travel)} travel` : "Route being checked";
      return `<button type="button" class="lrBoundaryStoreChoice" data-lr-boundary-request="${safe(request.requestID)}" data-lr-boundary-index="${index}"><span class="grow"><strong>${safe(location.name || location.brand || "Store")}</strong><small>${safe(location.address || "")}</small></span><span class="lrBoundaryStoreChoiceMeta">${safe(routeLabel)}</span></button>`;
    }).join("")}</div>`;
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
    clearTimeout(request.timeout);
    request.finished = true;
    const source = Array.isArray(evt.locations) ? evt.locations : [];
    request.locations = source.slice(0, 18).map((location, index) => ({
      ...location,
      id: `${request.requestID}|loc-${index}`
    }));
    const loadButton = request.host?.closest(".gapOption")?.querySelector("[data-boundary-stores]");
    if (loadButton) {
      loadButton.disabled = false;
      loadButton.textContent = request.locations.length ? "Search again" : "Search stores";
    }
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
    if (current?.__boundaryStopPlannerWrapped) return;
    const wrapped = function lifeRouteNativeEventWithBoundaryPlanner(evt) {
      if (typeof current === "function") current(evt);
      if (evt?.type === "storeLocations") handleStoreLocations(evt);
      if (evt?.type === "routeTimes") handleRouteTimes(evt);
    };
    wrapped.__boundaryStopPlannerWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const handleClick = event => {
    const placeButton = event.target.closest?.("[data-boundary-place]");
    if (placeButton) {
      const card = placeButton.closest(".lrBoundaryGap");
      const mode = clean(card?.dataset?.boundaryMode);
      const place = (window.places || []).find(item => String(item.id) === String(placeButton.dataset.boundaryPlace));
      if (mode && place) {
        event.preventDefault();
        event.stopImmediatePropagation();
        saveBoundaryStop(mode, { kind: "place", id: place.id, name: place.name, address: place.address, stopMinutes: place.minVisit });
      }
      return;
    }

    const todoButton = event.target.closest?.("[data-boundary-todo]");
    if (todoButton) {
      const card = todoButton.closest(".lrBoundaryGap");
      const mode = clean(card?.dataset?.boundaryMode);
      const todo = (window.lifeRouteTodos || []).find(item => String(item.id) === String(todoButton.dataset.boundaryTodo));
      if (mode && todo?.address) {
        event.preventDefault();
        event.stopImmediatePropagation();
        saveBoundaryStop(mode, { kind: "todo", id: todo.id, name: todo.title, address: todo.address, stopMinutes: todo.duration });
      }
      return;
    }

    const storeButton = event.target.closest?.("[data-boundary-stores]");
    if (storeButton) {
      event.preventDefault();
      event.stopImmediatePropagation();
      startStoreSearch(storeButton, storeButton.dataset.boundaryStores);
      return;
    }

    const branchButton = event.target.closest?.("[data-lr-boundary-request][data-lr-boundary-index]");
    if (branchButton) {
      const request = requests.get(clean(branchButton.dataset.lrBoundaryRequest));
      const index = Number(branchButton.dataset.lrBoundaryIndex);
      const location = request?.locations?.[index];
      if (!request || !location) return;
      event.preventDefault();
      event.stopImmediatePropagation();
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
    }
  };

  const polishButtons = () => {
    document.querySelectorAll("[data-boundary-place],[data-boundary-todo]").forEach(button => {
      if (button.textContent !== "Add to Day") button.textContent = "Add to Day";
    });
    document.querySelectorAll("[data-boundary-stores]").forEach(button => {
      if (!button.disabled && !/again/i.test(button.textContent || "")) button.textContent = "Search stores";
    });
    decorateBoundaryCards();
  };

  const style = document.createElement("style");
  style.id = "lifeRouteBoundaryStopPlannerStyles";
  style.textContent = `
    .lrBoundaryPlanned{border-style:solid!important;border-color:color-mix(in srgb,var(--green) 34%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--green) 5%,transparent),color-mix(in srgb,var(--blue) 4%,transparent)),var(--panel)!important}
    .lrBoundaryPlannedTop{display:flex;align-items:center;gap:10px}.lrBoundaryPlannedIcon{width:34px;height:34px;border-radius:11px;display:grid;place-items:center;background:color-mix(in srgb,var(--green) 8%,var(--panel2));border:1px solid color-mix(in srgb,var(--green) 20%,var(--line));color:var(--green)}
    .lrBoundaryPlanRoute{display:flex;align-items:center;gap:6px;margin-top:9px;font-size:10px;color:var(--muted)}.lrBoundaryPlanRoute .lrIcon{color:var(--gold)}.lrBoundaryPlanMetrics{margin-top:6px;color:var(--muted)}.lrBoundaryPlanActions{display:flex;gap:7px;margin-top:10px}.lrBoundaryPlanActions button{display:inline-flex;align-items:center;gap:5px;font-size:10px;padding:7px 10px}
    .lrBoundaryStorePicker{margin-top:10px;padding-top:10px;border-top:1px solid color-mix(in srgb,var(--line) 75%,transparent)}.lrBoundaryStoreLoading{padding:10px 11px;border-radius:12px;background:color-mix(in srgb,var(--panel2) 72%,transparent);border:1px solid var(--line)}.lrBoundaryStoreHead{display:flex;justify-content:space-between;gap:8px;align-items:center;margin-bottom:7px}.lrBoundaryStoreList{display:grid;gap:7px}.lrBoundaryStoreChoice{width:100%;display:flex;align-items:center;gap:10px;text-align:left;padding:10px 11px;border-radius:13px;background:color-mix(in srgb,var(--panel2) 76%,transparent);border:1px solid var(--line);color:var(--text)}.lrBoundaryStoreChoice strong,.lrBoundaryStoreChoice small{display:block}.lrBoundaryStoreChoice strong{font-size:11.5px}.lrBoundaryStoreChoice small{margin-top:2px;color:var(--muted);font-size:9px;line-height:1.35}.lrBoundaryStoreChoiceMeta{font-size:9px;color:var(--gold);white-space:nowrap}
  `;
  document.head.appendChild(style);

  document.addEventListener("click", handleClick, true);

  const start = () => {
    installEventHook();
    polishButtons();
    const observer = new MutationObserver(() => {
      installEventHook();
      polishButtons();
    });
    observer.observe(document.body, { childList: true, subtree: true });
    [300, 900, 1800, 3500].forEach(delay => setTimeout(() => { installEventHook(); polishButtons(); }, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
