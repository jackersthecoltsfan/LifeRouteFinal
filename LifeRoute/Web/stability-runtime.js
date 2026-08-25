// LifeRoute stability runtime: touch reliability, bottom actions, scroll safety,
// and mobile compositing guardrails shared by native iPhone and web builds.
(() => {
  if (window.__lifeRouteStabilityRuntimeLoaded) return;
  window.__lifeRouteStabilityRuntimeLoaded = true;

  const isNative = !!window.webkit?.messageHandlers?.lifeRoute;
  const root = document.documentElement;
  root.dataset.lifeRouteRuntime = isNative ? "native" : "web";

  const style = document.createElement("style");
  style.id = "lifeRouteStabilityRuntimeStyles";
  style.textContent = `
    html,body{overscroll-behavior-x:none;overscroll-behavior-y:none}
    html{min-height:100%;background:var(--metal-base,var(--bg,#07111f))}
    body{min-height:100dvh;touch-action:pan-y;-webkit-tap-highlight-color:transparent}
    button,a,[role="button"]{touch-action:manipulation}
    .bottom,.bottomin,.bottomin button{pointer-events:auto!important}
    .lrBoundaryGap,.lrBoundarySummary,.lrBoundaryOpen,.lrBoundaryGap button{pointer-events:auto!important}
    .lrBoundaryOpen,.lrBoundaryGap button{position:relative;z-index:2}
    #lifeRouteMetalBackdrop,#lifeRouteThemeFX,#lifeRouteNatureBackdrop,#lifeRouteDynamicBackdrop{pointer-events:none!important}
    html[data-life-route-runtime="native"] .bottom{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}
    html[data-life-route-runtime="native"] .tabs,
    html[data-life-route-runtime="native"] .calendarHubNav,
    html[data-life-route-runtime="native"] .liveDayPanel{backdrop-filter:blur(8px)!important;-webkit-backdrop-filter:blur(8px)!important}
    html[data-life-route-runtime="native"] #lifeRouteMetalBackdrop .metalWave,
    html[data-life-route-runtime="native"] #lifeRouteMetalBackdrop .specular{will-change:auto!important}
    @media(max-width:700px) and (pointer:coarse){
      html[data-life-route-runtime="web"] .dynC{display:none!important}
      html[data-life-route-runtime="web"] .dynLayer{filter:blur(24px)!important;will-change:auto!important}
      html[data-life-route-runtime="web"][data-nature-theme="true"] #lrNatureAtmosphere{display:none!important}
      html[data-life-route-runtime="web"] .bottom{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}
      html[data-life-route-runtime="web"][data-dynamic-theme] .card,
      html[data-life-route-runtime="web"][data-dynamic-theme] .metric,
      html[data-life-route-runtime="web"][data-dynamic-theme] .hero,
      html[data-life-route-runtime="web"][data-nature-theme="true"] .card,
      html[data-life-route-runtime="web"][data-nature-theme="true"] .metric,
      html[data-life-route-runtime="web"][data-nature-theme="true"] .hero{backdrop-filter:blur(8px)!important;-webkit-backdrop-filter:blur(8px)!important}
    }
    @media(prefers-reduced-motion:reduce){
      #lifeRouteMetalBackdrop *,#lifeRouteThemeFX *,#lifeRouteDynamicBackdrop *,#lifeRouteNatureBackdrop *{animation:none!important}
    }
  `;
  document.head.appendChild(style);

  const status = message => {
    try { if (typeof window.setStatus === "function") window.setStatus(message); } catch (_) {}
  };

  window.refreshCalendars = function lifeRouteStableRefreshCalendars() {
    let requested = false;
    const promises = [];

    if (isNative && typeof window.postNative === "function") {
      try {
        const sources = window.prefs?.sources || {};
        if (sources.apple !== false) requested = !!window.postNative({ action: "refreshAppleCalendar" }) || requested;
        if (sources.google !== false) requested = !!window.postNative({ action: "refreshGoogleCalendar" }) || requested;
      } catch (_) {}
    } else {
      const googleRefresh = document.getElementById("googleWebRefresh");
      if (googleRefresh && !googleRefresh.disabled) {
        googleRefresh.click();
        requested = true;
      }
    }

    try {
      if (typeof window.refreshLifeRouteCalendarFeeds === "function") {
        const result = window.refreshLifeRouteCalendarFeeds();
        if (result && typeof result.then === "function") promises.push(result);
        requested = true;
      }
    } catch (_) {}

    status(requested ? "Refreshing calendars…" : "Calendars are up to date");
    window.setTimeout(() => {
      try { window.renderAll?.(); } catch (_) {}
    }, 250);

    return promises.length ? Promise.allSettled(promises) : requested;
  };

  window.optimizeWeek = function lifeRouteStableOptimizeWeek() {
    try { window.renderWeek?.(); } catch (_) {}
    try { window.showView?.("week"); } catch (_) {}
    status("Showing this week’s best gaps");
    requestAnimationFrame(() => {
      const target = document.getElementById("weekInsight") || document.getElementById("weekChart");
      try { target?.scrollIntoView({ behavior: "smooth", block: "center" }); } catch (_) {}
    });
  };

  const bindBottomActions = () => {
    const bar = document.querySelector(".bottomin");
    if (!bar) return false;
    const buttons = bar.querySelectorAll("button");
    const refresh = buttons[0];
    const gaps = buttons[1];

    if (refresh && refresh.dataset.lifeRouteStableBound !== "1") {
      refresh.dataset.lifeRouteStableBound = "1";
      refresh.type = "button";
      refresh.removeAttribute("onclick");
      refresh.addEventListener("click", event => {
        event.preventDefault();
        window.refreshCalendars();
      });
    }

    if (gaps && gaps.dataset.lifeRouteStableBound !== "1") {
      gaps.dataset.lifeRouteStableBound = "1";
      gaps.type = "button";
      gaps.removeAttribute("onclick");
      gaps.addEventListener("click", event => {
        event.preventDefault();
        window.optimizeWeek();
      });
    }
    return !!(refresh && gaps);
  };

  const start = () => {
    bindBottomActions();
    const bar = document.querySelector(".bottomin");
    if (bar) new MutationObserver(bindBottomActions).observe(bar, { childList: true, subtree: true });
    [100, 350, 900, 1800].forEach(delay => setTimeout(bindBottomActions, delay));
  };

  window.addEventListener("pageshow", () => {
    bindBottomActions();
    if (window.scrollY < 0) window.scrollTo(0, 0);
  });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
