// LifeRoute Themes experience v4.
// Turns the settings theme catalog into a calm category browser and gives each
// core palette a distinct low-cost motion signature rather than a simple recolor.
(() => {
  if (window.__lifeRouteThemeExperienceV4Loaded) return;
  window.__lifeRouteThemeExperienceV4Loaded = true;

  const categories = [
    { key:'core', label:'Core', ids:['lifeRouteCoreThemeSection'] },
    { key:'metal', label:'Metal', ids:['lifeRouteMetallicWaveThemeSection'] },
    { key:'scene', label:'Scenery', match:/^(Nature scenery|Scenery)$/i },
    { key:'dynamic', label:'Dynamic', ids:['lifeRouteDynamicThemeSection'] },
    { key:'fluid', label:'Fluid', ids:['lifeRouteFluidSceneSection'] },
    { key:'creatures', label:'Creatures', ids:['lifeRouteDynamicAnimalSection'] }
  ];
  let activeCategory = 'core';

  const style = document.createElement('style');
  style.id = 'lifeRouteThemeExperienceV4Styles';
  style.textContent = `
    #lifeRouteSettingsOverlay .lrSettingsSheet{padding-left:12px!important;padding-right:12px!important;background:linear-gradient(160deg,color-mix(in srgb,var(--panel) 90%,transparent),color-mix(in srgb,var(--bg) 86%,transparent))!important}
    #lifeRouteSettingsOverlay .lrSettingsTop{position:sticky;top:0;z-index:8;margin:-2px -2px 10px;padding:4px 2px 10px;background:linear-gradient(180deg,color-mix(in srgb,var(--panel) 95%,transparent) 72%,transparent);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    #lifeRouteSettingsOverlay .lrThemeCatalogCount{opacity:.72}
    .lrThemeCategoryTabs{display:flex;gap:4px;padding:4px;margin:0 0 12px;border-radius:16px;overflow-x:auto;scrollbar-width:none}.lrThemeCategoryTabs::-webkit-scrollbar{display:none}.lrThemeCategoryTabs button{flex:1 0 auto;min-width:72px;min-height:39px!important;padding:7px 10px!important;border:0!important;border-radius:12px!important;color:var(--muted)!important;background:transparent!important;font-size:9px!important;font-weight:900!important;white-space:nowrap}.lrThemeCategoryTabs button.active{color:var(--text)!important}
    #lifeRouteSettingsOverlay .lrSettingsSection{margin:0 0 10px!important;padding:12px!important;border-radius:18px!important;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 78%,transparent),color-mix(in srgb,var(--panel2) 56%,transparent))!important;border:1px solid color-mix(in srgb,var(--line) 78%,white 7%)!important;box-shadow:inset 0 1px rgba(255,255,255,.055),0 10px 30px rgba(0,0,0,.08)!important}
    #lifeRouteSettingsOverlay .lrSettingsSectionHead{margin-bottom:9px!important}#lifeRouteSettingsOverlay .lrSettingsSectionHead b{font-size:13px!important}#lifeRouteSettingsOverlay .lrSettingsSectionHead span{font-size:8.5px!important;line-height:1.35!important;color:var(--muted)!important}
    #lifeRouteSettingsOverlay .lrThemeSectionHidden{display:none!important}
    .lrThemeChoiceGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px}.lrThemeChoice{min-height:58px!important;display:grid!important;grid-template-columns:34px 1fr auto;align-items:center;gap:9px;padding:9px!important;text-align:left!important;border-radius:14px!important;background:color-mix(in srgb,var(--panel2) 63%,transparent)!important;color:var(--text)!important;border:1px solid color-mix(in srgb,var(--line) 82%,transparent)!important;box-shadow:inset 0 1px rgba(255,255,255,.04)!important}.lrThemeChoice.active{border-color:color-mix(in srgb,var(--gold) 52%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 6%,var(--panel2)),color-mix(in srgb,var(--blue) 8%,var(--panel2)))!important}.lrThemeChoiceSwatch{width:34px;height:34px;border-radius:11px;background:linear-gradient(145deg,var(--swatch-a),var(--swatch-b));box-shadow:inset 0 1px rgba(255,255,255,.24),0 5px 14px rgba(0,0,0,.16)}.lrThemeChoice b{font-size:10px;line-height:1.15}.lrThemeChoiceCheck{opacity:0;color:var(--gold);font-size:13px;font-weight:1000}.lrThemeChoice.active .lrThemeChoiceCheck{opacity:1}.lrThemeSourceSelect{position:absolute!important;width:1px!important;height:1px!important;opacity:.001!important;pointer-events:none!important}
    #lifeRouteSettingsOverlay .lrThemeCard{min-height:76px!important;border-radius:15px!important;transition:transform .14s cubic-bezier(.18,.89,.26,1.22),border-color .18s ease,box-shadow .18s ease!important;box-shadow:inset 0 1px rgba(255,255,255,.05),0 7px 22px rgba(0,0,0,.08)!important}#lifeRouteSettingsOverlay .lrThemeCard:active{transform:scale(.965)!important}#lifeRouteSettingsOverlay .lrThemeCard.active{border-color:color-mix(in srgb,var(--gold) 58%,var(--line))!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 34%,transparent),0 8px 22px rgba(0,0,0,.10)!important}

    #lifeRouteThemeSignature{position:fixed;inset:-14%;z-index:0;pointer-events:none;overflow:hidden;opacity:.26;contain:strict;mix-blend-mode:screen}#lifeRouteThemeSignature::before,#lifeRouteThemeSignature::after{content:"";position:absolute;inset:10%;border-radius:44% 56% 62% 38% / 45% 42% 58% 55%;background:radial-gradient(ellipse at 34% 42%,var(--lr-signature-a),transparent 55%),radial-gradient(ellipse at 73% 61%,var(--lr-signature-b),transparent 52%);filter:blur(28px);transform:translate3d(0,0,0);animation:lrSignatureFloat 24s ease-in-out infinite alternate}#lifeRouteThemeSignature::after{inset:22% 4%;opacity:.65;animation-name:lrSignatureCounter;animation-duration:31s}
    @keyframes lrSignatureFloat{from{transform:translate3d(-9%,-4%,0) rotate(-5deg) scale(.92)}to{transform:translate3d(13%,8%,0) rotate(8deg) scale(1.12)}}@keyframes lrSignatureCounter{from{transform:translate3d(11%,7%,0) rotate(8deg) scale(1.08)}to{transform:translate3d(-12%,-9%,0) rotate(-10deg) scale(.9)}}
    html[data-theme="royal"]{--lr-signature-a:rgba(70,137,255,.42);--lr-signature-b:rgba(242,200,109,.30)}html[data-theme="royal"] #lifeRouteThemeSignature::before{border-radius:56% 44% 50% 50% / 40% 60% 40% 60%;animation-duration:28s}
    html[data-theme="obsidian"]{--lr-signature-a:rgba(231,194,105,.28);--lr-signature-b:rgba(164,177,194,.16)}html[data-theme="obsidian"] #lifeRouteThemeSignature::before{inset:18% -8%;border-radius:22%;transform:rotate(-18deg);animation-name:lrObsidianSweep;animation-duration:34s}@keyframes lrObsidianSweep{from{transform:translate3d(-16%,0,0) rotate(-18deg) scaleX(.72)}to{transform:translate3d(18%,5%,0) rotate(-8deg) scaleX(1.1)}}
    html[data-theme="carbon"]{--lr-signature-a:rgba(181,202,224,.20);--lr-signature-b:rgba(70,86,105,.18)}html[data-theme="carbon"] #lifeRouteThemeSignature{opacity:.18;background:repeating-linear-gradient(118deg,transparent 0 24px,rgba(255,255,255,.025) 25px 26px)}
    html[data-theme="midnight"]{--lr-signature-a:rgba(82,91,242,.36);--lr-signature-b:rgba(141,80,255,.24)}html[data-theme="midnight"] #lifeRouteThemeSignature::after{border-radius:50%;animation-duration:42s}
    html[data-theme="navy-noir"]{--lr-signature-a:rgba(34,113,204,.31);--lr-signature-b:rgba(218,178,85,.19)}html[data-theme="navy-noir"] #lifeRouteThemeSignature::before{inset:38% -12% 4%;border-radius:50%;animation-duration:19s}
    html[data-theme="titanium"]{--lr-signature-a:rgba(233,242,250,.24);--lr-signature-b:rgba(124,149,174,.18)}html[data-theme="titanium"] #lifeRouteThemeSignature::after{inset:4% 32%;border-radius:18%;animation-duration:36s}
    html[data-theme="ocean"],html[data-theme="sapphire-tide"]{--lr-signature-a:rgba(0,198,230,.35);--lr-signature-b:rgba(32,107,255,.30)}html[data-theme="ocean"] #lifeRouteThemeSignature::before,html[data-theme="sapphire-tide"] #lifeRouteThemeSignature::before{inset:42% -18% 0;border-radius:50% 50% 32% 68%;animation-name:lrTidePulse;animation-duration:16s}@keyframes lrTidePulse{from{transform:translate3d(-8%,5%,0) scaleX(1.05)}to{transform:translate3d(10%,-9%,0) scaleX(.9)}}
    html[data-theme="aurora"],html[data-theme="arctic-pulse"]{--lr-signature-a:rgba(67,245,211,.34);--lr-signature-b:rgba(100,91,255,.30)}html[data-theme="aurora"] #lifeRouteThemeSignature::before,html[data-theme="arctic-pulse"] #lifeRouteThemeSignature::before{inset:-6% 18%;border-radius:30%;filter:blur(38px);animation-duration:21s}
    html[data-theme="forest"],html[data-theme="emerald-tempest"]{--lr-signature-a:rgba(43,204,132,.30);--lr-signature-b:rgba(177,215,82,.19)}html[data-theme="forest"] #lifeRouteThemeSignature::before,html[data-theme="emerald-tempest"] #lifeRouteThemeSignature::before{inset:28% 4% -8%;border-radius:58% 42% 68% 32%;animation-duration:37s}
    html[data-theme="plum"],html[data-theme="ultraviolet"],html[data-theme="rose-nebula"]{--lr-signature-a:rgba(190,72,255,.32);--lr-signature-b:rgba(255,84,173,.25)}html[data-theme="plum"] #lifeRouteThemeSignature::after,html[data-theme="ultraviolet"] #lifeRouteThemeSignature::after,html[data-theme="rose-nebula"] #lifeRouteThemeSignature::after{border-radius:50%;animation-duration:18s}
    html[data-theme="ember"],html[data-theme="solar-flare"],html[data-theme="molten-gold"]{--lr-signature-a:rgba(255,96,40,.32);--lr-signature-b:rgba(255,193,56,.28)}html[data-theme="ember"] #lifeRouteThemeSignature::before,html[data-theme="solar-flare"] #lifeRouteThemeSignature::before,html[data-theme="molten-gold"] #lifeRouteThemeSignature::before{inset:50% 0 -12%;border-radius:50%;animation-name:lrHeatBreathe;animation-duration:10s}@keyframes lrHeatBreathe{from{transform:scale(.82);opacity:.62}to{transform:scale(1.16);opacity:1}}
    html[data-theme="slate"],html[data-theme="phantom-silver"]{--lr-signature-a:rgba(140,169,199,.23);--lr-signature-b:rgba(230,239,248,.15)}html[data-theme="slate"] #lifeRouteThemeSignature::before,html[data-theme="phantom-silver"] #lifeRouteThemeSignature::before{filter:blur(52px);animation-duration:48s}
    html[data-theme="mono"]{--lr-signature-a:rgba(255,255,255,.14);--lr-signature-b:rgba(143,143,143,.12)}html[data-theme="mono"] #lifeRouteThemeSignature{opacity:.13}
    html[data-theme="daylight"]{--lr-signature-a:rgba(79,155,227,.22);--lr-signature-b:rgba(243,190,66,.18)}html[data-theme="daylight"] #lifeRouteThemeSignature{mix-blend-mode:multiply;opacity:.18}
    html[data-dynamic-theme] #lifeRouteThemeSignature,html[data-fluid-scene] #lifeRouteThemeSignature,html[data-animal-theme] #lifeRouteThemeSignature,html[data-nature-theme="true"] #lifeRouteThemeSignature{opacity:.10}
    html.lrInteractionBusy #lifeRouteThemeSignature::before,html.lrInteractionBusy #lifeRouteThemeSignature::after{animation-play-state:paused!important}
    @media(max-width:560px){.lrThemeChoiceGrid{grid-template-columns:1fr 1fr}.lrThemeChoice{grid-template-columns:29px 1fr auto;gap:7px;min-height:54px!important}.lrThemeChoiceSwatch{width:29px;height:29px}.lrThemeCategoryTabs{margin-bottom:9px}}
    @media(prefers-reduced-motion:reduce){#lifeRouteThemeSignature::before,#lifeRouteThemeSignature::after{animation:none!important}}
  `;
  document.head.appendChild(style);

  const swatches = {
    royal:['#377dff','#f2c86d'],obsidian:['#111318','#d6ad52'],carbon:['#2d3947','#bac5d1'],midnight:['#18204c','#7767ff'],'navy-noir':['#071a2d','#327fc4'],titanium:['#343a41','#d9e0e8'],ocean:['#07536f','#2dd5ef'],aurora:['#166c68','#5af0d4'],forest:['#164c35','#7fcf88'],plum:['#542b64','#d062eb'],ember:['#6a2c1e','#ef7847'],slate:['#354353','#96aec5'],mono:['#202226','#b9b9b9'],daylight:['#dbeaf7','#e9cb79'],
    'solar-flare':['#ff512c','#ffbf3f'],'electric-storm':['#00ddff','#7f42ff'],ultraviolet:['#6f2adb','#ff5fb8'],'molten-gold':['#a94d00','#ffe36a'],'arctic-pulse':['#4fe8dd','#8ba5ff'],'emerald-tempest':['#087e5a','#b9de56'],'rose-nebula':['#a533cc','#ff9468'],'royal-cosmos':['#635cff','#d492ff'],'sapphire-tide':['#006ee8','#52efd7'],'phantom-silver':['#4e6680','#eef5fb']
  };

  const sectionFor = category => {
    const sheet = document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet');
    if (!sheet) return [];
    const found = [];
    (category.ids || []).forEach(id => { const node = document.getElementById(id); if (node) found.push(node); });
    if (category.match) {
      [...sheet.querySelectorAll(':scope > .lrSettingsSection')].forEach(section => {
        const text = section.querySelector('.lrSettingsSectionHead b')?.textContent?.trim() || '';
        if (category.match.test(text)) found.push(section);
      });
    }
    return [...new Set(found)];
  };

  const allThemeSections = () => [...new Set(categories.flatMap(sectionFor))];

  const applyCategory = key => {
    activeCategory = categories.some(item => item.key === key) ? key : 'core';
    const active = categories.find(item => item.key === activeCategory);
    const wanted = new Set(sectionFor(active));
    allThemeSections().forEach(section => section.classList.toggle('lrThemeSectionHidden', !wanted.has(section)));
    document.querySelectorAll('.lrThemeCategoryTabs [data-lr-theme-category]').forEach(button => {
      const selected = button.dataset.lrThemeCategory === activeCategory;
      button.classList.toggle('active',selected);
      button.setAttribute('aria-selected',selected?'true':'false');
    });
    window.LifeRouteLiquidInteractionV4?.refresh?.();
  };

  const ensureCategoryTabs = sheet => {
    let host = document.getElementById('lifeRouteThemeCategoryTabsV4');
    if (!host) {
      host = document.createElement('div');
      host.id = 'lifeRouteThemeCategoryTabsV4';
      host.className = 'lrThemeCategoryTabs';
      host.setAttribute('role','tablist');
      host.setAttribute('aria-label','Theme category');
      host.innerHTML = categories.map(item => `<button type="button" role="tab" data-lr-theme-category="${item.key}">${item.label}</button>`).join('');
      const top = sheet.querySelector('.lrSettingsTop');
      if (top?.nextSibling) sheet.insertBefore(host,top.nextSibling); else sheet.prepend(host);
      host.querySelectorAll('[data-lr-theme-category]').forEach(button => button.addEventListener('click',()=>applyCategory(button.dataset.lrThemeCategory)));
    }
    return host;
  };

  const buildChoiceGrid = select => {
    if (!select || select.dataset.lrThemeChoices === '1') return;
    select.dataset.lrThemeChoices = '1';
    select.classList.add('lrThemeSourceSelect');
    const grid = document.createElement('div');
    grid.className = 'lrThemeChoiceGrid';
    grid.dataset.sourceSelect = select.id;
    [...select.options].filter(option => option.value).forEach(option => {
      const key = option.value;
      const pair = swatches[key] || ['#4d7fb8','#d8b662'];
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'lrThemeChoice';
      button.dataset.themeValue = key;
      button.style.setProperty('--swatch-a',pair[0]);
      button.style.setProperty('--swatch-b',pair[1]);
      button.innerHTML = `<span class="lrThemeChoiceSwatch" aria-hidden="true"></span><b>${option.textContent}</b><span class="lrThemeChoiceCheck">✓</span>`;
      button.addEventListener('click',()=>{
        if (select.value === key) return;
        select.value = key;
        select.dispatchEvent(new Event('change',{bubbles:true}));
        syncChoices();
      });
      grid.appendChild(button);
    });
    select.insertAdjacentElement('afterend',grid);
  };

  const syncChoices = () => {
    document.querySelectorAll('.lrThemeChoiceGrid').forEach(grid => {
      const select = document.getElementById(grid.dataset.sourceSelect || '');
      grid.querySelectorAll('.lrThemeChoice').forEach(button => button.classList.toggle('active',select?.value === button.dataset.themeValue));
    });
  };

  const activeCategoryForTheme = () => {
    if (document.documentElement.dataset.animalTheme) return 'creatures';
    if (document.documentElement.dataset.fluidScene) return 'fluid';
    if (document.documentElement.dataset.dynamicTheme) return 'dynamic';
    if (document.documentElement.dataset.natureTheme === 'true') return 'scene';
    const key = String(window.prefs?.theme || document.documentElement.dataset.theme || 'royal');
    return ['solar-flare','electric-storm','ultraviolet','molten-gold','arctic-pulse','emerald-tempest','rose-nebula','royal-cosmos','sapphire-tide','phantom-silver'].includes(key) ? 'metal' : 'core';
  };

  const ensureSignature = () => {
    if (document.getElementById('lifeRouteThemeSignature')) return;
    const node = document.createElement('div');
    node.id = 'lifeRouteThemeSignature';
    node.setAttribute('aria-hidden','true');
    document.body.prepend(node);
  };

  const normalize = () => {
    const sheet = document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet');
    if (!sheet) return false;
    ensureCategoryTabs(sheet);
    buildChoiceGrid(document.getElementById('lifeRouteCoreThemeSelect'));
    buildChoiceGrid(document.getElementById('lifeRouteMetallicWaveThemeSelect'));
    syncChoices();
    const overlay = document.getElementById('lifeRouteSettingsOverlay');
    const newlyOpened = overlay && !overlay.hidden && overlay.dataset.lrThemeOpenedV4 !== '1';
    if (newlyOpened) {
      overlay.dataset.lrThemeOpenedV4 = '1';
      activeCategory = activeCategoryForTheme();
    }
    if (overlay?.hidden) overlay.dataset.lrThemeOpenedV4 = '0';
    applyCategory(activeCategory);
    return true;
  };

  let queued = false;
  const queue = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(()=>{queued=false;normalize();});
  };

  document.addEventListener('click',event=>{
    if (event.target.closest?.('#lifeRouteSettingsButton,.lrThemeCard,.lrThemeChoice')) setTimeout(queue,0);
  },true);
  document.addEventListener('change',event=>{
    if (event.target?.matches?.('#lifeRouteCoreThemeSelect,#lifeRouteMetallicWaveThemeSelect')) setTimeout(queue,0);
  },true);

  const start = () => {
    ensureSignature();
    queue();
    const observer = new MutationObserver(queue);
    observer.observe(document.body,{childList:true,subtree:true});
    [180,520,1100].forEach(delay=>setTimeout(queue,delay));
  };

  window.LifeRouteThemeExperienceV4 = { normalize:queue, showCategory:applyCategory };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
