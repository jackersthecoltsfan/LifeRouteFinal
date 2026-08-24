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

    const badge = document.createElement("div");
    badge.id = "webPreviewBadge";
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    badge.innerHTML = `<b>WEB PREVIEW${build ? " · " + build : ""}</b><span>Interactive UI preview · Google Calendar and calendar links work here. Direct iPhone Apple Calendar, GPS, notifications, and MapKit actions require the iPhone build.</span>`;
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
      script.async = true;
      document.body.appendChild(script);
    };

    // Browser-preview-only helpers. All are cache-busted to the deployed SHA.
    loadPreviewScript("welcome.js");
    loadPreviewScript("nav-cleanup.js");
    loadPreviewScript("icloud-calendar-web.js");
    loadPreviewScript("google-calendar-web.js");
    loadPreviewScript("google-calendar-return.js");
    loadPreviewScript("first-then-back.js");

    // The native config layer still owns the legacy Google badge and can label
    // a browser connection as "SETUP NEEDED" after renderAll(). In the web
    // build the OAuth client is already configured, so keep the browser UI in
    // sync with the actual Google connection state and remove developer setup.
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

      // Nobody using the deployed web app should have to see or enter the
      // project's OAuth Client ID. Keep that configuration developer-only.
      document.getElementById("googleWebSetup")?.remove();

      const connect = document.getElementById("googleWebConnect");
      if (connect) {
        const wanted = connected ? "Reconnect Google" : "Connect Google Calendar";
        if (connect.textContent !== wanted) connect.textContent = wanted;
      }
    };

    const googleChromeObserver = new MutationObserver(() => {
      window.setTimeout(polishGoogleWebUI, 0);
    });
    googleChromeObserver.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["data-kind"]
    });
    [50, 180, 450, 900, 1800, 3500].forEach(delay => window.setTimeout(polishGoogleWebUI, delay));

    // Keep browser-only previewing from appearing frozen when a native-only
    // feature is tapped. Normal tabs, forms, themes, To-Dos, Google Calendar,
    // calendar links, and UI controls remain fully interactive.
    const oldStatus = window.setStatus;
    window.webPreviewNativeNotice = () => {
      if (typeof oldStatus === "function") oldStatus("Web preview · iPhone feature");
    };
  });
})();
