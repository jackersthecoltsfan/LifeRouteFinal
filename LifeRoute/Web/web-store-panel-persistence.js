// Web-only store search UI persistence.
// Route-time updates can rerender the entire Day timeline while a store search
// is still running. The native boundary planner keeps request state in memory,
// but its DOM references then point at detached nodes. This bridge mirrors the
// active request and rehydrates it into the replacement card so mobile Safari
// never appears to "go back" when Search stores is tapped.
(() => {
  if (window.__lifeRouteWebStorePanelPersistenceLoaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebStorePanelPersistenceLoaded = true;

  const clean = value => String(value || "").trim();
  const safe = value => clean(value).replace(/[&<>"']/g, ch => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[ch]);

  let active = null;
  let restoreQueued = false;

  const miles = meters => Number(meters || 0) / 1609.344;
  const fmtMinutes = minutes => `${Math.max(1, Math.round(Number(minutes || 0)))}m`;

  const activeButton = () => {
    const openPanel = document.querySelector('.lrBoundaryPanel[data-lr-boundary-open="1"]');
    const buttons = Array.from((openPanel || document).querySelectorAll?.('[data-boundary-stores]') || []);
    return buttons.find(button => button.disabled || /Searching/i.test(button.textContent || "")) || buttons[0] || null;
  };

  const locateLiveNodes = state => {
    if (!state) return {};
    const card = document.querySelector(`#timeline .lrBoundaryGap[data-boundary-mode="${state.mode}"]`);
    const panel = card?.querySelector('.lrBoundaryPanel,.gapSuggest');
    let button = null;
    if (panel) {
      button = Array.from(panel.querySelectorAll('[data-boundary-stores]'))
        .find(node => String(node.dataset.boundaryStores) === String(state.todoID)) || null;
    }
    const host = button?.closest('.lrBoundaryTodoChoice')?.querySelector('.lrBoundaryStorePicker') || null;
    return { card, panel, button, host };
  };

  const routeFor = (state, index, direction) => {
    if (!state?.routes) return null;
    return state.routes.get(`${state.requestID}|loc-${index}|${direction}`) || null;
  };

  const renderIntoLivePanel = () => {
    if (!active) return;
    if (Date.now() > active.keepUntil) {
      active = null;
      return;
    }

    let { card, panel, button, host } = locateLiveNodes(active);
    if (!card || !panel) return;

    if (panel.dataset.lrBoundaryOpen !== "1" || panel.style.display === "none") {
      const open = card.querySelector('[data-lr-boundary-open]');
      if (typeof window.lifeRouteOpenBoundaryPlanner === "function") {
        window.lifeRouteOpenBoundaryPlanner(active.mode, panel.id, open);
      } else {
        panel.style.display = "block";
        panel.dataset.lrBoundaryOpen = "1";
      }
      ({ card, panel, button, host } = locateLiveNodes(active));
    }

    if (!button || !host) return;

    if (active.status === "searching") {
      button.disabled = true;
      button.textContent = "Searching…";
      host.innerHTML = `<div class="lrBoundaryStoreStatus"><b>Finding nearby branches…</b><span>${safe(active.queries.join(" · "))}</span></div>`;
      return;
    }

    button.disabled = false;
    button.textContent = "Search again";

    if (active.status === "error") {
      host.innerHTML = `<div class="lrBoundaryStoreStatus"><b>Store search unavailable</b><span>${safe(active.error || "Tap Search again to retry.")}</span></div>`;
      return;
    }

    const locations = Array.isArray(active.locations) ? active.locations : [];
    if (!locations.length) {
      host.innerHTML = '<div class="lrBoundaryStoreStatus"><b>No nearby branches found</b><span>Tap Search again to retry.</span></div>';
      return;
    }

    const ranked = locations.map((location, index) => {
      const out = routeFor(active, index, "out");
      const back = routeFor(active, index, "back");
      const travel = Number(out?.minutes || 0) + Number(back?.minutes || 0);
      const distance = Number(out?.distanceMeters || 0) + Number(back?.distanceMeters || 0);
      return { location, index, travel, distance };
    }).sort((a, b) => {
      if (a.travel && b.travel) return a.travel - b.travel;
      if (a.travel) return -1;
      if (b.travel) return 1;
      return a.index - b.index;
    });

    host.innerHTML = `<div class="lrBoundaryStoreResults">
      <div class="lrBoundaryStoreResultsHead"><b>Nearby branches</b><span>${ranked.length}</span></div>
      ${ranked.slice(0, 10).map(item => {
        const metric = item.travel
          ? `${fmtMinutes(item.travel)}${item.distance ? ` · ${miles(item.distance).toFixed(1)} mi` : ""}`
          : "Choose";
        return `<button type="button" class="lrBoundaryStoreChoice" data-lr-boundary-request="${safe(active.requestID)}" data-lr-boundary-location="${item.index}">
          <span class="grow"><strong>${safe(item.location?.name || item.location?.brand || "Store")}</strong><small>${safe(item.location?.address || "")}</small></span>
          <span class="lrBoundaryChoiceMeta">${safe(metric)}</span>
        </button>`;
      }).join("")}
    </div>`;
  };

  const scheduleRestore = () => {
    if (!active || restoreQueued) return;
    restoreQueued = true;
    requestAnimationFrame(() => {
      restoreQueued = false;
      renderIntoLivePanel();
    });
  };

  const installPostNativeHook = () => {
    const current = window.postNative;
    if (typeof current !== "function" || current.__lifeRouteWebStorePersistenceWrapped) return;

    const wrapped = function lifeRouteWebStorePersistencePostNative(payload) {
      if (clean(payload?.action) === "searchStoreLocations" && clean(payload?.requestID)) {
        const button = activeButton();
        const card = button?.closest('.lrBoundaryGap');
        const mode = clean(card?.dataset.boundaryMode);
        const todoID = clean(button?.dataset.boundaryStores);
        active = {
          requestID: clean(payload.requestID),
          mode,
          todoID,
          queries: Array.isArray(payload.queries) ? payload.queries.map(clean).filter(Boolean) : [],
          locations: [],
          routes: new Map(),
          status: "searching",
          error: "",
          keepUntil: Date.now() + 90000
        };
        scheduleRestore();
      }
      return current(payload);
    };
    wrapped.__lifeRouteWebStorePersistenceWrapped = true;
    window.postNative = wrapped;
    try { postNative = wrapped; } catch (_) {}
  };

  const installNativeEventHook = () => {
    const current = window.lifeRouteNativeEvent;
    if (typeof current !== "function" || current.__lifeRouteWebStorePersistenceWrapped) return;

    const wrapped = function lifeRouteWebStorePersistenceEvent(evt) {
      current(evt);

      if (active && evt?.type === "storeLocations" && clean(evt.requestID) === active.requestID) {
        active.locations = Array.isArray(evt.locations) ? evt.locations.slice(0, 18) : [];
        active.status = evt?.error && !active.locations.length ? "error" : "results";
        active.error = clean(evt?.error);
        active.keepUntil = Date.now() + 90000;
        scheduleRestore();
      }

      if (active && evt?.type === "routeTimes") {
        const results = Array.isArray(evt.results) ? evt.results : [];
        let changed = false;
        results.forEach(result => {
          const id = clean(result?.id);
          if (!id.startsWith(`${active.requestID}|loc-`)) return;
          active.routes.set(id, result);
          changed = true;
        });
        if (changed) scheduleRestore();
      }
    };

    // Preserve the planner marker so its own installer does not wrap this again.
    if (current.__lifeRouteBoundaryPlannerWrapped) wrapped.__lifeRouteBoundaryPlannerWrapped = true;
    wrapped.__lifeRouteWebStorePersistenceWrapped = true;
    window.lifeRouteNativeEvent = wrapped;
  };

  const installRenderHook = () => {
    const current = window.renderToday;
    if (typeof current !== "function" || current.__lifeRouteWebStorePersistenceWrapped) return;
    const wrapped = function renderTodayWithPersistentWebStorePicker(...args) {
      const result = current.apply(this, args);
      if (active) scheduleRestore();
      return result;
    };
    wrapped.__lifeRouteWebStorePersistenceWrapped = true;
    window.renderToday = wrapped;
  };

  // A close/selection gesture means the user intentionally left the picker;
  // clear mirrored state before the boundary planner's click handler runs.
  document.addEventListener("pointerdown", event => {
    if (!active) return;
    if (event.target.closest?.('[data-lr-boundary-close],[data-lr-boundary-location],[data-lr-boundary-change]')) {
      active = null;
    }
  }, true);

  const start = () => {
    installPostNativeHook();
    installNativeEventHook();
    installRenderHook();

    const timeline = document.getElementById("timeline");
    if (timeline) {
      new MutationObserver(() => {
        installPostNativeHook();
        installNativeEventHook();
        installRenderHook();
        scheduleRestore();
      }).observe(timeline, { childList: true, subtree: true });
    }

    [200, 600, 1400, 3000].forEach(delay => setTimeout(() => {
      installPostNativeHook();
      installNativeEventHook();
      installRenderHook();
      scheduleRestore();
    }, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
