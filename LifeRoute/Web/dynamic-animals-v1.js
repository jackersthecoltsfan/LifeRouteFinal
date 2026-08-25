// Dynamic animal themes for LifeRoute Settings.
(() => {
  if (window.__lifeRouteDynamicAnimalsV1Loaded) return;
  window.__lifeRouteDynamicAnimalsV1Loaded = true;

  const STORE = "liferoute_dynamic_animal_v1";
  const THEMES = [
    ["moon-wolf","Moon Wolf","prowl","#020711","#294d78","#9bc9ff","#e8edf4"],
    ["storm-dragon","Storm Dragon","soar","#05020d","#5e34aa","#79b8ff","#f0c96b"],
    ["golden-eagle","Golden Eagle","soar","#0d0802","#9c6516","#ffd56e","#f6f0d2"],
    ["shadow-panther","Shadow Panther","prowl","#020305","#26313d","#8aa2bc","#d7e4ee"],
    ["ember-fox","Ember Fox","prowl","#100401","#b9441f","#ff9652","#ffd18a"],
    ["night-owl","Night Owl","pulse","#02050d","#304b7c","#99b8ff","#d9c8ff"],
    ["cosmic-whale","Cosmic Whale","glide","#020817","#086f9f","#59d9ee","#a78cff"],
    ["silver-stag","Silver Stag","pulse","#040708","#496457","#c3ddcf","#f0e7bd"],
    ["midnight-horse","Midnight Horse","glide","#03050b","#324a75","#86a8e7","#e3d09a"],
    ["aurora-raven","Aurora Raven","soar","#010506","#0e776b","#5be1c0","#8d75ff"]
  ];
  const MAP = Object.fromEntries(THEMES.map(theme => [theme[0], theme]));

  const SHAPES = {
    "moon-wolf": '<path d="M50 9 62 27 80 18 74 47c-2 22-12 35-24 43-12-8-22-21-24-43L20 18l18 9L50 9Zm-18 39 11 5-8 5m33-10-11 5 8 5M42 69h16l-8 8-8-8Z"/>',
    "storm-dragon": '<path d="M18 66c14-7 20-18 24-30L28 22l20 7 6-17 7 17 18-8-12 17c8 7 13 17 15 30-11-9-20-12-27-9-9 4-17 5-37 7Zm34-31 10 4-8 6-2-10Z"/>',
    "golden-eagle": '<path d="M8 49c17-16 31-19 42-11 11-8 25-5 42 11-14-5-25-4-34 3l-8 28-8-28c-9-7-20-8-34-3Zm42-22 8 8-8 7-8-7 8-8Z"/>',
    "shadow-panther": '<path d="M13 58c14-16 29-21 47-15l17-8 11 5-12 8c5 5 8 10 10 16-10-4-20-5-28-2-16 6-29 5-45-4Zm22 1-9 19h9l8-17m20-1 8 19h9L73 56Z"/>',
    "ember-fox": '<path d="M50 13 64 30l20-9-8 28c-4 18-13 30-26 38-13-8-22-20-26-38l-8-28 20 9 14-17Zm-18 39 12 3-9 7m33-10-12 3 9 7M40 70h20L50 79 40 70Z"/>',
    "night-owl": '<path d="M24 25 41 35 50 18l9 17 17-10-4 24c4 18-4 33-22 42-18-9-26-24-22-42l-4-24Zm10 27 12-7-2 15-10-8Zm32 0-12-7 2 15 10-8ZM45 67h10l-5 8-5-8Z"/>',
    "cosmic-whale": '<path d="M10 55c14-18 34-25 56-20 9 2 15 7 19 15l10-8-3 14 3 13-12-7c-8 12-22 18-40 16-16-2-27-10-33-23Zm28-4 5 3-5 3v-6Z"/>',
    "silver-stag": '<path d="M43 88c-7-13-9-27-4-39L28 35l-12 4 10-12-7-13 15 10 6-15 5 20h10l5-20 6 15 15-10-7 13 10 12-12-4-11 14c5 12 3 26-4 39H43Zm0-40 7 8 7-8-7-8-7 8Z"/>',
    "midnight-horse": '<path d="M31 86c6-18 7-33 3-46l9-27 18 8 13 19-8 18-13 5 7 23H31Zm14-51 14 3-4 8-12-2 2-9Z"/>',
    "aurora-raven": '<path d="M12 60c13-18 26-26 39-22 9-10 21-15 37-13-12 7-19 15-22 24 8 5 13 13 16 24-12-8-23-10-32-5-13 7-25 4-38-8Zm39-22 7 5-8 5 1-10Z"/>'
  };

  const svgFor = (key, className = "") => `<svg class="${className}" viewBox="0 0 100 100" aria-hidden="true" focusable="false">${SHAPES[key] || SHAPES["moon-wolf"]}</svg>`;

  const style = document.createElement("style");
  style.id = "lifeRouteDynamicAnimalsV1Styles";
  style.textContent = `
    #lifeRouteAnimalBackdrop{position:fixed;inset:-10%;z-index:0;display:none;pointer-events:none;overflow:hidden;background:radial-gradient(circle at 50% 10%,color-mix(in srgb,var(--animal-c) 22%,transparent),transparent 34%),linear-gradient(150deg,var(--animal-a),color-mix(in srgb,var(--animal-b) 34%,#010204));transform:translateZ(0)}
    html[data-animal-theme] #lifeRouteAnimalBackdrop{display:block}html[data-animal-theme] body{background:transparent!important}html[data-animal-theme] .app{position:relative;z-index:2}html[data-animal-theme] #lifeRouteMetalBackdrop,html[data-animal-theme] #lifeRouteThemeFX,html[data-animal-theme] #lifeRouteNatureBackdrop,html[data-animal-theme] #lifeRouteDynamicBackdrop,html[data-animal-theme] #lifeRouteFluidBackdrop{display:none!important}
    html[data-animal-theme] .bottom{z-index:8!important;background:color-mix(in srgb,var(--animal-a) 58%,transparent)!important}html[data-animal-theme] .card,html[data-animal-theme] .metric,html[data-animal-theme] .hero,html[data-animal-theme] .provider,html[data-animal-theme] .notice{background-color:color-mix(in srgb,var(--panel) 72%,transparent)!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    .lrAnimalGlow{position:absolute;inset:-20%;background:conic-gradient(from 10deg,transparent 0 18%,color-mix(in srgb,var(--animal-b) 40%,transparent) 25%,transparent 39%,color-mix(in srgb,var(--animal-c) 32%,transparent) 52%,transparent 68%,color-mix(in srgb,var(--animal-d) 24%,transparent) 78%,transparent 90%);filter:blur(48px);opacity:.7;animation:lrAnimalGlow 16s linear infinite}
    .lrAnimalHero,.lrAnimalGhost{position:absolute;color:color-mix(in srgb,var(--animal-d) 88%,var(--animal-c));filter:drop-shadow(0 0 28px color-mix(in srgb,var(--animal-c) 52%,transparent));will-change:transform,opacity}.lrAnimalHero{width:min(68vw,620px);right:-7%;top:13%;opacity:.23;animation:lrAnimalSoar 12s ease-in-out infinite alternate}.lrAnimalGhost{width:min(42vw,360px);left:-8%;bottom:7%;opacity:.11;transform:scaleX(-1);animation:lrAnimalProwl 9s ease-in-out infinite alternate}.lrAnimalHero svg,.lrAnimalGhost svg{display:block;width:100%;height:auto;fill:currentColor}
    html[data-animal-motion="prowl"] .lrAnimalHero{animation:lrAnimalProwl 10s ease-in-out infinite alternate}html[data-animal-motion="prowl"] .lrAnimalGhost{animation-duration:7s}
    html[data-animal-motion="glide"] .lrAnimalHero{animation:lrAnimalGlide 15s ease-in-out infinite alternate}html[data-animal-motion="pulse"] .lrAnimalHero{animation:lrAnimalPulse 7s ease-in-out infinite alternate}
    .lrAnimalPreview{position:absolute;inset:0;overflow:hidden;background:radial-gradient(circle at 72% 18%,color-mix(in srgb,var(--ac) 34%,transparent),transparent 36%),linear-gradient(145deg,var(--aa),color-mix(in srgb,var(--ab) 45%,#010204))}.lrAnimalPreview svg{position:absolute;width:82%;height:82%;right:-10%;bottom:-9%;fill:color-mix(in srgb,var(--ad) 86%,var(--ac));opacity:.67;filter:drop-shadow(0 0 12px color-mix(in srgb,var(--ac) 60%,transparent));animation:lrAnimalPreviewMove 4.8s ease-in-out infinite alternate}.lrAnimalPreview:after{content:"";position:absolute;inset:-50%;background:conic-gradient(from 20deg,transparent,var(--ab),transparent 35%,var(--ac),transparent 65%);filter:blur(16px);opacity:.32;animation:lrAnimalGlow 10s linear infinite}
    @keyframes lrAnimalGlow{to{transform:rotate(360deg) scale(1.08)}}@keyframes lrAnimalSoar{from{transform:translate3d(-8%,8%,0) rotate(-5deg) scale(.9)}to{transform:translate3d(10%,-8%,0) rotate(7deg) scale(1.12)}}@keyframes lrAnimalProwl{from{transform:translate3d(-12%,2%,0) scale(.92)}to{transform:translate3d(18%,-2%,0) scale(1.08)}}@keyframes lrAnimalGlide{from{transform:translate3d(-14%,5%,0) rotate(-2deg) scale(.94)}to{transform:translate3d(12%,-4%,0) rotate(3deg) scale(1.07)}}@keyframes lrAnimalPulse{from{transform:scale(.88) rotate(-3deg);opacity:.16}to{transform:scale(1.12) rotate(3deg);opacity:.3}}@keyframes lrAnimalPreviewMove{to{transform:translate3d(-8%,-7%,0) rotate(5deg) scale(1.08)}}
    @media(prefers-reduced-motion:reduce){.lrAnimalGlow,.lrAnimalHero,.lrAnimalGhost,.lrAnimalPreview svg,.lrAnimalPreview:after{animation:none!important}}
  `;
  document.head.appendChild(style);

  let backdrop = document.getElementById("lifeRouteAnimalBackdrop");
  if (!backdrop) {
    backdrop = document.createElement("div");
    backdrop.id = "lifeRouteAnimalBackdrop";
    backdrop.setAttribute("aria-hidden", "true");
    backdrop.innerHTML = '<div class="lrAnimalGlow"></div><div class="lrAnimalHero"></div><div class="lrAnimalGhost"></div>';
    document.body.prepend(backdrop);
  }

  const clearAnimals = (clearStored = true) => {
    const root = document.documentElement;
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
    ["--animal-a","--animal-b","--animal-c","--animal-d"].forEach(name => root.style.removeProperty(name));
    if (clearStored) { try { localStorage.removeItem(STORE); } catch (_) {} }
    document.querySelectorAll(".lrAnimalThemeCard").forEach(card => { card.classList.remove("active"); card.setAttribute("aria-pressed", "false"); });
  };

  const clearOtherThemes = () => {
    const root = document.documentElement;
    try { window.LifeRouteDynamicThemes?.clear?.(true); } catch (_) {}
    try { window.LifeRouteFluidScenes?.clear?.(true); } catch (_) {}
    root.removeAttribute("data-nature-theme");
    root.removeAttribute("data-scene");
    root.removeAttribute("data-photo-scene");
    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.removeAttribute("data-fluid-scene");
    try {
      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
      localStorage.removeItem("liferoute_fluid_scene_v1");
    } catch (_) {}
  };

  const applyAnimal = key => {
    const theme = MAP[key];
    if (!theme) return;
    clearOtherThemes();
    clearAnimals(false);
    const [id,,motion,a,b,c,d] = theme;
    const root = document.documentElement;
    try { window.setTheme?.("royal"); } catch (_) {}
    root.dataset.animalTheme = id;
    root.dataset.animalMotion = motion;
    root.style.setProperty("--animal-a", a);
    root.style.setProperty("--animal-b", b);
    root.style.setProperty("--animal-c", c);
    root.style.setProperty("--animal-d", d);
    backdrop.querySelector(".lrAnimalHero").innerHTML = svgFor(id);
    backdrop.querySelector(".lrAnimalGhost").innerHTML = svgFor(id);
    try { localStorage.setItem(STORE, id); } catch (_) {}
    document.querySelectorAll(".lrThemeCard").forEach(card => {
      const active = card.dataset.animalKey === id;
      card.classList.toggle("active", active);
      if (card.classList.contains("lrAnimalThemeCard")) card.setAttribute("aria-pressed", active ? "true" : "false");
    });
  };

  const installSection = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    if (document.getElementById("lifeRouteDynamicAnimalSection")) return true;
    const section = document.createElement("div");
    section.id = "lifeRouteDynamicAnimalSection";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Dynamic Animals</b><span>10 living motion scenes</span></div><div class="lrThemeGrid">${THEMES.map(([key,name,,a,b,c,d]) => `<button type="button" class="lrThemeCard lrAnimalThemeCard" data-animal-key="${key}" aria-pressed="false"><span class="lrAnimalPreview" style="--aa:${a};--ab:${b};--ac:${c};--ad:${d}">${svgFor(key, "lrAnimalPreviewSVG")}</span><span class="lrThemeName">${name}</span></button>`).join("")}</div>`;
    const fluid = document.getElementById("lifeRouteFluidSceneSection");
    if (fluid) fluid.after(section); else sheet.appendChild(section);
    section.querySelectorAll("[data-animal-key]").forEach(card => card.addEventListener("click", () => applyAnimal(card.dataset.animalKey)));
    const saved = (() => { try { return localStorage.getItem(STORE) || ""; } catch (_) { return ""; } })();
    if (MAP[saved]) applyAnimal(saved);
    return true;
  };

  document.addEventListener("click", event => {
    const card = event.target.closest?.(".lrThemeCard");
    if (card && !card.classList.contains("lrAnimalThemeCard")) clearAnimals(true);
  }, true);
  document.addEventListener("change", event => {
    if (event.target?.matches?.("#lifeRouteClassicThemeSelect,#lifeRouteMetallicWaveThemeSelect,#lifeRouteCoreThemeSelect,#themeSelect")) clearAnimals(true);
  }, true);

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 120) clearInterval(timer);
  }, 100);

  window.LifeRouteDynamicAnimals = { themes: THEMES.map(theme => ({ key: theme[0], name: theme[1], motion: theme[2] })), apply: applyAnimal, clear: clearAnimals };
})();
