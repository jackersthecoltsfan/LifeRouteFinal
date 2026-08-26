// Simplified Schedule presentation: keep the useful route timeline, remove dashboard clutter.
(() => {
  if (window.__lifeRouteScheduleSimplifyV1Loaded) return;
  window.__lifeRouteScheduleSimplifyV1Loaded = true;

  const installStyles = () => {
    if (document.getElementById("lifeRouteScheduleSimplifyStyles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteScheduleSimplifyStyles";
    style.textContent = `
      #today > .metrics{display:none!important}
      #today .lrScheduleRedundant{display:none!important}
      #today #smartContextStrip{display:none!important}
      #today .lrDayCommandStrip{padding:0!important;margin:0 0 10px!important;gap:7px!important}
      #today .lrDayPrimaryControls{flex:1 1 auto!important}
      #today .lrDayPrimaryControls .liveDayGenerate{min-width:132px}
      #today .lrDayMore{position:relative;margin-left:auto}.lrDayMore>summary{list-style:none;min-height:40px;min-width:42px;display:grid;place-items:center;border:1px solid var(--line);border-radius:12px;background:var(--panel2);color:var(--text);font-size:18px;font-weight:900;cursor:pointer}.lrDayMore>summary::-webkit-details-marker{display:none}.lrDayMoreMenu{position:absolute;right:0;top:46px;z-index:1200;width:min(230px,72vw);padding:7px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel) 97%,#07111f 3%);box-shadow:0 18px 48px rgba(0,0,0,.32);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}.lrDayMoreMenu .lrDayClearControls{display:grid!important;width:100%!important;gap:6px!important}.lrDayMoreMenu .lrDayClearControls button{width:100%;min-height:40px!important;text-align:left}
      #today .sectionHead{margin-bottom:7px!important}#today .section{margin-top:13px!important}
      #today #timeline{display:grid;gap:8px}
      @media(max-width:520px){#today .lrDayPrimaryControls{width:auto!important}.lrDayMore{margin-left:0}.lrDayMore>summary{min-height:40px}.lrDayCommandStrip{flex-wrap:nowrap!important}.lrDayPrimaryControls .liveDayEnd{font-size:10px!important;padding-inline:9px!important}}
    `;
    document.head.appendChild(style);
  };

  const markRedundantSections = () => {
    document.getElementById("dayInsight")?.closest(".section")?.classList.add("lrScheduleRedundant");
    document.getElementById("smartContextStrip")?.remove();
    document.querySelectorAll("#today .sourceLine").forEach(node => node.classList.add("lrScheduleRedundant"));
  };

  const moveClearControlsIntoMore = () => {
    const strip = document.getElementById("lrDayCommandStrip");
    const clears = strip?.querySelector(".lrDayClearControls");
    if (!strip || !clears) return;
    let details = strip.querySelector(".lrDayMore");
    if (!details) {
      details = document.createElement("details");
      details.className = "lrDayMore";
      details.innerHTML = `<summary aria-label="More schedule actions">•••</summary><div class="lrDayMoreMenu"></div>`;
      strip.appendChild(details);
      details.addEventListener("toggle", () => {
        if (!details.open) return;
        const close = event => {
          if (!details.contains(event.target)) details.open = false;
        };
        setTimeout(() => document.addEventListener("pointerdown", close, { once: true, capture: true }), 0);
      });
    }
    const menu = details.querySelector(".lrDayMoreMenu");
    if (menu && clears.parentElement !== menu) menu.appendChild(clears);
  };

  const moveEndHomeToHomeSetup = () => {
    const option = document.getElementById("endHomeOption");
    const homeField = document.getElementById("homeAddressField");
    const homeCard = homeField?.closest(".card");
    if (!option || !homeCard || option.parentElement === homeCard) return;
    option.classList.remove("lrEndHomeCompact");
    option.style.marginTop = "10px";
    homeCard.appendChild(option);
  };

  const removeExactSmartBadges = () => {
    document.querySelectorAll("button,.badge,.chip,.contextPill").forEach(node => {
      if (String(node.textContent || "").trim().toLowerCase() === "smart") node.remove();
    });
  };

  let queued = false;
  const reconcile = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      markRedundantSections();
      moveClearControlsIntoMore();
      moveEndHomeToHomeSetup();
      removeExactSmartBadges();
    });
  };

  const start = () => {
    installStyles();
    reconcile();
    const today = document.getElementById("today");
    if (today) new MutationObserver(reconcile).observe(today, { childList: true, subtree: true });
    const setup = document.getElementById("setup");
    if (setup) new MutationObserver(reconcile).observe(setup, { childList: true, subtree: true });
  };

  window.LifeRouteScheduleSimplifyV1 = { reconcile };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();