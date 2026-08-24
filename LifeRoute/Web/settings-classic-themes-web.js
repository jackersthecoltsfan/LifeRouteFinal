// Keeps LifeRoute's existing/classic themes accessible after Appearance moves into Settings.
(() => {
  if (window.__lifeRouteClassicSettingsLoaded) return;
  window.__lifeRouteClassicSettingsLoaded = true;

  const CLASSICS = [
    ["royal","Royal Blue + Gold"],["obsidian","Obsidian Gold"],["carbon","Carbon"],["midnight","Midnight Indigo"],["navy-noir","Navy Noir"],["titanium","Titanium Night"],["ocean","Deep Ocean"],["aurora","Aurora Night"],["forest","Emerald Night"],["plum","Plum Night"],["ember","Ember"],["slate","Graphite"],["mono","Monochrome"],["daylight","Daylight"],
    ["solar-flare","Solar Flare"],["electric-storm","Electric Storm"],["ultraviolet","Ultraviolet"],["molten-gold","Molten Gold"],["arctic-pulse","Arctic Pulse"],["emerald-tempest","Emerald Tempest"],["rose-nebula","Rose Nebula"],["royal-cosmos","Royal Cosmos"],["sapphire-tide","Sapphire Tide"],["phantom-silver","Phantom Silver"]
  ];

  const applyClassic = key => {
    const root = document.documentElement;
    root.removeAttribute("data-nature-theme");
    root.removeAttribute("data-scene");
    root.style.removeProperty("--scene-sky1");
    root.style.removeProperty("--scene-sky2");
    root.style.removeProperty("--scene-ground");
    root.style.removeProperty("--scene-land");
    root.style.removeProperty("--scene-accent");
    ["--bg","--bg2","--panel","--panel2","--line","--text","--muted","--gold"].forEach(name => root.style.removeProperty(name));
    if (typeof window.setTheme === "function") {
      try { window.setTheme(key); } catch (_) { root.dataset.theme = key; }
    } else root.dataset.theme = key;
    if (window.prefs) {
      window.prefs.theme = key;
      try { window.persist?.(); } catch (_) {}
    }
    try { localStorage.removeItem("liferoute_nature_theme_v1"); } catch (_) {}
    document.querySelectorAll(".lrThemeCard").forEach(card => card.classList.remove("active"));
  };

  const install = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet || document.getElementById("lifeRouteClassicThemeSection")) return false;
    const placeholder = sheet.querySelector(".lrSettingsPlaceholder")?.closest(".lrSettingsSection");
    const section = document.createElement("div");
    section.id = "lifeRouteClassicThemeSection";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Classic themes</b><span>original LifeRoute styles</span></div><select id="lifeRouteClassicThemeSelect"><option value="">Choose a classic theme…</option>${CLASSICS.map(([key,name]) => `<option value="${key}">${name}</option>`).join("")}</select>`;
    if (placeholder) sheet.insertBefore(section, placeholder); else sheet.appendChild(section);
    const select = section.querySelector("select");
    select.addEventListener("change", () => { if (select.value) applyClassic(select.value); });
    return true;
  };

  const start = () => {
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (install() || attempts > 60) clearInterval(timer);
    }, 100);
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once:true });
  else start();
})();
