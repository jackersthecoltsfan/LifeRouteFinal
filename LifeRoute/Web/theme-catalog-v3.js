// Normalizes the complete LifeRoute theme catalog inside the top-right Settings sheet.
(() => {
  if (window.__lifeRouteThemeCatalogV3Loaded) return;
  window.__lifeRouteThemeCatalogV3Loaded = true;

  const CORE_KEYS = new Set(["royal","obsidian","carbon","midnight","navy-noir","titanium","ocean","aurora","forest","plum","ember","slate","mono","daylight"]);
  const METALLIC_KEYS = new Set(["solar-flare","electric-storm","ultraviolet","molten-gold","arctic-pulse","emerald-tempest","rose-nebula","royal-cosmos","sapphire-tide","phantom-silver"]);

  const style = document.createElement("style");
  style.id = "lifeRouteThemeCatalogV3Styles";
  style.textContent = `
    #lifeRouteSettingsOverlay .lrSettingsPlaceholder{display:none!important}
    #lifeRouteSettingsOverlay .lrSettingsSection.lrThemePlaceholderSection{display:none!important}
    #lifeRouteSettingsOverlay .lrSettingsSheet{scroll-behavior:smooth}
    #lifeRouteSettingsOverlay .lrSettingsTop .lrThemeCatalogCount{font-size:9px;color:var(--muted);margin-top:3px;font-weight:800;letter-spacing:.02em}
    #lifeRouteSettingsOverlay .lrSettingsSectionHead b{display:flex;align-items:center;gap:6px}
    #lifeRouteSettingsOverlay .lrThemeSelectedMark{display:inline-grid;place-items:center;width:19px;height:19px;border-radius:999px;background:var(--gold);color:#07111f;font-size:11px;font-weight:1000;box-shadow:0 3px 10px rgba(0,0,0,.24)}
  `;
  document.head.appendChild(style);

  const currentClassic = () => String(window.prefs?.theme || document.documentElement.dataset.theme || "royal") || "royal";
  const currentAnimal = () => String(document.documentElement.dataset.animalTheme || "");
  const currentFluid = () => String(document.documentElement.dataset.fluidScene || "");
  const currentDynamic = () => String(document.documentElement.dataset.dynamicTheme || "");
  const currentNature = () => document.documentElement.dataset.natureTheme === "true" ? String(document.documentElement.dataset.theme || "") : "";

  const removePlaceholder = sheet => {
    sheet.querySelectorAll(".lrSettingsSection").forEach(section => {
      if (section.querySelector(".lrSettingsPlaceholder") || /^More settings$/i.test(section.querySelector(".lrSettingsSectionHead b")?.textContent?.trim() || "")) {
        section.classList.add("lrThemePlaceholderSection");
      }
    });
  };

  const syncClassicSelects = () => {
    const key = currentClassic();
    const core = document.getElementById("lifeRouteCoreThemeSelect");
    const metallic = document.getElementById("lifeRouteMetallicWaveThemeSelect");
    if (core) core.value = CORE_KEYS.has(key) ? key : "";
    if (metallic) metallic.value = METALLIC_KEYS.has(key) ? key : "";
  };

  const setHeadMark = (section, active) => {
    if (!section) return;
    const head = section.querySelector(".lrSettingsSectionHead b");
    if (!head) return;
    let mark = head.querySelector(".lrThemeSelectedMark");
    if (active) {
      if (!mark) {
        mark = document.createElement("span");
        mark.className = "lrThemeSelectedMark";
        mark.textContent = "✓";
        head.appendChild(mark);
      }
    } else mark?.remove();
  };

  const syncCards = () => {
    const nature = currentNature();
    const dynamic = currentDynamic();
    const fluid = currentFluid();
    const animal = currentAnimal();
    document.querySelectorAll(".lrThemeCard").forEach(card => {
      let active = false;
      if (card.dataset.animalKey) active = card.dataset.animalKey === animal;
      else if (card.dataset.fluidKey) active = card.dataset.fluidKey === fluid;
      else if (card.dataset.dynamicKey) active = card.dataset.dynamicKey === dynamic;
      else if (card.dataset.themeKey) active = card.dataset.themeKey === nature;
      card.classList.toggle("active", active);
      if (card.hasAttribute("aria-pressed")) card.setAttribute("aria-pressed", active ? "true" : "false");
    });
  };

  const syncMarks = () => {
    syncClassicSelects();
    syncCards();
    const key = currentClassic();
    setHeadMark(document.getElementById("lifeRouteCoreThemeSection"), CORE_KEYS.has(key) && !currentNature() && !currentDynamic() && !currentFluid() && !currentAnimal());
    setHeadMark(document.getElementById("lifeRouteMetallicWaveThemeSection"), METALLIC_KEYS.has(key) && !currentNature() && !currentDynamic() && !currentFluid() && !currentAnimal());
    setHeadMark(document.getElementById("lifeRouteDynamicThemeSection"), !!currentDynamic());
    setHeadMark(document.getElementById("lifeRouteFluidSceneSection"), !!currentFluid());
    setHeadMark(document.getElementById("lifeRouteDynamicAnimalSection"), !!currentAnimal());
    const scenery = [...document.querySelectorAll("#lifeRouteSettingsOverlay .lrSettingsSection")].find(section => /^(Nature scenery|Scenery)$/i.test(section.querySelector(".lrSettingsSectionHead b")?.childNodes?.[0]?.textContent?.trim() || section.querySelector(".lrSettingsSectionHead b")?.textContent?.trim() || ""));
    setHeadMark(scenery, !!currentNature());
  };

  const orderSections = sheet => {
    const sections = [...sheet.querySelectorAll(":scope > .lrSettingsSection")];
    const find = id => document.getElementById(id);
    const scenery = sections.find(section => /^(Nature scenery|Scenery)/i.test(section.querySelector(".lrSettingsSectionHead b")?.textContent?.trim() || ""));
    const ordered = [
      find("lifeRouteCoreThemeSection"),
      find("lifeRouteMetallicWaveThemeSection"),
      scenery,
      find("lifeRouteDynamicThemeSection"),
      find("lifeRouteFluidSceneSection"),
      find("lifeRouteDynamicAnimalSection")
    ].filter(Boolean);
    ordered.forEach(section => sheet.appendChild(section));
  };

  const addCatalogCount = sheet => {
    const top = sheet.querySelector(".lrSettingsTop > div");
    if (!top) return;
    let count = top.querySelector(".lrThemeCatalogCount");
    if (!count) {
      count = document.createElement("div");
      count.className = "lrThemeCatalogCount";
      top.appendChild(count);
    }
    const natureCount = sheet.querySelectorAll(".lrThemeCard[data-theme-key]").length;
    const dynamicCount = sheet.querySelectorAll(".lrThemeCard[data-dynamic-key]").length;
    const fluidCount = sheet.querySelectorAll(".lrThemeCard[data-fluid-key]").length;
    const animalCount = sheet.querySelectorAll(".lrThemeCard[data-animal-key]").length;
    const coreCount = document.querySelectorAll("#lifeRouteCoreThemeSelect option[value]:not([value=''])").length;
    const metallicCount = document.querySelectorAll("#lifeRouteMetallicWaveThemeSelect option[value]:not([value=''])").length;
    const total = natureCount + dynamicCount + fluidCount + animalCount + coreCount + metallicCount;
    count.textContent = total ? `${total} themes` : "Themes";
  };

  const normalize = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet) return false;
    removePlaceholder(sheet);
    orderSections(sheet);
    syncMarks();
    addCatalogCount(sheet);
    return true;
  };

  let queued = false;
  const queueNormalize = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      normalize();
    });
  };

  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton,.lrThemeCard")) setTimeout(queueNormalize, 0);
  }, true);
  document.addEventListener("change", event => {
    if (event.target?.matches?.("#lifeRouteCoreThemeSelect,#lifeRouteMetallicWaveThemeSelect")) setTimeout(queueNormalize, 0);
  }, true);

  const observer = new MutationObserver(queueNormalize);
  const start = () => {
    observer.observe(document.body, { childList: true, subtree: true });
    [0,120,350,800,1600].forEach(delay => setTimeout(queueNormalize, delay));
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();

  window.LifeRouteThemeCatalogV3 = { normalize, syncMarks };
})();
