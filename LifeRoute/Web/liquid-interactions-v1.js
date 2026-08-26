// LifeRoute Liquid Interaction System v1.
// A lightweight Apple-inspired navigation/control layer: sliding selection glass,
// directional view transitions, and haptics for non-button controls. It never moves
// the document viewport; the user's finger remains the only scroll owner.
(() => {
  if (window.__lifeRouteLiquidInteractionsV1Loaded) return;
  window.__lifeRouteLiquidInteractionsV1Loaded = true;

  const REDUCE = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  const BAR_SELECTOR = '.tabs,.lrContextTabs,.lrPlaceCategories,.setupSubnav,.calendarHubNav';
  const barObservers = new WeakMap();
  const previousIndex = new WeakMap();

  const style = document.createElement('style');
  style.id = 'lifeRouteLiquidInteractionsV1Styles';
  style.textContent = `
    :root{--lr-glass-line:color-mix(in srgb,var(--line) 74%,white 8%);--lr-glass-hi:rgba(255,255,255,.13);--lr-glass-shadow:0 12px 34px rgba(0,0,0,.12)}
    .lrLiquidTabBar{position:relative!important;isolation:isolate}
    .lrLiquidTabBar>.lrSlidingIndicator{position:absolute;z-index:0;left:0;top:0;width:20px;height:20px;border-radius:12px;pointer-events:none;opacity:0;background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 20%,var(--panel2)),color-mix(in srgb,var(--gold) 12%,var(--panel2) 88%));border:1px solid color-mix(in srgb,var(--gold) 30%,var(--lr-glass-line));box-shadow:inset 0 1px var(--lr-glass-hi),0 7px 20px rgba(0,0,0,.13);backdrop-filter:blur(14px) saturate(128%);-webkit-backdrop-filter:blur(14px) saturate(128%);transition:transform .30s cubic-bezier(.2,.88,.24,1.06),width .30s cubic-bezier(.2,.88,.24,1.06),height .24s ease,opacity .14s ease,border-radius .24s ease}
    .lrLiquidTabBar>button,.lrLiquidTabBar>[role="tab"]{position:relative;z-index:1;background:transparent!important;box-shadow:none!important;transition:color .20s ease,transform .14s cubic-bezier(.2,.9,.24,1.14),filter .14s ease!important}
    .lrLiquidTabBar>button.active,.lrLiquidTabBar>[role="tab"].active,.lrLiquidTabBar>[aria-selected="true"]{background:transparent!important;box-shadow:none!important;color:var(--text)!important}
    .lrLiquidTabBar>button:active,.lrLiquidTabBar>[role="tab"]:active{transform:scale(.965)!important;filter:brightness(1.08)!important}

    .tabs.lrLiquidTabBar,.lrContextTabs.lrLiquidTabBar,.lrPlaceCategories.lrLiquidTabBar,.setupSubnav.lrLiquidTabBar{background:color-mix(in srgb,var(--panel) 54%,transparent)!important;border:1px solid var(--lr-glass-line)!important;box-shadow:inset 0 1px var(--lr-glass-hi),var(--lr-glass-shadow)!important;backdrop-filter:blur(15px) saturate(120%)!important;-webkit-backdrop-filter:blur(15px) saturate(120%)!important}

    .lrSlideFromRight{animation:lrSlideFromRight .25s cubic-bezier(.2,.86,.24,1) both!important}
    .lrSlideFromLeft{animation:lrSlideFromLeft .25s cubic-bezier(.2,.86,.24,1) both!important}
    @keyframes lrSlideFromRight{from{opacity:.26;transform:translate3d(16px,0,0) scale(.994)}to{opacity:1;transform:translate3d(0,0,0) scale(1)}}
    @keyframes lrSlideFromLeft{from{opacity:.26;transform:translate3d(-16px,0,0) scale(.994)}to{opacity:1;transform:translate3d(0,0,0) scale(1)}}

    .primary,.goldButton,.lrSettingsButton,.lrQuickAddButton{position:relative;overflow:hidden}
    .primary:after,.goldButton:after,.lrSettingsButton:after,.lrQuickAddButton:after{content:"";position:absolute;inset:-45% -70%;pointer-events:none;background:linear-gradient(110deg,transparent 37%,rgba(255,255,255,.22) 49%,transparent 61%);transform:translate3d(-25%,0,0);opacity:0;transition:transform .30s ease,opacity .16s ease}
    .primary:active:after,.goldButton:active:after,.lrSettingsButton:active:after,.lrQuickAddButton:active:after{transform:translate3d(25%,0,0);opacity:.78}

    html.lrInteractionBusy .lrSlidingIndicator{transition-duration:.10s!important}
    @media(prefers-reduced-motion:reduce){.lrSlidingIndicator{transition-duration:.01ms!important}.lrSlideFromRight,.lrSlideFromLeft{animation:none!important}.primary:after,.goldButton:after,.lrSettingsButton:after,.lrQuickAddButton:after{display:none!important}}
  `;
  document.head.appendChild(style);

  const tabButtons = bar => [...bar.children].filter(node => node.matches?.('button,[role="tab"]') && !node.classList.contains('lrSlidingIndicator'));
  const activeButton = bar => tabButtons(bar).find(button => button.classList.contains('active') || button.getAttribute('aria-selected') === 'true') || null;

  const syncBar = bar => {
    if (!bar?.isConnected) return;
    const indicator = bar.querySelector(':scope > .lrSlidingIndicator');
    const active = activeButton(bar);
    if (!indicator || !active || active.offsetParent === null) {
      if (indicator) indicator.style.opacity = '0';
      return;
    }
    const x = active.offsetLeft;
    const y = active.offsetTop;
    indicator.style.width = `${active.offsetWidth}px`;
    indicator.style.height = `${active.offsetHeight}px`;
    indicator.style.transform = `translate3d(${x}px,${y}px,0)`;
    indicator.style.borderRadius = getComputedStyle(active).borderRadius || '12px';
    indicator.style.opacity = '1';
    const buttons = tabButtons(bar);
    const index = buttons.indexOf(active);
    if (index >= 0) previousIndex.set(bar, index);
  };

  const installBar = bar => {
    if (!bar || bar.dataset.lrLiquidBar === '1') return;
    bar.dataset.lrLiquidBar = '1';
    bar.classList.add('lrLiquidTabBar');
    const indicator = document.createElement('span');
    indicator.className = 'lrSlidingIndicator';
    indicator.setAttribute('aria-hidden', 'true');
    bar.prepend(indicator);
    const observer = new MutationObserver(() => requestAnimationFrame(() => syncBar(bar)));
    observer.observe(bar, { attributes:true, subtree:true, attributeFilter:['class','aria-selected','hidden','style'] });
    barObservers.set(bar, observer);
    requestAnimationFrame(() => syncBar(bar));
  };

  const scanBars = root => {
    if (root?.matches?.(BAR_SELECTOR)) installBar(root);
    root?.querySelectorAll?.(BAR_SELECTOR).forEach(installBar);
  };

  const directionFor = button => {
    const bar = button?.closest?.(BAR_SELECTOR);
    if (!bar) return 1;
    const buttons = tabButtons(bar);
    const next = buttons.indexOf(button);
    const current = previousIndex.has(bar) ? previousIndex.get(bar) : buttons.indexOf(activeButton(bar));
    return next >= current ? 1 : -1;
  };

  const visibleTransitionTargets = () => {
    const targets = [];
    const view = document.querySelector('.view.active');
    if (view) targets.push(view);
    document.querySelectorAll('.lrSetupPane.active,.setupPane.active').forEach(node => targets.push(node));
    const tools = document.querySelector('#tools.view.active .toolGrid');
    if (tools) targets.push(tools);
    const resources = document.querySelector('#resources.view.active #resourceGroups');
    if (resources) targets.push(resources);
    return [...new Set(targets)];
  };

  const animateCurrentContent = direction => {
    if (REDUCE?.matches) return;
    requestAnimationFrame(() => {
      const className = direction >= 0 ? 'lrSlideFromRight' : 'lrSlideFromLeft';
      visibleTransitionTargets().forEach(node => {
        node.classList.remove('lrSlideFromRight','lrSlideFromLeft');
        void node.offsetWidth;
        node.classList.add(className);
        setTimeout(() => node.classList.remove(className), 310);
      });
    });
  };

  const emitHaptic = styleName => {
    try { window.webkit?.messageHandlers?.lifeRoute?.postMessage?.({ action:'haptic', style:styleName }); } catch (_) {}
  };

  document.addEventListener('click', event => {
    const button = event.target?.closest?.('button,[role="tab"]');
    if (!button) return;
    const bar = button.closest(BAR_SELECTOR);
    if (!bar || button.parentElement !== bar) return;
    const direction = directionFor(button);
    requestAnimationFrame(() => syncBar(bar));
    setTimeout(() => { syncBar(bar); animateCurrentContent(direction); }, 0);
  }, true);

  document.addEventListener('change', event => {
    const control = event.target;
    if (!(control instanceof HTMLInputElement || control instanceof HTMLSelectElement)) return;
    if (control.matches('input[type="checkbox"],input[type="radio"],input[type="range"],select')) emitHaptic('selection');
  }, true);

  window.addEventListener('resize', () => document.querySelectorAll(BAR_SELECTOR).forEach(syncBar), { passive:true });
  const discover = new MutationObserver(records => {
    for (const record of records) for (const node of record.addedNodes) if (node instanceof Element) scanBars(node);
  });

  const start = () => {
    scanBars(document);
    discover.observe(document.body, { childList:true, subtree:true });
    window.LifeRouteLiquidInteractionsV1 = { sync: () => document.querySelectorAll(BAR_SELECTOR).forEach(syncBar), haptic: emitHaptic };
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true });
  else start();
})();
