// Reliable launch + persistent exit control for the full-screen First / Then board.
(() => {
  if (window.__lifeRouteFirstThenBackLoaded) return;
  window.__lifeRouteFirstThenBackLoaded = true;

  const STYLE_ID = "lifeRouteFirstThenBackStyles";

  const installStyles = () => {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      #firstThenOverlay.show{
        display:block!important;
        pointer-events:auto!important;
        visibility:visible!important;
        opacity:1!important;
      }
      #firstThenOverlay #firstThenClose.firstThenOverlayBack{
        position:fixed!important;
        left:max(14px,env(safe-area-inset-left))!important;
        top:calc(14px + env(safe-area-inset-top))!important;
        z-index:12500!important;
        display:inline-flex!important;
        align-items:center!important;
        justify-content:center!important;
        gap:7px!important;
        min-width:92px!important;
        min-height:44px!important;
        padding:10px 15px!important;
        border-radius:999px!important;
        border:1px solid color-mix(in srgb,var(--gold) 35%,var(--line))!important;
        background:color-mix(in srgb,var(--panel) 92%,black)!important;
        color:var(--text)!important;
        box-shadow:0 12px 34px rgba(0,0,0,.34)!important;
        backdrop-filter:blur(18px)!important;
        -webkit-backdrop-filter:blur(18px)!important;
        font-size:13px!important;
        font-weight:900!important;
        letter-spacing:0!important;
        opacity:1!important;
        visibility:visible!important;
        pointer-events:auto!important;
      }
      #firstThenOverlay #firstThenClose.firstThenOverlayBack:active{transform:scale(.96)}
      html[data-web-preview="true"] #firstThenOverlay #firstThenClose.firstThenOverlayBack{
        top:calc(116px + env(safe-area-inset-top))!important;
      }
      @media(max-width:680px){
        #firstThenOverlay #firstThenClose.firstThenOverlayBack{
          min-width:88px!important;
          min-height:42px!important;
          padding:9px 13px!important;
          font-size:12px!important;
        }
      }
    `;
    document.head.appendChild(style);
  };

  const decorate = () => {
    installStyles();
    const overlay = document.getElementById("firstThenOverlay");
    const button = document.getElementById("firstThenClose");
    if (!overlay || !button) return false;

    if (!button.classList.contains("firstThenOverlayBack")) {
      button.classList.add("firstThenOverlayBack");
    }
    if (button.textContent !== "← Back") button.textContent = "← Back";
    if (button.getAttribute("aria-label") !== "Back to First Then setup") {
      button.setAttribute("aria-label", "Back to First Then setup");
    }
    if (button.getAttribute("title") !== "Back") button.setAttribute("title", "Back");

    if (button.dataset.lifeRouteBackBound !== "1") {
      button.dataset.lifeRouteBackBound = "1";
      button.addEventListener("click", () => {
        overlay.classList.remove("show");
        overlay.style.pointerEvents = "none";
      });
    }
    return true;
  };

  const forceOpen = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay) return false;
    overlay.classList.add("show");
    overlay.style.removeProperty("display");
    overlay.style.pointerEvents = "auto";
    overlay.style.visibility = "visible";
    overlay.style.opacity = "1";
    document.documentElement.style.removeProperty("pointer-events");
    document.body.style.removeProperty("pointer-events");
    decorate();
    return true;
  };

  // Let the original First / Then handler populate and create the overlay first,
  // then guarantee that Safari actually paints it as a full-screen interactive view.
  document.addEventListener("click", event => {
    if (!event.target.closest?.("#showFirstThen")) return;
    [0, 30, 120].forEach(delay => setTimeout(forceOpen, delay));
  }, false);

  const start = () => {
    installStyles();
    decorate();

    // Observe only for creation of the overlay. Disconnect permanently once it
    // exists so decorating the Back button cannot create a mutation loop.
    if (!document.getElementById("firstThenOverlay")) {
      const observer = new MutationObserver(() => {
        if (decorate()) observer.disconnect();
      });
      observer.observe(document.body, { childList: true, subtree: true });
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
