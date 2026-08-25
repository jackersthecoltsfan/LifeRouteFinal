// Realistic fantastical animal living scenes for LifeRoute Settings.
// Wildlife scenes prefer photographic Wikimedia Commons media; the dragon theme prefers fantasy artwork.
(() => {
  if (window.__lifeRouteDynamicAnimalsV1Loaded) return;
  window.__lifeRouteDynamicAnimalsV1Loaded = true;

  const STORE = "liferoute_dynamic_animal_v1";
  const CACHE = "liferoute_dynamic_animal_media_v2";
  const THEMES = [
    { key:"lunar-wolf", name:"Lunar Wolf", query:"gray wolf forest wildlife photograph", require:["wolf"], motion:"prowl", a:"#020711", b:"#294d78", c:"#9bc9ff", d:"#e8edf4" },
    { key:"storm-dragon", name:"Storm Dragon", query:"fantasy dragon digital art illustration", require:["dragon"], fantasy:true, motion:"soar", a:"#05020d", b:"#5e34aa", c:"#79b8ff", d:"#f0c96b" },
    { key:"celestial-eagle", name:"Celestial Eagle", query:"golden eagle flying wildlife photograph", require:["eagle"], motion:"soar", a:"#0d0802", b:"#9c6516", c:"#ffd56e", d:"#f6f0d2" },
    { key:"obsidian-panther", name:"Obsidian Panther", query:"black panther jaguar wildlife photograph", require:["panther","jaguar"], motion:"prowl", a:"#020305", b:"#26313d", c:"#8aa2bc", d:"#d7e4ee" },
    { key:"ember-fox", name:"Ember Fox", query:"red fox forest wildlife photograph", require:["fox"], motion:"prowl", a:"#100401", b:"#b9441f", c:"#ff9652", d:"#ffd18a" },
    { key:"starfall-owl", name:"Starfall Owl", query:"owl night wildlife photograph", require:["owl"], motion:"pulse", a:"#02050d", b:"#304b7c", c:"#99b8ff", d:"#d9c8ff" },
    { key:"astral-whale", name:"Astral Whale", query:"humpback whale underwater photograph", require:["whale"], motion:"glide", a:"#020817", b:"#086f9f", c:"#59d9ee", d:"#a78cff" },
    { key:"silver-stag", name:"Silver Stag", query:"stag deer forest wildlife photograph", require:["stag","deer"], motion:"pulse", a:"#040708", b:"#496457", c:"#c3ddcf", d:"#f0e7bd" },
    { key:"night-stallion", name:"Night Stallion", query:"black horse running photograph", require:["horse","stallion"], motion:"glide", a:"#03050b", b:"#324a75", c:"#86a8e7", d:"#e3d09a" },
    { key:"aurora-raven", name:"Aurora Raven", query:"raven bird wildlife photograph", require:["raven"], motion:"soar", a:"#010506", b:"#0e776b", c:"#5be1c0", d:"#8d75ff" }
  ];
  const MAP = Object.fromEntries(THEMES.map(theme => [theme.key, theme]));
  let mediaCache = {};
  try { mediaCache = JSON.parse(localStorage.getItem(CACHE) || "{}"); } catch (_) { mediaCache = {}; }

  const style = document.createElement("style");
  style.id = "lifeRouteDynamicAnimalsV2Styles";
  style.textContent = `
    #lifeRouteAnimalBackdrop{position:fixed;inset:0;z-index:0;display:none;pointer-events:none;overflow:hidden;background:linear-gradient(150deg,var(--animal-a),color-mix(in srgb,var(--animal-b) 34%,#010204));isolation:isolate}
    html[data-animal-theme] #lifeRouteAnimalBackdrop{display:block}html[data-animal-theme] body{background:transparent!important}html[data-animal-theme] .app{position:relative;z-index:2}html[data-animal-theme] #lifeRouteMetalBackdrop,html[data-animal-theme] #lifeRouteThemeFX,html[data-animal-theme] #lifeRouteNatureBackdrop,html[data-animal-theme] #lifeRouteDynamicBackdrop,html[data-animal-theme] #lifeRouteFluidBackdrop{display:none!important}
    html[data-animal-theme] .bottom{z-index:8!important;background:color-mix(in srgb,var(--animal-a) 58%,transparent)!important}html[data-animal-theme] .card,html[data-animal-theme] .metric,html[data-animal-theme] .hero,html[data-animal-theme] .provider,html[data-animal-theme] .notice{background-color:color-mix(in srgb,var(--panel) 76%,transparent)!important;backdrop-filter:blur(19px);-webkit-backdrop-filter:blur(19px)}
    .lrAnimalScenePhoto{position:absolute;inset:-6%;z-index:0;background-image:var(--animal-photo);background-size:cover;background-position:50% 48%;filter:saturate(1.06) contrast(1.08) brightness(.68);transform:scale(1.06);animation:lrAnimalPhotoDrift 26s ease-in-out infinite alternate;opacity:0;transition:opacity .65s ease}.lrAnimalScenePhoto.ready{opacity:1}
    .lrAnimalSceneGrade{position:absolute;inset:0;z-index:1;background:linear-gradient(180deg,rgba(1,5,12,.28),rgba(1,5,12,.04) 34%,rgba(1,5,12,.18) 68%,rgba(1,5,12,.62)),radial-gradient(circle at 72% 16%,color-mix(in srgb,var(--animal-c) 23%,transparent),transparent 36%),linear-gradient(125deg,color-mix(in srgb,var(--animal-b) 18%,transparent),transparent 48%,color-mix(in srgb,var(--animal-d) 12%,transparent));mix-blend-mode:normal}
    .lrAnimalMist{position:absolute;z-index:2;left:-20%;right:-20%;bottom:12%;height:32%;background:linear-gradient(90deg,transparent,rgba(225,239,246,.03),color-mix(in srgb,var(--animal-c) 15%,rgba(240,247,250,.12)),rgba(225,239,246,.03),transparent);filter:blur(34px);animation:lrAnimalMist 13s ease-in-out infinite alternate}
    .lrAnimalLight{position:absolute;z-index:2;inset:-25%;background:conic-gradient(from 210deg at 50% 100%,transparent 0 25%,color-mix(in srgb,var(--animal-c) 19%,transparent) 31%,transparent 39%,color-mix(in srgb,var(--animal-d) 13%,transparent) 48%,transparent 58%);filter:blur(36px);animation:lrAnimalAurora 17s ease-in-out infinite alternate;opacity:.72}
    .lrAnimalStars{position:absolute;z-index:3;inset:0;background-image:radial-gradient(circle at 8% 14%,rgba(255,255,255,.8) 0 1px,transparent 1.5px),radial-gradient(circle at 22% 7%,rgba(255,255,255,.7) 0 1px,transparent 1.5px),radial-gradient(circle at 42% 18%,rgba(255,255,255,.65) 0 1px,transparent 1.5px),radial-gradient(circle at 67% 8%,rgba(255,255,255,.8) 0 1px,transparent 1.5px),radial-gradient(circle at 88% 19%,rgba(255,255,255,.66) 0 1px,transparent 1.5px);opacity:.3;animation:lrAnimalStars 4.6s ease-in-out infinite alternate}
    html[data-animal-motion="prowl"] .lrAnimalScenePhoto{animation-name:lrAnimalPhotoProwl;animation-duration:22s}html[data-animal-motion="glide"] .lrAnimalScenePhoto{animation-duration:32s}html[data-animal-motion="pulse"] .lrAnimalLight{animation-duration:9s}
    .lrAnimalPreview{position:absolute;inset:0;overflow:hidden;background:radial-gradient(circle at 72% 18%,color-mix(in srgb,var(--ac) 26%,transparent),transparent 36%),linear-gradient(145deg,var(--aa),color-mix(in srgb,var(--ab) 45%,#010204));background-size:cover;background-position:center;animation:lrAnimalPreviewDrift 8s ease-in-out infinite alternate}.lrAnimalPreview:before{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(1,5,12,.05),rgba(1,5,12,.58)),radial-gradient(circle at 72% 14%,color-mix(in srgb,var(--ac) 18%,transparent),transparent 38%)}.lrAnimalPreview:after{content:"";position:absolute;inset:-45%;background:conic-gradient(from 20deg,transparent,var(--ab),transparent 35%,var(--ac),transparent 65%);filter:blur(18px);opacity:.23;animation:lrAnimalAurora 12s ease-in-out infinite alternate}
    .lrAnimalMediaCredit{position:absolute;right:7px;bottom:7px;z-index:5;max-width:76%;padding:3px 6px;border-radius:999px;background:rgba(3,8,16,.56);color:rgba(255,255,255,.74);font-size:6.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;backdrop-filter:blur(7px);-webkit-backdrop-filter:blur(7px)}
    @keyframes lrAnimalPhotoDrift{from{transform:translate3d(-1.2%,-.5%,0) scale(1.065)}to{transform:translate3d(1.4%,1%,0) scale(1.105)}}@keyframes lrAnimalPhotoProwl{from{transform:translate3d(-2.5%,.2%,0) scale(1.08)}to{transform:translate3d(2.6%,-.8%,0) scale(1.12)}}@keyframes lrAnimalMist{from{transform:translate3d(-8%,2%,0) scaleX(.94);opacity:.3}to{transform:translate3d(9%,-3%,0) scaleX(1.1);opacity:.72}}@keyframes lrAnimalAurora{from{transform:translate3d(-4%,2%,0) rotate(-4deg) scale(.95)}to{transform:translate3d(5%,-3%,0) rotate(5deg) scale(1.08)}}@keyframes lrAnimalStars{from{opacity:.18}to{opacity:.46}}@keyframes lrAnimalPreviewDrift{from{background-position:47% 49%}to{background-position:54% 52%}}
    @media(prefers-reduced-motion:reduce){.lrAnimalScenePhoto,.lrAnimalMist,.lrAnimalLight,.lrAnimalStars,.lrAnimalPreview,.lrAnimalPreview:after{animation:none!important}}
  `;
  document.head.appendChild(style);

  let backdrop = document.getElementById("lifeRouteAnimalBackdrop");
  if (!backdrop) {
    backdrop = document.createElement("div");
    backdrop.id = "lifeRouteAnimalBackdrop";
    backdrop.setAttribute("aria-hidden", "true");
    backdrop.innerHTML = '<div class="lrAnimalScenePhoto"></div><div class="lrAnimalSceneGrade"></div><div class="lrAnimalMist"></div><div class="lrAnimalLight"></div><div class="lrAnimalStars"></div>';
    document.body.prepend(backdrop);
  }

  const normalized = value => String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
  const reject = ["logo","flag","coat of arms","herald","statue","sculpture","toy","plush","taxidermy","diagram","map","icon","symbol","coin","stamp"];

  const scorePage = (theme, page) => {
    const info = page?.imageinfo?.[0];
    const title = normalized(String(page?.title || "").replace(/^file:/i, ""));
    const mime = String(info?.mime || "");
    if (!/^image\/(jpeg|png|webp)$/i.test(mime) || reject.some(term => title.includes(term))) return -1000;
    const matches = theme.require.filter(term => title.includes(term));
    if (!matches.length) return -1000;
    let score = matches.length * 7;
    if (/photo|photograph|jpg|jpeg/.test(title)) score += theme.fantasy ? 0 : 4;
    if (theme.fantasy && /fantasy|digital|art|illustration|painting/.test(title)) score += 6;
    if (!theme.fantasy && /wild|wildlife|forest|flying|underwater|running|bird|mammal/.test(title)) score += 3;
    if (!theme.fantasy && /illustration|drawing|painting|artwork/.test(title)) score -= 8;
    return score;
  };

  const saveMediaCache = () => { try { localStorage.setItem(CACHE, JSON.stringify(mediaCache)); } catch (_) {} };

  const resolveMedia = async theme => {
    const cached = mediaCache[theme.key];
    if (cached?.url) return cached;
    const params = new URLSearchParams({
      action:"query", generator:"search", gsrsearch:theme.query, gsrnamespace:"6", gsrlimit:"24",
      prop:"imageinfo", iiprop:"url|mime|extmetadata", iiurlwidth:"1800", format:"json", origin:"*"
    });
    try {
      const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params}`, { mode:"cors", credentials:"omit", cache:"default" });
      if (!response.ok) return null;
      const data = await response.json();
      const ranked = Object.values(data?.query?.pages || {}).map(page => ({ page, score:scorePage(theme, page) })).filter(item => item.score > -100).sort((a,b) => b.score - a.score);
      const best = ranked[0]?.page;
      const info = best?.imageinfo?.[0];
      const url = info?.thumburl || info?.url;
      if (!url) return null;
      const title = String(best.title || "").replace(/^File:/i, "");
      const license = String(info?.extmetadata?.LicenseShortName?.value || "Commons").replace(/<[^>]+>/g, "");
      const result = { url, title, license };
      mediaCache[theme.key] = result;
      saveMediaCache();
      return result;
    } catch (_) { return null; }
  };

  const clearAnimals = (clearStored = true) => {
    const root = document.documentElement;
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
    ["--animal-a","--animal-b","--animal-c","--animal-d","--animal-photo"].forEach(name => root.style.removeProperty(name));
    backdrop.querySelector(".lrAnimalScenePhoto")?.classList.remove("ready");
    if (clearStored) { try { localStorage.removeItem(STORE); } catch (_) {} }
    document.querySelectorAll(".lrAnimalThemeCard").forEach(card => { card.classList.remove("active"); card.setAttribute("aria-pressed", "false"); });
  };

  const clearOtherThemes = () => {
    const root = document.documentElement;
    try { window.LifeRouteDynamicThemes?.clear?.(true); } catch (_) {}
    try { window.LifeRouteFluidScenes?.clear?.(true); } catch (_) {}
    root.removeAttribute("data-nature-theme");root.removeAttribute("data-scene");root.removeAttribute("data-photo-scene");root.removeAttribute("data-dynamic-theme");root.removeAttribute("data-dynamic-motion");root.removeAttribute("data-fluid-scene");
    try { localStorage.removeItem("liferoute_nature_theme_v1");localStorage.removeItem("liferoute_dynamic_theme_v1");localStorage.removeItem("liferoute_fluid_scene_v1"); } catch (_) {}
  };

  const decorateCard = async theme => {
    const card = document.querySelector(`.lrAnimalThemeCard[data-animal-key="${CSS.escape(theme.key)}"]`);
    const preview = card?.querySelector(".lrAnimalPreview");
    if (!preview || preview.dataset.mediaResolved === "1") return;
    preview.dataset.mediaResolved = "1";
    const media = await resolveMedia(theme);
    if (!media?.url) return;
    preview.style.backgroundImage = `url("${media.url}")`;
    const credit = document.createElement("span");
    credit.className = "lrAnimalMediaCredit";
    credit.textContent = `${media.license} · Wikimedia Commons`;
    preview.appendChild(credit);
  };

  const applyAnimal = async key => {
    const theme = MAP[key];
    if (!theme) return;
    clearOtherThemes();clearAnimals(false);
    const root = document.documentElement;
    try { window.setTheme?.("royal"); } catch (_) {}
    root.dataset.animalTheme = theme.key;root.dataset.animalMotion = theme.motion;
    root.style.setProperty("--animal-a", theme.a);root.style.setProperty("--animal-b", theme.b);root.style.setProperty("--animal-c", theme.c);root.style.setProperty("--animal-d", theme.d);
    try { localStorage.setItem(STORE, theme.key); } catch (_) {}
    document.querySelectorAll(".lrThemeCard").forEach(card => { const active = card.dataset.animalKey === theme.key;card.classList.toggle("active", active);if (card.classList.contains("lrAnimalThemeCard")) card.setAttribute("aria-pressed", active ? "true" : "false"); });
    const photo = backdrop.querySelector(".lrAnimalScenePhoto");
    photo?.classList.remove("ready");
    const media = await resolveMedia(theme);
    if (document.documentElement.dataset.animalTheme !== theme.key || !media?.url) return;
    root.style.setProperty("--animal-photo", `url("${media.url}")`);
    requestAnimationFrame(() => photo?.classList.add("ready"));
    decorateCard(theme);
  };

  const installSection = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    if (document.getElementById("lifeRouteDynamicAnimalSection")) return true;
    const section = document.createElement("div");
    section.id = "lifeRouteDynamicAnimalSection";section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Living Creatures</b><span>10 realistic fantastical dynamic scenes</span></div><div class="lrThemeGrid">${THEMES.map(theme => `<button type="button" class="lrThemeCard lrAnimalThemeCard" data-animal-key="${theme.key}" aria-pressed="false"><span class="lrAnimalPreview" style="--aa:${theme.a};--ab:${theme.b};--ac:${theme.c};--ad:${theme.d}"></span><span class="lrThemeName">${theme.name}</span></button>`).join("")}</div>`;
    const fluid = document.getElementById("lifeRouteFluidSceneSection");if (fluid) fluid.after(section);else sheet.appendChild(section);
    section.querySelectorAll("[data-animal-key]").forEach(card => card.addEventListener("click", () => applyAnimal(card.dataset.animalKey)));
    const saved = (() => { try { return localStorage.getItem(STORE) || ""; } catch (_) { return ""; } })();
    if (MAP[saved]) applyAnimal(saved);
    return true;
  };

  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) {
      THEMES.forEach((theme,index) => setTimeout(() => decorateCard(theme), 180 + index * 180));
    }
    const themeCard = event.target.closest?.(".lrThemeCard");
    if (themeCard && !themeCard.classList.contains("lrAnimalThemeCard")) clearAnimals(true);
  }, true);
  document.addEventListener("change", event => { if (event.target?.matches?.("#lifeRouteClassicThemeSelect,#lifeRouteMetallicWaveThemeSelect,#lifeRouteCoreThemeSelect,#themeSelect")) clearAnimals(true); }, true);

  let attempts = 0;
  const timer = setInterval(() => { attempts += 1;if (installSection() || attempts > 100) clearInterval(timer); }, 100);
  window.LifeRouteDynamicAnimals = { themes:THEMES.map(({key,name}) => ({key,name})), apply:applyAnimal, clear:clearAnimals };
})();
