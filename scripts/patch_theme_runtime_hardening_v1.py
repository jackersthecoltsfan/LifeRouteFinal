from pathlib import Path
import re


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))


def regex_once(path: Path, pattern: str, replacement: str, label: str):
    text = path.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"Could not harden {label}: expected pattern not found")
    path.write_text(updated)


# Classic themes explicitly clear every moving family and never inject duplicate
# theme scripts that already exist in the canonical shared startup list.
classic = Path("LifeRoute/Web/settings-classic-themes-web.js")
replace_once(classic,
'''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
''',
'''    root.removeAttribute("data-dynamic-theme");
    root.removeAttribute("data-dynamic-motion");
    root.removeAttribute("data-fluid-scene");
    root.removeAttribute("data-animal-theme");
    root.removeAttribute("data-animal-motion");
''', "classic scene exclusivity")
replace_once(classic,
'''      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
''',
'''      localStorage.removeItem("liferoute_nature_theme_v1");
      localStorage.removeItem("liferoute_dynamic_theme_v1");
      localStorage.removeItem("liferoute_fluid_scene_v1");
      localStorage.removeItem("liferoute_dynamic_animal_v1");
''', "classic storage exclusivity")
regex_once(classic,
    r'  const loadHelper = .*?\n  const start = \(\) => \{.*?\n  \};\n(?=  if \(document\.readyState)',
'''  const start = () => {
    install();
    document.addEventListener("click", event => {
      if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(install);
    }, true);
  };
''', "classic deterministic installation")

# Scenery explicitly clears every competing scene family.
nature = Path("LifeRoute/Web/nature-settings-web.js")
replace_once(nature,
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
''', "scenery exclusivity")

# Dynamic clears fluid/animal state.
dynamic = Path("LifeRoute/Web/dynamic-themes-web.js")
replace_once(dynamic,
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
''', "dynamic exclusivity")
regex_once(dynamic,
    r'\n  let attempts = 0;\n  const timer = setInterval\(\(\) => \{.*?\}, 100\);',
'''\n  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);''', "dynamic deterministic installation")

# Fluid clears animal state.
fluid = Path("LifeRoute/Web/fluid-scenes-v1.js")
replace_once(fluid,
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
''', "fluid exclusivity")
regex_once(fluid,
    r'\n  let attempts = 0;\n  const timer = setInterval\(\(\) => \{.*?\}, 100\);',
'''\n  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);''', "fluid deterministic installation")

# Living Creatures also install deterministically; tolerate either one-line or
# multiline timer formatting from older revisions.
animal = Path("LifeRoute/Web/dynamic-animals-v1.js")
regex_once(animal,
    r'\n  let attempts = 0;\n  const timer = setInterval\(\(\) => \{.*?\}, 100\);',
'''\n  installSection();
  document.addEventListener("click", event => {
    if (event.target.closest?.("#lifeRouteSettingsButton")) requestAnimationFrame(installSection);
  }, true);''', "animal deterministic installation")

# Theme catalog observes only its Settings sheet, not calendars/timers/tools.
catalog = Path("LifeRoute/Web/theme-catalog-v3.js")
replace_once(catalog,
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
''', "theme catalog observer scope")

print("Theme runtime hardened: deterministic loading, scoped observer, no polling, explicit family exclusivity.")
