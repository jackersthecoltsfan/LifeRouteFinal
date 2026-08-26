// LifeRoute Premium Interactions v1
// Apple-inspired motion, tactile icon response, semantic haptics, and smooth view/sheet transitions.
// Performance note: keep interaction work compositor-friendly and avoid whole-document mutation observation.
(() => {
  if (window.__lifeRoutePremiumInteractionsV1Loaded) return;
  window.__lifeRoutePremiumInteractionsV1Loaded = true;

  const reduceMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;
  const haptic = style => {
    try {
      if (window.LifeRouteInteractionPolish?.haptic) return window.LifeRouteInteractionPolish.haptic(style);
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (handler?.postMessage) handler.postMessage({action:'haptic',style:style || 'selection'});
    } catch (_) {}
  };

  const style = document.createElement('style');
  style.id = 'lifeRoutePremiumInteractionsV1Styles';
  style.textContent = `
    :root{--lr-premium-spring:cubic-bezier(.2,.86,.24,1.18);--lr-premium-ease:cubic-bezier(.16,1,.3,1)}
    button:not(:disabled) svg,[role="button"]:not([aria-disabled="true"]) svg,button:not(:disabled) .lrDelightFallbackIcon,[role="button"]:not([aria-disabled="true"]) .lrDelightFallbackIcon{transform-origin:center;transition:transform .2s var(--lr-premium-spring)}
    .lrPremiumIconTap svg,.lrPremiumIconTap .lrDelightFallbackIcon{transform:scale(.9)}
    .lrPremiumIconRelease svg,.lrPremiumIconRelease .lrDelightFallbackIcon{animation:lrPremiumIconSettle .28s var(--lr-premium-spring) both}
    .lrPremiumIconSpin svg,.lrPremiumIconSpin .lrDelightFallbackIcon{animation:lrPremiumIconSpin .34s var(--lr-premium-ease) both}
    .lrPremiumIconPulse svg,.lrPremiumIconPulse .lrDelightFallbackIcon{animation:lrPremiumIconPulse .28s var(--lr-premium-spring) both}
    .lrPremiumIconAdvance svg,.lrPremiumIconAdvance .lrDelightFallbackIcon{animation:lrPremiumIconAdvance .28s var(--lr-premium-spring) both}
    @keyframes lrPremiumIconSettle{0%{transform:scale(.92)}60%{transform:scale(1.06)}100%{transform:none}}
    @keyframes lrPremiumIconSpin{0%{transform:scale(.94) rotate(0)}72%{transform:scale(1.03) rotate(300deg)}100%{transform:none}}
    @keyframes lrPremiumIconPulse{0%{transform:scale(.9)}62%{transform:scale(1.1)}100%{transform:none}}
    @keyframes lrPremiumIconAdvance{0%{transform:translate3d(-1px,0,0) scale(.96)}58%{transform:translate3d(4px,0,0) scale(1.03)}100%{transform:none}}
    .card,.hero,.metric,.gapOption,.storeOption,.lrHubCard{transition:transform .16s var(--lr-premium-ease),box-shadow .18s ease,border-color .16s ease,background-color .16s ease}
    .lrPremiumSurfaceDown{transform:scale(.988)}
    .view.active.lrPremiumViewEnter,.lrSetupPane.active.lrPremiumViewEnter{animation:lrPremiumViewEnter .24s var(--lr-premium-ease) both;transform-origin:50% 24%}
    @keyframes lrPremiumViewEnter{from{opacity:.35;transform:translate3d(0,7px,0) scale(.993)}to{opacity:1;transform:none}}
    dialog[open],.sheet.show,.modal.show,[role="dialog"]:not([hidden]){animation:lrPremiumSheetIn .24s var(--lr-premium-ease) both;transform-origin:50% 100%}
    @keyframes lrPremiumSheetIn{from{opacity:.2;transform:translate3d(0,12px,0) scale(.994)}to{opacity:1;transform:none}}
    .lrPremiumSavedFlash{animation:lrPremiumSavedFlash .34s var(--lr-premium-ease) both}@keyframes lrPremiumSavedFlash{0%{opacity:.82}45%{opacity:1}100%{opacity:1}}
    .calendarHubNav button{transition:transform .14s var(--lr-premium-ease),background-color .16s ease,color .16s ease,box-shadow .16s ease}
    .calendarHubNav button:active{transform:scale(.97)}
    .tabs .tab,.tabs button,[data-lr-top-nav="true"]{transform:translate3d(0,0,0);transition:transform .14s var(--lr-premium-spring),background-color .16s ease,color .16s ease,border-color .16s ease,box-shadow .16s ease,opacity .16s ease;will-change:transform}
    .tabs .tab:active,.tabs button:active,[data-lr-top-nav="true"]:active{transform:translate3d(0,1px,0) scale(.965)}
    .tabs .tab.active,.tabs button.active,[data-lr-top-nav="true"].active{transform:translate3d(0,-1px,0) scale(1.015)}
    .tabs .tab.lrPremiumNavRelease,.tabs button.lrPremiumNavRelease,[data-lr-top-nav="true"].lrPremiumNavRelease{animation:lrPremiumNavRelease .24s var(--lr-premium-spring) both}
    @keyframes lrPremiumNavRelease{0%{transform:scale(.965)}62%{transform:scale(1.035)}100%{transform:scale(1)}}
    @media(max-width:680px){
      #lifeRouteThemeFX .fxOrb,#lifeRouteThemeFX .fxBeam{animation:none!important;filter:none!important;opacity:.055!important}
      .calendarHubNav,.lrBackButton{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
      .tabs .tab,.tabs button,[data-lr-top-nav="true"]{will-change:auto}
    }
    @media(prefers-reduced-motion:reduce){.lrPremiumIconRelease svg,.lrPremiumIconRelease .lrDelightFallbackIcon,.lrPremiumIconSpin svg,.lrPremiumIconSpin .lrDelightFallbackIcon,.lrPremiumIconPulse svg,.lrPremiumIconPulse .lrDelightFallbackIcon,.lrPremiumIconAdvance svg,.lrPremiumIconAdvance .lrDelightFallbackIcon,.view.active.lrPremiumViewEnter,.lrSetupPane.active.lrPremiumViewEnter,dialog[open],.sheet.show,.modal.show,[role="dialog"]:not([hidden]),.lrPremiumSavedFlash,.lrPremiumNavRelease{animation:none!important}.lrPremiumIconTap svg,.lrPremiumIconTap .lrDelightFallbackIcon{transform:none!important}.tabs .tab,.tabs button,[data-lr-top-nav="true"]{transition:none!important;transform:none!important}}
  `;
  document.head.appendChild(style);

  const buttonSelector = 'button,[role="button"]';
  const surfaceSelector = '.card[onclick],.hero[onclick],.metric[onclick],.gapOption[onclick],.storeOption[onclick],.lrHubCard[onclick],[data-lr-interactive-surface="true"]';
  const topNavSelector = '.tabs .tab,.tabs button,[data-lr-top-nav="true"]';
  const classify = control => {
    const text = `${control?.getAttribute?.('aria-label')||''} ${control?.title||''} ${control?.textContent||''} ${control?.className||''}`.toLowerCase();
    if (/refresh|reload|sync|settings|gear/.test(text)) return 'lrPremiumIconSpin';
    if (/next|route|navigate|direction|go|forward|open/.test(text)) return 'lrPremiumIconAdvance';
    if (/save|favorite|heart|check|done|complete|add|plus/.test(text)) return 'lrPremiumIconPulse';
    return 'lrPremiumIconRelease';
  };
  const motionClasses = ['lrPremiumIconTap','lrPremiumIconRelease','lrPremiumIconSpin','lrPremiumIconPulse','lrPremiumIconAdvance'];
  const clear = control => control?.classList.remove(...motionClasses);
  const settle = control => {
    if (!control || reduceMotion()) return;
    const motion = classify(control);
    clear(control);
    requestAnimationFrame(() => {
      control.classList.add(motion);
      window.setTimeout(() => clear(control), 380);
    });
  };
  const settleTopNav = control => {
    if (!control?.matches?.(topNavSelector) || reduceMotion()) return;
    control.classList.remove('lrPremiumNavRelease');
    requestAnimationFrame(() => {
      control.classList.add('lrPremiumNavRelease');
      window.setTimeout(() => control.classList.remove('lrPremiumNavRelease'), 280);
    });
  };

  const syncCalendarSelection = button => {
    if (!button?.matches?.('[data-calendar-view]')) return;
    const nav = button.closest('.calendarHubNav') || button.parentElement;
    nav?.querySelectorAll?.('[data-calendar-view]').forEach(item => {
      const selected = item === button;
      item.classList.toggle('active', selected);
      item.setAttribute('aria-selected', selected ? 'true' : 'false');
    });
  };

  document.addEventListener('pointerdown', event => {
    const control = event.target?.closest?.(buttonSelector);
    if (control && !control.matches(':disabled') && control.getAttribute('aria-disabled') !== 'true') {
      if (control.matches('[data-calendar-view]')) syncCalendarSelection(control);
      if (!reduceMotion()) { clear(control); control.classList.add('lrPremiumIconTap'); }
    }
    const surface = event.target?.closest?.(surfaceSelector);
    if (surface) surface.classList.add('lrPremiumSurfaceDown');
  }, true);

  document.addEventListener('pointerup', event => {
    const control = event.target?.closest?.(buttonSelector);
    if (control?.classList.contains('lrPremiumIconTap')) settle(control);
    const topNav = event.target?.closest?.(topNavSelector);
    if (topNav) settleTopNav(topNav);
    event.target?.closest?.(surfaceSelector)?.classList.remove('lrPremiumSurfaceDown');
  }, true);
  document.addEventListener('pointercancel', event => {
    const control = event.target?.closest?.(buttonSelector); if (control) clear(control);
    event.target?.closest?.(surfaceSelector)?.classList.remove('lrPremiumSurfaceDown');
  }, true);

  let previousActive = null;
  let observedViews = [];
  let viewObserver = null;
  const animateActive = () => {
    const active = document.querySelector('.view.active,.lrSetupPane.active');
    if (!active || active === previousActive) return;
    previousActive = active;
    if (reduceMotion()) return;
    active.classList.remove('lrPremiumViewEnter');
    requestAnimationFrame(() => {
      active.classList.add('lrPremiumViewEnter');
      window.setTimeout(() => active.classList.remove('lrPremiumViewEnter'), 290);
    });
  };
  const observeKnownViews = () => {
    const next = Array.from(document.querySelectorAll('.view,.lrSetupPane'));
    if (next.length === observedViews.length && next.every((node,index)=>node===observedViews[index])) return;
    viewObserver?.disconnect();
    observedViews = next;
    viewObserver = new MutationObserver(() => requestAnimationFrame(animateActive));
    observedViews.forEach(node => viewObserver.observe(node,{attributes:true,attributeFilter:['class']}));
  };
  const start = () => {
    observeKnownViews();
    animateActive();
    document.addEventListener('liferoute-view-changed', animateActive);
    window.setTimeout(observeKnownViews, 1200);
  };
  if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',start,{once:true}); else start();

  window.LifeRoutePremiumInteractions = {
    feedback(kind='selection', target=null){
      const map={selection:'selection',success:'success',warning:'warning',error:'error',impact:'medium'};
      haptic(map[kind]||'selection');
      const el=typeof target==='string'?document.querySelector(target):target;
      if(el instanceof HTMLElement&&!reduceMotion()){
        el.classList.remove('lrPremiumSavedFlash');
        requestAnimationFrame(()=>{
          el.classList.add('lrPremiumSavedFlash');
          window.setTimeout(()=>el.classList.remove('lrPremiumSavedFlash'),390);
        });
      }
    }
  };
})();
