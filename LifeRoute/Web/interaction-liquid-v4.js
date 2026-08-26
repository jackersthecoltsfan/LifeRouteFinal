// LifeRoute interaction + Liquid Glass v4.
// Adds a shared moving selection indicator, restrained glass navigation, directional
// page motion, and haptics for non-button controls without ever moving document scroll.
(() => {
  if (window.__lifeRouteInteractionLiquidV4Loaded) return;
  window.__lifeRouteInteractionLiquidV4Loaded = true;

  const reduceMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;
  const TAB_HOST_SELECTOR = '.tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs';
  const TAB_BUTTON_SELECTOR = '.tabs>button,.lrContextTabs>button,.lrPlaceCategories>button,.setupSubnav>button,.calendarHubNav>button,.lrThemeCategoryTabs>button';

  const style = document.createElement('style');
  style.id = 'lifeRouteInteractionLiquidV4Styles';
  style.textContent = `
    :root{--lr-glass-edge:color-mix(in srgb,var(--line) 68%,white 14%);--lr-glass-fill:color-mix(in srgb,var(--panel) 55%,transparent);--lr-glass-highlight:color-mix(in srgb,white 18%,transparent)}
    .tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs{position:relative!important;isolation:isolate;overflow:hidden;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 58%,transparent),color-mix(in srgb,var(--panel2) 39%,transparent))!important;border:1px solid var(--lr-glass-edge)!important;box-shadow:inset 0 1px var(--lr-glass-highlight),0 12px 34px rgba(0,0,0,.10)!important;backdrop-filter:blur(14px) saturate(132%)!important;-webkit-backdrop-filter:blur(14px) saturate(132%)!important}
    .tabs>button,.lrContextTabs>button,.lrPlaceCategories>button,.setupSubnav>button,.calendarHubNav>button,.lrThemeCategoryTabs>button{position:relative;z-index:2;background:transparent!important;box-shadow:none!important;transition:color .24s ease,transform .145s cubic-bezier(.18,.89,.26,1.22),filter .12s ease!important}
    .tabs>button.active,.lrContextTabs>button.active,.lrPlaceCategories>button.active,.setupSubnav>button.active,.calendarHubNav>button.active,.lrThemeCategoryTabs>button.active{background:transparent!important;box-shadow:none!important;color:var(--text)!important}
    .lrLiquidIndicator{position:absolute;z-index:1;pointer-events:none;left:0;top:4px;bottom:4px;width:0;border-radius:12px;background:linear-gradient(145deg,color-mix(in srgb,var(--panel2) 78%,white 6%),color-mix(in srgb,var(--blue) 14%,var(--panel2)));border:1px solid color-mix(in srgb,var(--gold) 31%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.16),0 7px 18px rgba(0,0,0,.13),0 0 18px color-mix(in srgb,var(--blue) 9%,transparent);transform:translate3d(0,0,0);transition:transform .34s cubic-bezier(.2,.82,.2,1),width .34s cubic-bezier(.2,.82,.2,1),opacity .18s ease;opacity:0}.lrLiquidIndicator.ready{opacity:1}.lrLiquidIndicator::after{content:"";position:absolute;inset:1px;border-radius:inherit;background:linear-gradient(110deg,rgba(255,255,255,.10),transparent 38%,rgba(255,255,255,.05) 62%,transparent);transform:translateX(-24%);transition:transform .42s cubic-bezier(.2,.8,.2,1)}.lrLiquidIndicator.moving::after{transform:translateX(24%)}
    .view.active.lrSlideFromRight,.lrSetupPane.active.lrSlideFromRight{animation:lrSlideFromRight .28s cubic-bezier(.2,.82,.2,1) both!important}.view.active.lrSlideFromLeft,.lrSetupPane.active.lrSlideFromLeft{animation:lrSlideFromLeft .28s cubic-bezier(.2,.82,.2,1) both!important}@keyframes lrSlideFromRight{from{opacity:.22;transform:translate3d(18px,0,0) scale(.995)}to{opacity:1;transform:none}}@keyframes lrSlideFromLeft{from{opacity:.22;transform:translate3d(-18px,0,0) scale(.995)}to{opacity:1;transform:none}}
    .lrGlassControl,select,input[type="search"]{transition:border-color .16s ease,background .16s ease,box-shadow .16s ease,transform .12s ease}select:focus,input[type="search"]:focus{box-shadow:0 0 0 4px color-mix(in srgb,var(--blue) 12%,transparent),inset 0 1px rgba(255,255,255,.06)!important}.switch .slider{transition:background .22s ease,border-color .22s ease,box-shadow .22s ease!important}.switch .slider:before{transition:transform .26s cubic-bezier(.18,.89,.26,1.22),box-shadow .18s ease!important}.switch input:checked+.slider{box-shadow:inset 0 1px rgba(255,255,255,.18),0 4px 14px color-mix(in srgb,var(--blue) 20%,transparent)}
    html.lrInteractionBusy .lrLiquidIndicator::after{transition:none!important}@media(max-width:560px){.lrLiquidIndicator{top:3px;bottom:3px;border-radius:11px}.tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs{backdrop-filter:blur(11px) saturate(126%)!important;-webkit-backdrop-filter:blur(11px) saturate(126%)!important}}@media(prefers-reduced-motion:reduce){.lrLiquidIndicator{transition:none!important}.view.active.lrSlideFromRight,.view.active.lrSlideFromLeft,.lrSetupPane.active.lrSlideFromRight,.lrSetupPane.active.lrSlideFromLeft{animation:none!important}}
  `;
  document.head.appendChild(style);

  const nativeHaptic = styleName => { try { const handler=window.webkit?.messageHandlers?.lifeRoute;if(handler?.postMessage)handler.postMessage({action:'haptic',style:styleName||'selection'}); } catch (_) {} };
  const activeButton = host => host.querySelector(':scope > button.active,:scope > .tab.active,:scope > .lrContextTab.active,:scope > .lrPlaceCategory.active') || host.querySelector(':scope > button[aria-selected="true"],:scope > button[aria-pressed="true"]');

  const layoutIndicator = host => {
    if (!(host instanceof HTMLElement) || !host.isConnected) return;
    let indicator=host.querySelector(':scope > .lrLiquidIndicator');
    if(!indicator){indicator=document.createElement('span');indicator.className='lrLiquidIndicator';indicator.setAttribute('aria-hidden','true');host.prepend(indicator);}
    const active=activeButton(host);if(!(active instanceof HTMLElement)){indicator.classList.remove('ready');return;}
    const hostRect=host.getBoundingClientRect(),activeRect=active.getBoundingClientRect();
    const left=activeRect.left-hostRect.left+host.scrollLeft;
    indicator.style.width=`${Math.max(0,activeRect.width)}px`;indicator.style.transform=`translate3d(${left}px,0,0)`;indicator.classList.add('ready','moving');clearTimeout(indicator.__lrMoveTimer);indicator.__lrMoveTimer=setTimeout(()=>indicator.classList.remove('moving'),360);
  };
  const installHost = host => {
    if(!(host instanceof HTMLElement)||host.dataset.lrLiquidIndicator==='1')return;host.dataset.lrLiquidIndicator='1';layoutIndicator(host);
    const observer=new MutationObserver(()=>requestAnimationFrame(()=>layoutIndicator(host)));observer.observe(host,{subtree:true,attributes:true,attributeFilter:['class','aria-selected','aria-pressed'],childList:true});host.__lrLiquidObserver=observer;
  };
  const scanHosts = root => { if(root instanceof HTMLElement&&root.matches?.(TAB_HOST_SELECTOR))installHost(root);root?.querySelectorAll?.(TAB_HOST_SELECTOR).forEach(installHost); };

  const topOrder=['today','tools','resources','setup'];
  let lastTopIndex=Math.max(0,topOrder.findIndex(key=>document.querySelector(`.tabs .tab.active[data-view="${key}"]`)));
  const markDirectionalEntry = button => {
    const host=button?.parentElement?.matches?.(TAB_HOST_SELECTOR)?button.parentElement:button?.closest?.(TAB_HOST_SELECTOR);if(!host)return;
    let direction=1;
    if(host.matches('.tabs')){const next=topOrder.indexOf(button.dataset.view||'');if(next>=0){direction=next>=lastTopIndex?1:-1;lastTopIndex=next;}}
    else{const buttons=[...host.querySelectorAll(':scope > button')];const active=activeButton(host);const from=active?buttons.indexOf(active):0;const to=buttons.indexOf(button);direction=to>=from?1:-1;}
    requestAnimationFrame(()=>{const pane=document.querySelector('.view.active,.lrSetupPane.active');if(!pane||reduceMotion())return;pane.classList.remove('lrSlideFromRight','lrSlideFromLeft');void pane.offsetWidth;pane.classList.add(direction>=0?'lrSlideFromRight':'lrSlideFromLeft');setTimeout(()=>pane.classList.remove('lrSlideFromRight','lrSlideFromLeft'),340);});
  };

  document.addEventListener('pointerdown',event=>{const tab=event.target?.closest?.(TAB_BUTTON_SELECTOR);if(tab)markDirectionalEntry(tab);},true);
  document.addEventListener('change',event=>{const control=event.target;if(!(control instanceof HTMLElement)||control.closest?.('#lifeRouteAuthGate'))return;if(control.matches('select,input[type="checkbox"],input[type="radio"],input[type="range"],.switch input'))nativeHaptic('selection');},true);
  window.addEventListener('resize',()=>document.querySelectorAll(TAB_HOST_SELECTOR).forEach(layoutIndicator),{passive:true});

  let scanQueued=false;
  const queueScan=()=>{if(scanQueued)return;scanQueued=true;requestAnimationFrame(()=>{scanQueued=false;scanHosts(document);document.querySelectorAll(TAB_HOST_SELECTOR).forEach(layoutIndicator);});};
  const start=()=>{scanHosts(document);const observer=new MutationObserver(queueScan);observer.observe(document.body,{childList:true,subtree:true});[120,420,900].forEach(delay=>setTimeout(queueScan,delay));};

  window.LifeRouteLiquidInteractionV4={refresh:queueScan,haptic:nativeHaptic};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
