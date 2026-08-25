// Compact Day controls + native Live Activity handoff.
(() => {
  if (window.__lifeRouteDayControlsV5Loaded) return;
  window.__lifeRouteDayControlsV5Loaded = true;

  const GENERATED_STORE = "liferoute_generated_days_v1";
  const GAP_STORE = "liferoute_selected_gap_routes_v2";
  const BOUNDARY_STORE = "liferoute_boundary_stops_v2";
  const AUTH_STORE = "liferoute_auth_browser_v2";
  const clean = value => String(value || "").trim();
  const dateKey = () => clean(window.selectedDate);
  const at = (day, time) => new Date(`${day}T${time || "00:00"}:00`);
  const addMinutes = (date, amount) => new Date(date.getTime() + Number(amount || 0) * 60000);
  const listForDay = day => typeof window.dayEvents === "function" ? window.dayEvents(day) : [];

  const readObject = key => {
    try {
      const parsed = JSON.parse(localStorage.getItem(key) || "{}");
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (_) { return {}; }
  };

  const writeObject = (key, value) => {
    try { localStorage.setItem(key, JSON.stringify(value || {})); } catch (_) {}
  };

  const boundaryFor = (day, mode) => readObject(BOUNDARY_STORE)[`${day}|${mode}`] || null;

  const checkpoint = ({ title, address, kind, start, end, leaveAt }) => ({
    title: clean(title) || "Next stop",
    address: clean(address),
    kind: clean(kind) || "stop",
    startISO: start.toISOString(),
    endISO: end.toISOString(),
    leaveAtISO: leaveAt instanceof Date && !Number.isNaN(leaveAt.getTime()) ? leaveAt.toISOString() : ""
  });

  const buildActivityCheckpoints = day => {
    const events = listForDay(day);
    if (!events.length) return [];
    const output = [];
    const before = boundaryFor(day, "before");
    const after = boundaryFor(day, "after");

    if (before) {
      const firstStart = at(day, events[0].start);
      const back = Math.max(0, Number(before.backMinutes || 0));
      const duration = Math.max(1, Number(before.stopMinutes || 30));
      const out = Math.max(0, Number(before.outMinutes || 0));
      const end = addMinutes(firstStart, -back);
      const start = addMinutes(end, -duration);
      output.push(checkpoint({
        title: before.label || before.name || "Planned stop",
        address: before.address,
        kind: before.kind || "stop",
        start,
        end,
        leaveAt: addMinutes(start, -out)
      }));
    }

    events.forEach((event, index) => {
      const start = at(day, event.start);
      const end = at(day, event.end);
      const buffer = Math.max(0, Number(event.buffer || 10));
      let leaveAt = Number(event.drive || 0) > 0 ? addMinutes(start, -(Number(event.drive || 0) + buffer)) : null;

      if (index > 0 && typeof window.lifeRouteSelectedGapFor === "function") {
        const previous = events[index - 1];
        const selection = window.lifeRouteSelectedGapFor(day, String(previous?.id || ""), String(event?.id || ""));
        if (selection) {
          const total = Math.max(0, Number(selection.routeMinutes || 0));
          const outMinutes = Math.max(0, Number(selection.outMinutes || (total ? Math.round(total / 2) : 0)));
          const backMinutes = Math.max(0, Number(selection.backMinutes || (total ? Math.max(1, total - outMinutes) : 0)));
          const stopMinutes = Math.max(1, Number(selection.stopMinutes || 30));
          const previousEnd = at(day, previous.end);
          const stopStart = addMinutes(previousEnd, outMinutes);
          const stopEnd = addMinutes(stopStart, stopMinutes);
          output.push(checkpoint({
            title: selection.label || "Planned stop",
            address: selection.stop,
            kind: "stop",
            start: stopStart,
            end: stopEnd,
            leaveAt: previousEnd
          }));
          if (backMinutes > 0) leaveAt = addMinutes(start, -(backMinutes + buffer));
        }
      }

      output.push(checkpoint({
        title: event.title || "Appointment",
        address: event.address,
        kind: "appointment",
        start,
        end,
        leaveAt
      }));
    });

    if (after) {
      const last = events.at(-1);
      const lastEnd = at(day, last.end);
      const out = Math.max(0, Number(after.outMinutes || 0));
      const duration = Math.max(1, Number(after.stopMinutes || 30));
      const start = addMinutes(lastEnd, out);
      output.push(checkpoint({
        title: after.label || after.name || "Planned stop",
        address: after.address,
        kind: after.kind || "stop",
        start,
        end: addMinutes(start, duration),
        leaveAt: lastEnd
      }));
    }

    if (window.prefs?.endDayAtHome) {
      const home = clean(window.prefs?.homeAddress) || clean((window.places || []).find(place => String(place?.type || "").toLowerCase() === "home")?.address);
      const last = events.at(-1);
      if (home && last) {
        const lastEnd = at(day, last.end);
        output.push(checkpoint({
          title: "Home",
          address: home,
          kind: "home",
          start: lastEnd,
          end: addMinutes(lastEnd, Math.max(20, Number(last.drive || 20))),
          leaveAt: lastEnd
        }));
      }
    }

    return output
      .sort((a, b) => new Date(a.startISO) - new Date(b.startISO))
      .slice(0, 12);
  };

  const startLiveActivity = () => {
    const day = dateKey();
    if (!day) return;
    const checkpoints = buildActivityCheckpoints(day);
    if (!checkpoints.length) return;
    const label = (() => {
      try {
        return new Date(`${day}T12:00:00`).toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" });
      } catch (_) { return day; }
    })();
    try {
      window.postNative?.({
        action: "startLiveDayActivity",
        dateKey: day,
        dayLabel: label,
        checkpoints
      });
    } catch (_) {}
  };

  const endLiveActivity = () => {
    try { window.postNative?.({ action: "endLiveDayActivity" }); } catch (_) {}
  };

  const clearDateKeys = (storeKey, day) => {
    const value = readObject(storeKey);
    Object.keys(value).forEach(key => {
      if (key === day || key.startsWith(`${day}|`)) delete value[key];
    });
    writeObject(storeKey, value);
  };

  const clearDay = () => {
    const day = dateKey();
    if (!day) return;
    if (!window.confirm("Clear this day's LifeRoute plan? Calendar events from connected providers will stay.")) return;

    try { window.endLifeRouteDay?.(); } catch (_) {}
    endLiveActivity();
    clearDateKeys(GENERATED_STORE, day);
    clearDateKeys(GAP_STORE, day);
    clearDateKeys(BOUNDARY_STORE, day);

    if (Array.isArray(window.events)) {
      window.events = window.events.filter(event => !(event?.date === day && (!event?.source || event.source === "manual")));
    }
    try { window.persist?.(); } catch (_) {}
    try { window.renderAll?.(); } catch (_) { try { window.renderToday?.(); } catch (_) {} }
  };

  const clearAll = () => {
    if (!window.confirm("Clear all LifeRoute plans, saved places, clients, To-Dos, calendar links, and preferences on this device? Your LifeRoute sign-in will stay.")) return;
    endLiveActivity();
    try { window.endLifeRouteDay?.(); } catch (_) {}

    let auth = null;
    try { auth = localStorage.getItem(AUTH_STORE); } catch (_) {}
    try {
      const keys = [];
      for (let i = 0; i < localStorage.length; i += 1) {
        const key = localStorage.key(i);
        if (key && key.startsWith("liferoute_")) keys.push(key);
      }
      keys.forEach(key => localStorage.removeItem(key));
      if (auth) localStorage.setItem(AUTH_STORE, auth);
    } catch (_) {}

    if (Array.isArray(window.events)) window.events = [];
    if (Array.isArray(window.places)) window.places = [];
    try { window.lifeRouteTodos = []; } catch (_) {}
    window.location.reload();
  };

  const ensureStrip = () => {
    const hero = document.querySelector("#today .hero");
    if (!hero) return;
    hero.classList.add("lrDayHeroRemoved");

    let strip = document.getElementById("lrDayCommandStrip");
    if (!strip) {
      strip = document.createElement("div");
      strip.id = "lrDayCommandStrip";
      strip.className = "lrDayCommandStrip";
      hero.before(strip);
    }

    const controls = document.getElementById("liveDayControls");
    if (controls && controls.parentElement !== strip) strip.prepend(controls);
    controls?.classList.add("lrDayPrimaryControls");

    if (!strip.querySelector("[data-lr-clear-day]")) {
      const actions = document.createElement("div");
      actions.className = "lrDayClearControls";
      actions.innerHTML = `
        <button type="button" class="secondary" data-lr-clear-day>Clear day</button>
        <button type="button" class="secondary lrClearAll" data-lr-clear-all>Clear all</button>`;
      strip.appendChild(actions);
      actions.querySelector("[data-lr-clear-day]")?.addEventListener("click", clearDay);
      actions.querySelector("[data-lr-clear-all]")?.addEventListener("click", clearAll);
    }

    const endHome = document.getElementById("endHomeOption");
    if (endHome && endHome.parentElement !== strip) {
      endHome.classList.add("lrEndHomeCompact");
      strip.appendChild(endHome);
    }
  };

  const wrapGenerate = () => {
    const original = window.generateLifeRouteDay;
    if (typeof original !== "function" || original.__lrActivityWrapped) return;
    const wrapped = function(...args) {
      const result = original.apply(this, args);
      setTimeout(() => {
        ensureStrip();
        startLiveActivity();
      }, 40);
      return result;
    };
    wrapped.__lrActivityWrapped = true;
    window.generateLifeRouteDay = wrapped;
  };

  const wrapEnd = () => {
    const original = window.endLifeRouteDay;
    if (typeof original !== "function" || original.__lrActivityWrapped) return;
    const wrapped = function(...args) {
      const result = original.apply(this, args);
      endLiveActivity();
      setTimeout(ensureStrip, 20);
      return result;
    };
    wrapped.__lrActivityWrapped = true;
    window.endLifeRouteDay = wrapped;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteDayControlsV5Styles";
  style.textContent = `
    #today .hero.lrDayHeroRemoved{display:none!important}
    .lrDayCommandStrip{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:0 0 13px;padding:0;background:transparent!important;border:0!important;box-shadow:none!important}
    .lrDayPrimaryControls{display:flex!important;align-items:center;gap:7px!important;flex-wrap:wrap;margin:0!important}.lrDayPrimaryControls button{min-height:42px!important;padding:9px 13px!important}
    .lrDayClearControls{display:flex;gap:7px;align-items:center}.lrDayClearControls button{min-height:42px;padding:9px 12px;font-size:10px}.lrClearAll{color:var(--red)!important;border-color:color-mix(in srgb,var(--red) 32%,var(--line))!important}
    .lrEndHomeCompact{order:10;flex:1 1 100%;margin:1px 0 0!important;min-height:auto!important;padding:9px 11px!important;border-radius:14px!important}.lrEndHomeCompact .title{font-size:10.5px!important}.lrEndHomeCompact .meta{font-size:8.5px!important}.lrEndHomeCompact .switch{transform:scale(.82);transform-origin:right center}
    @media(max-width:520px){.lrDayCommandStrip{gap:6px}.lrDayPrimaryControls{flex:1 1 auto}.lrDayPrimaryControls .liveDayGenerate{flex:1}.lrDayClearControls{width:100%}.lrDayClearControls button{flex:1}.lrDayPrimaryControls button{min-height:40px!important}.lrDayClearControls button{min-height:38px}}
  `;
  document.head.appendChild(style);

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithActivity(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (evt?.type !== "liveActivityStatus") return;
    const panel = document.getElementById("liveDayPanel");
    if (!panel) return;
    panel.dataset.liveActivity = evt.started ? "started" : evt.ended ? "ended" : "status";
  };

  let queued = false;
  const install = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      wrapGenerate();
      wrapEnd();
      ensureStrip();
    });
  };

  const observer = new MutationObserver(install);
  const start = () => {
    observer.observe(document.body, { childList: true, subtree: true });
    install();
    [100, 300, 800, 1600].forEach(delay => setTimeout(install, delay));
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();

  window.LifeRouteDayControlsV5 = { clearDay, clearAll, buildActivityCheckpoints, startLiveActivity };
})();
