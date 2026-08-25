// High-motion fluid screensaver themes for LifeRoute.
(() => {
  if (window.__lifeRouteFluidScenesV1Loaded) return;
  window.__lifeRouteFluidScenesV1Loaded = true;

  const STORE = "liferoute_fluid_scene_v1";
  const SCENES = [
    ["mercury-flow","Mercury Flow","#030507","#a8bdd2","#eef7ff","#5f7d9f"],
    ["cobalt-plasma","Cobalt Plasma","#020817","#1268e8","#63dcff","#6857ff"],
    ["aurora-ink","Aurora Ink","#020b0c","#18d6b1","#73f6e0","#6b57ff"],
    ["gold-current","Gold Current","#0b0702","#d48a16","#ffe17c","#fff3c2"],
    ["violet-melt","Violet Melt","#090311","#7838e8","#ea66ff","#4cbcff"],
    ["emerald-tide","Emerald Tide","#020b07","#0b9b63","#6af2b4","#d9d56d"],
    ["solar-fluid","Solar Fluid","#100402","#ef4b22","#ffb72f","#ffe37d"],
    ["arctic-glass","Arctic Glass","#020b12","#3ca7d8","#bff7ff","#8b9fff"]
  ];
  const MAP = Object.fromEntries(SCENES.map(scene => [scene[0], scene]));

  const style = document.createElement("style");
  style.id = "lifeRouteFluidScenesV1Styles";
  style.textContent = `
    #lifeRouteFluidBackdrop{position:fixed;inset:-12%;z-index:0;display:none;pointer-events:none;overflow:hidden;background:linear-gradient(145deg,var(--fluid-a),#010204);transform:translateZ(0)}
    html[data-fluid-scene] #lifeRouteFluidBackdrop{display:block}html[data-fluid-scene] body{background:transparent!important}html[data-fluid-scene] .app{position:relative;z-index:2}html[data-fluid-scene] #lifeRouteMetalBackdrop,html[data-fluid-scene] #lifeRouteThemeFX,html[data-fluid-scene] #lifeRouteNatureBackdrop,html[data-fluid-scene] #lifeRouteDynamicBackdrop{display:none!important}
    html[data-fluid-scene] .bottom{z-index:8!important;background:color-mix(in srgb,var(--fluid-a) 55%,transparent)!important}html[data-fluid-scene] .card,html[data-fluid-scene] .metric,html[data-fluid-scene] .hero,html[data-fluid-scene] .provider,html[data-fluid-scene] .notice{background-color:color-mix(in srgb,var(--panel) 70%,transparent)!important;backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
    .lrFluidBlob{position:absolute;width:72vmax;height:72vmax;border-radius:44% 56% 58% 42%/44% 40% 60% 56%;filter:blur(48px);opacity:.62;will-change:transform,border-radius;mix-blend-mode:screen}.lrFluidOne{left:-22%;top:-25%;background:radial-gradient(circle at 35% 35%,var(--fluid-c),var(--fluid-b) 46%,transparent 70%);animation:lrFluidMorphA 9s ease-in-out infinite alternate}.lrFluidTwo{right:-28%;top:8%;background:radial-gradient(circle at 52% 38%,var(--fluid-d),var(--fluid-b) 48%,transparent 70%);animation:lrFluidMorphB 11s ease-in-out infinite alternate}.lrFluidThree{left:8%;bottom:-35%;background:conic-gradient(from 30deg,var(--fluid-b),var(--fluid-c),var(--fluid-d),var(--fluid-b));animation:lrFluidSpin 14s linear infinite;opacity:.44}.lrFluidWave{position:absolute;inset:-25%;background:repeating-radial-gradient(ellipse at 50% 50%,transparent 0 7%,color-mix(in srgb,var(--fluid-c) 18%,transparent) 8% 10%,transparent 11% 18%);filter:blur(8px);opacity:.5;animation:lrFluidPulse 6.5s ease-in-out infinite alternate}
    .lrFluidPreview{position:absolute;inset:0;overflow:hidden;background:linear-gradient(145deg,var(--fa),#010204)}.lrFluidPreview:before{content:"";position:absolute;width:140%;height:140%;left:-50%;top:-45%;border-radius:43% 57% 55% 45%;background:radial-gradient(circle at 40% 35%,var(--fc),var(--fb) 48%,transparent 72%);filter:blur(10px);animation:lrFluidPreviewA 3.8s ease-in-out infinite alternate}.lrFluidPreview:after{content:"";position:absolute;width:130%;height:130%;right:-48%;bottom:-55%;border-radius:60% 40% 45% 55%;background:radial-gradient(circle at 55% 45%,var(--fd),var(--fb) 48%,transparent 72%);filter:blur(12px);animation:lrFluidPreviewB 4.6s ease-in-out infinite alternate;mix-blend-mode:screen}
    @keyframes lrFluidMorphA{0%{transform:translate3d(-4%,-5%,0) scale(.88) rotate(-8deg);border-radius:44% 56% 58% 42%/44% 40% 60% 56%}100%{transform:translate3d(25%,18%,0) scale(1.18) rotate(28deg);border-radius:62% 38% 42% 58%/34% 62% 38% 66%}}
    @keyframes lrFluidMorphB{0%{transform:translate3d(8%,-12%,0) scale(1.08) rotate(10deg)}100%{transform:translate3d(-28%,20%,0) scale(.9) rotate(-24deg)}}@keyframes lrFluidSpin{to{transform:rotate(360deg) scale(1.08)}}@keyframes lrFluidPulse{from{transform:scale(.78) rotate(-7deg);opacity:.28}to{transform:scale(1.18) rotate(9deg);opacity:.58}}@keyframes lrFluidPreviewA{to{transform:translate3d(28%,20%,0) rotate(30deg) scale(1.18)}}@keyframes lrFluidPreviewB{to{transform:translate3d(-22%,-24%,0) rotate(-25deg) scale(.86)}}
    @media(prefers-reduced-motion:reduce){.lrFluidBlob,.lrFluidWave,.lrFluidPreview:before,.lrFluidPreview:after{animation:none!important}}
  `;
  document.head.appendChild(style);

  let backdrop = document.getElementById("lifeRouteFluidBackdrop");
  if (!backdrop) {
    backdrop = document.createElement("div");
    backdrop.id = "lifeRouteFluidBackdrop";
    backdrop.setAttribute("aria-hidden", "true");
    backdrop.innerHTML = '<div class="lrFluidBlob lrFluidOne"></div><div class="lrFluidBlob lrFluidTwo"></div><div class="lrFluidBlob lrFluidThree"></div><div class="lrFluidWave"></div>';
    document.body.prepend(backdrop);
  }

  const clearFluid = (clearStored = true) => {
    const root = document.documentElement;
    root.removeAttribute("data-fluid-scene");
    ["--fluid-a","--fluid-b","--fluid-c","--fluid-d"].forEach(name => root.style.removeProperty(name));
    if (clearStored) { try { localStorage.removeItem(STORE); } catch (_) {} }
    document.querySelectorAll(".lrFluidSceneCard").forEach(card => card.classList.remove("active"));
  };

  const clearOtherSceneState = () => {
    const root = document.documentElement;
    root.removeAttribute("data-nature-theme");
    root.removeAttribute("data-scene");
    root.removeAttribute("data-photo-scene");
    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    try {
      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
    } catch (_) {}
  };

  const applyFluid = key => {
    const scene = MAP[key];
    if (!scene) return;
    clearOtherSceneState();
    clearFluid(false);
    const [id,,a,b,c,d] = scene;
    const root = document.documentElement;
    try { window.setTheme?.("royal"); } catch (_) {}
    root.dataset.fluidScene = id;
    root.style.setProperty("--fluid-a", a);
    root.style.setProperty("--fluid-b", b);
    root.style.setProperty("--fluid-c", c);
    root.style.setProperty("--fluid-d", d);
    try { localStorage.setItem(STORE, id); } catch (_) {}
    document.querySelectorAll(".lrThemeCard").forEach(card => card.classList.toggle("active", card.dataset.fluidKey === id));
  };

  const installSection = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    if (document.getElementById("lifeRouteFluidSceneSection")) return true;
    const section = document.createElement("div");
    section.id = "lifeRouteFluidSceneSection";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Fluid Motion</b><span>high-motion screensaver scenes</span></div><div class="lrThemeGrid">${SCENES.map(([key,name,a,b,c,d]) => `<button type="button" class="lrThemeCard lrFluidSceneCard" data-fluid-key="${key}"><span class="lrFluidPreview" style="--fa:${a};--fb:${b};--fc:${c};--fd:${d}"></span><span class="lrThemeName">${name}</span></button>`).join("")}</div>`;
    const dynamic = document.getElementById("lifeRouteDynamicThemeSection");
    if (dynamic) dynamic.after(section); else sheet.appendChild(section);
    section.querySelectorAll("[data-fluid-key]").forEach(card => card.addEventListener("click", () => applyFluid(card.dataset.fluidKey)));
    const saved = (() => { try { return localStorage.getItem(STORE) || ""; } catch (_) { return ""; } })();
    if (MAP[saved]) applyFluid(saved);
    return true;
  };

  document.addEventListener("click", event => {
    const themeCard = event.target.closest?.(".lrThemeCard");
    if (themeCard && !themeCard.classList.contains("lrFluidSceneCard")) clearFluid(true);
  }, true);
  document.addEventListener("change", event => {
    if (event.target?.matches?.("#lifeRouteClassicThemeSelect,#lifeRouteMetallicWaveThemeSelect,#lifeRouteCoreThemeSelect,#themeSelect")) clearFluid(true);
  }, true);

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 100) clearInterval(timer);
  }, 100);
  window.LifeRouteFluidScenes = { scenes: SCENES.map(scene => ({ key: scene[0], name: scene[1] })), apply: applyFluid, clear: clearFluid };
})();
