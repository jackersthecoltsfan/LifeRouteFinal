// Web-only Google OAuth return + Safari interaction recovery.
(() => {
  if (window.__lifeRouteGoogleCalendarStabilityLoaded) return;
  window.__lifeRouteGoogleCalendarStabilityLoaded = true;

  // Keep the account connection across fresh web-app visits without persisting
  // Google access/refresh tokens. The helper asks Google to restore a fresh token
  // from the browser's existing signed-in session and prior consent.
  const loadPersistenceHelper = () => {
    if (window.__lifeRouteGoogleCalendarPersistenceLoaded || document.getElementById("lifeRouteGooglePersistenceScript")) return;
    const script = document.createElement("script");
    script.id = "lifeRouteGooglePersistenceScript";
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    script.src = `google-calendar-persistence-web.js${build ? "?v=" + encodeURIComponent(build) : ""}`;
    script.async = false;
    document.body.appendChild(script);
  };
  loadPersistenceHelper();

  const RETURN_KEY = "liferoute_google_return_after_auth_v2";
  let returned = false;

  const markStarted = () => {
    returned = false;
    try { sessionStorage.setItem(RETURN_KEY, "1"); } catch (_) {}
  };

  const authWasStarted = () => {
    try { return sessionStorage.getItem(RETURN_KEY) === "1"; } catch (_) { return false; }
  };

  const clearStarted = () => {
    try { sessionStorage.removeItem(RETURN_KEY); } catch (_) {}
  };

  const restoreInteraction = () => {
    // Defensive cleanup for mobile Safari after an OAuth popup/tab closes.
    [document.documentElement, document.body, document.querySelector(".app")].forEach(node => {
      if (!node) return;
      if (node.style?.pointerEvents === "none") node.style.pointerEvents = "";
      if (node.hasAttribute?.("inert")) node.removeAttribute("inert");
    });

    document.querySelectorAll(".view[inert], .setupPane[inert], .card[inert]").forEach(node => node.removeAttribute("inert"));

    // If a First/Then or timer overlay is not visibly open, make sure it cannot
    // remain as an invisible touch target after Safari restores the page.
    ["firstThenOverlay", "visualTimerOverlay"].forEach(id => {
      const overlay = document.getElementById(id);
      if (!overlay) return;
      if (!overlay.classList.contains("show")) {
        overlay.style.pointerEvents = "none";
      } else {
        overlay.style.pointerEvents = "";
      }
    });
  };

  const isGoogleConnected = () => {
    const status = document.getElementById("googleWebStatus");
    return status?.dataset?.kind === "connected" || /google event(?:s)? synced/i.test(status?.textContent || "");
  };

  const openCalendarDay = () => {
    restoreInteraction();
    try { localStorage.setItem("liferoute_calendar_view", "today"); } catch (_) {}

    try {
      if (typeof window.showView === "function") window.showView("today");
    } catch (_) {}

    const calendarTab = document.querySelector('.tab[data-view="calendar"]');
    if (calendarTab && !calendarTab.classList.contains("active")) {
      try { calendarTab.click(); } catch (_) {}
    }
    const dayButton = document.querySelector('#calendarHubNav [data-calendar-view="today"]');
    if (dayButton && !dayButton.classList.contains("active")) {
      try { dayButton.click(); } catch (_) {}
    }

    try {
      const url = new URL(location.href);
      url.hash = "calendar";
      history.replaceState(history.state, "", url.href);
    } catch (_) {}

    requestAnimationFrame(() => {
      try { window.scrollTo({ top: 0, behavior: "auto" }); } catch (_) { window.scrollTo(0, 0); }
    });
  };

  const finishReturn = () => {
    restoreInteraction();
    if (returned || !authWasStarted() || !isGoogleConnected()) return;
    returned = true;
    clearStarted();
    openCalendarDay();
    [80, 260, 650].forEach(delay => setTimeout(openCalendarDay, delay));
  };

  document.addEventListener("click", event => {
    if (event.target.closest?.("#googleWebConnect")) markStarted();
  }, true);

  const attachStatusObserver = () => {
    const status = document.getElementById("googleWebStatus");
    if (!status || status.dataset.lifeRouteStabilityObserved === "1") return false;
    status.dataset.lifeRouteStabilityObserved = "1";
    new MutationObserver(() => finishReturn()).observe(status, {
      childList: true,
      characterData: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["data-kind"]
    });
    finishReturn();
    return true;
  };

  ["focus", "pageshow"].forEach(type => window.addEventListener(type, () => {
    restoreInteraction();
    setTimeout(finishReturn, 30);
  }));
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) {
      restoreInteraction();
      setTimeout(finishReturn, 30);
    }
  });

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    restoreInteraction();
    if (attachStatusObserver() || attempts > 100) clearInterval(timer);
  }, 100);

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => {
    restoreInteraction();
    attachStatusObserver();
    loadPersistenceHelper();
  }, { once: true });
  else {
    restoreInteraction();
    attachStatusObserver();
    loadPersistenceHelper();
  }
})();
