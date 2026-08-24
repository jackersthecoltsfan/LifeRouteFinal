// LifeRoute web settings + dynamic nature scenery themes.
(() => {
  if (window.__lifeRouteNatureSettingsLoaded) return;
  window.__lifeRouteNatureSettingsLoaded = true;

  const NATURE_THEMES = [
    ["alpine-sunrise","Alpine Sunrise","mountain","#071421","#ffb56b","#213e5f","#dfe9ef","#f7c870"],
    ["blue-ridge-mist","Blue Ridge Mist","mountain","#071827","#76a6c8","#183e5c","#8fb2c5","#d2e5ef"],
    ["golden-rockies","Golden Rockies","mountain","#160b05","#e58a38","#4b2b1d","#b97238","#ffd582"],
    ["moonlit-peaks","Moonlit Peaks","mountain","#020611","#172b52","#0d1b35","#526d98","#d9e8ff"],
    ["ocean-cliffs","Ocean Cliffs","ocean","#03101b","#166580","#092d42","#247b94","#e7d8a7"],
    ["tropical-tide","Tropical Tide","ocean","#021919","#1ba7a5","#07545b","#62d6c7","#ffd589"],
    ["storm-coast","Storm Coast","ocean","#04080d","#40566b","#162938","#607b89","#c2d3dd"],
    ["desert-sunset","Desert Sunset","desert","#1a0803","#e26c31","#692a13","#c15123","#ffd074"],
    ["sahara-night","Sahara Night","desert","#03040d","#232657","#151531","#61558a","#e9d69a"],
    ["red-canyon","Red Canyon","canyon","#180604","#a13f24","#532113","#d56c35","#f1b66f"],
    ["snowbound-pines","Snowbound Pines","snow","#061019","#9bc4d8","#16313d","#e8f5fb","#b8d7e4"],
    ["arctic-twilight","Arctic Twilight","snow","#030612","#5c6fb8","#131e42","#d2ddff","#9ae6e0"],
    ["glacier-blue","Glacier Blue","snow","#02111a","#4fafd0","#0d4258","#bceeff","#e7fbff"],
    ["emerald-forest","Emerald Forest","forest","#020b08","#1f6e4c","#0b3828","#40966d","#c9c47a"],
    ["redwood-fog","Redwood Fog","forest","#070d0b","#5d7268","#263a31","#86978c","#c5d2c9"],
    ["autumn-valley","Autumn Valley","forest","#150805","#9a4924","#492216","#d77b31","#f4c86f"],
    ["waterfall-gorge","Waterfall Gorge","waterfall","#03100d","#237963","#0c3f38","#63b9a3","#d5f3e8"],
    ["northern-lights","Northern Lights","aurora","#01040b","#18304c","#071526","#4ce8b2","#b186ff"],
    ["volcanic-dawn","Volcanic Dawn","volcano","#100301","#8f2f16","#3e1108","#e75e23","#ffd06e"],
    ["wildflower-highlands","Wildflower Highlands","meadow","#071424","#6da5c4","#1f553a","#63a557","#ffd980"]
  ];
  const THEME_MAP = Object.fromEntries(NATURE_THEMES.map(theme => [theme[0], theme]));
  const isNature = key => !!THEME_MAP[key];

  const style = document.createElement("style");
  style.id = "lifeRouteNatureSettingsStyles";
  style.textContent = `
    .lrSettingsButton{position:relative;flex:0 0 auto;width:42px;height:42px;padding:0!important;border-radius:14px!important;display:grid;place-items:center;background:color-mix(in srgb,var(--panel) 88%,transparent)!important;color:var(--text)!important;border:1px solid var(--line)!important;box-shadow:0 12px 32px rgba(0,0,0,.2);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);font-size:20px!important;z-index:6}.lrSettingsButton:active{transform:scale(.96)}
    .lrSettingsOverlay{position:fixed;inset:0;z-index:22000;display:none;background:rgba(2,6,13,.66);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);padding:calc(14px + env(safe-area-inset-top)) 12px calc(14px + env(safe-area-inset-bottom));align-items:flex-end;justify-content:center}.lrSettingsOverlay.show{display:flex}.lrSettingsSheet{width:min(720px,100%);max-height:88vh;overflow:auto;border-radius:28px 28px 22px 22px;padding:18px;background:color-mix(in srgb,var(--panel) 96%,#08111d);border:1px solid var(--line);box-shadow:0 35px 100px rgba(0,0,0,.45)}.lrSettingsHandle{width:44px;height:5px;border-radius:999px;background:var(--line);margin:0 auto 14px}.lrSettingsTop{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:13px}.lrSettingsTop h2{margin:0;font-size:23px}.lrSettingsClose{border-radius:999px!important}.lrSettingsSection{margin-top:16px}.lrSettingsSectionHead{display:flex;justify-content:space-between;align-items:end;gap:10px;margin-bottom:8px}.lrSettingsSectionHead b{font-size:15px}.lrSettingsSectionHead span{font-size:9px;color:var(--muted)}.lrThemeGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.lrThemeCard{position:relative;overflow:hidden;min-height:96px;padding:0!important;border-radius:17px!important;border:1px solid var(--line)!important;background:var(--panel2)!important;color:white!important;text-align:left}.lrThemeCard.active{box-shadow:inset 0 0 0 2px var(--gold),0 10px 28px rgba(0,0,0,.18)}.lrThemePreview{position:absolute;inset:0;background:linear-gradient(180deg,var(--p1),var(--p2) 52%,var(--p3));}.lrThemePreview:before{content:"";position:absolute;left:-10%;right:-10%;bottom:-22%;height:69%;background:var(--p4);clip-path:polygon(0 100%,0 66%,18% 38%,29% 62%,46% 23%,58% 56%,74% 31%,100% 68%,100% 100%);opacity:.85}.lrThemeCard[data-scene="ocean"] .lrThemePreview:before{clip-path:none;border-radius:50% 50% 0 0/20% 20% 0 0;height:36%;bottom:-5%;background:linear-gradient(180deg,var(--p4),var(--p2))}.lrThemeCard[data-scene="desert"] .lrThemePreview:before,.lrThemeCard[data-scene="canyon"] .lrThemePreview:before{clip-path:ellipse(62% 48% at 50% 100%);height:58%;bottom:-15%;background:var(--p4)}.lrThemeCard[data-scene="forest"] .lrThemePreview:before{clip-path:polygon(0 100%,0 55%,10% 25%,14% 54%,24% 12%,29% 58%,43% 23%,48% 62%,62% 8%,67% 55%,80% 20%,85% 61%,100% 35%,100% 100%);background:var(--p4)}.lrThemeCard[data-scene="snow"] .lrThemePreview:before{background:#dcecf5}.lrThemeName{position:absolute;left:10px;right:10px;bottom:9px;z-index:2;font-size:11px;font-weight:950;text-shadow:0 2px 8px rgba(0,0,0,.65)}.lrSettingsPlaceholder{padding:11px;border:1px dashed var(--line);border-radius:15px;color:var(--muted);font-size:10px;line-height:1.45}
    #lifeRouteNatureBackdrop{position:fixed;inset:0;z-index:0;pointer-events:none;overflow:hidden;background:linear-gradient(180deg,var(--scene-sky1),var(--scene-sky2) 55%,var(--scene-ground));display:none}.app{position:relative;z-index:2}.bottom{z-index:8!important}
    html[data-nature-theme="true"] #lifeRouteNatureBackdrop{display:block}html[data-nature-theme="true"] #lifeRouteMetalBackdrop,html[data-nature-theme="true"] #lifeRouteThemeFX{display:none!important}html[data-nature-theme="true"] body{background:transparent!important}html[data-nature-theme="true"] .card,html[data-nature-theme="true"] .metric,html[data-nature-theme="true"] .hero,html[data-nature-theme="true"] .todoMetric,html[data-nature-theme="true"] .monthMetric,html[data-nature-theme="true"] .provider,html[data-nature-theme="true"] .notice{background-color:color-mix(in srgb,var(--panel) 78%,transparent)!important}html[data-nature-theme="true"] .bottom{background:color-mix(in srgb,var(--bg) 62%,transparent)!important}
    .natureSun{position:absolute;width:22vmin;height:22vmin;max-width:180px;max-height:180px;border-radius:50%;right:8%;top:10%;background:radial-gradient(circle,var(--scene-accent) 0 22%,color-mix(in srgb,var(--scene-accent) 62%,transparent) 32%,transparent 70%);filter:blur(.2px);opacity:.85;animation:natureSun 18s ease-in-out infinite alternate}.natureCloud{position:absolute;width:34vw;height:11vw;max-width:360px;max-height:100px;border-radius:50%;background:rgba(235,245,250,.16);filter:blur(18px);animation:natureCloud 36s linear infinite}.natureCloud.c1{top:18%;left:-35%}.natureCloud.c2{top:31%;left:-55%;animation-delay:-17s;opacity:.6}.natureMist{position:absolute;left:-20%;width:140%;height:25%;bottom:25%;background:linear-gradient(90deg,transparent,rgba(220,238,245,.12),rgba(255,255,255,.22),rgba(220,238,245,.1),transparent);filter:blur(28px);animation:natureMist 16s ease-in-out infinite alternate}
    .natureFar,.natureNear{position:absolute;left:-7%;width:114%;bottom:0;transform-origin:bottom center}.natureFar{height:60%;background:color-mix(in srgb,var(--scene-land) 70%,#000);clip-path:polygon(0 100%,0 73%,8% 62%,17% 40%,25% 68%,37% 31%,48% 62%,59% 22%,68% 58%,80% 34%,90% 65%,100% 48%,100% 100%);opacity:.62;animation:natureLand 18s ease-in-out infinite alternate}.natureNear{height:46%;background:var(--scene-land);clip-path:polygon(0 100%,0 64%,12% 49%,23% 71%,38% 39%,53% 68%,68% 44%,82% 62%,100% 38%,100% 100%);opacity:.78;animation:natureNear 23s ease-in-out infinite alternate}
    .natureStars{position:absolute;inset:0;opacity:0;background-image:radial-gradient(circle at 10% 18%,#fff 0 1px,transparent 1.5px),radial-gradient(circle at 22% 9%,#fff 0 1px,transparent 1.6px),radial-gradient(circle at 37% 20%,#fff 0 1px,transparent 1.5px),radial-gradient(circle at 56% 11%,#fff 0 1px,transparent 1.5px),radial-gradient(circle at 73% 23%,#fff 0 1px,transparent 1.6px),radial-gradient(circle at 88% 12%,#fff 0 1px,transparent 1.5px);animation:natureTwinkle 4s ease-in-out infinite alternate}.natureParticles{position:absolute;inset:-10%;opacity:0;background-image:radial-gradient(circle,#fff 0 1.5px,transparent 2px);background-size:48px 48px;animation:natureFall 12s linear infinite}.natureAurora{position:absolute;inset:-25% -20% 25%;opacity:0;background:conic-gradient(from 210deg at 50% 100%,transparent 0 24%,color-mix(in srgb,var(--scene-accent) 55%,transparent) 29%,transparent 35%,color-mix(in srgb,#8d75ff 42%,transparent) 43%,transparent 52%);filter:blur(30px);animation:natureAurora 13s ease-in-out infinite alternate}
    html[data-scene="ocean"] .natureFar{height:31%;clip-path:none;border-radius:48% 52% 0 0/16% 18% 0 0;background:color-mix(in srgb,var(--scene-land) 80%,#1d83a0);animation:natureOcean 7s ease-in-out infinite alternate}html[data-scene="ocean"] .natureNear{height:24%;clip-path:none;border-radius:52% 48% 0 0/20% 15% 0 0;background:color-mix(in srgb,var(--scene-land) 60%,#42abc2);animation:natureOcean 5s ease-in-out infinite alternate-reverse}
    html[data-scene="desert"] .natureFar,html[data-scene="desert"] .natureNear{clip-path:ellipse(72% 52% at 50% 100%)}html[data-scene="desert"] .natureFar{height:48%;left:-24%;width:130%}html[data-scene="desert"] .natureNear{height:37%;left:18%;width:105%}
    html[data-scene="canyon"] .natureFar{clip-path:polygon(0 100%,0 20%,18% 28%,23% 58%,37% 62%,43% 31%,57% 25%,63% 60%,78% 66%,84% 25%,100% 18%,100% 100%)}html[data-scene="canyon"] .natureNear{clip-path:polygon(0 100%,0 52%,15% 39%,28% 73%,48% 54%,63% 76%,82% 47%,100% 63%,100% 100%)}
    html[data-scene="forest"] .natureFar,html[data-scene="forest"] .natureNear{clip-path:polygon(0 100%,0 58%,5% 27%,9% 60%,17% 16%,21% 62%,30% 31%,34% 64%,43% 10%,48% 61%,58% 25%,63% 67%,72% 17%,77% 62%,87% 29%,91% 60%,100% 20%,100% 100%)}
    html[data-scene="snow"] .natureParticles{opacity:.65}html[data-scene="snow"] .natureNear{background:color-mix(in srgb,var(--scene-land) 30%,#e9f4f9)}html[data-scene="snow"] .natureFar{background:color-mix(in srgb,var(--scene-land) 40%,#b6d7e7)}
    html[data-scene="waterfall"] .natureNear:after{content:"";position:absolute;left:48%;top:4%;width:9%;height:92%;background:linear-gradient(90deg,transparent,rgba(225,250,250,.75),#c9f7f2,rgba(225,250,250,.72),transparent);filter:blur(3px);animation:natureWater 4s linear infinite}
    html[data-scene="aurora"] .natureStars,html[data-theme="moonlit-peaks"] .natureStars,html[data-theme="sahara-night"] .natureStars{opacity:.75}html[data-scene="aurora"] .natureAurora{opacity:.95}html[data-scene="volcano"] .natureNear:after{content:"";position:absolute;left:46%;top:14%;width:12%;height:60%;background:linear-gradient(#ffdc79,#ff5b1c,transparent);filter:blur(8px);clip-path:polygon(48% 0,65% 100%,32% 100%);animation:natureLava 3s ease-in-out infinite alternate}html[data-scene="meadow"] .natureNear{clip-path:ellipse(85% 48% at 50% 100%);background:var(--scene-land)}html[data-scene="meadow"] .natureParticles{opacity:.35;background-image:radial-gradient(circle,var(--scene-accent) 0 2px,transparent 2.5px);background-size:66px 52px;animation:natureFloat 18s linear infinite}
    @keyframes natureCloud{from{transform:translateX(0)}to{transform:translateX(190vw)}}@keyframes natureSun{from{transform:translate3d(0,0,0) scale(.94)}to{transform:translate3d(-3vw,2vh,0) scale(1.08)}}@keyframes natureMist{from{transform:translateX(-6%) scaleY(.9);opacity:.55}to{transform:translateX(7%) scaleY(1.2);opacity:.9}}@keyframes natureLand{from{transform:translateX(-1.2%) scale(1.02)}to{transform:translateX(1.2%) scale(1.05)}}@keyframes natureNear{from{transform:translateX(1%) scale(1.03)}to{transform:translateX(-1%) scale(1.06)}}@keyframes natureOcean{from{transform:translate3d(-1.5%,1%,0) scaleX(1.02)}to{transform:translate3d(1.5%,-3%,0) scaleX(1.07)}}@keyframes natureFall{from{transform:translate3d(0,-8%,0)}to{transform:translate3d(8%,20%,0)}}@keyframes natureTwinkle{from{opacity:.38}to{opacity:.9}}@keyframes natureAurora{from{transform:translateX(-7%) skewX(-7deg) scaleY(.9)}to{transform:translateX(8%) skewX(7deg) scaleY(1.15)}}@keyframes natureWater{from{background-position:0 -80px}to{background-position:0 120px}}@keyframes natureLava{from{opacity:.55;transform:scaleX(.8)}to{opacity:1;transform:scaleX(1.25)}}@keyframes natureFloat{from{transform:translate3d(-3%,8%,0)}to{transform:translate3d(6%,-12%,0)}}
    @media(max-width:680px){.lrThemeGrid{grid-template-columns:1fr 1fr}.lrSettingsSheet{padding:15px;border-radius:24px 24px 18px 18px}.lrThemeCard{min-height:88px}}
    @media(prefers-reduced-motion:reduce){#lifeRouteNatureBackdrop *{animation:none!important}}
  `;
  document.head.appendChild(style);

  const backdrop = document.createElement("div");
  backdrop.id = "lifeRouteNatureBackdrop";
  backdrop.setAttribute("aria-hidden","true");
  backdrop.innerHTML = '<div class="natureStars"></div><div class="natureAurora"></div><div class="natureSun"></div><div class="natureCloud c1"></div><div class="natureCloud c2"></div><div class="natureMist"></div><div class="natureFar"></div><div class="natureNear"></div><div class="natureParticles"></div>';

  const mountBackdrop = () => {
    if (!document.getElementById("lifeRouteNatureBackdrop")) document.body.prepend(backdrop);
  };

  const saveTheme = key => {
    if (window.prefs) {
      window.prefs.theme = key;
      try { window.persist?.(); } catch (_) {}
    }
    try { localStorage.setItem("liferoute_nature_theme_v1", key); } catch (_) {}
  };

  const applyTheme = key => {
    const theme = THEME_MAP[key];
    if (!theme) {
      document.documentElement.removeAttribute("data-nature-theme");
      document.documentElement.removeAttribute("data-scene");
      if (typeof window.setTheme === "function") {
        try { window.setTheme(key); } catch (_) { document.documentElement.dataset.theme = key; }
      } else document.documentElement.dataset.theme = key;
      saveTheme(key);
      renderActive();
      return;
    }
    const [, , scene, sky1, sky2, land, land2, accent] = theme;
    const root = document.documentElement;
    root.dataset.theme = key;
    root.dataset.natureTheme = "true";
    root.dataset.scene = scene;
    root.style.setProperty("--scene-sky1", sky1);
    root.style.setProperty("--scene-sky2", sky2);
    root.style.setProperty("--scene-ground", land);
    root.style.setProperty("--scene-land", land2);
    root.style.setProperty("--scene-accent", accent);
    root.style.setProperty("--bg", sky1);
    root.style.setProperty("--bg2", land);
    root.style.setProperty("--panel", "rgba(8,18,28,.82)");
    root.style.setProperty("--panel2", "rgba(18,37,50,.86)");
    root.style.setProperty("--line", "rgba(218,235,246,.18)");
    root.style.setProperty("--text", "#f8fbff");
    root.style.setProperty("--muted", "#b9cbd7");
    root.style.setProperty("--gold", accent);
    saveTheme(key);
    const legacySelect = document.getElementById("themeSelect");
    if (legacySelect) legacySelect.value = Array.from(legacySelect.options).some(option => option.value === key) ? key : legacySelect.value;
    renderActive();
  };

  const currentTheme = () => String(document.documentElement.dataset.theme || window.prefs?.theme || "royal");
  const renderActive = () => {
    document.querySelectorAll(".lrThemeCard").forEach(card => card.classList.toggle("active", card.dataset.themeKey === currentTheme()));
  };

  const ensureSettings = () => {
    const header = document.querySelector("header");
    if (!header) return false;
    let button = document.getElementById("lifeRouteSettingsButton");
    if (!button) {
      button = document.createElement("button");
      button.id = "lifeRouteSettingsButton";
      button.className = "lrSettingsButton";
      button.type = "button";
      button.setAttribute("aria-label","Open settings");
      button.textContent = "⚙︎";
      const status = header.querySelector(".status");
      if (status) status.insertAdjacentElement("afterend", button); else header.appendChild(button);
    }

    let overlay = document.getElementById("lifeRouteSettingsOverlay");
    if (!overlay) {
      overlay = document.createElement("div");
      overlay.id = "lifeRouteSettingsOverlay";
      overlay.className = "lrSettingsOverlay";
      overlay.innerHTML = `<div class="lrSettingsSheet" role="dialog" aria-modal="true" aria-labelledby="lrSettingsTitle"><div class="lrSettingsHandle"></div><div class="lrSettingsTop"><div><div class="small" style="color:var(--gold);font-weight:950;letter-spacing:.12em">LIFEROUTE</div><h2 id="lrSettingsTitle">Settings</h2></div><button type="button" class="secondary lrSettingsClose">Done</button></div><div class="lrSettingsSection"><div class="lrSettingsSectionHead"><b>Nature scenery</b><span>20 dynamic environments</span></div><div class="lrThemeGrid">${NATURE_THEMES.map(([key,name,scene,p1,p2,p3,p4]) => `<button type="button" class="lrThemeCard" data-theme-key="${key}" data-scene="${scene}"><span class="lrThemePreview" style="--p1:${p1};--p2:${p2};--p3:${p3};--p4:${p4}"></span><span class="lrThemeName">${name}</span></button>`).join("")}</div></div><div class="lrSettingsSection"><div class="lrSettingsSectionHead"><b>More settings</b><span>coming next</span></div><div class="lrSettingsPlaceholder">This Settings panel is now the permanent home for appearance and future LifeRoute preferences.</div></div></div>`;
      document.body.appendChild(overlay);
      overlay.querySelector(".lrSettingsClose").onclick = () => overlay.classList.remove("show");
      overlay.addEventListener("click", event => { if (event.target === overlay) overlay.classList.remove("show"); });
      overlay.querySelectorAll("[data-theme-key]").forEach(card => card.onclick = () => applyTheme(card.dataset.themeKey));
    }
    button.onclick = () => { renderActive(); overlay.classList.add("show"); };
    return true;
  };

  const hideLegacyThemeControl = () => {
    const select = document.getElementById("themeSelect");
    if (!select) return;
    const parent = select.closest(".grid2")?.parentElement || select.parentElement;
    const section = parent?.closest(".section");
    if (section && /Appearance/i.test(section.textContent || "")) section.style.display = "none";
    else select.parentElement.style.display = "none";
  };

  const start = () => {
    mountBackdrop();
    ensureSettings();
    hideLegacyThemeControl();
    let saved = "";
    try { saved = localStorage.getItem("liferoute_nature_theme_v1") || ""; } catch (_) {}
    const initial = isNature(window.prefs?.theme) ? window.prefs.theme : isNature(saved) ? saved : "";
    if (initial) applyTheme(initial);
    [200,600,1400].forEach(delay => setTimeout(() => { ensureSettings(); hideLegacyThemeControl(); }, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once:true });
  else start();
})();
