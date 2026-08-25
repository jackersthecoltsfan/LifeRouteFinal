from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))

# 1) Classic theme selection must explicitly clear every scene family. This
# avoids depending on bubbling/capture listener order across independent modules.
classic = Path("LifeRoute/Web/settings-classic-themes-web.js")
replace_once(
    classic,
    '''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
''',
    '''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.removeAttribute("data-fluid-scene");
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
''',
    "classic theme scene exclusivity",
)
replace_once(
    classic,
    '''      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
''',
    '''      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
      localStorage.removeItem("liferoute_fluid_scene_v1");
      localStorage.removeItem("liferoute_dynamic_animal_v1");
''',
    "classic theme storage exclusivity",
)
replace_once(
    classic,
    '''  const loadHelper = (id, filename, loadedFlag) => {
    if (document.getElementById(id) || window[loadedFlag]) return;
    const script = document.createElement("script");
    script.id = id;
    const build = document.querySelector('meta[name="liferoute-web-build"]')?.content || "";
    script.src = `${filename}${build ? "?v=" + encodeURIComponent(build) : ""}`;
    script.async = true;
    document.body.appendChild(script);
  };

  const start = () => {
    loadHelper("lifeRoutePhotorealNatureScript","photoreal-nature-web.js","__lifeRoutePhotorealNatureLoaded");
    loadHelper("lifeRouteDynamicThemesScript","dynamic-themes-web.js","__lifeRouteDynamicThemesLoaded");
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (install() || attempts > 60) clearInterval(timer);
    }, 100);
  };
''',
    '''  const start = () => {
    install();
    document.addEventListener("click", event => {
      if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(install);
    }, true);
  };
''',
    "classic theme deterministic installation",
)

# 2) Scenery themes explicitly clear every other moving theme family.
nature = Path("LifeRoute/Web/nature-settings-web.js")
replace_once(
    nature,
    '''    const [, , scene, sky1, sky2, land, land2, accent] = theme;
    const root = document.documentElement;
    root.dataset.theme = key;
''',
    '''    const [, , scene, sky1, sky2, land, land2, accent] = theme;
    const root = document.documentElement;
    try { window.LifeRouteDynamicThemes?.clear?.(true); } catch (_) {}
    try { window.LifeRouteFluidScenes?.clear?.(true); } catch (_) {}
    try { window.LifeRouteDynamicAnimals?.clear?.(true); } catch (_) {}
    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.removeAttribute("data-fluid-scene");
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
    try {
      localStorage.removeItem("liferoute_dynamic_theme_v1");
      localStorage.removeItem("liferoute_fluid_scene_v1");
      localStorage.removeItem("liferoute_dynamic_animal_v1");
    } catch (_) {}
    root.dataset.theme = key;
''',
    "scenery theme exclusivity",
)

# 3) Dynamic themes: explicitly clear fluid/animal state and replace 10-second
# polling with deterministic install + Settings-click retry.
dynamic = Path("LifeRoute/Web/dynamic-themes-web.js")
replace_once(
    dynamic,
    '''  const applyDynamic = key => {
    const theme = MAP[key];
    if (!theme) return;
    clearNatureState();
    clearDynamic(false);
''',
    '''  const applyDynamic = key => {
    const theme = MAP[key];
    if (!theme) return;
    clearNatureState();
    try { window.LifeRouteFluidScenes?.clear?.(true); } catch (_) {}
    try { window.LifeRouteDynamicAnimals?.clear?.(true); } catch (_) {}
    const rootForClear = document.documentElement;
    rootForClear.removeAttribute("data-fluid-scene");
    rootForClear.removeAttribute("data-animal-theme");
    rootForClear.removeAttribute("data-animal-motion");
    try { localStorage.removeItem("liferoute_fluid_scene_v1"); localStorage.removeItem("liferoute_dynamic_animal_v1"); } catch (_) {}
    clearDynamic(false);
''',
    "dynamic theme exclusivity",
)
replace_once(
    dynamic,
    '''  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 100) clearInterval(timer);
  }, 100);
})();
''',
    '''  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);
})();
''',
    "dynamic theme deterministic installation",
)

# 4) Fluid themes: explicitly clear animal state and remove polling.
fluid = Path("LifeRoute/Web/fluid-scenes-v1.js")
replace_once(
    fluid,
    '''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    try {
      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
''',
    '''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
    try { window.LifeRouteDynamicAnimals?.clear?.(true); } catch (_) {}
    try {
      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
      localStorage.removeItem("liferoute_dynamic_animal_v1");
''',
    "fluid theme exclusivity",
)
replace_once(
    fluid,
    '''  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 100) clearInterval(timer);
  }, 100);
  window.LifeRouteFluidScenes = { scenes: SCENES.map(scene => ({ key: scene[0], name: scene[1] })), apply: applyFluid, clear: clearFluid };
})();
''',
    '''  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);
  window.LifeRouteFluidScenes = { scenes: SCENES.map(scene => ({ key: scene[0], name: scene[1] })), apply: applyFluid, clear: clearFluid };
})();
''',
    "fluid theme deterministic installation",
)

# 5) Animal themes: avoid polling and expose a stable clear API used by other
# families. Existing imagery remains lazy-triggered when Settings opens.
animal = Path("LifeRoute/Web/dynamic-animals-v1.js")
replace_once(
    animal,
    '''  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (installSection() || attempts > 100) clearInterval(timer);
  }, 100);

  window.LifeRouteDynamicAnimals = { themes:THEMES.map(({key,name,motion}) => ({key,name,motion})), apply:applyAnimal, clear:clearAnimals };
})();
''',
    '''  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);

  window.LifeRouteDynamicAnimals = { themes:THEMES.map(({key,name,motion}) => ({key,name,motion})), apply:applyAnimal, clear:clearAnimals };
})();
''',
    "animal theme deterministic installation",
)

# 6) Theme catalog normalization only needs to observe the Settings sheet, not
# every mutation made by calendars, timers, Live Day, or tools elsewhere.
catalog = Path("LifeRoute/Web/theme-catalog-v3.js")
replace_once(
    catalog,
    '''  const observer = new MutationObserver(queueNormalize);
  const start = () => {
    observer.observe(document.body, { childList: true, subtree: true });
    [0,120,350,800,1600].forEach(delay => setTimeout(queueNormalize, delay));
  };
''',
    '''  let observedSheet = null;
  const observer = new MutationObserver(queueNormalize);
  const observeSheet = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet || sheet === observedSheet) return !!sheet;
    observer.disconnect();
    observer.observe(sheet, { childList: true, subtree: true });
    observedSheet = sheet;
    return true;
  };
  const start = () => {
    observeSheet();
    queueNormalize();
    document.addEventListener("click", event => {
      if (event.target.closest?.("#lifeRouteSettingsButton")) {
        requestAnimationFrame(() => { observeSheet(); queueNormalize(); });
      }
    }, true);
  };
''',
    "theme catalog observer scope",
)

print("Theme runtime hardened: deterministic loading, scoped observer, no polling, explicit family exclusivity.")
