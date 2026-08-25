// LifeRoute refined UI: quiet hierarchy, compact navigation, fewer competing
// surfaces, and consistent controls. This layer changes presentation only.
(() => {
  if (window.__lifeRouteRefinedUIV2Loaded) return;
  window.__lifeRouteRefinedUIV2Loaded = true;

  const style = document.createElement("style");
  style.id = "lifeRouteRefinedUIV2Styles";
  style.textContent = `
    :root{--lr-radius:17px;--lr-small-radius:12px;--lr-line:color-mix(in srgb,var(--line) 68%,transparent)}
    body{letter-spacing:-.006em}
    .app{max-width:860px!important;padding-left:11px!important;padding-right:11px!important;padding-bottom:94px!important}
    header{align-items:center!important;gap:9px!important;margin-bottom:1px!important}.brand{gap:8px!important}.mark{width:36px!important;height:36px!important;border-radius:11px!important;box-shadow:0 7px 22px rgba(0,0,0,.14)!important}h1{font-size:22px!important;letter-spacing:-.65px!important}.subtitle{font-size:9.5px!important;margin-top:1px!important}.status{font-size:8px!important;padding:5px 7px!important;max-width:150px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;background:color-mix(in srgb,var(--panel) 76%,transparent)!important;border-color:var(--lr-line)!important}

    .tabs{display:flex!important;grid-template-columns:none!important;gap:3px!important;padding:3px!important;margin:9px 0 11px!important;border:1px solid var(--lr-line)!important;border-radius:14px!important;background:color-mix(in srgb,var(--panel) 68%,transparent)!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}.tabs .tab{flex:1;min-width:0;border:0!important;border-radius:10px!important;padding:8px 5px!important;background:transparent!important;color:var(--muted)!important;font-size:9.5px!important;font-weight:850!important;box-shadow:none!important}.tabs .tab.active{background:color-mix(in srgb,var(--panel2) 86%,transparent)!important;color:var(--text)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 26%,var(--line))!important}
    .calendarHubNav{gap:3px!important;padding:3px!important;margin:0 0 9px!important;border-radius:12px!important;background:color-mix(in srgb,var(--panel) 66%,transparent)!important;border-color:var(--lr-line)!important}.calendarHubNav button{min-height:32px!important;padding:6px!important;border-radius:9px!important;font-size:9.5px!important}.calendarHubNav button.active{box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 28%,var(--line))!important}

    /* Back stays in document flow. It must never float over Day content. */
    .lrBackRow{position:relative!important;top:auto!important;z-index:10!important;margin:3px 0 6px!important;pointer-events:auto!important}.lrBackButton{min-height:31px!important;padding:6px 9px!important;border-radius:10px!important;font-size:9px!important;box-shadow:none!important;background:color-mix(in srgb,var(--panel2) 76%,transparent)!important}.lrBackButton.isHome{display:none!important}

    .hero{padding:12px 13px!important;border-radius:17px!important;margin-bottom:8px!important;border-color:var(--lr-line)!important;box-shadow:0 7px 24px rgba(0,0,0,.08)!important;background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 5%,transparent),color-mix(in srgb,var(--gold) 3%,transparent)),color-mix(in srgb,var(--panel) 92%,transparent)!important}.hero h2{font-size:16px!important;margin-bottom:2px!important}.hero p{font-size:10px!important;line-height:1.38!important}.sourceLine{margin-top:5px!important;gap:4px!important}.chip,.badge{font-size:8px!important;padding:3px 6px!important}
    .metrics{gap:5px!important}.metric{padding:9px!important;border-radius:13px!important;border-color:var(--lr-line)!important;box-shadow:0 5px 17px rgba(0,0,0,.06)!important;background:color-mix(in srgb,var(--panel) 89%,transparent)!important}.metric b{font-size:16px!important}.metric span{font-size:7.5px!important;margin-top:1px!important}

    .section{margin-top:12px!important}.sectionHead{margin-bottom:6px!important;align-items:center!important}.section h2,.sectionHead h2{font-size:14px!important}.hint{font-size:8px!important}
    .card{padding:11px!important;margin-bottom:7px!important;border-radius:var(--lr-radius)!important;border-color:var(--lr-line)!important;box-shadow:0 6px 22px rgba(0,0,0,.07)!important;background:color-mix(in srgb,var(--panel) 91%,transparent)!important}.row{gap:8px!important}.title{font-size:14px!important;letter-spacing:-.18px!important}.meta,.small{font-size:9.5px!important;line-height:1.34!important}.tiny{font-size:8.5px!important;line-height:1.36!important}
    button{border-radius:10px!important;padding:8px 10px!important;min-height:35px!important;touch-action:manipulation}.secondary{background:color-mix(in srgb,var(--panel2) 77%,transparent)!important;border-color:var(--lr-line)!important}.primary,.goldButton{box-shadow:none!important}.danger{min-height:32px!important}input,select{border-radius:10px!important;padding:9px 10px!important;border-color:var(--lr-line)!important}
    .route{padding:8px 9px!important;margin-top:7px!important;border-radius:12px!important;background:color-mix(in srgb,var(--panel2) 68%,transparent)!important;font-size:10px!important}.route button{min-height:33px!important;padding:7px 9px!important}

    .lrDayPager{gap:4px!important;margin-bottom:8px!important}.lrDayPager button{min-height:35px!important;border-radius:10px!important;font-size:10px!important}.lrDayToday{background:color-mix(in srgb,var(--gold) 5%,var(--panel2))!important}
    .lrBoundaryGap{padding:10px!important}.lrBoundaryGap .title{font-size:13px!important}.lrBoundaryGap .meta{font-size:8.7px!important}.lrBoundaryOpen{min-height:33px!important}

    .gapSuggest{margin-top:8px!important;padding-top:8px!important}.gapSuggestHead{font-size:11px!important;margin-bottom:5px!important}.gapOption{padding:9px!important;border-radius:13px!important;border-color:var(--lr-line)!important;background:color-mix(in srgb,var(--panel2) 48%,transparent)!important;margin-top:6px!important}.gapOption .title{font-size:13px!important}.gapOptionButtons{gap:5px!important;margin-top:7px!important}.gapOptionButtons button{min-height:33px!important;font-size:9px!important;padding:6px 9px!important}.storeChooser{margin-top:7px!important;padding-top:7px!important}.storeOption{padding:9px!important;border-radius:13px!important;background:color-mix(in srgb,var(--panel2) 48%,transparent)!important}.storeOptionButtons button{min-height:33px!important}
    .selectedGapMetrics{gap:4px!important}.selectedGapMetrics>div{padding:7px 8px!important;border-radius:10px!important}.selectedGapActions{gap:5px!important}.selectedGapActions button{min-height:32px!important}

    .setupSubnav{gap:3px!important;padding:3px!important;border-radius:12px!important}.setupSubnav button{min-height:32px!important;font-size:9px!important;border-radius:9px!important}.integration{grid-template-columns:34px 1fr auto!important;gap:8px!important}.integrationIcon{width:34px!important;height:34px!important;border-radius:10px!important;font-size:15px!important}.notice{padding:9px!important;border-radius:12px!important;font-size:9px!important}

    .bottom{padding:6px 10px calc(6px + env(safe-area-inset-bottom))!important;background:color-mix(in srgb,var(--bg) 88%,transparent)!important;backdrop-filter:blur(22px)!important;-webkit-backdrop-filter:blur(22px)!important}.bottomin{max-width:860px!important;gap:5px!important}.bottomin button{min-height:39px!important;font-size:10px!important;border-radius:11px!important}
    #webPreviewBadge{padding:4px 8px!important;font-size:7.5px!important;line-height:1.2!important;gap:4px!important;border-radius:0 0 9px 9px!important;min-height:27px!important}#webPreviewBadge b{letter-spacing:.03em}

    @media(max-width:560px){
      .app{padding-left:9px!important;padding-right:9px!important;padding-bottom:88px!important}.subtitle{display:none!important}header .status{max-width:100px!important}.tabs{margin-top:7px!important}.tabs .tab{font-size:9px!important;padding:7px 3px!important}.calendarHubNav{margin-bottom:7px!important}
      .metrics{grid-template-columns:repeat(3,1fr)!important}.metrics .metric:nth-child(4){display:none!important}.metric{padding:8px 7px!important}.metric b{font-size:15px!important}
      .card{padding:10px!important}.title{font-size:13.5px!important}.meta,.small{font-size:9px!important}
      .bottomin button:first-child{font-size:0!important}.bottomin button:first-child:after{content:"Refresh";font-size:10px}.bottomin button:last-child{font-size:0!important}.bottomin button:last-child:after{content:"Find gaps";font-size:10px}
      #webPreviewBadge span{display:none!important}
    }
  `;
  document.head.appendChild(style);

  const polish = () => {
    document.querySelectorAll(".gapSuggestHead").forEach(node => {
      const text = String(node.textContent || "");
      if (/^Best options for this .* window$/i.test(text)) node.textContent = "Best options";
    });
    document.querySelectorAll(".gapSuggest > .tiny").forEach(node => {
      const text = String(node.textContent || "");
      if (/LifeRoute ranks task time/i.test(text)) node.textContent = "Ranked by fit, route, priority, and due date.";
    });
    document.querySelectorAll(".lrBoundaryGap [data-boundary-place],.lrBoundaryGap [data-boundary-todo]").forEach(button => {
      if (!button.disabled) button.textContent = "Add";
    });
    document.querySelectorAll(".lrBoundaryGap [data-boundary-stores]").forEach(button => {
      if (!button.disabled && !/again|try/i.test(button.textContent || "")) button.textContent = "Search stores";
    });
    const refresh = document.querySelector(".bottomin button:first-child");
    const gaps = document.querySelector(".bottomin button:last-child");
    refresh?.setAttribute("aria-label", "Refresh calendars");
    gaps?.setAttribute("aria-label", "Find best gaps");
  };

  const start = () => {
    polish();
    const observer = new MutationObserver(polish);
    observer.observe(document.body, { childList: true, subtree: true });
    [120, 420, 1000, 2200].forEach(delay => setTimeout(polish, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();