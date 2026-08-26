// LifeRoute Premium Interactions v1
// Apple-inspired motion, tactile icon response, semantic haptics, and smooth view/sheet transitions.
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
    button:not(:disabled) svg,[role="button"]:not([aria-disabled="true"]) svg,button:not(:disabled) .lrDelightFallbackIcon,[role="button"]:not([aria-disabled="true"]) .lrDelightFallbackIcon{transform-origin:center;transition:transform .34s var(--lr-premium-spring),filter .2s ease}
    .lrPremiumIconTap svg,.lrPremiumIconTap .lrDelightFallbackIcon{transform:scale(.84) rotate(-7deg)}
    .lrPremiumIconRelease svg,.lrPremiumIconRelease .lrDelightFallbackIcon{animation:lrPremiumIconSettle .42s var(--lr-premium-spring) both}
    .lrPremiumIconSpin svg,.lrPremiumIconSpin .lrDelightFallbackIcon{animation:lrPremiumIconSpin .48s var(--lr-premium-ease) both}
    .lrPremiumIconPulse svg,.lrPremiumIconPulse .lrDelightFallbackIcon{animation:lrPremiumIconPulse .38s var(--lr-premium-spring) both}
    .lrPremiumIconAdvance svg,.lrPremiumIconAdvance .lrDelightFallbackIcon{animation:lrPremiumIconAdvance .38s var(--lr-premium-spring) both}
    @keyframes lrPremiumIconSettle{0%{transform:scale(.88) rotate(-5deg)}58%{transform:scale(1.09) rotate(2deg)}100%{transform:none}}
    @keyframes lrPremiumIconSpin{0%{transform:scale(.9) rotate(0)}70%{transform:scale(1.06) rotate(320deg)}100%{transform:none}}
    @keyframes lrPremiumIconPulse{0%{transform:scale(.82)}62%{transform:scale(1.16)}100%{transform:none}}
    @keyframes lrPremiumIconAdvance{0%{transform:translateX(-2px) scale(.92)}58%{transform:translateX(5px) scale(1.06)}100%{transform:none}}
    .card,.hero,.metric,.gapOption,.storeOption,.lrHubCard{transition:transform .22s var(--lr-premium-ease),box-shadow .24s ease,border-color .22s ease,background .22s ease,filter .22s ease}
    .lrPremiumInteractiveSurface{transform:translateZ(0)}.lrPremiumInteractiveSurface.lrPremiumSurfaceDown{transform:scale(.985);filter:brightness(1.035)}
    .view.active.lrPremiumViewEnter,.lrSetupPane.active.lrPremiumViewEnter{animation:lrPremiumViewEnter .34s var(--lr-premium-ease) both!important;transform-origin:50% 24%}
    @keyframes lrPremiumViewEnter{from{opacity:.08;transform:translate3d(0,11px,0) scale(.985);filter:blur(2px)}to{opacity:1;transform:none;filter:none}}
    dialog[open],.sheet.show,.modal.show,[role="dialog"]:not([hidden]){animation:lrPremiumSheetIn .32s var(--lr-premium-ease) both;transform-origin:50% 100%}
    @keyframes lrPremiumSheetIn{from{opacity:0;transform:translate3d(0,18px,0) scale(.985)}to{opacity:1;transform:none}}
    .lrPremiumSavedFlash{animation:lrPremiumSavedFlash .52s var(--lr-premium-ease) both}@keyframes lrPremiumSavedFlash{0%{filter:brightness(1)}42%{filter:brightness(1.18) saturate(1.08)}100%{filter:none}}
    @media(prefers-reduced-motion:reduce){.lrPremiumIconRelease svg,.lrPremiumIconRelease .lrDelightFallbackIcon,.lrPremiumIconSpin svg,.lrPremiumIconSpin .lrDelightFallbackIcon,.lrPremiumIconPulse svg,.lrPremiumIconPulse .lrDelightFallbackIcon,.lrPremiumIconAdvance svg,.lrPremiumIconAdvance .lrDelightFallbackIcon,.view.active.lrPremiumViewEnter,.lrSetupPane.active.lrPremiumViewEnter,dialog[open],.sheet.show,.modal.show,[role="dialog"]:not([hidden]),.lrPremiumSavedFlash{animation:none!important}.lrPremiumIconTap svg,.lrPremiumIconTap .lrDelightFallbackIcon{transform:none!important}}
  `;
  document.head.appendChild(style);

  const buttonSelector = 'button,[role="button"]';
  const surfaceSelector = '.card[onclick],.hero[onclick],.metric[onclick],.gapOption[onclick],.storeOption[onclick],.lrHubCard[onclick],[data-lr-interactive-surface="true"]';
  const classify = control => {
    const text = `${control?.getAttribute?.('aria-label')||''} ${control?.title||''} ${control?.textContent||''} ${control?.className||''}`.toLowerCase();
    if (/refresh|reload|sync|settings|gear/.test(text)) return 'lrPremiumIconSpin';
    if (/next|route|navigate|direction|go|forward|open/.test(text)) return 'lrPremiumIconAdvance';
    if (/save|favorite|heart|check|done|complete|add|plus/.test(text)) return 'lrPremiumIconPulse';
    return 'lrPremiumIconRelease';
  };
  const clear = control => control?.classList.remove('lrPremiumIconTap','lrPremiumIconRelease','lrPremiumIconSpin','lrPremiumIconPulse','lrPremiumIconAdvance');

  document.addEventListener('pointerdown', event => {
    const control = event.target?.closest?.(buttonSelector);
    if (control && !control.matches(':disabled') && control.getAttribute('aria-disabled') !== 'true' && !reduceMotion()) { clear(control); control.classList.add('lrPremiumIconTap'); }
    const surface = event.target?.closest?.(surfaceSelector); if (surface) surface.classList.add('lrPremiumInteractiveSurface','lrPremiumSurfaceDown');
  }, true);
  ['pointerup','pointercancel','pointerleave'].forEach(type => document.addEventListener(type, event => {
    const control = event.target?.closest?.(buttonSelector);
    if (control?.classList.contains('lrPremiumIconTap')) { control.classList.remove('lrPremiumIconTap'); if (!reduceMotion()) { const motion=classify(control); void control.offsetWidth; control.classList.add(motion); setTimeout(()=>clear(control),540); } }
    const surface = event.target?.closest?.(surfaceSelector); if (surface) surface.classList.remove('lrPremiumSurfaceDown');
  }, true));

  let previousActive = null;
  const animateActive = () => {
    const active = document.querySelector('.view.active,.lrSetupPane.active');
    if (!active || active === previousActive) return; previousActive = active; if (reduceMotion()) return;
    active.classList.remove('lrPremiumViewEnter'); void active.offsetWidth; active.classList.add('lrPremiumViewEnter'); setTimeout(()=>active.classList.remove('lrPremiumViewEnter'),430);
  };
  const observer = new MutationObserver(records => { if (records.some(r=>r.type==='attributes'&&r.attributeName==='class')) requestAnimationFrame(animateActive); records.forEach(r=>r.addedNodes.forEach(node=>{if(!(node instanceof HTMLElement))return;if(node.matches?.(surfaceSelector))node.classList.add('lrPremiumInteractiveSurface');node.querySelectorAll?.(surfaceSelector).forEach(el=>el.classList.add('lrPremiumInteractiveSurface'));})); });
  const start = () => { document.querySelectorAll(surfaceSelector).forEach(el=>el.classList.add('lrPremiumInteractiveSurface')); animateActive(); observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class']}); };
  if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',start,{once:true}); else start();

  window.LifeRoutePremiumInteractions = {
    feedback(kind='selection', target=null){ const map={selection:'selection',success:'success',warning:'warning',error:'error',impact:'medium'}; haptic(map[kind]||'selection'); const el=typeof target==='string'?document.querySelector(target):target; if(el instanceof HTMLElement&&!reduceMotion()){el.classList.remove('lrPremiumSavedFlash');void el.offsetWidth;el.classList.add('lrPremiumSavedFlash');setTimeout(()=>el.classList.remove('lrPremiumSavedFlash'),620);} }
  };
})();
