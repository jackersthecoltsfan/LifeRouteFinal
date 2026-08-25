// Reliable First / Then launch + escape control that survives smart visual regeneration.
// The escape control lives outside the generated board. Never observe/rewrite the
// board child tree: smart visual insertion can otherwise create a self-triggering
// MutationObserver loop in WKWebView.
(() => {
  if (window.__lifeRouteFirstThenBackLoaded) return;
  window.__lifeRouteFirstThenBackLoaded = true;

  const STYLE_ID = "lifeRouteFirstThenBackStyles";
  let openRequested = false;
  let openTimers = [];
  let overlayClassObserver = null;
  let observedOverlay = null;

  const installStyles = () => {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      #firstThenOverlay.show{display:block!important;pointer-events:auto!important;visibility:visible!important;opacity:1!important}
      #firstThenOverlay:not(.show){pointer-events:none!important}
      #lifeRouteFirstThenEscape{
        position:fixed;left:max(14px,env(safe-area-inset-left));top:calc(14px + env(safe-area-inset-top));z-index:40050;
        display:none;align-items:center;justify-content:center;gap:7px;min-width:92px;min-height:44px;padding:10px 15px;
        border-radius:999px;border:1px solid color-mix(in srgb,var(--gold) 35%,var(--line));
        background:color-mix(in srgb,var(--panel) 94%,black);color:var(--text);box-shadow:0 12px 34px rgba(0,0,0,.34);
        backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);font-size:13px;font-weight:900;pointer-events:auto;
      }
      #lifeRouteFirstThenEscape.show{display:inline-flex!important}
      #lifeRouteFirstThenEscape:active{transform:scale(.96)}
      #firstThenOverlay #firstThenClose{visibility:hidden!important;pointer-events:none!important}
      html[data-web-preview="true"] #lifeRouteFirstThenEscape{top:calc(116px + env(safe-area-inset-top))}
      .firstThenVisualImage{animation:lrFirstThenLivingVisual 7s ease-in-out infinite alternate;transform-origin:center center;will-change:transform}
      @keyframes lrFirstThenLivingVisual{from{transform:scale(1.005) translate3d(-.3%,.2%,0)}to{transform:scale(1.035) translate3d(.45%,-.35%,0)}}
      @media(prefers-reduced-motion:reduce){.firstThenVisualImage{animation:none!important}}
      @media(max-width:680px){#lifeRouteFirstThenEscape{min-width:88px;min-height:44px;padding:9px 13px;font-size:12px}}
    `;
    document.head.appendChild(style);
  };

  const escapeButton = () => {
    let button = document.getElementById("lifeRouteFirstThenEscape");
    if (button) return button;
    button = document.createElement("button");
    button.id = "lifeRouteFirstThenEscape";
    button.type = "button";
    button.className = "secondary";
    button.textContent = "← Back";
    button.setAttribute("aria-label", "Close First Then board");
    button.setAttribute("aria-hidden", "true");
    document.body.appendChild(button);
    return button;
  };

  const cancelOpenTimers = () => {
    openTimers.forEach(timer => clearTimeout(timer));
    openTimers = [];
  };

  const syncEscape = () => {
    const overlay = document.getElementById("firstThenOverlay");
    const button = escapeButton();
    const shown = !!overlay?.classList.contains("show");
    button.classList.toggle("show", shown);
    button.setAttribute("aria-hidden", shown ? "false" : "true");
    if (overlay && overlay.getAttribute("aria-hidden") !== (shown ? "false" : "true")) {
      overlay.setAttribute("aria-hidden", shown ? "false" : "true");
    }
  };

  const bindOverlay = overlay => {
    if (!overlay) return false;
    if (observedOverlay === overlay && overlayClassObserver) return true;
    overlayClassObserver?.disconnect();
    observedOverlay = overlay;
    overlayClassObserver = new MutationObserver(syncEscape);
    overlayClassObserver.observe(overlay, { attributes: true, attributeFilter: ["class"] });
    const internal = overlay.querySelector("#firstThenClose");
    if (internal && internal.getAttribute("aria-label") !== "Close First Then board") {
      internal.setAttribute("aria-label", "Close First Then board");
    }
    syncEscape();
    return true;
  };

  const closeBoard = () => {
    openRequested = false;
    cancelOpenTimers();
    const overlay = document.getElementById("firstThenOverlay");
    if (overlay) {
      overlay.classList.remove("show");
      overlay.style.pointerEvents = "none";
      overlay.style.visibility = "hidden";
      overlay.style.opacity = "0";
      overlay.setAttribute("aria-hidden", "true");
    }
    syncEscape();
    const first = document.getElementById("firstThenFirst");
    if (first && typeof first.focus === "function") {
      setTimeout(() => {
        try { first.focus({ preventScroll: true }); } catch (_) {}
      }, 0);
    }
  };

  const forceOpen = () => {
    if (!openRequested) return false;
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay) return false;
    bindOverlay(overlay);
    overlay.classList.add("show");
    overlay.style.removeProperty("display");
    overlay.style.pointerEvents = "auto";
    overlay.style.visibility = "visible";
    overlay.style.opacity = "1";
    overlay.setAttribute("aria-hidden", "false");
    document.documentElement.style.removeProperty("pointer-events");
    document.body.style.removeProperty("pointer-events");
    syncEscape();
    return true;
  };

  const requestOpen = () => {
    openRequested = true;
    cancelOpenTimers();
    // The base tool creates the overlay in its normal click handler. These bounded
    // retries attach only after that handler has had a chance to run.
    openTimers.push(setTimeout(forceOpen, 0));
    openTimers.push(setTimeout(forceOpen, 120));
  };

  document.addEventListener("click", event => {
    if (!event.target.closest?.("#showFirstThen")) return;
    requestOpen();
  }, true);

  // Own every exit route in capture phase so generated visual handlers cannot swallow it.
  document.addEventListener("click", event => {
    if (!event.target.closest?.("#lifeRouteFirstThenEscape,#firstThenClose")) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    closeBoard();
  }, true);

  document.addEventListener("keydown", event => {
    if (event.key !== "Escape" || !document.getElementById("firstThenOverlay")?.classList.contains("show")) return;
    event.preventDefault();
    closeBoard();
  }, true);

  const start = () => {
    installStyles();
    escapeButton();
    bindOverlay(document.getElementById("firstThenOverlay"));
    window.addEventListener("pagehide", closeBoard);
    window.LifeRouteFirstThen = { close: closeBoard, open: requestOpen };
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
