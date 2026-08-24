(() => {
  window.addEventListener("DOMContentLoaded", () => {
    if (window.webkit?.messageHandlers?.lifeRoute) return;

    document.documentElement.dataset.webPreview = "true";

    const badge = document.createElement("div");
    badge.id = "webPreviewBadge";
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    badge.innerHTML = `<b>WEB PREVIEW${build ? " · " + build : ""}</b><span>Interactive UI preview · iPhone-only calendar, GPS, notifications, and MapKit actions require TestFlight.</span>`;
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

    // Keep browser-only previewing from appearing frozen when a native-only
    // feature is tapped. Normal tabs, forms, themes, To-Dos, and UI controls
    // remain fully interactive.
    const oldStatus = window.setStatus;
    window.webPreviewNativeNotice = () => {
      if (typeof oldStatus === "function") oldStatus("Web preview · iPhone feature");
    };
  });
})();
