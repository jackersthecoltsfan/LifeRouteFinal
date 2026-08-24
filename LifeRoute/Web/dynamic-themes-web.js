// Premium animated abstract themes for LifeRoute Settings.
(() => {
  if (window.__lifeRouteDynamicThemesLoaded) return;
  window.__lifeRouteDynamicThemesLoaded = true;

  const STORAGE_KEY = "liferoute_dynamic_theme_v1";
  const THEMES = [
    ["celestial-silk","Celestial Silk","silk","#050716","#5367ff","#d895ff","#f4c86d"],
    ["obsidian-prism","Obsidian Prism","prism","#020305","#59616f","#dce5ef","#b68cff"],
    ["liquid-sapphire","Liquid Sapphire","liquid","#020817","#0d65c8","#55d9ff","#d9c675"],
    ["royal-velvet","Royal Velvet","silk","#090413","#6a28a8","#d65ea7","#e8c776"],
    ["platinum-orbit","Platinum Orbit","halo","#05070b","#6f839b","#f1f4f7","#9fb8ff"],
    ["emerald-glass","Emerald Glass","liquid","#020b08","#087a58","#59e6b0","#d4ca77"],
    ["midnight-champagne","Midnight Champagne","halo","#070609","#8e6b38","#f5dca1","#8472d8"],
    ["violet-current","Violet Current","silk","#070312","#6236d7","#dd6fff","#66d9ff"],
    ["black-diamond","Black Diamond","prism","#010203","#253242","#bcd8f2","#ffffff"],
    ["ruby-motion","Ruby Motion","liquid","#0d0205","#a8153c","#ff6387","#f0bd70"],
    ["aether-rings","Aether Rings","halo","#02070d","#16789e","#83efff","#a289ff"],
    ["gilded-vortex","Gilded Vortex","prism","#080603","#9b6819","#ffe283","#ffffff"],
    ["polar-chrome","Polar Chrome","lattice","#02070b","#207f9c","#c9f6ff","#a4bad2"],
    ["nebula-luxe","Nebula Luxe","liquid","#080312","#7736a9","#ff62b5","#5c85ff"],
    ["jade-kinetic","Jade Kinetic","lattice","#020806","#177857","#99e2bd","#d5be72"],
    ["cobalt-fold","Cobalt Fold","silk","#020617","#174fa8","#688dff","#d8e4ff"],
    ["rose-gold-flow","Rose Gold Flow","silk","#0d0608","#a85363","#f4b3a3","#e7c177"],
    ["cosmic-porcelain","Cosmic Porcelain","halo","#070a12","#6979b5","#e5e8ff","#d3a9ff"],
    ["onyx-aurora","Onyx Aurora","lattice","#010405","#166a63","#5ee8cd","#9a74ff"],
    ["imperial-flux","Imperial Flux","prism","#07030d","#6334b5","#e55fa9","#f5cd72"]
  ];
  const MAP = Object.fromEntries(THEMES.map(t => [t[0], t]));

  const style = document.createElement("style");
  style.id = "lifeRouteDynamicThemeStyles";
  style.textContent = `
    #lifeRouteDynamicBackdrop{position:fixed;inset:-8%;z-index:0;pointer-events:none;overflow:hidden;display:none;background:
      radial-gradient(circle at 14% 12%,color-mix(in srgb,var(--dyn-b) 28%,transparent),transparent 30%),
      radial-gradient(circle at 88% 24%,color-mix(in srgb,var(--dyn-c) 20%,transparent),transparent 32%),
      linear-gradient(145deg,var(--dyn-a),color-mix(in srgb,var(--dyn-a) 78%,#000) 58%,#010204);transform:translateZ(0)}
    html[data-dynamic-theme] #lifeRouteDynamicBackdrop{display:block}
    html[data-dynamic-theme] #lifeRouteMetalBackdrop,html[data-dynamic-theme] #lifeRouteThemeFX,html[data-dynamic-theme] #lifeRouteNatureBackdrop{display:none!important}
    html[data-dynamic-theme] body{background:transparent!important}
    html[data-dynamic-theme] .app{position:relative;z-index:2}
    html[data-dynamic-theme] .bottom{z-index:8!important;background:color-mix(in srgb,var(--dyn-a) 58%,transparent)!important}
    html[data-dynamic-theme] .card,html[data-dynamic-theme] .metric,html[data-dynamic-theme] .hero,html[data-dynamic-theme] .provider,html[data-dynamic-theme] .notice{background-color:color-mix(in srgb,var(--panel) 73%,transparent)!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    .dynLayer{position:absolute;inset:-35%;will-change:transform,opacity;transform-origin:50% 50%;filter:blur(38px);opacity:.56}
    .dynA{background:conic-gradient(from 45deg at 50% 50%,transparent 0 12%,var(--dyn-b) 19%,transparent 31%,var(--dyn-c) 46%,transparent 60%,var(--dyn-d) 76%,transparent 88%);animation:lrDynRotate 34s linear infinite}
    .dynB{inset:-20%;background:radial-gradient(ellipse at 28% 38%,color-mix(in srgb,var(--dyn-c) 76%,transparent) 0 9%,transparent 35%),radial-gradient(ellipse at 70% 62%,color-mix(in srgb,var(--dyn-b) 72%,transparent) 0 8%,transparent 38%);animation:lrDynDrift 18s ease-in-out infinite alternate;mix-blend-mode:screen;opacity:.42}
    .dynC{inset:-16%;background:linear-gradient(112deg,transparent 18%,color-mix(in srgb,var(--dyn-d) 42%,transparent) 37%,transparent 52%,color-mix(in srgb,var(--dyn-c) 33%,transparent) 69%,transparent 82%);animation:lrDynSweep 14s ease-in-out infinite alternate;mix-blend-mode:soft-light;opacity:.7}
    html[data-dynamic-motion="silk"] .dynA{filter:blur(52px);transform:scale(1.18);animation-duration:42s}html[data-dynamic-motion="silk"] .dynC{filter:blur(24px);background:linear-gradient(124deg,transparent 12%,color-mix(in srgb,var(--dyn-b) 48%,transparent) 28%,transparent 42%,color-mix(in srgb,var(--dyn-c) 45%,transparent) 58%,transparent 72%,color-mix(in srgb,var(--dyn-d) 35%,transparent) 84%,transparent)}
    html[data-dynamic-motion="liquid"] .dynA{border-radius:46%;filter:blur(68px);animation:lrDynLiquid 21s ease-in-out infinite alternate}html[data-dynamic-motion="liquid"] .dynB{filter:blur(52px);animation-duration:13s}
    html[data-dynamic-motion="prism"] .dynA{filter:blur(22px);opacity:.44;background:conic-gradient(from 0deg at 48% 52%,transparent 0 8%,var(--dyn-b) 14%,transparent 24%,var(--dyn-c) 34%,transparent 48%,var(--dyn-d) 57%,transparent 69%,var(--dyn-b) 79%,transparent 92%)}html[data-dynamic-motion="prism"] .dynC{filter:blur(12px);opacity:.44}
    html[data-dynamic-motion="halo"] .dynA{inset:-12%;filter:blur(28px);background:repeating-radial-gradient(circle at 52% 49%,transparent 0 9%,color-mix(in srgb,var(--dyn-b) 28%,transparent) 11% 13%,transparent 16% 24%,color-mix(in srgb,var(--dyn-c) 25%,transparent) 26% 28%,transparent 31% 38%);animation:lrDynHalo 18s ease-in-out infinite alternate}html[data-dynamic-motion="halo"] .dynB{animation-duration:25s}
    html[data-dynamic-motion="lattice"] .dynA{filter:blur(18px);opacity:.32;background:repeating-linear-gradient(52deg,transparent 0 7%,color-mix(in srgb,var(--dyn-b) 30%,transparent) 8% 9%,transparent 10% 18%),repeating-linear-gradient(-42deg,transparent 0 10%,color-mix(in srgb,var(--dyn-c) 24%,transparent) 11% 12%,transparent 13% 21%);animation:lrDynLattice 26s linear infinite}
    .lrDynamicPreview{position:absolute;inset:0;overflow:hidden;background:linear-gradient(145deg,var(--da),color-mix(in srgb,var(--db) 35%,#020306))}.lrDynamicPreview:before{content:"";position:absolute;inset:-45%;background:conic-gradient(from 20deg,transparent,var(--db),transparent 28%,var(--dc),transparent 55%,var(--dd),transparent 80%);filter:blur(14px);opacity:.68;animation:lrDynRotate 13s linear infinite}.lrDynamicPreview:after{content:"";position:absolute;inset:0;background:linear-gradient(120deg,transparent 28%,rgba(255,255,255,.18) 45%,transparent 61%);animation:lrDynCardSweep 5.5s ease-in-out infinite alternate}
    @keyframes lrDynRotate{to{transform:rotate(360deg) scale(1.06)}}
    @keyframes lrDynDrift{from{transform:translate3d(-9%,-7%,0) scale(.9) rotate(-5deg)}to{transform:translate3d(10%,8%,0) scale(1.14) rotate(7deg)}}
    @keyframes lrDynSweep{from{transform:translate3d(-10%,-6%,0) rotate(-6deg) scale(1)}to{transform:translate3d(12%,9%,0) rotate(8deg) scale(1.12)}}
    @keyframes lrDynLiquid{from{transform:translate3d(-8%,4%,0) rotate(-10deg) scale(.88,1.08)}to{transform:translate3d(9%,-5%,0) rotate(12deg) scale(1.12,.9)}}
    @keyframes lrDynHalo{from{transform:scale(.88) rotate(-8deg);opacity:.42}to{transform:scale(1.18) rotate(9deg);opacity:.7}}
    @keyframes lrDynLattice{from{transform:translate3d(-5%,-4%,0) rotate(0)}to{transform:translate3d(7%,5%,0) rotate(8deg)}}
    @keyframes lrDynCardSweep{from{transform:translateX(-35%)}to{transform:translateX(35%)}}
    @media(prefers-reduced-motion:reduce){.dynLayer,.lrDynamicPreview:before,.lrDynamicPreview:after{animation:none!important}}
  `;
  document.head.appendChild(style);

  let backdrop = document.getElementById("lifeRouteDynamicBackdrop");
  if (!backdrop) {
    backdrop = document.createElement("div");
    backdrop.id = "lifeRouteDynamicBackdrop";
    backdrop.setAttribute("aria-hidden","true");
    backdrop.innerHTML = '<div class="dynLayer dynA"></div><div class="dynLayer dynB"></div><div class="dynLayer dynC"></div>';
    document.body.prepend(backdrop);
  }

  const clearNatureState = () => {
    const root = document.documentElement;
    root.removeAttribute("data-nature-theme");
    root.removeAttribute("data-scene");
    root.removeAttribute("data-photo-scene");
    ["--scene-sky1","--scene-sky2","--scene-ground","--scene-land","--scene-accent"].forEach(name => root.style.removeProperty(name));
    try { localStorage.removeItem("liferoute_nature_theme_v1"); } catch (_) {}
  };

  const clearDynamic = (clearStored = true) => {
    const root = document.documentElement;
    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    ["--dyn-a","--dyn-b","--dyn-c","--dyn-d"].forEach(name => root.style.removeProperty(name));
    if (clearStored) { try { localStorage.removeItem(STORAGE_KEY); } catch (_) {} }
    document.querySelectorAll(".lrDynamicThemeCard").forEach(card => card.classList.remove("active"));
  };

  const applyDynamic = key => {
    const theme = MAP[key];
    if (!theme) return;
    clearNatureState();
    clearDynamic(false);
    const [id,,motion,a,b,c,d] = theme;
    const root = document.documentElement;
    try { window.setTheme?.("royal"); } catch (_) { root.dataset.theme = ""; }
    root.dataset.dynamicTheme = id;
    root.dataset.dynamicMotion = motion;
    root.style.setProperty("--dyn-a",a);
    root.style.setProperty("--dyn-b",b);
    root.style.setProperty("--dyn-c",c);
    root.style.setProperty("--dyn-d",d);
    try { localStorage.setItem(STORAGE_KEY,id); } catch (_) {}
    document.querySelectorAll(".lrThemeCard,.lrDynamicThemeCard").forEach(card => card.classList.toggle("active", card.dataset.dynamicKey === id));
  };

  const relabelScenery = sheet => {
    sheet.querySelectorAll(".lrSettingsSectionHead b").forEach(label => {
      if (/^nature scenery$/i.test(label.textContent.trim())) label.textContent = "Scenery";
    });
  };

  const installSection = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    relabelScenery(sheet);
    if (document.getElementById("lifeRouteDynamicThemeSection")) return true;
    const scenerySection = [...sheet.querySelectorAll(".lrSettingsSection")].find(section => /scenery/i.test(section.querySelector(".lrSettingsSectionHead b")?.textContent || ""));
    const section = document.createElement("div");
    section.id = "lifeRouteDynamicThemeSection";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Dynamic</b><span>20 premium moving designs</span></div><div class="lrThemeGrid">${THEMES.map(([key,name,,a,b,c,d]) => `<button type="button" class="lrThemeCard lrDynamicThemeCard" data-dynamic-key="${key}"><span class="lrDynamicPreview" style="--da:${a};--db:${b};--dc:${c};--dd:${d}"></span><span class="lrThemeName">${name}</span></button>`).join("")}</div>`;
    if (scenerySection) sheet.insertBefore(section, scenerySection); else sheet.appendChild(section);
    section.querySelectorAll("[data-dynamic-key]").forEach(card => card.addEventListener("click", () => applyDynamic(card.dataset.dynamicKey)));
    const saved = (() => { try { return localStorage.getItem(STORAGE_KEY) || ""; } catch (_) { return ""; } })();
    if (MAP[saved]) applyDynamic(saved);
    return true;
  };

  document.addEventListener("click", event => {
    const natureCard = event.target.closest?.(".lrThemeCard[data-theme-key]");
    if (natureCard && !natureCard.classList.contains("lrDynamicThemeCard")) clearDynamic(true);
  }, true);
  document.addEventListener("change", event => {
    if (event.target?.id === "lifeRouteClassicThemeSelect" || event.target?.id === "lifeRouteMetallicWaveThemeSelect" || event.target?.id === "lifeRouteCoreThemeSelect") clearDynamic(true);
  }, true);

  window.LifeRouteDynamicThemes = { themes: THEMES.map(t => ({key:t[0],name:t[1],motion:t[2]})), apply: applyDynamic, clear: clearDynamic };

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 100) clearInterval(timer);
  }, 100);
})();
