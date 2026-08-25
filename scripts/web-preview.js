(() => {
  window.addEventListener("DOMContentLoaded", () => {
    if (window.webkit?.messageHandlers?.lifeRoute) return;

    document.documentElement.dataset.webPreview = "true";

    // Public browser OAuth configuration. A Google OAuth Client ID is not a
    // secret; never place the corresponding Client Secret in browser code.
    window.LifeRouteConfig = window.LifeRouteConfig || {};
    window.LifeRouteConfig.googleCalendar = Object.assign(
      {},
      window.LifeRouteConfig.googleCalendar || {},
      {
        enabled: true,
        clientId: "601974933090-am03tgj3094d1hkb708ec74jjvvsh58j.apps.googleusercontent.com",
        scopes: ["https://www.googleapis.com/auth/calendar.readonly"],
        mode: "web-read-only-oauth"
      }
    );

    // Preload Google Identity Services before the user taps Connect. Mobile
    // Safari can silently block an OAuth popup if the library finishes loading
    // only after the original tap has already returned.
    const preloadGoogleIdentity = () => {
      if (window.google?.accounts?.oauth2) return;
      if (document.querySelector('script[src^="https://accounts.google.com/gsi/client"]')) return;
      const script = document.createElement("script");
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      script.dataset.lifeRouteGooglePreload = "1";
      document.head.appendChild(script);
    };
    preloadGoogleIdentity();

    const badge = document.createElement("div");
    badge.id = "webPreviewBadge";
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    badge.innerHTML = `<b>WEB PREVIEW${build ? " · " + build : ""}</b><span>Interactive UI preview · Google Calendar, calendar links, browser location, gap routing, and nearby-store comparisons work here. Apple Calendar, notifications, and Apple MapKit remain iPhone features.</span>`;
    badge.style.cssText = [
      "position:sticky","top:0","z-index:99999","display:flex","gap:8px",
      "align-items:center","justify-content:center","flex-wrap:wrap",
      "margin:0 auto 8px","max-width:920px","padding:7px 12px",
      "border-radius:0 0 12px 12px","text-align:center",
      "font:750 10px/1.3 system-ui,-apple-system,sans-serif",
      "background:rgba(8,16,30,.92)","color:#d9e5f5",
      "border:1px solid rgba(242,200,109,.22)","border-top:0",
      "backdrop-filter:blur(18px)","-webkit-backdrop-filter:blur(18px)",
      "pointer-events:none"
    ].join(";");
    const strong = badge.querySelector("b");
    if (strong) strong.style.color = "#f2c86d";
    document.body.prepend(badge);

    const loadPreviewScript = name => {
      const script = document.createElement("script");
      script.src = `${name}${build ? "?v=" + encodeURIComponent(build) : ""}`;
      // Preserve insertion/execution order for browser helpers. Several of them
      // wrap the same global functions, so random async execution can detach a
      // handler on mobile Safari after a later helper mounts.
      script.async = false;
      document.body.appendChild(script);
    };

    // Browser-preview-only helpers. All are cache-busted to the deployed SHA.
    // Load route intelligence first so later user actions use the browser bridge
    // instead of the old native-only postNative behavior.
    loadPreviewScript("web-routing-bridge.js");
    loadPreviewScript("web-store-search-fallback.js");
    loadPreviewScript("web-routing-resilience.js");
    loadPreviewScript("web-store-late-guard.js");
    loadPreviewScript("welcome.js");
    loadPreviewScript("nav-cleanup.js");
    loadPreviewScript("icloud-calendar-web.js");
    loadPreviewScript("google-calendar-web.js");
    loadPreviewScript("google-calendar-stability.js");
    loadPreviewScript("google-calendar-persistence-web.js");
    loadPreviewScript("first-then-back.js");
    loadPreviewScript("visual-quality-web.js");
    loadPreviewScript("photo-source-picker-web.js");
    loadPreviewScript("end-home-route-web.js");
    loadPreviewScript("mileage-tracker-web.js");
    loadPreviewScript("resources-hub-web.js");
    loadPreviewScript("nature-settings-web.js");
    loadPreviewScript("settings-classic-themes-web.js");
    loadPreviewScript("photoreal-nature-web.js");
    loadPreviewScript("dynamic-themes-web.js");

    // If Google is unusually slow to load, make the first tap visibly prepare
    // sign-in rather than appearing dead. The normal Google handler remains in
    // control once GIS is ready.
    document.addEventListener("click", event => {
      const connect = event.target.closest?.("#googleWebConnect");
      if (!connect || window.google?.accounts?.oauth2) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      preloadGoogleIdentity();
      const status = document.getElementById("googleWebStatus");
      if (status) {
        status.textContent = "Preparing Google sign-in… tap Connect again in a moment.";
        status.dataset.kind = "loading";
      }
      const check = setInterval(() => {
        if (!window.google?.accounts?.oauth2) return;
        clearInterval(check);
        if (status) {
          status.textContent = "Google sign-in ready · tap Connect Google Calendar.";
          status.dataset.kind = "";
        }
      }, 100);
      setTimeout(() => clearInterval(check), 10000);
    }, true);

    // Keep the legacy/native Google badge from overwriting the real browser
    // OAuth status. Watch only the Google status element; never the whole DOM.
    const polishGoogleWebUI = () => {
      const configured = !!String(window.LifeRouteConfig?.googleCalendar?.clientId || "").trim();
      if (!configured) return;

      const status = document.getElementById("googleWebStatus");
      const kind = status?.dataset?.kind || "";
      const statusText = String(status?.textContent || "");
      const connected = kind === "connected" || /Google event(?:s)? synced/i.test(statusText);
      const loading = kind === "loading";

      try {
        if (window.nativeState) {
          window.nativeState.googleCalendarConfigured = true;
          window.nativeState.googleCalendarConnected = connected;
        }
      } catch (_) {}

      const googleBadge = document.getElementById("googleStatus");
      if (googleBadge) {
        const wanted = connected ? "CONNECTED" : loading ? "SYNCING" : "READY";
        if (googleBadge.textContent !== wanted) googleBadge.textContent = wanted;
        const wantedClass = `badge ${connected ? "green" : loading ? "gold" : ""}`.trim();
        if (googleBadge.className !== wantedClass) googleBadge.className = wantedClass;
      }

      document.getElementById("googleWebSetup")?.remove();
      const connect = document.getElementById("googleWebConnect");
      if (connect) {
        const wanted = connected ? "Reconnect Google" : "Connect Google Calendar";
        if (connect.textContent !== wanted) connect.textContent = wanted;
      }
    };

    const attachGoogleObserver = () => {
      const status = document.getElementById("googleWebStatus");
      if (!status || status.dataset.lifeRoutePolishObserved === "1") return false;
      status.dataset.lifeRoutePolishObserved = "1";
      new MutationObserver(polishGoogleWebUI).observe(status, {
        childList: true,
        characterData: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["data-kind"]
      });
      polishGoogleWebUI();
      return true;
    };

    let attempts = 0;
    const observerTimer = setInterval(() => {
      attempts += 1;
      if (attachGoogleObserver() || attempts > 80) clearInterval(observerTimer);
    }, 100);
    [100, 300, 700, 1500, 3000].forEach(delay => setTimeout(polishGoogleWebUI, delay));

    // Keep browser-only previewing from appearing frozen when a native-only
    // feature is tapped. Normal tabs, forms, themes, To-Dos, Google Calendar,
    // calendar links, web gap routing, and UI controls remain interactive.
    const oldStatus = window.setStatus;
    window.webPreviewNativeNotice = () => {
      if (typeof oldStatus === "function") oldStatus("Web preview · iPhone feature");
    };
  });
})();
