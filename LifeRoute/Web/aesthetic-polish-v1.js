// LifeRoute aesthetic polish: consistent touch sizing, focus treatment, overflow safety,
// and final mobile presentation guardrails shared by web and native iPhone builds.
(() => {
  if (window.__lifeRouteAestheticPolishV1Loaded) return;
  window.__lifeRouteAestheticPolishV1Loaded = true;

  const style = document.createElement("style");
  style.id = "lifeRouteAestheticPolishV1Styles";
  style.textContent = `
    html,body{max-width:100%;overflow-x:hidden}
    body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
    button,input,select,a{outline:none}
    button:focus-visible,input:focus-visible,select:focus-visible,a:focus-visible,[role="button"]:focus-visible{
      outline:2px solid color-mix(in srgb,var(--blue) 78%,white)!important;
      outline-offset:2px!important;
      box-shadow:0 0 0 4px color-mix(in srgb,var(--blue) 14%,transparent)!important;
    }
    button:disabled{opacity:.5;cursor:default}
    .card,.metric,.hero,.route,.gapOption,.storeOption{overflow-wrap:anywhere}
    .title,.meta,.small,.tiny,.hint{max-width:100%}
    .lrDayCommandStrip button,.bottomin button,.tabs .tab,.calendarHubNav button{white-space:nowrap}

    /* Keep the compact visual language while meeting comfortable iPhone touch sizing. */
    @media(max-width:700px) and (pointer:coarse){
      button,.tabs .tab,.calendarHubNav button,.lrDayPager button,.lrBoundaryOpen,
      .gapOptionButtons button,.selectedGapActions button,.setupSubnav button,
      .lrDayPrimaryControls button,.lrDayClearControls button,.timerChromeButton,.lrTimerSoundToggle{
        min-height:44px!important;
      }
      input,select{min-height:44px!important}
      .tiny{font-size:max(9px,0.72rem)!important}
      .hint{font-size:max(9px,0.72rem)!important}
      .lrDayCommandStrip{row-gap:7px!important}
      .lrEndHomeCompact{padding-top:10px!important;padding-bottom:10px!important}
    }

    /* Decorative motion should never interfere with reading or tapping. */
    #lifeRouteMetalBackdrop,#lifeRouteThemeFX,#lifeRouteDynamicBackdrop,#lifeRouteNatureBackdrop,
    .lrAnimalScenePhoto,.lrAnimalAtmosphere,.lrTimerInnerGrid{pointer-events:none!important}

    @media(prefers-reduced-motion:reduce){
      html{scroll-behavior:auto!important}
      *,*:before,*:after{scroll-behavior:auto!important}
    }
  `;
  document.head.appendChild(style);
})();
