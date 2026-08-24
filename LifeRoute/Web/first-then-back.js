// Persistent exit control for the full-screen First / Then board.
(() => {
  const STYLE_ID = "lifeRouteFirstThenBackStyles";

  const installStyles = () => {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
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

    button.classList.add("firstThenOverlayBack");
    button.textContent = "← Back";
    button.setAttribute("aria-label", "Back to First Then setup");
    button.setAttribute("title", "Back");

    // Keep the existing close behavior, but guarantee it even if another module
    // replaces the original click handler later.
    if (button.dataset.lifeRouteBackBound !== "1") {
      button.dataset.lifeRouteBackBound = "1";
      button.addEventListener("click", () => overlay.classList.remove("show"));
    }
    return true;
  };

  const start = () => {
    decorate();
    new MutationObserver(() => decorate()).observe(document.body, {
      childList: true,
      subtree: true
    });
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
