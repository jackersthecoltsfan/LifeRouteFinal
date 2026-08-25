// LifeRoute aesthetic polish: consistent touch sizing, focus treatment, overflow safety,
// tactile interaction feedback, and final mobile presentation guardrails shared by web and native iPhone builds.
(() => {
  if (window.__lifeRouteAestheticPolishV1Loaded) return;
  window.__lifeRouteAestheticPolishV1Loaded = true;

  const INTERACTION_MS = 250;
  const style = document.createElement("style");
  style.id = "lifeRouteAestheticPolishV1Styles";
  style.textContent = `
    html,body{max-width:100%;overflow-x:hidden}
    body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
    button,input,select,a{outline:none}
    button,[role="button"]{-webkit-tap-highlight-color:transparent;touch-action:manipulation;transform-origin:center;transition:transform .25s cubic-bezier(.2,.8,.2,1),filter .25s ease,box-shadow .25s ease,opacity .25s ease}
    button:not(:disabled):not([aria-disabled="true"]):active,
    button.lrPressed:not(:disabled):not([aria-disabled="true"]),
    [role="button"].lrPressed:not([aria-disabled="true"]){transform:scale(.965);filter:brightness(1.08) saturate(1.04)}
    .tabs .tab.lrPressed,.lrHubCard.lrPressed,.lrPlaceCategory.lrPressed{box-shadow:0 8px 20px color-mix(in srgb,var(--blue) 18%,transparent)!important}
    button:focus-visible,input:focus-visible,select:focus-visible,a:focus-visible,[role="button"]:focus-visible{
      outline:2px solid color-mix(in srgb,var(--blue) 78%,white)!important;
      outline-offset:2px!important;
      box-shadow:0 0 0 4px color-mix(in srgb,var(--blue) 14%,transparent)!important;
    }
    button:disabled{opacity:.5;cursor:default}
    .card,.metric,.hero,.route,.gapOption,.storeOption{overflow-wrap:anywhere}
    .title,.meta,.small,.tiny,.hint{max-width:100%}
    .lrDayCommandStrip button,.bottomin button,.tabs .tab,.calendarHubNav button{white-space:nowrap}

    /* Every page/pane arrives with one short, polished quarter-second transition. */
    .view.active,.lrSetupPane.active,#lifeRouteSetupHubV2:not([hidden]),.lrSessionToolsHub:not([hidden]){
      animation:lrPageEnter .25s cubic-bezier(.2,.8,.2,1) both;
    }
    @keyframes lrPageEnter{
      from{opacity:.18;transform:translate3d(0,7px,0) scale(.996)}
      to{opacity:1;transform:translate3d(0,0,0) scale(1)}
    }

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
      *,*:before,*:after{scroll-behavior:auto!important;animation:none!important;transition-duration:.01ms!important}
    }
  `;
  document.head.appendChild(style);

  const interactiveSelector = 'button,[role="button"]';
  const enabledTarget = target => {
    const control = target?.closest?.(interactiveSelector);
    if (!control) return null;
    if (control.matches?.(':disabled') || control.getAttribute('aria-disabled') === 'true') return null;
    return control;
  };

  const emitNativeHaptic = styleName => {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (handler?.postMessage) handler.postMessage({ action: "haptic", style: styleName || "light" });
    } catch (_) {}
  };

  const pressControl = control => {
    if (!control) return;
    control.classList.add('lrPressed');
    if (control.__lifeRouteReleaseTimer) clearTimeout(control.__lifeRouteReleaseTimer);
  };

  const releaseControl = control => {
    if (!control) return;
    if (control.__lifeRouteReleaseTimer) clearTimeout(control.__lifeRouteReleaseTimer);
    control.__lifeRouteReleaseTimer = setTimeout(() => {
      control.classList.remove('lrPressed');
      control.__lifeRouteReleaseTimer = 0;
    }, 70);
  };

  document.addEventListener('pointerdown', event => {
    const control = enabledTarget(event.target);
    if (!control) return;
    pressControl(control);
    control.__lifeRouteHapticAt = performance.now();
    emitNativeHaptic('light');
  }, true);

  ['pointerup','pointercancel','pointerleave'].forEach(type => {
    document.addEventListener(type, event => releaseControl(enabledTarget(event.target)), true);
  });

  // Keyboard/assistive activation has no pointerdown, so provide the same response on click.
  document.addEventListener('click', event => {
    const control = enabledTarget(event.target);
    if (!control) return;
    const lastHaptic = Number(control.__lifeRouteHapticAt || 0);
    if (!lastHaptic || performance.now() - lastHaptic > 500) {
      pressControl(control);
      releaseControl(control);
      emitNativeHaptic('light');
    }
  }, true);

  window.LifeRouteInteractionPolish = { durationMs: INTERACTION_MS, haptic: emitNativeHaptic };
})();
