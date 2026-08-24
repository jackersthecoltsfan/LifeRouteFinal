// Persistent selected-gap routes + ahead-of-time start planning.
// A chosen stop replaces the generic gap card and stays visible with route time,
// distance, start point, stop duration, and next destination.
(() => {
  const STORAGE_KEY = "liferoute_selected_gap_routes_v2";
  let selections = {};
  const metricRequests = new Map();

  const load = () => {
    try {
      const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      selections = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch (_) {
      selections = {};
    }
  };
  load();

  const save = () => localStorage.setItem(STORAGE_KEY, JSON.stringify(selections));
  const routeKey = (dateKey, previousID, nextID) => `${dateKey}|${previousID}|${nextID}`;
  const safeText = value => typeof esc === "function" ? esc(String(value || "")) : String(value || "");
  const icon = (name, size = 15) => typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon(name, size) : "";
  const miles = meters => Number(meters || 0) / 1609.344;

  const minutesLabel = (value, status = "ready") => {
    if (status === "loading") return "Updating…";
    const amount = Math.max(0, Math.round(Number(value || 0)));
    if (!amount) return "—";
    if (typeof fmt === "function") return fmt(amount);
    const hours = Math.floor(amount / 60);
    const mins = amount % 60;
    return hours ? `${hours}h${mins ? ` ${mins}m` : ""}` : `${mins}m`;
  };

  const distanceLabel = (meters, status = "ready") => {
    if (status === "loading") return "Updating…";
    const value = miles(meters);
    if (!(value > 0)) return "—";
    return `${value.toFixed(value < 10 ? 1 : 0)} mi`;
  };

  window.lifeRouteSelectedGapFor = (dateKey, previousID, nextID) => selections[routeKey(dateKey, previousID, nextID)] || null;

  const openRouteForSelection = selection => {
    const origin = selection.originMode === "previous" ? selection.originAddress || "" : "";
    if (typeof routeGapStop === "function") {
      routeGapStop(
        encodeURIComponent(selection.stop || ""),
        encodeURIComponent(selection.finalDestination || ""),
        encodeURIComponent(origin)
      );
    } else if (typeof routeTo === "function") {
      routeTo(encodeURIComponent(selection.stop || ""));
    }
  };

  const renderNow = () => {
    if (typeof renderToday === "function") renderToday();
    requestAnimationFrame(() => window.decorateLifeRouteSelectedGaps?.());
    setTimeout(() => window.decorateLifeRouteSelectedGaps?.(), 80);
  };

  const requestCurrentLocationMetrics = selection => {
    const live = typeof nativeState !== "undefined" ? nativeState.currentLocation : null;
    if (live?.latitude == null || live?.longitude == null || !selection.stop) {
      selection.metricStatus = "ready";
      selection.routeMinutes = selection.baseRouteMinutes || 0;
      selection.distanceMeters = selection.baseDistanceMeters || 0;
      selection.estimated = true;
      save();
      renderNow();
      return;
    }

    const token = `selected-gap-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const segments = [{
      id: `${token}|out`,
      origin: "Current location",
      originLatitude: Number(live.latitude),
      originLongitude: Number(live.longitude),
      destination: selection.stop,
      destinationMapItemKey: selection.stopMapItemKey || undefined
    }];
    if (selection.finalDestination) {
      segments.push({
        id: `${token}|back`,
        origin: selection.stop,
        originMapItemKey: selection.stopMapItemKey || undefined,
        destination: selection.finalDestination
      });
    }

    metricRequests.set(token, { key: selection.key, expected: segments.length });
    selection.metricStatus = "loading";
    selection.routeMinutes = 0;
    selection.distanceMeters = 0;
    save();
    renderNow();

    if (typeof postNative !== "function" || !postNative({ action: "requestRouteTimes", segments })) {
      metricRequests.delete(token);
      selection.metricStatus = "ready";
      selection.routeMinutes = selection.baseRouteMinutes || 0;
      selection.distanceMeters = selection.baseDistanceMeters || 0;
      selection.estimated = true;
      save();
      renderNow();
    }
  };

  const ensurePlanner = () => {
    let overlay = document.getElementById("gapRouteStartPlanner");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "gapRouteStartPlanner";
    overlay.className = "gapRoutePlannerOverlay";
    overlay.innerHTML = `
      <div class="gapRoutePlannerSheet" role="dialog" aria-modal="true" aria-labelledby="gapRoutePlannerTitle">
        <div class="gapRoutePlannerHandle"></div>
        <div class="small selectedGapKicker">PLAN THIS ROUTE</div>
        <div class="title" id="gapRoutePlannerTitle">Where should the route start?</div>
        <div class="meta" id="gapRoutePlannerCopy"></div>
        <div class="gapRoutePlannerChoices">
          <button class="primary" id="gapRouteStartCurrent">${icon("navigation", 15)} Current location</button>
          <button class="secondary" id="gapRouteStartPrevious">${icon("pin", 15)} Previous client</button>
          <button class="secondary" id="gapRouteStartCancel">Cancel</button>
        </div>
      </div>`;
    document.body.appendChild(overlay);
    return overlay;
  };

  const commitSelection = (pending, originMode) => {
    const key = routeKey(pending.dateKey, pending.previousID, pending.nextID);
    const selection = {
      key,
      dateKey: pending.dateKey,
      previousID: String(pending.previousID),
      nextID: String(pending.nextID),
      stop: pending.stop,
      stopMapItemKey: pending.stopMapItemKey || "",
      finalDestination: pending.finalDestination,
      label: pending.label,
      originMode,
      originAddress: originMode === "previous" ? pending.previousAddress : "",
      originLabel: originMode === "previous" ? pending.previousLabel : "Current location",
      baseRouteMinutes: Number(pending.routeMinutes || 0),
      baseDistanceMeters: Number(pending.distanceMeters || 0),
      routeMinutes: originMode === "previous" ? Number(pending.routeMinutes || 0) : 0,
      distanceMeters: originMode === "previous" ? Number(pending.distanceMeters || 0) : 0,
      stopMinutes: Number(pending.stopMinutes || 0),
      metricStatus: originMode === "previous" ? "ready" : "loading",
      estimated: false,
      selectedAt: new Date().toISOString()
    };
    selections[key] = selection;
    save();
    renderNow();
    if (typeof setStatus === "function") setStatus(`Route selected · ${selection.label}`);
    if (originMode === "current") requestCurrentLocationMetrics(selection);
    openRouteForSelection(selection);
  };

  window.planLifeRouteGapRoute = function planLifeRouteGapRoute(
    dateKey,
    previousID,
    nextID,
    encodedStop,
    encodedFinal,
    encodedLabel,
    routeMinutes,
    distanceMeters,
    stopMinutes,
    encodedPreviousAddress = "",
    encodedPreviousLabel = "Previous client",
    encodedMapItemKey = ""
  ) {
    const pending = {
      dateKey,
      previousID,
      nextID,
      stop: decodeURIComponent(encodedStop || "").trim(),
      finalDestination: decodeURIComponent(encodedFinal || "").trim(),
      label: decodeURIComponent(encodedLabel || "").trim() || "Selected stop",
      previousAddress: decodeURIComponent(encodedPreviousAddress || "").trim(),
      previousLabel: decodeURIComponent(encodedPreviousLabel || "").trim() || "Previous client",
      stopMapItemKey: decodeURIComponent(encodedMapItemKey || "").trim(),
      routeMinutes: Number(routeMinutes || 0),
      distanceMeters: Number(distanceMeters || 0),
      stopMinutes: Number(stopMinutes || 0)
    };
    if (!pending.dateKey || !pending.previousID || !pending.nextID || !pending.stop) return;

    const live = typeof nativeState !== "undefined" ? nativeState.currentLocation : null;
    const hasLive = live?.latitude != null && live?.longitude != null;
    if (!hasLive || !pending.previousAddress) {
      commitSelection(pending, pending.previousAddress ? "previous" : "current");
      return;
    }

    const overlay = ensurePlanner();
    const copy = overlay.querySelector("#gapRoutePlannerCopy");
    const previousButton = overlay.querySelector("#gapRouteStartPrevious");
    if (copy) copy.innerHTML = `Your live location is available. For planning ahead, you can instead start from <b>${safeText(pending.previousLabel)}</b>.`;
    if (previousButton) previousButton.innerHTML = `${icon("pin", 15)} Start from ${safeText(pending.previousLabel)}`;
    overlay.classList.add("show");

    const close = () => overlay.classList.remove("show");
    overlay.querySelector("#gapRouteStartCurrent").onclick = () => { close(); commitSelection(pending, "current"); };
    overlay.querySelector("#gapRouteStartPrevious").onclick = () => { close(); commitSelection(pending, "previous"); };
    overlay.querySelector("#gapRouteStartCancel").onclick = close;
    overlay.onclick = event => { if (event.target === overlay) close(); };
  };

  // Backward-compatible entry point for any older build-time button patch.
  window.chooseLifeRouteGapRoute = function chooseLifeRouteGapRoute(...args) {
    window.planLifeRouteGapRoute(...args);
  };

  window.clearLifeRouteGapRoute = encodedKey => {
    const key = decodeURIComponent(encodedKey || "");
    if (!key || !selections[key]) return;
    delete selections[key];
    save();
    renderNow();
    if (typeof setStatus === "function") setStatus("Gap route cleared");
  };

  window.reopenLifeRouteGapRoute = encodedKey => {
    const key = decodeURIComponent(encodedKey || "");
    const selection = selections[key];
    if (selection) openRouteForSelection(selection);
  };

  const selectedCardHTML = (selection, next) => {
    const status = selection.metricStatus || "ready";
    const routeTime = minutesLabel(selection.routeMinutes, status);
    const distance = distanceLabel(selection.distanceMeters, status);
    const stopTime = Number(selection.stopMinutes || 0) > 0 ? `${minutesLabel(selection.stopMinutes)} stop` : "Planned stop";
    const nextLabel = next?.title || "next event";
    const estimate = selection.estimated ? '<span class="selectedGapEstimate">estimated</span>' : "";
    return `
      <div class="selectedGapTop">
        <div class="selectedGapIcon">${icon("route", 17)}</div>
        <div class="grow">
          <div class="small selectedGapKicker">SELECTED ROUTE</div>
          <div class="title">${safeText(selection.label)}</div>
          <div class="meta">${safeText(selection.stop)}</div>
        </div>
        <span class="badge green">Planned</span>
      </div>
      <div class="selectedGapStart">${icon(selection.originMode === "previous" ? "pin" : "navigation", 13)} <span>Start: <b>${safeText(selection.originLabel || "Current location")}</b></span></div>
      <div class="selectedGapMetrics">
        <div><span>${icon("clock", 14)} Travel time ${estimate}</span><b>${safeText(routeTime)}</b></div>
        <div><span>${icon("route", 14)} Distance</span><b>${safeText(distance)}</b></div>
        <div><span>${icon("check", 14)} Stop</span><b>${safeText(stopTime)}</b></div>
      </div>
      <div class="selectedGapNext">${icon("navigation", 14)} <span>Then continue to <b>${safeText(nextLabel)}</b></span></div>
      <div class="selectedGapActions">
        <button class="secondary" onclick="event.stopPropagation();reopenLifeRouteGapRoute('${encodeURIComponent(selection.key)}')">${icon("navigation", 14)} Open route</button>
        <button class="secondary" onclick="event.stopPropagation();clearLifeRouteGapRoute('${encodeURIComponent(selection.key)}')">Change</button>
      </div>`;
  };

  window.decorateLifeRouteSelectedGaps = function decorateLifeRouteSelectedGaps() {
    if (typeof dayEvents !== "function" || typeof selectedDate === "undefined") return;
    const list = dayEvents(selectedDate);
    const gaps = Array.from(document.querySelectorAll("#timeline .card.gap"));
    gaps.forEach((gap, index) => {
      const previous = list[index];
      const next = list[index + 1];
      if (!previous || !next) return;
      const key = routeKey(selectedDate, String(previous.id), String(next.id));
      const selection = selections[key];
      if (!selection || gap.dataset.selectedRouteKey === key) return;
      gap.dataset.selectedRouteKey = key;
      gap.classList.add("gapRouteSelected");
      gap.classList.remove("gapClickable");
      gap.onclick = null;
      gap.innerHTML = selectedCardHTML(selection, next);
    });
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithSelectedGapMetrics(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (!evt || evt.type !== "routeTimes") return;
    const results = Array.isArray(evt.results) ? evt.results : [];
    for (const [token, request] of metricRequests.entries()) {
      const matches = results.filter(result => String(result.id || "").startsWith(`${token}|`));
      if (!matches.length) continue;
      const selection = selections[request.key];
      metricRequests.delete(token);
      if (!selection) continue;
      const good = matches.filter(result => Number(result.minutes || 0) > 0 && !result.error);
      if (good.length) {
        selection.routeMinutes = good.reduce((sum, result) => sum + Number(result.minutes || 0), 0);
        selection.distanceMeters = good.reduce((sum, result) => sum + Number(result.distanceMeters || 0), 0);
        selection.metricStatus = "ready";
        selection.estimated = good.some(result => !!result.approximate) || good.length < request.expected;
      } else {
        selection.routeMinutes = selection.baseRouteMinutes || 0;
        selection.distanceMeters = selection.baseDistanceMeters || 0;
        selection.metricStatus = "ready";
        selection.estimated = true;
      }
      save();
      renderNow();
    }
  };

  const style = document.createElement("style");
  style.id = "selectedGapRouteStyles";
  style.textContent = `
    .gapRouteSelected{border-color:color-mix(in srgb,var(--gold) 43%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 5%,transparent),color-mix(in srgb,var(--blue) 5%,transparent)),var(--panel)!important;box-shadow:0 14px 38px rgba(0,0,0,.13),inset 0 0 0 1px color-mix(in srgb,var(--gold) 7%,transparent)!important}
    .selectedGapTop{display:flex;align-items:center;gap:10px}.selectedGapIcon{width:34px;height:34px;display:grid;place-items:center;border-radius:11px;background:color-mix(in srgb,var(--blue) 9%,var(--panel2));border:1px solid color-mix(in srgb,var(--line) 82%,transparent);color:var(--blue)}
    .selectedGapKicker{font-size:8.5px!important;letter-spacing:.11em;font-weight:900;color:var(--gold)!important;margin-bottom:2px}.selectedGapStart,.selectedGapNext{display:flex;align-items:center;gap:6px;margin-top:9px;color:var(--muted);font-size:10px}.selectedGapStart .lrIcon,.selectedGapNext .lrIcon{color:var(--gold)}
    .selectedGapMetrics{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:10px}.selectedGapMetrics>div{padding:9px 10px;border-radius:12px;background:color-mix(in srgb,var(--panel2) 74%,transparent);border:1px solid color-mix(in srgb,var(--line) 66%,transparent)}.selectedGapMetrics span{display:flex;align-items:center;gap:5px;font-size:8.5px;color:var(--muted);margin-bottom:4px}.selectedGapMetrics b{display:block;font-size:12.5px;letter-spacing:-.15px}.selectedGapEstimate{font-size:7.5px!important;text-transform:uppercase;letter-spacing:.07em;color:var(--gold)!important}
    .selectedGapActions{display:flex;gap:7px;margin-top:10px}.selectedGapActions button{font-size:10px;padding:7px 10px;display:inline-flex;align-items:center;gap:5px}
    .gapRoutePlannerOverlay{position:fixed;inset:0;z-index:9999;display:flex;align-items:flex-end;justify-content:center;padding:14px;background:rgba(2,7,14,.42);backdrop-filter:blur(9px);-webkit-backdrop-filter:blur(9px);opacity:0;pointer-events:none;transition:opacity .18s ease}.gapRoutePlannerOverlay.show{opacity:1;pointer-events:auto}.gapRoutePlannerSheet{width:min(520px,100%);padding:17px;border-radius:22px;background:color-mix(in srgb,var(--panel) 95%,var(--bg));border:1px solid color-mix(in srgb,var(--line) 90%,transparent);box-shadow:0 28px 90px rgba(0,0,0,.35);transform:translateY(16px);transition:transform .2s ease}.gapRoutePlannerOverlay.show .gapRoutePlannerSheet{transform:translateY(0)}.gapRoutePlannerHandle{width:38px;height:4px;border-radius:999px;background:color-mix(in srgb,var(--muted) 35%,transparent);margin:0 auto 14px}.gapRoutePlannerSheet>.title{font-size:18px!important;margin-bottom:5px}.gapRoutePlannerChoices{display:grid;gap:8px;margin-top:14px}.gapRoutePlannerChoices button{min-height:44px;display:flex;align-items:center;justify-content:center;gap:7px}
    @media(max-width:480px){.selectedGapMetrics{grid-template-columns:1fr 1fr}.selectedGapMetrics>div:last-child{grid-column:1/-1}.selectedGapTop .badge{display:none}}
  `;
  document.head.appendChild(style);

  const previousRenderToday = window.renderToday;
  if (typeof previousRenderToday === "function" && !previousRenderToday.__lifeRouteSelectedGapV2) {
    const wrapped = function renderTodayWithPersistentGapRoute(...args) {
      const value = previousRenderToday.apply(this, args);
      window.decorateLifeRouteSelectedGaps();
      return value;
    };
    wrapped.__lifeRouteSelectedGapV2 = true;
    window.renderToday = wrapped;
  }

  const startObserver = () => {
    const timeline = document.getElementById("timeline");
    if (!timeline || timeline.dataset.selectedGapObserver) return;
    timeline.dataset.selectedGapObserver = "1";
    let queued = false;
    const observer = new MutationObserver(() => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        window.decorateLifeRouteSelectedGaps();
      });
    });
    observer.observe(timeline, { childList: true, subtree: false });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      startObserver();
      window.decorateLifeRouteSelectedGaps();
    }, { once: true });
  } else {
    startObserver();
    window.decorateLifeRouteSelectedGaps();
  }
})();
