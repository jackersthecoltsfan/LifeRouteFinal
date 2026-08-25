// LifeRoute refined UI pass: simpler hierarchy, calmer surfaces, tighter navigation.
(() => {
  if (window.__lifeRouteRefinedUIV2Loaded) return;
  window.__lifeRouteRefinedUIV2Loaded = true;

  const style = document.createElement("style");
  style.id = "lifeRouteRefinedUIV2Styles";
  style.textContent = `
    :root{--lr-radius:18px;--lr-radius-sm:13px;--lr-soft-line:color-mix(in srgb,var(--line) 72%,transparent)}
    body{letter-spacing:-.005em}
    .app{max-width:900px;padding-left:12px!important;padding-right:12px!important}
    header{align-items:center!important;margin-bottom:2px}header .brand{gap:9px}.mark{width:38px!important;height:38px!important;border-radius:12px!important;box-shadow:0 8px 28px rgba(0,0,0,.16)!important}h1{font-size:24px!important;letter-spacing:-.7px!important}.subtitle{font-size:10.5px!important;margin-top:2px!important}.status{font-size:9px!important;padding:6px 8px!important;background:color-mix(in srgb,var(--panel) 82%,transparent)!important}
    .tabs{display:flex!important;grid-template-columns:none!important;gap:4px!important;padding:4px!important;margin:12px 0 14px!important;border:1px solid var(--lr-soft-line);border-radius:16px;background:color-mix(in srgb,var(--panel) 72%,transparent);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    .tabs .tab{flex:1;min-width:0;border:0!important;border-radius:12px!important;padding:9px 7px!important;background:transparent!important;font-size:10.5px!important;color:var(--muted)!important;box-shadow:none!important}.tabs .tab.active{background:color-mix(in srgb,var(--panel2) 88%,transparent)!important;color:var(--text)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 30%,var(--line)),0 5px 16px rgba(0,0,0,.08)!important}
    .calendarHubNav{gap:4px!important;padding:4px!important;margin-bottom:10px!important;border-radius:14px!important;background:color-mix(in srgb,var(--panel) 72%,transparent)!important}.calendarHubNav button{min-height:34px!important;font-size:10.5px!important;border-radius:10px!important}.calendarHubNav button.active{box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 34%,var(--line))!important}
    .lrBackRow{margin:6px 0 -2px!important}.lrBackButton{min-height:34px!important;padding:7px 10px!important;font-size:10px!important;box-shadow:0 6px 18px rgba(0,0,0,.12)!important}.lrBackButton.isHome{display:none!important}
    .hero{padding:14px!important;border-radius:20px!important;margin-bottom:10px!important;box-shadow:0 10px 34px rgba(0,0,0,.12)!important}.hero h2{font-size:18px!important;margin-bottom:4px!important}.hero p{font-size:11px!important;line-height:1.4!important}.sourceLine{margin-top:6px!important}.chip{font-size:8.5px!important;padding:4px 7px!important}
    .metrics{gap:6px!important}.metric{padding:10px 11px!important;border-radius:15px!important;box-shadow:0 6px 20px rgba(0,0,0,.08)!important}.metric b{font-size:17px!important}.metric span{font-size:8.5px!important;margin-top:2px!important}
    .section{margin-top:14px!important}.sectionHead{margin-bottom:7px!important;align-items:center!important}.section h2,.sectionHead h2{font-size:15px!important}.hint{font-size:9px!important}
    .card{padding:13px!important;margin-bottom:8px!important;border-radius:var(--lr-radius)!important;border-color:var(--lr-soft-line)!important;box-shadow:0 8px 28px rgba(0,0,0,.10)!important}.title{font-size:15px!important;letter-spacing:-.2px}.meta,.small{font-size:10.5px!important;line-height:1.4}.tiny{font-size:9.25px!important;line-height:1.4}
    button{border-radius:11px!important;padding:9px 11px!important;min-height:38px;touch-action:manipulation}.primary,.goldButton{box-shadow:0 5px 16px rgba(0,0,0,.08)}.secondary{background:color-mix(in srgb,var(--panel2) 84%,transparent)!important;border-color:var(--lr-soft-line)!important}.danger{min-height:34px!important}
    input,select{border-radius:11px!important;padding:10px!important;border-color:var(--lr-soft-line)!important}
    .route{padding:9px 10px!important;margin-top:8px!important;border-radius:13px!important;background:color-mix(in srgb,var(--panel2) 78%,transparent)!important}.route button{min-height:36px!important}
    .lrDayPager{gap:5px!important;margin-bottom:9px!important}.lrDayPager button{min-height:38px!important;border-radius:12px!important}.lrDayToday{background:color-mix(in srgb,var(--gold) 7%,var(--panel2))!important}
    .lrBoundaryGap{border-style:solid!important;border-color:color-mix(in srgb,var(--gold) 22%,var(--line))!important;background:color-mix(in srgb,var(--panel) 91%,transparent)!important}.lrBoundaryGap .small{letter-spacing:.06em!important;font-size:8px!important}.lrBoundaryGap .title{font-size:13.5px!important}.lrBoundaryOpen{font-size:9.5px!important;min-height:36px!important;white-space:nowrap}
    .gapSuggest{margin-top:9px!important;padding-top:9px!important}.gapSuggestHead{font-size:12px!important;margin-bottom:4px}.gapOption{padding:11px!important;border-radius:15px!important;border-color:var(--lr-soft-line)!important;background:color-mix(in srgb,var(--panel2) 58%,transparent)!important}.gapOptionButtons{gap:6px!important;margin-top:8px!important}.gapOptionButtons button{min-height:36px!important;font-size:9.5px!important;padding:7px 10px!important}
    .storeChooser{margin-top:8px!important;padding-top:8px!important}.storeOption{padding:11px!important;border-radius:15px!important;background:color-mix(in srgb,var(--panel2) 60%,transparent)!important}.storeOptionButtons button{min-height:36px!important}
    .selectedGapMetrics{gap:5px!important}.selectedGapMetrics>div{padding:8px 9px!important;border-radius:11px!important}.selectedGapActions{gap:6px!important}.selectedGapActions button{min-height:35px!important}
    #today.lrSimpleDay .hero{padding:12px 13px!important}#today.lrSimpleDay .section{margin-top:12px!important}#today.lrSimpleDay #timeline>.card{margin-bottom:7px!important}
    #today .section:has(#dayInsight){margin-top:10px!important}#today .section:has(#dayInsight)>.sectionHead{margin-bottom:5px!important}#today #dayInsight{font-size:10.5px!important;line-height:1.45!important}.insight{border-left-width:2px!important;padding-left:10px!important}
    .bottom{padding:7px 12px calc(7px + env(safe-area-inset-bottom))!important;background:color-mix(in srgb,var(--bg) 90%,transparent)!important;backdrop-filter:blur(24px)!important;-webkit-backdrop-filter:blur(24px)!important}.bottomin{max-width:900px!important;gap:6px!important}.bottomin button{min-height:42px!important;font-size:11px!important;border-radius:13px!important}
    #webPreviewBadge{padding:5px 9px!important;font-size:8.5px!important;line-height:1.25!important;gap:5px!important;border-radius:0 0 10px 10px!important}#webPreviewBadge span{max-width:650px}
    .setupSubnav{gap:4px!important;padding:4px!important;border-radius:14px!important}.setupSubnav button{min-height:35px!important;font-size:10px!important}
    .integration{grid-template-columns:36px 1fr auto!important;gap:9px!important}.integrationIcon{width:36px!important;height:36px!important;border-radius:11px!important;font-size:16px!important}
    @media(max-width:560px){
      .app{padding-left:10px!important;padding-right:10px!important;padding-bottom:105px!important}header .subtitle{display:none}header .status{max-width:98px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.tabs{margin-top:9px!important}.tabs .tab{font-size:10px!important;padding:8px 4px!important}
      .metrics{grid-template-columns:repeat(3,1fr)!important}.metrics .metric:nth-child(4){display:none!important}.metric{padding:9px!important}.metric b{font-size:16px!important}
      .card{padding:12px!important}.row{gap:8px!important}.title{font-size:14.5px!important}.meta,.small{font-size:10px!important}
      .bottomin button:first-child{font-size:0!important}.bottomin button:first-child:after{content:"Refresh";font-size:11px}.bottomin button:last-child{font-size:0!important}.bottomin button:last-child:after{content:"Find gaps";font-size:11px}
      .lrBoundaryGap>.row{align-items:flex-start!important}.lrBoundaryGap .lrBoundaryOpen{padding:7px 9px!important}
    }
  `;
  document.head.appendChild(style);

  const polish = () => {
    const refresh = document.querySelector(".bottomin button:first-child");
    const gaps = document.querySelector(".bottomin button:last-child");
    if (refresh) refresh.setAttribute("aria-label", "Refresh calendars");
    if (gaps) gaps.setAttribute("aria-label", "Find best gaps");

    document.querySelectorAll(".lrBoundaryGap [data-boundary-place],.lrBoundaryGap [data-boundary-todo]").forEach(button => {
      if (!button.disabled) button.textContent = "Add to Day";
    });
    document.querySelectorAll(".lrBoundaryGap [data-boundary-stores]").forEach(button => {
      if (!button.disabled && !/again/i.test(button.textContent || "")) button.textContent = "Search stores";
    });
  };

  const start = () => {
    polish();
    const observer = new MutationObserver(polish);
    observer.observe(document.body, { childList: true, subtree: true });
    [100, 350, 900, 1800].forEach(delay => setTimeout(polish, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
