// LifeRoute day-route experience: simplified Day UI, boundary stop slots, and one
// consistent directions launcher for saved places, appointments, and to-dos.
(() => {
  if (window.__lifeRouteDayRouteExperienceLoaded) return;
  window.__lifeRouteDayRouteExperienceLoaded = true;

  const icon = (name, size = 15, cls = "") => typeof window.lifeRouteIcon === "function"
    ? window.lifeRouteIcon(name, size, cls)
    : "";
  const clean = value => String(value || "").trim();
  const safe = value => typeof window.esc === "function" ? window.esc(String(value || "")) : String(value || "");
  const currentDayKey = () => clean(window.selectedDate);
  const currentEvents = () => typeof window.dayEvents === "function" ? window.dayEvents(currentDayKey()) : [];
  const homeAddress = () => clean(window.prefs?.homeAddress) || clean((window.places || []).find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const isToday = () => typeof window.localDateKey === "function" && currentDayKey() === window.localDateKey(new Date());

  const clientCode = client => {
    const pair = value => {
      const letters = clean(value).replace(/[^a-z]/gi, "").slice(0, 2);
      return letters ? letters[0].toUpperCase() + letters.slice(1).toLowerCase() : "";
    };
    return `${pair(client?.first2)}${pair(client?.last2)}` || clean(client?.name) || "Client";
  };

  const clientOrigins = () => (Array.isArray(window.prefs?.clients) ? window.prefs.clients : [])
    .filter(client => clean(client?.address))
    .map(client => ({ label: clientCode(client), address: clean(client.address), icon: "user" }));

  const transportFlag = () => {
    const mode = clean(window.prefs?.transportMode || "driving");
    return mode === "walking" ? "w" : mode === "transit" ? "r" : "d";
  };

  const selectedProvider = () => {
    let provider = clean(window.prefs?.mapProvider || "apple");
    if (provider === "ask") provider = window.confirm("OK = Google Maps\nCancel = Apple Maps") ? "google" : "apple";
    return provider === "google" ? "google" : "apple";
  };

  const launchDirections = (destination, origin = "") => {
    const dest = clean(destination);
    if (!dest) return;
    const start = clean(origin);
    const provider = selectedProvider();
    const mode = clean(window.prefs?.transportMode || "driving");

    try {
      if (typeof window.postNative === "function" && window.postNative({
        action: "openRoute",
        provider,
        origin: start || undefined,
        destination: dest
      })) return;
    } catch (_) {}

    if (provider === "google") {
      const params = new URLSearchParams({ api: "1", destination: dest, travelmode: mode });
      if (start) params.set("origin", start);
      window.location.href = `https://www.google.com/maps/dir/?${params.toString()}`;
      return;
    }

    const params = new URLSearchParams({ daddr: dest, dirflg: transportFlag() });
    if (start) params.set("saddr", start);
    window.location.href = `https://maps.apple.com/?${params.toString()}`;
  };

  const ensureOriginPicker = () => {
    let overlay = document.getElementById("lifeRouteOriginPicker");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteOriginPicker";
    overlay.className = "lrOriginOverlay";
    overlay.innerHTML = `
      <div class="lrOriginSheet" role="dialog" aria-modal="true" aria-labelledby="lrOriginTitle">
        <div class="lrOriginHandle"></div>
        <div class="small">START DIRECTIONS</div>
        <div class="title" id="lrOriginTitle">Where are you starting?</div>
        <div class="meta" id="lrOriginDestination"></div>
        <div class="lrOriginChoices" id="lrOriginChoices"></div>
        <button type="button" class="secondary lrOriginCancel">Cancel</button>
      </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector(".lrOriginCancel").onclick = () => overlay.classList.remove("show");
    overlay.onclick = event => { if (event.target === overlay) overlay.classList.remove("show"); };
    return overlay;
  };

  window.lifeRouteChooseRouteOrigin = function lifeRouteChooseRouteOrigin(destination, options = {}) {
    const dest = clean(destination);
    if (!dest) return;
    const overlay = ensureOriginPicker();
    const destinationLabel = clean(options.destinationLabel) || dest;
    const meta = overlay.querySelector("#lrOriginDestination");
    if (meta) meta.textContent = `To ${destinationLabel}`;
    const choices = overlay.querySelector("#lrOriginChoices");
    if (!choices) return;

    const items = [{ label: "Live location", address: "", icon: "navigation", note: "Use where you are now" }];
    const home = homeAddress();
    if (home) items.push({ label: "Home", address: home, icon: "home", note: home });
    clientOrigins().forEach(client => items.push({ ...client, note: client.address }));

    choices.innerHTML = items.map((item, index) => `
      <button type="button" class="lrOriginChoice ${index === 0 ? "primary" : "secondary"}" data-origin-index="${index}">
        <span class="lrOriginChoiceIcon">${icon(item.icon, 17)}</span>
        <span class="grow"><b>${safe(item.label)}</b><small>${safe(item.note || "")}</small></span>
        ${icon("navigation", 14)}
      </button>`).join("");
    choices.querySelectorAll("[data-origin-index]").forEach(button => {
      button.onclick = () => {
        const item = items[Number(button.dataset.originIndex)];
        overlay.classList.remove("show");
        launchDirections(dest, item?.address || "");
      };
    });
    overlay.classList.add("show");
  };

  // Simple routes throughout the app now share the same origin picker. Multi-stop
  // gap routes keep their explicit origin/waypoint logic.
  window.routeTo = encoded => window.lifeRouteChooseRouteOrigin(decodeURIComponent(encoded || ""));
  window.openPlace = encoded => window.lifeRouteChooseRouteOrigin(decodeURIComponent(encoded || ""));
  window.lifeRouteLaunchDirections = launchDirections;

  const boundaryContexts = new Map();
  const storeRequests = new Map();
  let requestCounter = 0;

  const originForBoundary = mode => {
    const list = currentEvents();
    const home = homeAddress();
    if (mode === "before") {
      const live = window.nativeState?.currentLocation;
      if (isToday() && live?.latitude != null && live?.longitude != null) {
        return { label: "Live location", address: "", latitude: Number(live.latitude), longitude: Number(live.longitude) };
      }
      return home ? { label: "Home", address: home } : { label: "Live location", address: "" };
    }
    const last = list.at(-1);
    return last ? { label: clean(last.title) || "Last appointment", address: clean(last.address) } : null;
  };

  const finalForBoundary = mode => {
    const list = currentEvents();
    if (mode === "before") {
      const first = list[0];
      return first ? { label: clean(first.title) || "First appointment", address: clean(first.address) } : null;
    }
    const home = homeAddress();
    return home ? { label: "Home", address: home } : null;
  };

  const routeBoundaryStop = (context, stop) => {
    const destination = clean(stop?.address || stop?.name);
    if (!destination) return;
    const origin = clean(context?.origin?.address);
    const final = clean(context?.final?.address);
    if (typeof window.routeGapStop === "function" && final) {
      window.routeGapStop(encodeURIComponent(destination), encodeURIComponent(final), encodeURIComponent(origin));
      return;
    }
    if (origin) launchDirections(destination, origin);
    else window.lifeRouteChooseRouteOrigin(destination, { destinationLabel: stop?.name || destination });
  };

  const openBoundaryPlanner = (mode, panelId) => {
    const panel = document.getElementById(panelId);
    const list = currentEvents();
    if (!panel || !list.length) return;
    const context = {
      mode,
      panelId,
      dateKey: currentDayKey(),
      origin: originForBoundary(mode),
      final: finalForBoundary(mode)
    };
    boundaryContexts.set(panelId, context);

    const todos = (window.lifeRouteTodos || []).filter(todo => !todo.completed);
    const savedPlaces = (window.places || []).filter(place => place.useInGaps && clean(place.address));
    const options = [];
    todos.slice(0, 10).forEach(todo => options.push({ type: "todo", todo }));
    savedPlaces.slice(0, 8).forEach(place => options.push({ type: "place", place }));

    const heading = mode === "before" ? "Stops before your first appointment" : "Stops on the way back";
    const routeCopy = [context.origin?.label, context.final?.label].filter(Boolean).join(" → stop → ") || "Choose a useful stop";
    if (!options.length) {
      panel.innerHTML = `<div class="gapSuggestHead">${heading}</div><div class="tiny">Add a To-Do or Saved Place and it can appear here.</div>`;
      panel.style.display = "block";
      return;
    }

    panel.innerHTML = `<div class="gapSuggestHead">${heading}</div><div class="tiny">${safe(routeCopy)}${context.final?.label ? safe(context.final.label) : ""}. These are optional stops, so LifeRoute ranks the route rather than pretending there is a fixed time window.</div>` + options.map(item => {
      if (item.type === "place") {
        const place = item.place;
        return `<div class="gapOption"><div class="row"><div class="grow"><div class="small">${icon("pin",13,"lrInlineIcon")}Saved place · ${safe(place.type || "Place")}</div><div class="title">${safe(place.name)}</div><div class="meta">${safe(place.address)}</div></div></div><div class="gapOptionButtons"><button type="button" class="secondary" data-boundary-place="${safe(place.id)}">Route this stop</button></div></div>`;
      }
      const todo = item.todo;
      const prefs = Array.isArray(todo.storePreferences) ? todo.storePreferences.filter(Boolean) : [];
      const located = clean(todo.address);
      return `<div class="gapOption"><div class="row"><div class="grow"><div class="small">${icon(prefs.length ? "cart" : "check",13,"lrInlineIcon")}To-Do · ${safe(todo.category || "Task")}</div><div class="title">${safe(todo.title)}</div><div class="meta">${prefs.length ? `Any ${safe(prefs.join(" · "))}` : located ? safe(located) : "Flexible / no location"}</div></div></div><div class="gapOptionButtons">${prefs.length ? `<button type="button" class="secondary" data-boundary-stores="${safe(todo.id)}">Load branches</button>` : located ? `<button type="button" class="secondary" data-boundary-todo="${safe(todo.id)}">Route this stop</button>` : ""}${typeof window.completeLifeRouteTodo === "function" ? `<button type="button" class="primary" data-boundary-done="${safe(todo.id)}">Mark done</button>` : ""}</div></div>`;
    }).join("");
    panel.style.display = "block";

    panel.querySelectorAll("[data-boundary-place]").forEach(button => button.onclick = event => {
      event.stopPropagation();
      const place = (window.places || []).find(item => String(item.id) === String(button.dataset.boundaryPlace));
      if (place) routeBoundaryStop(context, place);
    });
    panel.querySelectorAll("[data-boundary-todo]").forEach(button => button.onclick = event => {
      event.stopPropagation();
      const todo = (window.lifeRouteTodos || []).find(item => String(item.id) === String(button.dataset.boundaryTodo));
      if (todo) routeBoundaryStop(context, { name: todo.title, address: todo.address });
    });
    panel.querySelectorAll("[data-boundary-done]").forEach(button => button.onclick = event => {
      event.stopPropagation();
      window.completeLifeRouteTodo?.(button.dataset.boundaryDone);
    });
    panel.querySelectorAll("[data-boundary-stores]").forEach(button => button.onclick = event => {
      event.stopPropagation();
      loadBoundaryStores(context, button.dataset.boundaryStores, panel);
    });
  };

  const loadBoundaryStores = (context, todoID, panel) => {
    const todo = (window.lifeRouteTodos || []).find(item => String(item.id) === String(todoID));
    const queries = Array.isArray(todo?.storePreferences) ? todo.storePreferences.filter(Boolean) : [];
    if (!todo || !queries.length || typeof window.postNative !== "function") return;
    requestCounter += 1;
    const requestID = `boundary-store-${requestCounter}-${Date.now()}`;
    storeRequests.set(requestID, { requestID, context, todo, panel, locations: [], routes: new Map() });
    const nearAddresses = [context.origin?.address, context.final?.address].map(clean).filter(Boolean);
    panel.insertAdjacentHTML("beforeend", `<div class="lrBoundaryStoreStatus" data-boundary-request="${requestID}"><b>Loading nearby branches…</b><div class="tiny">Comparing ${safe(queries.join(" · "))} along this route.</div></div>`);
    if (!window.postNative({ action: "searchStoreLocations", requestID, queries, nearAddresses, limitPerQuery: 4 })) {
      const status = panel.querySelector(`[data-boundary-request="${requestID}"]`);
      if (status) status.innerHTML = '<b>Branch search unavailable</b><div class="tiny">Try again after route services are available.</div>';
    }
  };

  const renderBoundaryStores = request => {
    const status = request.panel?.querySelector(`[data-boundary-request="${request.requestID}"]`);
    if (!status) return;
    const ranked = request.locations.map(location => {
      const out = request.routes.get(`${location.id}|out`);
      const back = request.routes.get(`${location.id}|back`);
      const minutes = Number(out?.minutes || 0) + Number(back?.minutes || 0);
      return { location, out, back, minutes, complete: (!!out || !request.context.origin?.address) && (!!back || !request.context.final?.address) };
    }).sort((a,b) => (a.complete === b.complete ? a.minutes - b.minutes : a.complete ? -1 : 1));
    if (!ranked.length) {
      status.innerHTML = '<b>No nearby branches found</b><div class="tiny">Try another preferred chain or check the route locations.</div>';
      return;
    }
    status.innerHTML = `<b>Nearby branches</b><div class="lrBoundaryBranchList">${ranked.slice(0,8).map((item,index) => `<button type="button" class="lrBoundaryBranch secondary" data-boundary-branch="${index}"><span class="grow"><strong>${safe(item.location.name || item.location.brand || "Store")}</strong><small>${safe(item.location.address || "")}</small></span><span>${item.minutes ? `${item.minutes}m` : "Route"}</span></button>`).join("")}</div>`;
    status.querySelectorAll("[data-boundary-branch]").forEach(button => button.onclick = event => {
      event.stopPropagation();
      const item = ranked[Number(button.dataset.boundaryBranch)];
      if (item) routeBoundaryStop(request.context, { name: item.location.name, address: item.location.address || item.location.name });
    });
  };

  const handleStoreLocations = evt => {
    const request = storeRequests.get(String(evt.requestID || ""));
    if (!request) return;
    request.locations = (Array.isArray(evt.locations) ? evt.locations : []).slice(0, 16).map((location,index) => ({ ...location, id: `${request.requestID}|loc-${index}` }));
    if (!request.locations.length) {
      renderBoundaryStores(request);
      return;
    }
    const segments = [];
    request.locations.forEach(location => {
      if (request.context.origin?.address) segments.push({ id: `${location.id}|out`, origin: request.context.origin.address, destination: location.address || location.name, destinationLatitude: location.latitude, destinationLongitude: location.longitude });
      if (request.context.final?.address) segments.push({ id: `${location.id}|back`, origin: location.address || location.name, originLatitude: location.latitude, originLongitude: location.longitude, destination: request.context.final.address });
    });
    if (!segments.length || !window.postNative({ action: "requestRouteTimes", segments })) {
      renderBoundaryStores(request);
    }
  };

  const handleRouteTimes = evt => {
    const results = Array.isArray(evt.results) ? evt.results : [];
    storeRequests.forEach(request => {
      const matches = results.filter(result => String(result.id || "").startsWith(`${request.requestID}|`));
      if (!matches.length) return;
      matches.forEach(result => request.routes.set(String(result.id), result));
      renderBoundaryStores(request);
    });
  };

  const installNativeEventHook = () => {
    if (window.lifeRouteNativeEvent?.__dayRouteExperienceWrapped) return;
    const previous = window.lifeRouteNativeEvent;
    const wrapped = function lifeRouteNativeEventWithBoundaryStops(evt) {
      if (typeof previous === "function") previous(evt);
      if (evt?.type === "storeLocations") handleStoreLocations(evt);
      if (evt?.type === "routeTimes") handleRouteTimes(evt);
    };
    wrapped.__dayRouteExperienceWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const boundaryCard = mode => {
    const before = mode === "before";
    const panelId = `boundaryGap-${mode}-${currentDayKey()}`.replace(/[^a-zA-Z0-9_-]/g,"-");
    const card = document.createElement("div");
    card.className = `card lrBoundaryGap lrBoundaryGap-${mode}`;
    card.dataset.boundaryMode = mode;
    const context = { origin: originForBoundary(mode), final: finalForBoundary(mode) };
    const routeLabel = before
      ? `${context.origin?.label || "Your start"} → optional stop → ${context.final?.label || "first appointment"}`
      : `${context.origin?.label || "Last appointment"} → optional stop${context.final?.label ? ` → ${context.final.label}` : ""}`;
    card.innerHTML = `<div class="row"><div class="grow"><div class="small">${before ? "BEFORE FIRST APPOINTMENT" : "AFTER LAST APPOINTMENT"}</div><div class="title">${before ? "Stop on the way" : "Stop on the way back"}</div><div class="meta">${safe(routeLabel)}</div></div><button type="button" class="secondary lrBoundaryOpen">Find a stop</button></div><div class="gapSuggest" id="${panelId}" style="display:none"></div>`;
    card.querySelector(".lrBoundaryOpen").onclick = event => { event.stopPropagation(); openBoundaryPlanner(mode,panelId); };
    card.onclick = event => { if (!event.target.closest("button")) openBoundaryPlanner(mode,panelId); };
    return card;
  };

  const renderBoundaryCards = () => {
    const timeline = document.getElementById("timeline");
    const list = currentEvents();
    if (!timeline || !list.length) return;
    timeline.querySelectorAll(".lrBoundaryGap").forEach(node => node.remove());
    timeline.prepend(boundaryCard("before"));
    timeline.appendChild(boundaryCard("after"));
  };

  const simplifyDay = () => {
    const today = document.getElementById("today");
    if (!today) return;
    today.classList.add("lrSimpleDay");
    const heroP = today.querySelector(".hero > p");
    if (heroP) heroP.textContent = "Appointments, travel, and useful stops — in one route.";
    const metricLabels = today.querySelectorAll(".metrics .metric span");
    if (metricLabels[0]) metricLabels[0].textContent = "scheduled";
    if (metricLabels[1]) metricLabels[1].textContent = "travel";
    if (metricLabels[2]) metricLabels[2].textContent = "open between";
  };

  const wrapRenderToday = () => {
    const previous = window.renderToday;
    if (typeof previous !== "function" || previous.__dayRouteExperienceWrapped) return false;
    const wrapped = function renderTodayWithBoundaryStops(...args) {
      const value = previous.apply(this,args);
      simplifyDay();
      renderBoundaryCards();
      installNativeEventHook();
      return value;
    };
    wrapped.__dayRouteExperienceWrapped = true;
    window.renderToday = wrapped;
    return true;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteDayRouteExperienceStyles";
  style.textContent = `
    #today.lrSimpleDay .hero{padding:13px 15px!important;margin-bottom:10px!important}#today.lrSimpleDay .hero h2{font-size:18px!important;margin-bottom:3px!important}#today.lrSimpleDay .hero p{font-size:11px!important;opacity:.88}#today.lrSimpleDay .sourceLine{margin-top:6px!important}
    #today.lrSimpleDay .metrics{grid-template-columns:repeat(3,1fr)!important;gap:7px!important}#today.lrSimpleDay .metrics .metric{padding:10px!important;border-radius:15px!important}#today.lrSimpleDay .metrics .metric b{font-size:17px!important}#today.lrSimpleDay .metrics .metric:nth-child(4){display:none!important}
    #today.lrSimpleDay .section{margin-top:14px!important}#today.lrSimpleDay .sectionHead{margin-bottom:7px!important}#today.lrSimpleDay #timeline>.card{margin-bottom:8px!important}
    .lrBoundaryGap{border-style:dashed!important;border-color:color-mix(in srgb,var(--gold) 32%,var(--line))!important;background:color-mix(in srgb,var(--panel) 88%,transparent)!important}.lrBoundaryGap .small{font-size:9px;font-weight:900;color:var(--gold);letter-spacing:.05em}.lrBoundaryGap .title{font-size:14px}.lrBoundaryOpen{white-space:nowrap;font-size:10px!important;padding:8px 10px!important}
    .lrOriginOverlay{position:fixed;inset:0;z-index:35000;display:none;align-items:flex-end;justify-content:center;padding:12px;background:rgba(2,7,14,.68);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px)}.lrOriginOverlay.show{display:flex}.lrOriginSheet{width:min(620px,100%);max-height:82vh;overflow:auto;padding:17px;border-radius:26px 26px 20px 20px;background:color-mix(in srgb,var(--panel) 96%,#07111f);border:1px solid var(--line);box-shadow:0 30px 90px rgba(0,0,0,.45)}.lrOriginHandle{width:44px;height:5px;border-radius:99px;background:var(--line);margin:0 auto 13px}.lrOriginChoices{display:grid;gap:7px;margin:13px 0}.lrOriginChoice{width:100%;display:flex!important;align-items:center!important;gap:10px!important;text-align:left!important;padding:11px 12px!important}.lrOriginChoice b{display:block;font-size:12px}.lrOriginChoice small{display:block;margin-top:2px;color:var(--muted);font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.lrOriginChoiceIcon{width:25px;display:grid;place-items:center}.lrOriginCancel{width:100%}
    .lrBoundaryStoreStatus{margin-top:10px;padding:10px;border-radius:13px;border:1px solid var(--line);background:var(--panel2)}.lrBoundaryBranchList{display:grid;gap:6px;margin-top:8px}.lrBoundaryBranch{display:flex!important;width:100%;align-items:center!important;gap:9px!important;text-align:left!important}.lrBoundaryBranch strong,.lrBoundaryBranch small{display:block}.lrBoundaryBranch small{margin-top:2px;color:var(--muted);font-size:9px;overflow:hidden;text-overflow:ellipsis}
    @media(max-width:520px){#today.lrSimpleDay .metrics{grid-template-columns:repeat(3,1fr)!important}#today.lrSimpleDay .metrics .metric{padding:9px 7px!important}#today.lrSimpleDay .metrics .metric b{font-size:15px!important}.lrBoundaryGap>.row{align-items:flex-start}.lrBoundaryOpen{flex:0 0 auto}}
  `;
  document.head.appendChild(style);

  const start = () => {
    simplifyDay();
    installNativeEventHook();
    wrapRenderToday();
    renderBoundaryCards();
    [400,900,1800].forEach(delay => setTimeout(() => { wrapRenderToday(); installNativeEventHook(); simplifyDay(); renderBoundaryCards(); },delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(start,120), { once:true });
  else setTimeout(start,120);
})();