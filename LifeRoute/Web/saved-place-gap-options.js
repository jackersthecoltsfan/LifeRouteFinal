// Saved Places inside the ordinary between-appointment gap chooser.
// This stays separate from To-Dos so a saved place does not have to masquerade
// as an errand. Choosing one uses the same persistent selected-gap route state.
(() => {
  if (window.__lifeRouteSavedPlaceGapOptionsLoaded) return;
  window.__lifeRouteSavedPlaceGapOptionsLoaded = true;

  const requests = new Map();
  const clean = value => String(value || "").trim();
  const safe = value => typeof window.esc === "function"
    ? window.esc(String(value || ""))
    : String(value || "").replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"})[ch]);
  const icon = (name, size = 14) => typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon(name, size, "lrInlineIcon") : "";
  const fmtMinutes = value => typeof window.fmt === "function" ? window.fmt(Number(value || 0)) : `${Math.max(0, Math.round(Number(value || 0)))}m`;
  const miles = meters => Number(meters || 0) / 1609.344;

  const availablePlaces = () => {
    const source = Array.isArray(window.places) ? window.places : [];
    return source
      .filter(place => clean(place?.address))
      .slice()
      .sort((a, b) => {
        const preferred = Number(!!b?.useInGaps) - Number(!!a?.useInGaps);
        if (preferred) return preferred;
        return clean(a?.name).localeCompare(clean(b?.name));
      })
      .slice(0, 10);
  };

  const requestKey = (dateKey, gapIndex, panelId) => `${dateKey}|${gapIndex}|${panelId}`;

  const statusFor = (candidate, rawGap) => {
    const duration = Math.max(0, Number(candidate.place?.minVisit || 30));
    const drive = Number(candidate.outMinutes || 0) + Number(candidate.backMinutes || 0);
    const required = duration + drive;
    const slack = rawGap - required;
    const routeKnown = candidate.expectedLegs === 0 || candidate.successLegs === candidate.expectedLegs;
    if (!routeKnown) return { label: "Route incomplete", cls: "unknown", slack, drive, duration, fit: false };
    if (slack >= 0) return { label: `Fits · ${fmtMinutes(slack)} left`, cls: "fit", slack, drive, duration, fit: true };
    return { label: `Needs ${fmtMinutes(Math.abs(slack))} more`, cls: "miss", slack, drive, duration, fit: false };
  };

  const renderSection = request => {
    const panel = document.getElementById(request.panelId);
    if (!panel) return;

    let section = panel.querySelector("[data-lr-saved-place-gap]");
    if (!section) {
      section = document.createElement("div");
      section.dataset.lrSavedPlaceGap = "1";
      section.className = "lrSavedPlaceGapSection";
      panel.appendChild(section);
    }

    if (!request.candidates.length) {
      section.innerHTML = `<div class="lrSavedPlaceGapHead"><div><b>Saved places</b><span>Nothing saved with an address yet</span></div></div>`;
      return;
    }

    const ranked = request.candidates.slice().map(candidate => ({
      ...candidate,
      status: statusFor(candidate, request.rawGap)
    })).sort((a, b) => {
      if (a.status.fit !== b.status.fit) return a.status.fit ? -1 : 1;
      if (!!a.place.useInGaps !== !!b.place.useInGaps) return a.place.useInGaps ? -1 : 1;
      return b.status.slack - a.status.slack;
    });

    section.innerHTML = `
      <div class="lrSavedPlaceGapHead">
        <div><b>Saved places</b><span>Places you already know</span></div>
        <span class="badge">${ranked.length}</span>
      </div>
      <div class="lrSavedPlaceGapList">
        ${ranked.slice(0, 8).map((candidate, index) => {
          const place = candidate.place;
          const s = candidate.status;
          const distanceMeters = Number(candidate.outDistanceMeters || 0) + Number(candidate.backDistanceMeters || 0);
          const parts = [];
          if (candidate.outMinutes) parts.push(`${fmtMinutes(candidate.outMinutes)} there`);
          parts.push(`${fmtMinutes(s.duration)} stop`);
          if (candidate.backMinutes) parts.push(`${fmtMinutes(candidate.backMinutes)} to next`);
          if (distanceMeters > 0) parts.push(`${miles(distanceMeters).toFixed(distanceMeters < 16093 ? 1 : 0)} mi`);
          if (candidate.expectedLegs > candidate.successLegs && candidate.finished) parts.push("route estimate incomplete");
          return `<div class="lrSavedPlaceGapOption ${index === 0 && s.fit ? "best" : ""}">
            <div class="lrSavedPlaceGapTop">
              <div class="lrSavedPlaceGapIcon">${icon("pin", 15)}</div>
              <div class="grow">
                <div class="small">${safe(place.type || "Saved place")}${place.useInGaps ? " · preferred" : ""}</div>
                <div class="title">${safe(place.name || "Saved place")}</div>
                <div class="meta">${safe(place.address)}</div>
              </div>
              <span class="${s.cls}">${safe(s.label)}</span>
            </div>
            <div class="tiny lrSavedPlaceGapMetrics">${safe(parts.join(" · "))}</div>
            <div class="gapOptionButtons"><button type="button" class="secondary" data-lr-place-choice="${index}">${icon("route", 13)} Choose</button></div>
          </div>`;
        }).join("")}
      </div>`;

    section.querySelectorAll("[data-lr-place-choice]").forEach(button => {
      button.addEventListener("click", event => {
        event.preventDefault();
        event.stopPropagation();
        const candidate = ranked[Number(button.dataset.lrPlaceChoice)];
        const place = candidate?.place;
        if (!candidate || !place || typeof window.planLifeRouteGapRoute !== "function") return;
        const drive = Number(candidate.outMinutes || 0) + Number(candidate.backMinutes || 0);
        const distance = Number(candidate.outDistanceMeters || 0) + Number(candidate.backDistanceMeters || 0);
        window.planLifeRouteGapRoute(
          request.dateKey,
          String(request.previous?.id || ""),
          String(request.next?.id || ""),
          encodeURIComponent(clean(place.address)),
          encodeURIComponent(clean(request.next?.address)),
          encodeURIComponent(clean(place.name || place.address)),
          drive,
          distance,
          Number(place.minVisit || 30),
          encodeURIComponent(clean(request.previous?.address)),
          encodeURIComponent(clean(request.previous?.title || "Previous appointment")),
          "",
          Number(candidate.outMinutes || 0),
          Number(candidate.backMinutes || 0),
          Number(candidate.outDistanceMeters || 0),
          Number(candidate.backDistanceMeters || 0)
        );
      });
    });
  };

  const startRequest = (dateKey, gapIndex, panelId) => {
    const panel = document.getElementById(panelId);
    const list = typeof window.dayEvents === "function" ? window.dayEvents(dateKey) : [];
    const previous = list[gapIndex];
    const next = list[gapIndex + 1];
    if (!panel || !previous || !next) return;

    const places = availablePlaces();
    const rawGap = Math.max(0, Number(window.mins?.(next.start) || 0) - Number(window.mins?.(previous.end) || 0));
    const candidates = places.map((place, index) => ({
      index,
      place,
      outMinutes: 0,
      backMinutes: 0,
      outDistanceMeters: 0,
      backDistanceMeters: 0,
      expectedLegs: 0,
      successLegs: 0,
      finished: false
    }));
    const token = `saved-place-gap-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const request = { token, dateKey, gapIndex, panelId, previous, next, rawGap, candidates, segmentMap: new Map(), observer: null };
    requests.set(requestKey(dateKey, gapIndex, panelId), request);

    // The To-Do engine may replace panel.innerHTML after its own route results
    // arrive. Re-attach Saved Places after that render without disturbing it.
    request.observer = new MutationObserver(() => {
      if (!document.getElementById(panelId)) return;
      if (!panel.querySelector("[data-lr-saved-place-gap]")) renderSection(request);
    });
    request.observer.observe(panel, { childList: true });

    renderSection(request);
    if (!candidates.length) return;

    const segments = [];
    candidates.forEach(candidate => {
      const address = clean(candidate.place.address);
      if (clean(previous.address)) {
        const id = `${token}|${candidate.index}|out`;
        candidate.expectedLegs += 1;
        request.segmentMap.set(id, { candidate, leg: "out" });
        segments.push({ id, date: dateKey, origin: previous.address, destination: address });
      }
      if (clean(next.address)) {
        const id = `${token}|${candidate.index}|back`;
        candidate.expectedLegs += 1;
        request.segmentMap.set(id, { candidate, leg: "back" });
        segments.push({ id, date: dateKey, origin: address, destination: next.address });
      }
    });

    if (!segments.length || typeof window.postNative !== "function" || !window.postNative({ action: "requestRouteTimes", segments })) {
      candidates.forEach(candidate => { candidate.finished = true; });
      renderSection(request);
    }
  };

  const installGapWrapper = () => {
    const current = window.openGapTodoSuggestions;
    if (typeof current !== "function") return false;
    if (current.__savedPlacesWrapped) return true;
    const wrapped = function openGapSuggestionsWithSavedPlaces(dateKey, gapIndex, panelId) {
      const result = current.apply(this, arguments);
      requestAnimationFrame(() => startRequest(dateKey, Number(gapIndex), panelId));
      return result;
    };
    wrapped.__savedPlacesWrapped = true;
    window.openGapTodoSuggestions = wrapped;
    return true;
  };

  const installEventWrapper = () => {
    const current = window.lifeRouteNativeEvent;
    if (current?.__savedPlaceGapWrapped) return true;
    const wrapped = function lifeRouteNativeEventWithSavedPlaces(evt) {
      if (typeof current === "function") current(evt);
      if (!evt || evt.type !== "routeTimes") return;
      const results = Array.isArray(evt.results) ? evt.results : [];
      if (!results.length) return;
      requests.forEach(request => {
        let touched = false;
        results.forEach(result => {
          const mapping = request.segmentMap.get(String(result.id || ""));
          if (!mapping) return;
          touched = true;
          const { candidate, leg } = mapping;
          if (!result.error && Number(result.minutes || 0) > 0) {
            candidate.successLegs += 1;
            if (leg === "out") {
              candidate.outMinutes = Number(result.minutes || 0);
              candidate.outDistanceMeters = Number(result.distanceMeters || 0);
            } else {
              candidate.backMinutes = Number(result.minutes || 0);
              candidate.backDistanceMeters = Number(result.distanceMeters || 0);
            }
          }
        });
        if (!touched) return;
        request.candidates.forEach(candidate => { candidate.finished = true; });
        renderSection(request);
      });
    };
    wrapped.__savedPlaceGapWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
    return true;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteSavedPlaceGapStyles";
  style.textContent = `
    .lrSavedPlaceGapSection{margin-top:12px;padding-top:12px;border-top:1px solid var(--line)}
    .lrSavedPlaceGapHead{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:7px}.lrSavedPlaceGapHead>div{display:grid;gap:1px}.lrSavedPlaceGapHead b{font-size:12px}.lrSavedPlaceGapHead span{font-size:9px;color:var(--muted)}
    .lrSavedPlaceGapList{display:grid;gap:7px}.lrSavedPlaceGapOption{padding:10px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel2) 58%,transparent)}.lrSavedPlaceGapOption.best{border-color:color-mix(in srgb,var(--gold) 48%,var(--line))}
    .lrSavedPlaceGapTop{display:flex;align-items:flex-start;gap:8px}.lrSavedPlaceGapIcon{width:28px;height:28px;display:grid;place-items:center;border-radius:9px;background:color-mix(in srgb,var(--blue) 10%,var(--panel2));border:1px solid var(--line);flex:0 0 28px}.lrSavedPlaceGapTop>.fit,.lrSavedPlaceGapTop>.miss,.lrSavedPlaceGapTop>.unknown{font-size:9px;font-weight:900;white-space:nowrap}.lrSavedPlaceGapMetrics{margin:6px 0 0 36px}
    @media(max-width:520px){.lrSavedPlaceGapTop{flex-wrap:wrap}.lrSavedPlaceGapTop>.fit,.lrSavedPlaceGapTop>.miss,.lrSavedPlaceGapTop>.unknown{margin-left:36px}.lrSavedPlaceGapMetrics{margin-left:36px}}
  `;
  document.head.appendChild(style);

  const start = () => {
    installGapWrapper();
    installEventWrapper();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      installGapWrapper();
      installEventWrapper();
      if (attempts > 60) clearInterval(timer);
    }, 100);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();