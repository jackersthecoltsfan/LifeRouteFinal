// Keeps LifeRoute's original and metallic-wave themes accessible in Settings.
(() => {
  if (window.__lifeRouteClassicSettingsLoaded) return;
  window.__lifeRouteClassicSettingsLoaded = true;

  const CORE = [
    ["royal","Royal Blue + Gold"],["obsidian","Obsidian Gold"],["carbon","Carbon"],["midnight","Midnight Indigo"],["navy-noir","Navy Noir"],["titanium","Titanium Night"],["ocean","Deep Ocean"],["aurora","Aurora Night"],["forest","Emerald Night"],["plum","Plum Night"],["ember","Ember"],["slate","Graphite"],["mono","Monochrome"],["daylight","Daylight"]
  ];
  const METALLIC_WAVE = [
    ["solar-flare","Solar Flare"],["electric-storm","Electric Storm"],["ultraviolet","Ultraviolet"],["molten-gold","Molten Gold"],["arctic-pulse","Arctic Pulse"],["emerald-tempest","Emerald Tempest"],["rose-nebula","Rose Nebula"],["royal-cosmos","Royal Cosmos"],["sapphire-tide","Sapphire Tide"],["phantom-silver","Phantom Silver"]
  ];

  const applyClassic = key => {
    const root = document.documentElement;
    root.removeAttribute("data-nature-theme");
    root.removeAttribute("data-scene");
    root.removeAttribute("data-photo-scene");
    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.style.removeProperty("--scene-sky1");
    root.style.removeProperty("--scene-sky2");
    root.style.removeProperty("--scene-ground");
    root.style.removeProperty("--scene-land");
    root.style.removeProperty("--scene-accent");
    ["--dyn-a","--dyn-b","--dyn-c","--dyn-d","--bg","--bg2","--panel","--panel2","--line","--text","--muted","--gold"].forEach(name => root.style.removeProperty(name));
    if (typeof window.setTheme === "function") {
      try { window.setTheme(key); } catch (_) { root.dataset.theme = key; }
    } else root.dataset.theme = key;
    if (window.prefs) {
      window.prefs.theme = key;
      try { window.persist?.(); } catch (_) {}
    }
    try {
      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
    } catch (_) {}
    document.querySelectorAll(".lrThemeCard").forEach(card => card.classList.remove("active"));
  };

  const makeSelect = (id, label, subtitle, items, prompt) => {
    const section = document.createElement("div");
    section.id = id;
    section.className = "lrSettingsSection";
    const selectID = id === "lifeRouteMetallicWaveThemeSection" ? "lifeRouteMetallicWaveThemeSelect" : "lifeRouteCoreThemeSelect";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>${label}</b><span>${subtitle}</span></div><select id="${selectID}"><option value="">${prompt}</option>${items.map(([key,name]) => `<option value="${key}">${name}</option>`).join("")}</select>`;
    section.querySelector("select").addEventListener("change", event => { if (event.target.value) applyClassic(event.target.value); });
    return section;
  };

  const install = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    const placeholder = sheet.querySelector(".lrSettingsPlaceholder")?.closest(".lrSettingsSection");
    if (!document.getElementById("lifeRouteMetallicWaveThemeSection")) {
      const metallic = makeSelect("lifeRouteMetallicWaveThemeSection","Metallic Wave","original animated wave collection",METALLIC_WAVE,"Choose a Metallic Wave theme…");
      if (placeholder) sheet.insertBefore(metallic, placeholder); else sheet.appendChild(metallic);
    }
    if (!document.getElementById("lifeRouteCoreThemeSection")) {
      const core = makeSelect("lifeRouteCoreThemeSection","Core","clean original palettes",CORE,"Choose a Core theme…");
      if (placeholder) sheet.insertBefore(core, placeholder); else sheet.appendChild(core);
    }
    return true;
  };

  const loadPhotorealNature = () => {
    if (document.getElementById("lifeRoutePhotorealNatureScript") || window.__lifeRoutePhotorealNatureLoaded) return;
    const script = document.createElement("script");
    script.id = "lifeRoutePhotorealNatureScript";
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    script.src = `photoreal-nature-web.js${build ? "?v=" + encodeURIComponent(build) : ""}`;
    script.async = true;
    document.body.appendChild(script);
  };

  const start = () => {
    loadPhotorealNature();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (install() || attempts > 60) clearInterval(timer);
    }, 100);
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once:true });
  else start();
})();
