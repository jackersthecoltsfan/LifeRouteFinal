// LifeRoute Delight UI v1: lightweight fluid-glass navigation, contextual tabs,
// responsive backgrounds, melodic interaction sounds, and a dedicated manual appointment page.
// Motion is intentionally transform/opacity based so the layer stays smooth on iPhone.
(() => {
  if (window.__lifeRouteDelightUIV1Loaded) return;
  window.__lifeRouteDelightUIV1Loaded = true;

  const root = document.documentElement;
  let audioContext = null;
  let currentSetup = 'places';
  let currentTool = 'timer';
  let currentResource = 'finance';

  const icon = (name, fallback, size = 17) => {
    try { if (typeof window.lifeRouteIcon === 'function') return window.lifeRouteIcon(name, size); } catch (_) {}
    return `<span class="lrDelightFallbackIcon" aria-hidden="true">${fallback}</span>`;
  };

  const style = document.createElement('style');
  style.id = 'lifeRouteDelightUIV1Styles';
  style.textContent = `
    :root{--lr-delight-a:#377dff;--lr-delight-b:#f3c75f;--lr-delight-c:#6bd8ff;--lr-motion-a:24s;--lr-motion-b:31s;--lr-motion-c:38s}
    html[data-theme="obsidian"]{--lr-delight-a:#d7982b;--lr-delight-b:#fff0ad;--lr-delight-c:#6c4814;--lr-motion-a:34s;--lr-motion-b:44s;--lr-motion-c:27s}
    html[data-theme="carbon"]{--lr-delight-a:#8d99a8;--lr-delight-b:#dce3ea;--lr-delight-c:#3c4650;--lr-motion-a:42s;--lr-motion-b:28s;--lr-motion-c:52s}
    html[data-theme="midnight"],html[data-theme="navy-noir"]{--lr-delight-a:#2653d8;--lr-delight-b:#7b5cff;--lr-delight-c:#e2b95f;--lr-motion-a:30s;--lr-motion-b:46s;--lr-motion-c:36s}
    html[data-theme="titanium"]{--lr-delight-a:#a6c6e8;--lr-delight-b:#66788c;--lr-delight-c:#e3e9ef;--lr-motion-a:45s;--lr-motion-b:33s;--lr-motion-c:55s}
    html[data-theme="ocean"],html[data-theme="sapphire-tide"]{--lr-delight-a:#00b8d9;--lr-delight-b:#146cff;--lr-delight-c:#57f0d2;--lr-motion-a:18s;--lr-motion-b:26s;--lr-motion-c:34s}
    html[data-theme="aurora"],html[data-theme="arctic-pulse"]{--lr-delight-a:#52f4d0;--lr-delight-b:#6b63ff;--lr-delight-c:#c8fbff;--lr-motion-a:32s;--lr-motion-b:21s;--lr-motion-c:41s}
    html[data-theme="forest"],html[data-theme="emerald-tempest"]{--lr-delight-a:#26d58f;--lr-delight-b:#b9de56;--lr-delight-c:#087e5a;--lr-motion-a:38s;--lr-motion-b:50s;--lr-motion-c:29s}
    html[data-theme="plum"],html[data-theme="ultraviolet"]{--lr-delight-a:#b946ff;--lr-delight-b:#ff5fb8;--lr-delight-c:#7650ff;--lr-motion-a:24s;--lr-motion-b:35s;--lr-motion-c:19s}
    html[data-theme="ember"],html[data-theme="solar-flare"]{--lr-delight-a:#ff512c;--lr-delight-b:#ffbf3f;--lr-delight-c:#ff6c75;--lr-motion-a:16s;--lr-motion-b:29s;--lr-motion-c:23s}
    html[data-theme="molten-gold"]{--lr-delight-a:#f39113;--lr-delight-b:#ffe36a;--lr-delight-c:#a94d00;--lr-motion-a:27s;--lr-motion-b:37s;--lr-motion-c:20s}
    html[data-theme="rose-nebula"]{--lr-delight-a:#ff3c8e;--lr-delight-b:#ff9468;--lr-delight-c:#a533cc;--lr-motion-a:28s;--lr-motion-b:20s;--lr-motion-c:43s}
    html[data-theme="royal-cosmos"]{--lr-delight-a:#635cff;--lr-delight-b:#d492ff;--lr-delight-c:#f0bd45;--lr-motion-a:39s;--lr-motion-b:25s;--lr-motion-c:49s}
    html[data-theme="electric-storm"]{--lr-delight-a:#00ddff;--lr-delight-b:#7f42ff;--lr-delight-c:#126bff;--lr-motion-a:17s;--lr-motion-b:31s;--lr-motion-c:22s}
    html[data-theme="slate"],html[data-theme="phantom-silver"]{--lr-delight-a:#8ca9c7;--lr-delight-b:#eef5fb;--lr-delight-c:#4e6680;--lr-motion-a:48s;--lr-motion-b:36s;--lr-motion-c:58s}
    html[data-theme="daylight"]{--lr-delight-a:#2d8cf0;--lr-delight-b:#ffc64e;--lr-delight-c:#72d5e9;--lr-motion-a:36s;--lr-motion-b:45s;--lr-motion-c:30s}

    #lifeRouteDelightBackdrop{position:fixed;inset:-18%;z-index:0;pointer-events:none;overflow:hidden;opacity:.38;contain:strict}
    #lifeRouteDelightBackdrop>span{position:absolute;width:78vmax;height:78vmax;border-radius:50%;will-change:transform;opacity:.5}
    .lrDelightOrbA{left:-34vmax;top:-35vmax;background:radial-gradient(circle,var(--lr-delight-a) 0,transparent 64%);animation:lrDelightDriftA var(--lr-motion-a) ease-in-out infinite alternate}
    .lrDelightOrbB{right:-42vmax;top:9%;background:radial-gradient(circle,var(--lr-delight-b) 0,transparent 66%);animation:lrDelightDriftB var(--lr-motion-b) ease-in-out infinite alternate}
    .lrDelightOrbC{left:11%;bottom:-49vmax;background:radial-gradient(circle,var(--lr-delight-c) 0,transparent 64%);animation:lrDelightDriftC var(--lr-motion-c) ease-in-out infinite alternate}
    @keyframes lrDelightDriftA{from{transform:translate3d(-5%,0,0) scale(.86)}to{transform:translate3d(22%,14%,0) scale(1.08)}}
    @keyframes lrDelightDriftB{from{transform:translate3d(8%,-9%,0) scale(.92)}to{transform:translate3d(-20%,16%,0) scale(1.12)}}
    @keyframes lrDelightDriftC{from{transform:translate3d(-12%,9%,0) scale(.88)}to{transform:translate3d(17%,-18%,0) scale(1.1)}}
    html[data-theme="ocean"] .lrDelightOrbA,html[data-theme="sapphire-tide"] .lrDelightOrbA{animation-name:lrDelightTide}
    html[data-theme="aurora"] .lrDelightOrbB,html[data-theme="ultraviolet"] .lrDelightOrbB,html[data-theme="electric-storm"] .lrDelightOrbB{animation-name:lrDelightOrbit}
    html[data-theme="ember"] .lrDelightOrbC,html[data-theme="solar-flare"] .lrDelightOrbC,html[data-theme="molten-gold"] .lrDelightOrbC{animation-name:lrDelightBreathe}
    @keyframes lrDelightTide{from{transform:translate3d(-18%,3%,0) scale(.94)}to{transform:translate3d(24%,-5%,0) scale(1.06)}}
    @keyframes lrDelightOrbit{from{transform:rotate(-8deg) translate3d(-9%,4%,0) scale(.9)}to{transform:rotate(13deg) translate3d(12%,-9%,0) scale(1.12)}}
    @keyframes lrDelightBreathe{from{transform:translate3d(-5%,5%,0) scale(.78);opacity:.34}to{transform:translate3d(6%,-6%,0) scale(1.17);opacity:.62}}
    html[data-nature-theme="true"] #lifeRouteDelightBackdrop{opacity:.16}

    header{position:relative!important;z-index:6}.lrHeaderActions{display:flex;align-items:center;gap:7px;margin-left:auto}.lrQuickAddButton,.lrSettingsButton{width:42px!important;height:42px!important;min-height:42px!important;padding:0!important;border-radius:14px!important;display:grid!important;place-items:center!important;background:color-mix(in srgb,var(--panel) 72%,transparent)!important;border:1px solid color-mix(in srgb,var(--line) 76%,white 8%)!important;box-shadow:inset 0 1px rgba(255,255,255,.08),0 12px 30px rgba(0,0,0,.16)!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    .lrQuickAddButton{color:var(--gold)!important;font-size:22px!important}.lrQuickAddButton svg,.lrSettingsButton svg{width:18px;height:18px}

    .tabs{width:min(100%,590px)!important;margin:9px auto 12px!important;padding:4px!important;gap:4px!important;border-radius:18px!important;background:color-mix(in srgb,var(--panel) 57%,transparent)!important;border:1px solid color-mix(in srgb,var(--line) 72%,white 7%)!important;box-shadow:inset 0 1px rgba(255,255,255,.06),0 14px 34px rgba(0,0,0,.10)!important;backdrop-filter:blur(22px)!important;-webkit-backdrop-filter:blur(22px)!important}
    .tabs .tab{min-height:55px!important;border-radius:14px!important;display:flex!important;flex-direction:column!important;align-items:center!important;justify-content:center!important;gap:4px!important;color:var(--muted)!important;transition:transform .12s cubic-bezier(.22,.9,.25,1),background .18s ease,color .18s ease,box-shadow .18s ease!important}
    .tabs .tab.active{background:linear-gradient(145deg,color-mix(in srgb,var(--panel2) 78%,white 5%),color-mix(in srgb,var(--blue) 10%,var(--panel2)))!important;color:var(--text)!important;box-shadow:inset 0 1px rgba(255,255,255,.12),inset 0 0 0 1px color-mix(in srgb,var(--gold) 34%,var(--line)),0 7px 18px rgba(0,0,0,.12)!important}
    .tabs .tab svg{width:18px!important;height:18px!important}.tabs .tab span:last-child{font-size:9px;font-weight:900}

    .calendarHubNav{display:none!important}
    html[data-lr-schedule-context="true"] .calendarHubNav.show{display:flex!important;width:min(100%,430px);margin:0 auto 10px!important;background:color-mix(in srgb,var(--panel) 55%,transparent)!important;box-shadow:inset 0 1px rgba(255,255,255,.05)!important}

    .lrContextTabs{display:flex;gap:4px;width:100%;padding:4px;margin:2px 0 13px;border-radius:16px;background:color-mix(in srgb,var(--panel) 58%,transparent);border:1px solid color-mix(in srgb,var(--line) 75%,white 6%);box-shadow:inset 0 1px rgba(255,255,255,.06),0 10px 28px rgba(0,0,0,.08);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);overflow-x:auto;scrollbar-width:none}.lrContextTabs::-webkit-scrollbar{display:none}
    .lrContextTab{flex:1 0 auto;min-width:76px;min-height:39px!important;padding:7px 10px!important;border-radius:12px!important;background:transparent!important;color:var(--muted)!important;border:0!important;font-size:9.5px!important;white-space:nowrap;box-shadow:none!important}.lrContextTab.active{color:var(--text)!important;background:color-mix(in srgb,var(--panel2) 82%,transparent)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 30%,var(--line)),0 5px 14px rgba(0,0,0,.10)!important}
    #lifeRouteSessionToolsHubV2,#lifeRouteSetupHubV2{display:none!important}#lifeRouteToolBackV2,.lrPaneBack{display:none!important}
    #tools .toolGrid{margin-top:0}.lrSetupPane.active{animation:lrFluidIn .2s cubic-bezier(.2,.8,.2,1) both}
    @keyframes lrFluidIn{from{opacity:.18;transform:translate3d(8px,5px,0) scale(.995)}to{opacity:1;transform:none}}

    #manualAppointment{padding-top:2px}.lrManualAppointmentHero{background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 10%,transparent),color-mix(in srgb,var(--gold) 7%,transparent)),color-mix(in srgb,var(--panel) 80%,transparent)!important}.lrManualAppointmentBack{margin-bottom:8px;display:inline-flex}

    .card,.hero,.metric,.lrContextTabs,.tabs{backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
    .card,.hero,.metric{box-shadow:inset 0 1px rgba(255,255,255,.045),0 10px 30px rgba(0,0,0,.08)!important}

    @media(max-width:560px){.lrHeaderActions{gap:6px}.lrQuickAddButton,.lrSettingsButton{width:40px!important;height:40px!important;min-height:40px!important}.tabs{width:100%!important}.tabs .tab{min-height:51px!important}.lrContextTabs{margin-top:0}.lrContextTab{min-width:70px;font-size:9px!important}}
    @media(prefers-reduced-motion:reduce){#lifeRouteDelightBackdrop>span{animation:none!important}}
  `;
  document.head.appendChild(style);

  const mountBackdrop = () => {
    if (document.getElementById('lifeRouteDelightBackdrop')) return;
    const host = document.createElement('div');
    host.id = 'lifeRouteDelightBackdrop';
    host.setAttribute('aria-hidden', 'true');
    host.innerHTML = '<span class="lrDelightOrbA"></span><span class="lrDelightOrbB"></span><span class="lrDelightOrbC"></span>';
    document.body.prepend(host);
  };

  const ensureAudio = async () => {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;
    try {
      if (!audioContext) audioContext = new AudioContextClass({ latencyHint: 'interactive' });
      if (audioContext.state === 'suspended') await audioContext.resume();
      return audioContext.state === 'running' ? audioContext : null;
    } catch (_) { return null; }
  };

  const tone = async (frequency, gain = .035, delay = 0, duration = .09) => {
    const ctx = await ensureAudio();
    if (!ctx) return;
    const start = ctx.currentTime + delay;
    const master = ctx.createGain();
    master.gain.setValueAtTime(.0001, start);
    master.gain.exponentialRampToValueAtTime(gain, start + .008);
    master.gain.exponentialRampToValueAtTime(.0001, start + duration);
    master.connect(ctx.destination);
    const fundamental = ctx.createOscillator();
    fundamental.type = 'sine';
    fundamental.frequency.setValueAtTime(frequency, start);
    fundamental.connect(master);
    const shimmerGain = ctx.createGain();
    shimmerGain.gain.setValueAtTime(.22, start);
    shimmerGain.gain.exponentialRampToValueAtTime(.0001, start + duration * .72);
    shimmerGain.connect(master);
    const shimmer = ctx.createOscillator();
    shimmer.type = 'sine';
    shimmer.frequency.setValueAtTime(frequency * 2.01, start);
    shimmer.connect(shimmerGain);
    fundamental.start(start); shimmer.start(start);
    fundamental.stop(start + duration + .01); shimmer.stop(start + duration * .8);
  };

  const playSound = kind => {
    if (kind === 'primary') {
      tone(660, .045, 0, .105); tone(880, .034, .055, .11);
    } else if (kind === 'nav') {
      tone(740, .026, 0, .075); tone(930, .018, .045, .08);
    } else {
      tone(520, .018, 0, .065);
    }
  };

  const classifySound = control => {
    if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'primary';
    if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'nav';
    return 'soft';
  };

  document.addEventListener('pointerdown', () => { ensureAudio(); }, { once: true, capture: true });
  document.addEventListener('pointerup', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || control.matches(':disabled') || control.getAttribute('aria-disabled') === 'true') return;
    control.__lrSoundAt = performance.now();
    playSound(classifySound(control));
  }, true);
  document.addEventListener('click', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || performance.now() - Number(control.__lrSoundAt || 0) < 400) return;
    playSound(classifySound(control));
  }, true);

  const polishTopNav = () => {
    const map = {
      today: ['calendar', '◫', 'Schedule'],
      tools: ['briefcase', '◈', 'Session Tools'],
      resources: ['book', '▤', 'Resources'],
      setup: ['person', '◎', 'Setup']
    };
    document.querySelectorAll('.tabs .tab').forEach(button => {
      const info = map[button.dataset.view];
      if (!info || button.dataset.lrDelightIcon === '1') return;
      button.dataset.lrDelightIcon = '1';
      button.innerHTML = `${icon(info[0], info[1], 18)}<span>${info[2]}</span>`;
    });
  };

  const openManualAppointment = () => {
    const page = ensureManualAppointment();
    if (!page) return;
    document.querySelectorAll('.view').forEach(view => view.classList.remove('active'));
    page.classList.add('active');
    document.querySelectorAll('.tabs .tab').forEach(button => button.classList.toggle('active', button.dataset.view === 'today'));
    root.dataset.lrScheduleContext = 'false';
    window.scrollTo({ top: 0, behavior: 'smooth' });
    setTimeout(() => document.getElementById('fDate')?.focus?.({ preventScroll: true }), 240);
  };

  const ensureHeaderActions = () => {
    const header = document.querySelector('header');
    const settings = document.getElementById('lifeRouteSettingsButton');
    if (!header || !settings) return false;
    let actions = document.getElementById('lifeRouteHeaderActionsV1');
    if (!actions) {
      actions = document.createElement('div');
      actions.id = 'lifeRouteHeaderActionsV1';
      actions.className = 'lrHeaderActions';
      settings.parentNode?.insertBefore(actions, settings);
    }
    let add = document.getElementById('lifeRouteQuickAddAppointment');
    if (!add) {
      add = document.createElement('button');
      add.id = 'lifeRouteQuickAddAppointment';
      add.type = 'button';
      add.className = 'lrQuickAddButton';
      add.setAttribute('aria-label', 'Add appointment');
      add.title = 'Add appointment';
      add.innerHTML = icon('calendar', '＋', 18);
      add.addEventListener('click', openManualAppointment);
    }
    if (add.parentElement !== actions) actions.appendChild(add);
    if (settings.parentElement !== actions) actions.appendChild(settings);
    return true;
  };

  const ensureManualAppointment = () => {
    let page = document.getElementById('manualAppointment');
    if (!page) {
      page = document.createElement('section');
      page.id = 'manualAppointment';
      page.className = 'view';
      page.innerHTML = `<button type="button" class="secondary lrManualAppointmentBack">← Schedule</button><div class="hero lrManualAppointmentHero"><div class="small" style="color:var(--gold);font-weight:950;letter-spacing:.1em">QUICK ADD</div><h2>Add an appointment.</h2><p>Create a timed commitment without crowding the main Schedule screen.</p></div><div id="lifeRouteManualAppointmentSlot"></div>`;
      document.querySelector('.app')?.appendChild(page);
      page.querySelector('.lrManualAppointmentBack')?.addEventListener('click', () => window.showView?.('today'));
    }
    const form = document.getElementById('fDate')?.closest('.section');
    const slot = document.getElementById('lifeRouteManualAppointmentSlot');
    if (form && slot && form.parentElement !== slot) {
      slot.appendChild(form);
      const heading = form.querySelector(':scope > h2,.sectionHead h2');
      if (heading) heading.textContent = 'Appointment details';
    }
    return page;
  };

  const makeTabs = (id, items, onSelect) => {
    let bar = document.getElementById(id);
    if (!bar) {
      bar = document.createElement('div');
      bar.id = id;
      bar.className = 'lrContextTabs';
      bar.setAttribute('role', 'tablist');
      bar.innerHTML = items.map(item => `<button type="button" class="lrContextTab" data-key="${item.key}" role="tab">${item.label}</button>`).join('');
      bar.querySelectorAll('.lrContextTab').forEach(button => button.addEventListener('click', () => onSelect(button.dataset.key)));
    }
    return bar;
  };

  const markTab = (bar, key) => bar?.querySelectorAll('.lrContextTab').forEach(button => {
    const active = button.dataset.key === key;
    button.classList.toggle('active', active);
    button.setAttribute('aria-selected', active ? 'true' : 'false');
  });

  const ensureToolTabs = () => {
    const view = document.getElementById('tools');
    if (!view || !window.LifeRouteToolbarCleanupV1) return;
    const bar = makeTabs('lifeRouteToolTabsV1', [
      { key:'timer', label:'Timer' }, { key:'visuals', label:'Visuals' }, { key:'docs', label:'Docs' }
    ], key => {
      currentTool = key;
      window.LifeRouteToolbarCleanupV1?.openToolGroup?.(key);
      markTab(bar, key);
    });
    const hero = view.querySelector('.hero');
    if (bar.parentElement !== view) hero?.insertAdjacentElement('afterend', bar) || view.prepend(bar);
    markTab(bar, currentTool);
  };

  const ensureSetupTabs = () => {
    const view = document.getElementById('setup');
    if (!view || !window.LifeRouteToolbarCleanupV1) return;
    const bar = makeTabs('lifeRouteSetupTabsV1', [
      { key:'places', label:'Places' }, { key:'clients', label:'Clients' }, { key:'tasks', label:'Tasks' }, { key:'connections', label:'Connections' }
    ], key => {
      currentSetup = key;
      window.LifeRouteToolbarCleanupV1?.openSetupPane?.(key);
      markTab(bar, key);
    });
    if (bar.parentElement !== view) view.prepend(bar);
    markTab(bar, currentSetup);
  };

  const ensureResourceTabs = () => {
    const view = document.getElementById('resources');
    if (!view) return;
    const bar = makeTabs('lifeRouteResourceTabsV1', [
      { key:'finance', label:'Finance & HR' }, { key:'clinical', label:'ABA / Clinical' }, { key:'other', label:'Work Portals' }, { key:'custom', label:'My Resources' }
    ], key => { currentResource = key; applyResourceFilter(); markTab(bar, key); });
    const hero = view.querySelector('.resourceHero,.hero');
    if (bar.parentElement !== view) hero?.insertAdjacentElement('afterend', bar) || view.prepend(bar);
    markTab(bar, currentResource);
    applyResourceFilter();
  };

  const resourceKey = group => {
    const title = String(group.querySelector('.sectionHead h2')?.textContent || '').toLowerCase();
    if (title.includes('finance')) return 'finance';
    if (title.includes('clinical')) return 'clinical';
    if (title.includes('my resources')) return 'custom';
    return 'other';
  };
  function applyResourceFilter() {
    const groups = document.querySelectorAll('#resources .resourceGroup');
    let visible = 0;
    groups.forEach(group => {
      const show = resourceKey(group) === currentResource;
      group.style.display = show ? '' : 'none';
      if (show) visible += 1;
    });
    const customCard = document.querySelector('#resources .resourceCustom');
    if (customCard) customCard.style.display = currentResource === 'custom' ? '' : 'none';
    if (currentResource === 'custom' && !visible) customCard?.scrollIntoView?.({ block:'nearest' });
  }

  const activeView = () => document.querySelector('.view.active')?.id || 'today';
  const syncContext = () => {
    polishTopNav();
    ensureHeaderActions();
    ensureManualAppointment();
    ensureToolTabs();
    ensureSetupTabs();
    ensureResourceTabs();
    const active = activeView();
    root.dataset.lrScheduleContext = ['today','week','month'].includes(active) ? 'true' : 'false';
    if (active === 'tools') {
      window.LifeRouteToolbarCleanupV1?.openToolGroup?.(currentTool);
      markTab(document.getElementById('lifeRouteToolTabsV1'), currentTool);
    } else if (active === 'setup') {
      window.LifeRouteToolbarCleanupV1?.openSetupPane?.(currentSetup);
      markTab(document.getElementById('lifeRouteSetupTabsV1'), currentSetup);
    } else if (active === 'resources') applyResourceFilter();
  };

  let queued = false;
  const queueSync = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; syncContext(); });
  };

  const start = () => {
    mountBackdrop();
    syncContext();
    [80,240,700,1500,2600].forEach(delay => setTimeout(syncContext, delay));
    const observer = new MutationObserver(queueSync);
    observer.observe(document.body, { childList:true, subtree:true, attributes:true, attributeFilter:['class'] });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true });
  else start();

  window.LifeRouteDelightUIV1 = { syncContext, openManualAppointment, playSound };
})();
