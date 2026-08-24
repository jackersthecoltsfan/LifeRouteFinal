// Persist the route a user actually chooses for a schedule gap.
// When they return from Maps, the chosen stop remains in the timeline in place
// of the generic gap and shows its route time + distance at a glance.
(() => {
  const STORAGE_KEY = "liferoute_selected_gap_routes_v1";
  let selections = {};

  const load = () => {
    try {
      const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      selections = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch (_) {
      selections = {};
    }
  };

  const save = () => localStorage.setItem(STORAGE_KEY, JSON.stringify(selections));
  const safeText = value => typeof esc === "function" ? esc(String(value || "")) : String(value || "");
  const routeKey = (dateKey, previousID, nextID) => `${dateKey}|${previousID}|${nextID}`;
  const miles = meters => Number(meters || 0) / 1609.344;

  const minutesLabel = value => {
    const amount = Math.max(0, Math.round(Number(value || 0)));
    if (!amount) return "Time unavailable";
    if (typeof fmt === "function") return fmt(amount);
    const hours = Math.floor(amount / 60);
    const mins = amount % 60;
    return hours ? `${hours}h${mins ? ` ${mins}m` : ""}` : `${mins}m`;
  };

  const distanceLabel = meters => {
    const value = miles(meters);
    if (!(value > 0)) return "Distance unavailable";
    return `${value.toFixed(value < 10 ? 1 : 0)} mi`;
  };

  const icon = (name, size = 15) => typeof window.lifeRouteIcon === "function"
    ? window.lifeRouteIcon(name, size)
    : "";

  window.chooseLifeRouteGapRoute = function chooseLifeRouteGapRoute(
    dateKey,
    previousID,
    nextID,
    encodedStop,
    encodedFinal,
    encodedLabel,
    routeMinutes,
    distanceMeters,
    stopMinutes = 0
  ) {
    const stop = decodeURIComponent(encodedStop || "").trim();
    const finalDestination = decodeURIComponent(encodedFinal || "").trim();
    const label = decodeURIComponent(encodedLabel || "").trim() || "Selected stop";
    if (!dateKey || !previousID || !nextID || !stop) return;

    const key = routeKey(dateKey, previousID, nextID);
    selections[key] = {
      key,
      dateKey,
      previousID: String(previousID),
      nextID: String(nextID),
      stop,
      finalDestination,
      label,
      routeMinutes: Number(routeMinutes || 0),
      distanceMeters: Number(distanceMeters || 0),
      stopMinutes: Number(stopMinutes || 0),
      selectedAt: new Date().toISOString()
    };
    save();

    if (typeof renderToday === "function") renderToday();
    if (typeof setStatus === "function") setStatus(`Route selected · ${label}`);

    // Keep the handoff inside the same user gesture so iOS opens the selected
    // maps provider immediately.
    if (typeof routeGapStop === "function") {
      routeGapStop(encodeURIComponent(stop), encodeURIComponent(finalDestination));
    } else if (typeof routeTo === "function") {
      routeTo(encodeURIComponent(stop));
    }
  };

  window.clearLifeRouteGapRoute = function clearLifeRouteGapRoute(encodedKey) {
    const key = decodeURIComponent(encodedKey || "");
    if (!key || !selections[key]) return;
    delete selections[key];
    save();
    if (typeof renderToday === "function") renderToday();
    if (typeof setStatus === "function") setStatus("Gap route cleared");
  };

  window.reopenLifeRouteGapRoute = function reopenLifeRouteGapRoute(encodedKey) {
    const key = decodeURIComponent(encodedKey || "");
    const selection = selections[key];
    if (!selection) return;
    if (typeof routeGapStop === "function") {
      routeGapStop(
        encodeURIComponent(selection.stop),
        encodeURIComponent(selection.finalDestination || "")
      );
    }
  };

  const decorateSelectedGaps = () => {
    if (typeof dayEvents !== "function" || typeof selectedDate === "undefined") return;
    const list = dayEvents(selectedDate);
    const gaps = Array.from(document.querySelectorAll("#timeline .card.gap"));

    gaps.forEach((gap, index) => {
      const previous = list[index];
      const next = list[index + 1];
      if (!previous || !next) return;
      const key = routeKey(selectedDate, String(previous.id), String(next.id));
      const selection = selections[key];
      if (!selection) return;

      const routeTime = minutesLabel(selection.routeMinutes);
      const distance = distanceLabel(selection.distanceMeters);
      const stopTime = Number(selection.stopMinutes || 0) > 0 ? `${minutesLabel(selection.stopMinutes)} stop` : "Planned stop";
      const finalLabel = next.title || "next event";

      gap.classList.add("gapRouteSelected");
      gap.classList.remove("gapClickable");
      gap.onclick = null;
      gap.innerHTML = `
        <div class="selectedGapTop">
          <div class="selectedGapIcon">${icon("route", 17)}</div>
          <div class="grow">
            <div class="small selectedGapKicker">SELECTED ROUTE</div>
            <div class="title">${safeText(selection.label)}</div>
            <div class="meta">${safeText(selection.stop)}</div>
          </div>
          <span class="badge green">Locked in</span>
        </div>
        <div class="selectedGapMetrics">
          <div><span>${icon("clock", 14)} Route time</span><b>${safeText(routeTime)}</b></div>
          <div><span>${icon("route", 14)} Distance</span><b>${safeText(distance)}</b></div>
          <div><span>${icon("check", 14)} Stop</span><b>${safeText(stopTime)}</b></div>
        </div>
        <div class="selectedGapNext">${icon("navigation", 14)} <span>Then continue to <b>${safeText(finalLabel)}</b></span></div>
        <div class="selectedGapActions">
          <button class="secondary" onclick="event.stopPropagation();reopenLifeRouteGapRoute('${encodeURIComponent(key)}')">${icon("navigation", 14)} Open route</button>
          <button class="secondary" onclick="event.stopPropagation();clearLifeRouteGapRoute('${encodeURIComponent(key)}')">Change</button>
        </div>`;
    });
  };

  const style = document.createElement("style");
  style.id = "selectedGapRouteStyles";
  style.textContent = `
    .gapRouteSelected{border-color:color-mix(in srgb,var(--gold) 45%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 6%,transparent),color-mix(in srgb,var(--blue) 5%,transparent)),var(--panel)!important;box-shadow:0 12px 34px rgba(0,0,0,.13),inset 0 0 0 1px color-mix(in srgb,var(--gold) 8%,transparent)!important}
    .selectedGapTop{display:flex;align-items:center;gap:10px}.selectedGapIcon{width:34px;height:34px;display:grid;place-items:center;border-radius:11px;background:color-mix(in srgb,var(--blue) 9%,var(--panel2));border:1px solid color-mix(in srgb,var(--line) 82%,transparent);color:var(--blue)}
    .selectedGapKicker{font-size:8.5px!important;letter-spacing:.11em;font-weight:900;color:var(--gold)!important;margin-bottom:2px}
    .selectedGapMetrics{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:11px}.selectedGapMetrics>div{padding:9px 10px;border-radius:12px;background:color-mix(in srgb,var(--panel2) 76%,transparent);border:1px solid color-mix(in srgb,var(--line) 68%,transparent)}.selectedGapMetrics span{display:flex;align-items:center;gap:5px;font-size:8.5px;color:var(--muted);margin-bottom:4px}.selectedGapMetrics b{display:block;font-size:12.5px;letter-spacing:-.15px}
    .selectedGapNext{display:flex;align-items:center;gap:6px;margin-top:9px;color:var(--muted);font-size:10px}.selectedGapNext .lrIcon{color:var(--gold)}
    .selectedGapActions{display:flex;gap:7px;margin-top:10px}.selectedGapActions button{font-size:10px;padding:7px 10px;display:inline-flex;align-items:center;gap:5px}
    @media(max-width:480px){.selectedGapMetrics{grid-template-columns:1fr 1fr}.selectedGapMetrics>div:last-child{grid-column:1/-1}.selectedGapTop .badge{display:none}}
  `;
  document.head.appendChild(style);

  const start = () => {
    load();
    const previousRenderToday = window.renderToday;
    if (typeof previousRenderToday === "function" && !previousRenderToday.__lifeRouteSelectedGapWrapped) {
      const wrapped = function renderTodayWithSelectedGap(...args) {
        const value = previousRenderToday.apply(this, args);
        decorateSelectedGaps();
        return value;
      };
      wrapped.__lifeRouteSelectedGapWrapped = true;
      window.renderToday = wrapped;
    }
    decorateSelectedGaps();
    if (typeof renderToday === "function") renderToday();
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
