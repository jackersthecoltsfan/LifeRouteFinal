// Remember a previously connected Google Calendar on the web preview and try to
// restore a fresh read-only Google token from the browser's existing Google session.
// No Google access token or refresh token is stored in localStorage.
(() => {
  if (window.__lifeRouteGoogleCalendarPersistenceLoaded) return;
  window.__lifeRouteGoogleCalendarPersistenceLoaded = true;

  const REMEMBER_KEY = "liferoute_google_web_remember_connection_v1";
  let restoreAttempted = false;
  let disconnecting = false;

  const readRemembered = () => {
    try {
      if (localStorage.getItem(REMEMBER_KEY) === "1") return true;
    } catch (_) {}
    return !!window.prefs?.sources?.google;
  };

  const remember = value => {
    try {
      if (value) localStorage.setItem(REMEMBER_KEY, "1");
      else localStorage.removeItem(REMEMBER_KEY);
    } catch (_) {}
    try {
      if (window.prefs?.sources) {
        window.prefs.sources.google = !!value;
        window.persist?.();
      }
    } catch (_) {}
  };

  const statusConnected = status => status?.dataset?.kind === "connected" || /Google event(?:s)? synced/i.test(String(status?.textContent || ""));

  const setVisibleStatus = (message, kind = "") => {
    const status = document.getElementById("googleWebStatus");
    if (!status) return;
    status.textContent = message;
    status.dataset.kind = kind;
  };

  const observeConnection = () => {
    const status = document.getElementById("googleWebStatus");
    if (!status || status.dataset.lifeRoutePersistenceObserved === "1") return false;
    status.dataset.lifeRoutePersistenceObserved = "1";

    const update = () => {
      if (statusConnected(status)) {
        remember(true);
        disconnecting = false;
      } else if (disconnecting || /Google Calendar disconnected/i.test(String(status.textContent || ""))) {
        remember(false);
        disconnecting = false;
      }
    };
    new MutationObserver(update).observe(status, {
      childList: true,
      characterData: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["data-kind"]
    });
    update();
    return true;
  };

  const attemptRestore = () => {
    if (restoreAttempted || !readRemembered()) return false;
    const refresh = document.getElementById("googleWebRefresh");
    const status = document.getElementById("googleWebStatus");
    if (!refresh || !status) return false;
    if (statusConnected(status)) {
      remember(true);
      return true;
    }

    restoreAttempted = true;
    setVisibleStatus("Restoring Google Calendar…", "loading");

    // The existing Refresh handler requests a token with prompt:"" when no token
    // is in memory. Google can usually satisfy that from an existing signed-in
    // browser session + prior consent without asking the user to reconnect.
    try { refresh.click(); } catch (_) {}

    setTimeout(() => {
      const current = document.getElementById("googleWebStatus");
      if (!current || statusConnected(current)) return;
      const text = String(current.textContent || "");
      if (/restoring|opening google sign-in|preparing google sign-in/i.test(text)) {
        setVisibleStatus("Google needs browser confirmation. Tap Connect Google Calendar once to continue.", "");
      }
    }, 9000);
    return true;
  };

  document.addEventListener("click", event => {
    if (event.target.closest?.("#googleWebDisconnect")) {
      disconnecting = true;
      remember(false);
      restoreAttempted = true;
    }
  }, true);

  const start = () => {
    observeConnection();
    attemptRestore();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      observeConnection();
      if (attemptRestore() || attempts > 120) clearInterval(timer);
    }, 100);
  };

  ["pageshow", "focus"].forEach(type => window.addEventListener(type, () => {
    observeConnection();
    if (!restoreAttempted) setTimeout(attemptRestore, 100);
  }));

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(start, 120), { once:true });
  else setTimeout(start, 120);
})();
