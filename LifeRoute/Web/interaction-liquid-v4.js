// LifeRoute interaction + Liquid Glass v4.
// Shared moving selection indicator, restrained glass navigation, and haptics.
// Performance: nav work is scoped to actual nav hosts; no whole-document mutation scans or forced layout animation restarts.
(() => {
  if (window.__lifeRouteInteractionLiquidV4Loaded) return;
  window.__lifeRouteInteractionLiquidV4Loaded = true;

  const reduceMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;
  const TAB_HOST_SELECTOR = '.tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs';
  const TAB_BUTTON_SELECTOR = '.tabs>button,.tabs>.tab,.lrContextTabs>button,.lrPlaceCategories>button,.setupSubnav>button,.calendarHubNav>button,.lrThemeCategoryTabs>button';

  const style = document.createElement('style');
  style.id = 'lifeRouteInteractionLiquidV4Styles';
  style.textContent = `
    :root{--lr-glass-edge:color-mix(in srgb,var(--line) 68%,white 14%);--lr-glass-fill:color-mix(in srgb,var(--panel) 55%,transparent);--lr-glass-highlight:color-mix(in srgb,white 18%,transparent)}
    .tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs{position:relative!important;isolation:isolate;overflow:hidden;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 58%,transparent),color-mix(in srgb,var(--panel2) 39%,transparent))!important;border:1px solid var(--lr-glass-edge)!important;box-shadow:inset 0 1px var(--lr-glass-highlight),0 8px 22px rgba(0,0,0,.09)!important;backdrop-filter:blur(8px)!important;-webkit-backdrop-filter:blur(8px)!important}
    .tabs>button,.tabs>.tab,.lrContextTabs>button,.lrPlaceCategories>button,.setupSubnav>button,.calendarHubNav>button,.lrThemeCategoryTabs>button{position:relative;z-index:2;background:transparent!important;box-shadow:none!important;transition:color .18s ease,transform .14s cubic-bezier(.18,.89,.26,1.22)!important}
    .tabs>button.active,.tabs>.tab.active,.lrContextTabs>button.active,.lrPlaceCategories>button.active,.setupSubnav>button.active,.calendarHubNav>button.active,.lrThemeCategoryTabs>button.active{background:transparent!important;box-shadow:none!important;color:var(--text)!important}
    .lrLiquidIndicator{position:absolute;z-index:1;pointer-events:none;left:0;top:4px;bottom:4px;width:0;border-radius:12px;background:linear-gradient(145deg,color-mix(in srgb,var(--panel2) 82%,white 5%),color-mix(in srgb,var(--blue) 12%,var(--panel2)));border:1px solid color-mix(in srgb,var(--gold) 31%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.13),0 5px 13px rgba(0,0,0,.10);transform:translate3d(0,0,0);transition:transform .24s cubic-bezier(.2,.82,.2,1),width .24s cubic-bezier(.2,.82,.2,1),opacity .14s ease;opacity:0}.lrLiquidIndicator.ready{opacity:1}
    .lrGlassControl,select,input[type="search"]{transition:border-color .14s ease,background-color .14s ease,box-shadow .14s ease,transform .1s ease}select:focus,input[type="search"]:focus{box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 11%,transparent)!important}.switch .slider{transition:background-color .18s ease,border-color .18s ease,box-shadow .18s ease!important}.switch .slider:before{transition:transform .22s cubic-bezier(.18,.89,.26,1.22)!important}
    @media(max-width:680px){.lrLiquidIndicator{top:3px;bottom:3px;border-radius:11px}.tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav,.lrThemeCategoryTabs{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}}
    @media(prefers-reduced-motion:reduce){.lrLiquidIndicator{transition:none!important}}
  `;
  document.head.appendChild(style);

  const nativeHaptic = styleName => { try { const handler=window.webkit?.messageHandlers?.lifeRoute;if(handler?.postMessage)handler.postMessage({action:'haptic',style:styleName||'selection'}); } catch (_) {} };
  const activeButton = host => host.querySelector(':scope > button.active,:scope > .tab.active,:scope > .lrContextTab.active,:scope > .lrPlaceCategory.active') || host.querySelector(':scope > button[aria-selected="true"],:scope > button[aria-pressed="true"]');

  let layoutFrame = 0;
  const layoutIndicator = host => {
    if (!(host instanceof HTMLElement) || !host.isConnected) return;
    let indicator=host.querySelector(':scope > .lrLiquidIndicator');
    if(!indicator){indicator=document.createElement('span');indicator.className='lrLiquidIndicator';indicator.setAttribute('aria-hidden','true');host.prepend(indicator);}
    const active=activeButton(host);if(!(active instanceof HTMLElement)){indicator.classList.remove('ready');return;}
    // One geometry read per selected-state change; no global traversal and no forced animation flush.
    const left=active.offsetLeft;
    const width=active.offsetWidth;
    indicator.style.width=`${Math.max(0,width)}px`;
    indicator.style.transform=`translate3d(${left}px,0,0)`;
    indicator.classList.add('ready');
  };
  const queueLayout = host => {
    if (!(host instanceof HTMLElement)) return;
    if (host.__lrLayoutQueued) return;
    host.__lrLayoutQueued = true;
    requestAnimationFrame(()=>{host.__lrLayoutQueued=false;layoutIndicator(host);});
  };
  const installHost = host => {
    if(!(host instanceof HTMLElement))return;
    if(host.dataset.lrLiquidIndicator==='1'){queueLayout(host);return;}
    host.dataset.lrLiquidIndicator='1';
    queueLayout(host);
    const observer=new MutationObserver(()=>queueLayout(host));
    observer.observe(host,{subtree:true,attributes:true,attributeFilter:['class','aria-selected','aria-pressed'],childList:true});
    host.__lrLiquidObserver=observer;
  };
  const scanKnownHosts = root => {
    if(root instanceof HTMLElement&&root.matches?.(TAB_HOST_SELECTOR))installHost(root);
    root?.querySelectorAll?.(TAB_HOST_SELECTOR).forEach(installHost);
  };

  document.addEventListener('pointerdown',event=>{
    const tab=event.target?.closest?.(TAB_BUTTON_SELECTOR);
    if(!tab)return;
    const host=tab.closest?.(TAB_HOST_SELECTOR);
    if(host)installHost(host);
  },true);
  document.addEventListener('pointerup',event=>{
    const tab=event.target?.closest?.(TAB_BUTTON_SELECTOR);
    const host=tab?.closest?.(TAB_HOST_SELECTOR);
    if(host)queueLayout(host);
  },true);
  document.addEventListener('change',event=>{const control=event.target;if(!(control instanceof HTMLElement)||control.closest?.('#lifeRouteAuthGate'))return;if(control.matches('select,input[type="checkbox"],input[type="radio"],input[type="range"],.switch input'))nativeHaptic('selection');},true);

  let resizeFrame=0;
  window.addEventListener('resize',()=>{
    if(resizeFrame)return;
    resizeFrame=requestAnimationFrame(()=>{resizeFrame=0;document.querySelectorAll(TAB_HOST_SELECTOR).forEach(queueLayout);});
  },{passive:true});

  const start=()=>{
    scanKnownHosts(document);
    // A few bounded startup rescans catch dynamically mounted setup/theme navigation without permanent global observation.
    [180,650,1500].forEach(delay=>window.setTimeout(()=>scanKnownHosts(document),delay));
  };

  window.LifeRouteLiquidInteractionV4={refresh:()=>scanKnownHosts(document),haptic:nativeHaptic};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
