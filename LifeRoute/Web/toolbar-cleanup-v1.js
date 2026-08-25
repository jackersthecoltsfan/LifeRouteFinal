// LifeRoute navigation architecture v2.
// Canonical top level: Schedule, Session Tools, Resources, Setup.
// Setup owns Saved Places, Clients, Personal Tasks, and Connections.
(() => {
  if (window.__lifeRouteNavigationArchitectureV2) return;
  window.__lifeRouteNavigationArchitectureV2 = true;

  const icon = (name, fallback) => {
    try {
      if (typeof window.lifeRouteIcon === 'function') return window.lifeRouteIcon(name, 16);
    } catch (_) {}
    return `<span aria-hidden="true">${fallback}</span>`;
  };

  const TOP_NAV = [
    { view: 'today', label: 'Schedule', icon: () => icon('calendar', '▣') },
    { view: 'tools', label: 'Session Tools', icon: () => '<span class="lrPuzzleIcon" aria-hidden="true">🧩</span>' },
    { view: 'resources', label: 'Resources', icon: () => icon('book', '▤') },
    { view: 'setup', label: 'Setup', icon: () => icon('person', '◎') }
  ];

  const installStyles = () => {
    if (document.getElementById('lifeRouteNavigationV2Styles')) return;
    const style = document.createElement('style');
    style.id = 'lifeRouteNavigationV2Styles';
    style.textContent = `
      .tabs{grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:7px!important}
      .tabs .tab{min-width:0;min-height:52px!important;padding:8px 5px!important;display:flex!important;align-items:center!important;justify-content:center!important;gap:5px!important;flex-direction:column!important;font-size:10px!important;line-height:1.08!important;text-align:center!important}
      .tabs .tab svg{width:17px;height:17px}.lrPuzzleIcon{font-size:17px;line-height:1}
      .lrSetupHub,.lrSessionToolsHub{display:grid;gap:9px}.lrSetupHub{grid-template-columns:1fr}.lrSessionToolsHub{grid-template-columns:repeat(3,minmax(0,1fr));margin:0 0 14px}
      .lrHubIntro{margin-bottom:12px}.lrHubCard{width:100%;min-height:74px;text-align:left!important;background:color-mix(in srgb,var(--panel) 92%,transparent)!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:18px!important;padding:13px 14px!important;display:grid!important;grid-template-columns:38px 1fr auto;gap:10px;align-items:center;box-shadow:var(--shadow)}
      .lrHubCard:active{transform:scale(.99)}.lrHubIcon{width:38px;height:38px;border-radius:13px;display:grid;place-items:center;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));border:1px solid var(--line);color:var(--gold);font-size:20px}.lrHubCard b{display:block;font-size:13px}.lrHubCard span.lrHubMeta{display:block;color:var(--muted);font-size:9px;line-height:1.35;margin-top:2px}.lrHubChevron{color:var(--muted);font-size:18px}
      .lrPaneBack{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 0 12px}.lrPaneBack button{min-height:40px}.lrPaneTitle{font-size:18px;font-weight:950}
      .lrPlaceCategories{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0 0 13px}.lrPlaceCategory{min-height:78px;text-align:left!important;background:color-mix(in srgb,var(--panel) 90%,transparent)!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:17px!important;padding:12px!important}.lrPlaceCategory b{display:block;font-size:13px}.lrPlaceCategory span{display:block;font-size:9px;color:var(--muted);line-height:1.35;margin-top:3px}.lrPlaceCategory .lrPlaceGlyph{font-size:20px;margin-bottom:6px;color:var(--gold)}
      #setupSubnav{display:none!important}#setupGeneral{display:none!important}.lrSetupPane{display:none}.lrSetupPane.active{display:block}.lrSetupHub[hidden],.lrSessionToolsHub[hidden]{display:none!important}
      .lrToolBack{display:none;margin:0 0 10px}.lrToolBack.show{display:flex}.lrToolBack button{min-height:40px}
      .lrSettingsPlanning{display:grid;grid-template-columns:1fr;gap:8px}.lrSettingsPlanning select{width:100%}
      @media(max-width:680px){.lrSessionToolsHub{grid-template-columns:1fr}.lrHubCard{min-height:70px}.lrPlaceCategories{grid-template-columns:1fr 1fr}.tabs .tab{font-size:9px!important;padding:8px 3px!important}}
    `;
    document.head.appendChild(style);
  };

  const topTabs = () => document.querySelector('.tabs');

  const setActiveTopTab = view => {
    const tabs = topTabs();
    if (!tabs) return;
    tabs.querySelectorAll('.tab').forEach(button => button.classList.toggle('active', button.dataset.view === view));
  };

  const ensureTopTabs = () => {
    const tabs = document.querySelector('.tabs');
    if (!tabs) return false;

    // Retain explicit Month de-duplication for the established audit contract.
    Array.from(tabs.children).forEach(child => {
      if (child?.classList?.contains('tab') && child.dataset?.view === 'month') child.remove();
    });

    const exact = TOP_NAV.every((item, index) => {
      const button = tabs.children[index];
      return button?.classList?.contains('tab') && button.dataset?.view === item.view;
    }) && tabs.children.length === TOP_NAV.length;

    if (!exact) {
      tabs.innerHTML = TOP_NAV.map(item => `<button class="tab" type="button" data-view="${item.view}" data-lr-nav-v2="1">${item.icon()}<span>${item.label}</span></button>`).join('');
    }

    tabs.querySelectorAll('.tab').forEach(button => {
      button.onclick = event => {
        event.preventDefault();
        navigateTop(button.dataset.view || 'today');
      };
    });

    const count = 4;
    tabs.style.setProperty('grid-template-columns', `repeat(${count}, minmax(0, 1fr))`, 'important');
    tabs.dataset.lifeRouteToolbarClean = '1';
    tabs.dataset.lifeRouteNavigationV2 = '1';
    return true;
  };

  const showOnlyView = id => {
    document.querySelectorAll('.view').forEach(view => view.classList.remove('active'));
    const target = document.getElementById(id);
    if (target) target.classList.add('active');
    setActiveTopTab(['today','week','month'].includes(id) ? 'today' : id);
  };

  let originalShowView = null;
  const installShowViewRouter = () => {
    if (window.__lifeRouteShowViewV2Installed) return;
    if (typeof window.showView !== 'function') return;
    window.__lifeRouteShowViewV2Installed = true;
    originalShowView = window.showView;
    window.showView = function lifeRouteStructuredShowView(id) {
      if (id === 'places') {
        showOnlyView('setup');
        openSetupPane('places');
        return;
      }
      if (id === 'todos') {
        showOnlyView('setup');
        openSetupPane('tasks');
        return;
      }
      if (id === 'week' || id === 'month') {
        showOnlyView(id);
        return;
      }
      showOnlyView(id);
      if (id === 'setup') showSetupHub();
      if (id === 'tools') showSessionToolsHub();
    };
  };

  const navigateTop = view => {
    if (view === 'setup') {
      showOnlyView('setup');
      showSetupHub();
      return;
    }
    if (view === 'tools') {
      showOnlyView('tools');
      showSessionToolsHub();
      return;
    }
    showOnlyView(view);
  };

  const setup = () => document.getElementById('setup');
  const paneMap = () => ({
    places: document.getElementById('places'),
    clients: document.getElementById('setupClients'),
    tasks: document.getElementById('todos'),
    connections: document.getElementById('setupConnectionsV2')
  });

  const paneTitle = name => ({ places: 'Saved Places', clients: 'Clients', tasks: 'Personal Tasks', connections: 'Connections' })[name] || 'Setup';

  const ensurePaneBack = (pane, name) => {
    if (!pane || pane.querySelector(':scope > .lrPaneBack')) return;
    const row = document.createElement('div');
    row.className = 'lrPaneBack';
    row.innerHTML = `<button class="secondary" type="button" data-lr-setup-back="1">← Setup</button><div class="lrPaneTitle">${paneTitle(name)}</div><span></span>`;
    pane.prepend(row);
    row.querySelector('[data-lr-setup-back]')?.addEventListener('click', showSetupHub);
  };

  const moveSetupSections = () => {
    const general = document.getElementById('setupGeneral');
    const connections = document.getElementById('setupConnectionsV2');
    const placesPane = document.getElementById('places');
    const schedule = document.getElementById('today');
    if (!general) return;

    Array.from(general.querySelectorAll(':scope > .section')).forEach(section => {
      const text = String(section.querySelector('.sectionHead h2, h2')?.textContent || section.textContent || '').trim();
      if (/Calendar inputs|Use these sources|Navigation/i.test(text)) {
        connections?.appendChild(section);
      } else if (section.querySelector('#homeAddressField') || /Commute intelligence/i.test(text)) {
        placesPane?.insertBefore(section, placesPane.children[1] || null);
      } else if (section.querySelector('#fDate') || /Add appointment manually/i.test(text)) {
        schedule?.appendChild(section);
      } else if (/Integration readiness/i.test(text)) {
        section.style.display = 'none';
      }
    });
  };

  const ensureConnectionsPane = () => {
    const root = setup();
    if (!root) return null;
    let pane = document.getElementById('setupConnectionsV2');
    if (!pane) {
      pane = document.createElement('div');
      pane.id = 'setupConnectionsV2';
      pane.className = 'lrSetupPane';
      root.appendChild(pane);
    }
    return pane;
  };

  const setupHubMarkup = () => `
    <div class="lrHubIntro"><div class="small" style="color:var(--gold);font-weight:950;letter-spacing:.1em">SETUP</div><div class="title" style="font-size:20px">Personalize LifeRoute.</div><div class="meta">Places, clients, personal tasks, and service connections live here.</div></div>
    <div class="lrSetupHub">
      <button class="lrHubCard" type="button" data-lr-setup-pane="places"><span class="lrHubIcon">⌂</span><span><b>Saved Places</b><span class="lrHubMeta">Home, relaxation, errands, and other locations.</span></span><span class="lrHubChevron">›</span></button>
      <button class="lrHubCard" type="button" data-lr-setup-pane="clients"><span class="lrHubIcon">◎</span><span><b>Clients</b><span class="lrHubMeta">ABA-style client profiles and service locations.</span></span><span class="lrHubChevron">›</span></button>
      <button class="lrHubCard" type="button" data-lr-setup-pane="tasks"><span class="lrHubIcon">✓</span><span><b>Personal Tasks</b><span class="lrHubMeta">Flexible tasks and errands to fit into open gaps.</span></span><span class="lrHubChevron">›</span></button>
      <button class="lrHubCard" type="button" data-lr-setup-pane="connections"><span class="lrHubIcon">↗</span><span><b>Connections</b><span class="lrHubMeta">Connect calendars and choose your navigation app.</span></span><span class="lrHubChevron">›</span></button>
    </div>`;

  const ensureSetupStructure = () => {
    const root = setup();
    const clients = document.getElementById('setupClients');
    const placesPane = document.getElementById('places');
    const tasksPane = document.getElementById('todos');
    if (!root || !clients || !placesPane || !tasksPane) return false;

    ensureConnectionsPane();

    let hub = document.getElementById('lifeRouteSetupHubV2');
    if (!hub) {
      hub = document.createElement('div');
      hub.id = 'lifeRouteSetupHubV2';
      hub.innerHTML = setupHubMarkup();
      root.prepend(hub);
      hub.querySelectorAll('[data-lr-setup-pane]').forEach(button => {
        button.addEventListener('click', () => openSetupPane(button.dataset.lrSetupPane));
      });
    }

    [placesPane, clients, tasksPane].forEach(pane => {
      pane.classList.remove('view', 'active', 'setupPane');
      pane.classList.add('lrSetupPane');
      if (pane.parentElement !== root) root.appendChild(pane);
    });
    const connections = document.getElementById('setupConnectionsV2');
    connections?.classList.add('lrSetupPane');

    moveSetupSections();
    ensurePaneBack(placesPane, 'places');
    ensurePaneBack(clients, 'clients');
    ensurePaneBack(tasksPane, 'tasks');
    ensurePaneBack(connections, 'connections');
    installSavedPlaceCategories();
    return true;
  };

  function showSetupHub() {
    if (!ensureSetupStructure()) return;
    const hub = document.getElementById('lifeRouteSetupHubV2');
    if (hub) hub.hidden = false;
    Object.values(paneMap()).forEach(pane => pane?.classList.remove('active'));
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function openSetupPane(name) {
    if (!ensureSetupStructure()) return;
    const hub = document.getElementById('lifeRouteSetupHubV2');
    if (hub) hub.hidden = true;
    Object.entries(paneMap()).forEach(([key, pane]) => pane?.classList.toggle('active', key === name));
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  const categoryInfo = {
    Home: ['⌂', 'Your start and end-of-day location.'],
    Relaxation: ['♧', 'Parks, gyms, cafés, quiet spots, and unwind places.'],
    Errand: ['🛒', 'Stores, pharmacies, pickups, and practical stops.'],
    Other: ['＋', 'Any saved place that does not fit the other groups.']
  };

  const setPlaceCategoryOptions = () => {
    const select = document.getElementById('placeType');
    if (!select) return;
    const current = select.value;
    const wanted = Object.keys(categoryInfo);
    if (Array.from(select.options).map(option => option.value).join('|') !== wanted.join('|')) {
      select.innerHTML = wanted.map(name => `<option value="${name}">${name}</option>`).join('');
      select.value = wanted.includes(current) ? current : 'Other';
    }
  };

  const focusPlaceCategory = name => {
    setPlaceCategoryOptions();
    if (name === 'Home') {
      const home = document.getElementById('homeAddressField');
      home?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => home?.focus({ preventScroll: true }), 250);
      return;
    }
    const select = document.getElementById('placeType');
    if (select) select.value = name;
    const add = document.getElementById('placeName')?.closest('.section');
    add?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setTimeout(() => document.getElementById('placeName')?.focus({ preventScroll: true }), 250);
  };

  function installSavedPlaceCategories() {
    const pane = document.getElementById('places');
    if (!pane) return;
    setPlaceCategoryOptions();
    let categories = document.getElementById('lifeRoutePlaceCategoriesV2');
    if (!categories) {
      categories = document.createElement('div');
      categories.id = 'lifeRoutePlaceCategoriesV2';
      categories.className = 'lrPlaceCategories';
      categories.innerHTML = Object.entries(categoryInfo).map(([name, [glyph, description]]) => `<button class="lrPlaceCategory" type="button" data-lr-place-category="${name}"><div class="lrPlaceGlyph">${glyph}</div><b>${name}</b><span>${description}</span></button>`).join('');
      const hero = pane.querySelector('.hero');
      if (hero) hero.insertAdjacentElement('afterend', categories);
      else pane.insertBefore(categories, pane.children[1] || null);
      categories.querySelectorAll('[data-lr-place-category]').forEach(button => button.addEventListener('click', () => focusPlaceCategory(button.dataset.lrPlaceCategory)));
    }
    const heroTitle = pane.querySelector('.hero h2');
    const heroText = pane.querySelector('.hero p');
    if (heroTitle) heroTitle.textContent = 'Saved Places';
    if (heroText) heroText.textContent = 'Organize the places LifeRoute can use for routing and gap suggestions.';
  }

  const toolDefinitions = [
    { key: 'timer', label: 'Visual Timer', glyph: '◴', meta: 'A large, session-friendly visual countdown.', targets: ['visualTimerTool'] },
    { key: 'visuals', label: 'Visuals Generator', glyph: '▧', meta: 'Create visual supports, First/Then boards, and choice boards.', targets: ['visualIconTool','choiceBoardTool','firstThenTool'] },
    { key: 'docs', label: 'Documentation Tools', glyph: '▤', meta: 'Quick notes, session planning, and documentation helpers.', targets: ['quickNotesTool','sessionPlanTool'] }
  ];

  const ensureSessionToolsHub = () => {
    const view = document.getElementById('tools');
    if (!view) return false;
    let hub = document.getElementById('lifeRouteSessionToolsHubV2');
    if (!hub) {
      hub = document.createElement('div');
      hub.id = 'lifeRouteSessionToolsHubV2';
      hub.className = 'lrSessionToolsHub';
      hub.innerHTML = toolDefinitions.map(tool => `<button class="lrHubCard" type="button" data-lr-tool-group="${tool.key}"><span class="lrHubIcon">${tool.glyph}</span><span><b>${tool.label}</b><span class="lrHubMeta">${tool.meta}</span></span><span class="lrHubChevron">›</span></button>`).join('');
      const hero = view.querySelector('.hero');
      if (hero) hero.insertAdjacentElement('afterend', hub); else view.prepend(hub);
      hub.querySelectorAll('[data-lr-tool-group]').forEach(button => button.addEventListener('click', () => openToolGroup(button.dataset.lrToolGroup)));
    }
    let back = document.getElementById('lifeRouteToolBackV2');
    if (!back) {
      back = document.createElement('div');
      back.id = 'lifeRouteToolBackV2';
      back.className = 'lrToolBack';
      back.innerHTML = '<button class="secondary" type="button">← Session Tools</button>';
      hub.insertAdjacentElement('afterend', back);
      back.querySelector('button')?.addEventListener('click', showSessionToolsHub);
    }
    const heroTitle = view.querySelector('.hero h2');
    if (heroTitle) heroTitle.textContent = 'Session Tools';
    return true;
  };

  function showSessionToolsHub() {
    if (!ensureSessionToolsHub()) return;
    const hub = document.getElementById('lifeRouteSessionToolsHubV2');
    const back = document.getElementById('lifeRouteToolBackV2');
    const grid = document.querySelector('#tools .toolGrid');
    if (hub) hub.hidden = false;
    back?.classList.remove('show');
    if (grid) grid.style.display = 'none';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function openToolGroup(key) {
    if (!ensureSessionToolsHub()) return;
    const definition = toolDefinitions.find(item => item.key === key);
    const hub = document.getElementById('lifeRouteSessionToolsHubV2');
    const back = document.getElementById('lifeRouteToolBackV2');
    const grid = document.querySelector('#tools .toolGrid');
    if (hub) hub.hidden = true;
    back?.classList.add('show');
    if (grid) {
      grid.style.display = '';
      Array.from(grid.children).forEach(card => {
        if (!(card instanceof HTMLElement)) return;
        if (definition?.targets.includes(card.id)) card.style.display = '';
        else if (key === 'docs' && !/visual|choice|firstthen|timer/i.test(card.id || '')) card.style.display = '';
        else card.style.display = 'none';
      });
    }
    const first = definition?.targets.map(id => document.getElementById(id)).find(Boolean) || grid;
    first?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  const installAppSettingsExtras = () => {
    const sheet = document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet');
    if (!sheet || document.getElementById('lifeRoutePlanningSettingsV2')) return false;
    const section = document.createElement('div');
    section.id = 'lifeRoutePlanningSettingsV2';
    section.className = 'lrSettingsSection';
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Planning preferences</b><span>general app settings</span></div><div class="lrSettingsPlanning"><label>Ideal maximum open gap</label><select id="lrSettingsGapV2"><option value="60">1 hour</option><option value="90">1.5 hours</option><option value="120">2 hours</option></select></div>`;
    sheet.appendChild(section);
    const select = section.querySelector('#lrSettingsGapV2');
    if (select) {
      try { select.value = String(prefs?.maxGap || 60); } catch (_) { select.value = '60'; }
      select.addEventListener('change', () => {
        try { prefs.maxGap = Number(select.value || 60); } catch (_) {}
        try { window.persist?.(); } catch (_) {}
        try { window.renderAll?.(); } catch (_) {}
      });
    }
    return true;
  };

  const reconcile = () => {
    installStyles();
    ensureTopTabs();
    installShowViewRouter();
    ensureSetupStructure();
    ensureSessionToolsHub();
    installSavedPlaceCategories();
    installAppSettingsExtras();
  };

  const start = () => {
    reconcile();
    [0, 80, 250, 700, 1400].forEach(delay => setTimeout(reconcile, delay));

    const tabs = document.querySelector('.tabs');
    if (tabs && !window.__lifeRouteToolbarCleanupObserver) {
      const observer = new MutationObserver(() => reconcile());
      observer.observe(tabs, { childList: true });
      window.__lifeRouteToolbarCleanupObserver = observer;
    }

    setTimeout(() => {
      const active = document.querySelector('.view.active')?.id || 'today';
      if (active === 'setup') showSetupHub();
      if (active === 'tools') showSessionToolsHub();
      setActiveTopTab(['week','month'].includes(active) ? 'today' : active);
    }, 160);
  };

  window.LifeRouteToolbarCleanupV1 = {
    reconcile,
    openSetupPane,
    showSetupHub,
    showSessionToolsHub,
    openToolGroup
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
