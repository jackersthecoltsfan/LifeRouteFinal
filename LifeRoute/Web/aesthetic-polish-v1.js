// LifeRoute aesthetic polish: consistent touch sizing, focus treatment, overflow safety,
// tactile press visuals, and final mobile presentation guardrails shared by web and native iPhone builds.
(() => {
  if (window.__lifeRouteAestheticPolishV1Loaded) return;
  window.__lifeRouteAestheticPolishV1Loaded = true;

  const INTERACTION_MS = 110;
  const style = document.createElement('style');
  style.id = 'lifeRouteAestheticPolishV1Styles';
  style.textContent = `
    html,body{max-width:100%;overflow-x:hidden}body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}button,input,select,a{outline:none}
    button,[role="button"]{-webkit-tap-highlight-color:transparent;touch-action:manipulation;transform-origin:center;transition:transform .11s cubic-bezier(.2,.8,.2,1),box-shadow .14s ease,opacity .12s ease}
    button:not(:disabled):not([aria-disabled="true"]):active,button.lrPressed:not(:disabled):not([aria-disabled="true"]),[role="button"].lrPressed:not([aria-disabled="true"]){transform:scale(.97)}
    .tabs .tab.lrPressed,.lrHubCard.lrPressed,.lrPlaceCategory.lrPressed,.lrContextTab.lrPressed{box-shadow:0 6px 16px color-mix(in srgb,var(--blue) 16%,transparent)!important}
    button:focus-visible,input:focus-visible,select:focus-visible,a:focus-visible,[role="button"]:focus-visible{outline:2px solid color-mix(in srgb,var(--blue) 78%,white)!important;outline-offset:2px!important;box-shadow:0 0 0 4px color-mix(in srgb,var(--blue) 14%,transparent)!important}
    button:disabled{opacity:.5;cursor:default}.card,.metric,.hero,.route,.gapOption,.storeOption{overflow-wrap:anywhere}.title,.meta,.small,.tiny,.hint{max-width:100%}.lrDayCommandStrip button,.bottomin button,.tabs .tab,.calendarHubNav button{white-space:nowrap}
    @media(max-width:700px) and (pointer:coarse){button,.tabs .tab,.calendarHubNav button,.lrDayPager button,.lrBoundaryOpen,.gapOptionButtons button,.selectedGapActions button,.setupSubnav button,.lrDayPrimaryControls button,.lrDayClearControls button,.timerChromeButton,.lrTimerSoundToggle{min-height:44px!important}input,select{min-height:44px!important}.tiny{font-size:max(9px,0.72rem)!important}.hint{font-size:max(9px,0.72rem)!important}.lrDayCommandStrip{row-gap:7px!important}.lrEndHomeCompact{padding-top:10px!important;padding-bottom:10px!important}}
    #lifeRouteMetalBackdrop,#lifeRouteThemeFX,#lifeRouteDynamicBackdrop,#lifeRouteNatureBackdrop,#lifeRouteDelightBackdrop,#lifeRouteThemeSignature,.lrAnimalScenePhoto,.lrAnimalAtmosphere,.lrTimerInnerGrid{pointer-events:none!important}
    @media(prefers-reduced-motion:reduce){html{scroll-behavior:auto!important}*,*:before,*:after{scroll-behavior:auto!important;animation:none!important;transition-duration:.01ms!important}}
  `;
  document.head.appendChild(style);

  const interactiveSelector = 'button,[role="button"]';
  const enabledTarget = target => {
    const control = target?.closest?.(interactiveSelector);
    if (!control || control.matches?.(':disabled') || control.getAttribute('aria-disabled') === 'true') return null;
    return control;
  };

  const emitNativeHaptic = styleName => {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (handler?.postMessage) handler.postMessage({action:'haptic',style:styleName || 'medium'});
    } catch (_) {}
  };

  const pressControl = control => {
    if (!control) return;
    control.classList.add('lrPressed');
    if (control.__lifeRouteReleaseTimer) {
      clearTimeout(control.__lifeRouteReleaseTimer);
      control.__lifeRouteReleaseTimer = 0;
    }
  };
  const releaseControl = control => {
    if (!control) return;
    if (control.__lifeRouteReleaseTimer) clearTimeout(control.__lifeRouteReleaseTimer);
    control.__lifeRouteReleaseTimer = setTimeout(()=>{control.classList.remove('lrPressed');control.__lifeRouteReleaseTimer=0;},28);
  };

  // One pointer lifecycle only. Do not repeat press work again on click.
  document.addEventListener('pointerdown',event=>{const control=enabledTarget(event.target);if(control)pressControl(control);},true);
  document.addEventListener('pointerup',event=>releaseControl(enabledTarget(event.target)),true);
  document.addEventListener('pointercancel',event=>releaseControl(enabledTarget(event.target)),true);

  const EXPERIENCE_LAYERS = [
    ['lifeRouteInteractionLiquidV4Script','interaction-liquid-v4.js','__lifeRouteInteractionLiquidV4Loaded'],
    ['lifeRoutePremiumInteractionsV1Script','premium-interactions-v1.js','__lifeRoutePremiumInteractionsV1Loaded'],
    ['lifeRouteThemeExperienceV4Script','theme-experience-v4.js','__lifeRouteThemeExperienceV4Loaded'],
    ['lifeRouteThemeAccordionV1Script','theme-accordion-v1.js','__lifeRouteThemeAccordionV1Loaded'],
    ['lifeRouteUniversalAutocompleteV2Script','universal-autocomplete-v2.js','__lifeRouteUniversalAutocompleteV2Loaded'],
    ['lifeRouteVisualScheduleV1Script','visual-schedule-v1.js','__lifeRouteVisualScheduleV1Loaded'],
    ['lifeRouteWelcomeTourV2Script','welcome.js','__lifeRouteWelcomeTourV2Loaded']
  ];
  const loadExperienceLayer = index => {
    if (index >= EXPERIENCE_LAYERS.length || !document.body) return;
    const [id,filename,flag] = EXPERIENCE_LAYERS[index];
    const existing = document.getElementById(id) || [...document.scripts].find(script=>String(script.getAttribute('src')||'').split('?')[0].endsWith(filename));
    if (window[flag] || existing) { loadExperienceLayer(index+1); return; }
    const script = document.createElement('script');
    script.id = id;
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || '';
    script.src = `${filename}${build ? '?v='+encodeURIComponent(build) : ''}`;
    script.async = false;
    script.onload = () => loadExperienceLayer(index+1);
    script.onerror = () => loadExperienceLayer(index+1);
    document.body.appendChild(script);
  };
  const startExperienceLayers = () => loadExperienceLayer(0);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',startExperienceLayers,{once:true});
  else startExperienceLayers();

  window.LifeRouteInteractionPolish = {durationMs:INTERACTION_MS,haptic:emitNativeHaptic};
})();
