// Return the web preview to Calendar → Day after Google OAuth completes.
(() => {
  if (window.__lifeRouteGoogleCalendarReturnLoaded) return;
  window.__lifeRouteGoogleCalendarReturnLoaded = true;

  const RETURN_KEY = "liferoute_google_return_after_auth_v1";
  let handled = false;

  const markAuthStarted = () => {
    handled = false;
    try { sessionStorage.setItem(RETURN_KEY, "1"); } catch (_) {}
  };

  const shouldReturn = () => {
    try { return sessionStorage.getItem(RETURN_KEY) === "1"; } catch (_) { return false; }
  };

  const clearReturn = () => {
    try { sessionStorage.removeItem(RETURN_KEY); } catch (_) {}
  };

  const statusIsConnected = () => {
    const status = document.getElementById("googleWebStatus");
    return status?.dataset?.kind === "connected" || /google event(?:s)? synced/i.test(status?.textContent || "");
  };

  const returnToCalendar = () => {
    if (handled || !shouldReturn() || !statusIsConnected()) return false;
    handled = true;
    clearReturn();

    try { localStorage.setItem("liferoute_calendar_view", "today"); } catch (_) {}

    const navigate = () => {
      try { window.focus(); } catch (_) {}
      try {
        if (typeof window.showView === "function") window.showView("today");
        else document.querySelector('.tab[data-view="calendar"]')?.click();
      } catch (_) {}

      const dayButton = document.querySelector('#calendarHubNav [data-calendar-view="today"]');
      if (dayButton && !dayButton.classList.contains("active")) {
        try { dayButton.click(); } catch (_) {}
      }

      try {
        const url = new URL(window.location.href);
        url.hash = "calendar";
        history.replaceState(history.state, "", url.href);
      } catch (_) {}

      requestAnimationFrame(() => {
        try { window.scrollTo({ top: 0, behavior: "smooth" }); } catch (_) { window.scrollTo(0, 0); }
      });
    };

    // Mobile Safari can temporarily keep the Google auth surface in front.
    // Re-focus LifeRoute a few times; if Safari keeps the other tab visible,
    // the visibility handler below guarantees Calendar is shown on return.
    navigate();
    [120, 420, 900].forEach(delay => setTimeout(navigate, delay));
    return true;
  };

  document.addEventListener("click", event => {
    const button = event.target.closest?.("#googleWebConnect");
    if (button) markAuthStarted();
  }, true);

  const observeStatus = () => {
    const status = document.getElementById("googleWebStatus");
    if (!status) return false;
    if (status.dataset.lifeRouteReturnObserved === "1") return true;
    status.dataset.lifeRouteReturnObserved = "1";
    new MutationObserver(returnToCalendar).observe(status, {
      attributes: true,
      attributeFilter: ["data-kind"],
      childList: true,
      characterData: true,
      subtree: true
    });
    returnToCalendar();
    return true;
  };

  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) setTimeout(returnToCalendar, 30);
  });
  window.addEventListener("focus", () => setTimeout(returnToCalendar, 30));
  window.addEventListener("pageshow", () => setTimeout(returnToCalendar, 30));

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (observeStatus() || attempts > 120) clearInterval(timer);
  }, 100);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", observeStatus, { once: true });
  } else {
    observeStatus();
  }
})();
