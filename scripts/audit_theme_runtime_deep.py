from pathlib import Path
import re

WEB = Path("LifeRoute/Web")
files = {name: (WEB / name).read_text() for name in [
    "nature-settings-web.js",
    "settings-classic-themes-web.js",
    "photoreal-nature-web.js",
    "dynamic-themes-web.js",
    "fluid-scenes-v1.js",
    "dynamic-animals-v1.js",
    "theme-catalog-v3.js",
    "ui-simplify-v4.js",
]}
index = (WEB / "index.html").read_text()
checks = []

def require(value, label): checks.append((bool(value), label))

# Entry point / catalog ownership.
require("lifeRouteSettingsButton" in files["nature-settings-web.js"], "top-right Settings gear owns appearance entry")
require("lifeRouteSettingsOverlay" in files["nature-settings-web.js"], "Settings overlay exists")
require('<h2>Appearance</h2>' not in index and 'id="themeSelect"' not in index, "redundant Appearance screen is absent")
require("lrThemeCatalogCount" in files["theme-catalog-v3.js"], "Settings exposes total theme count")
require('content:"✓"' in files["ui-simplify-v4.js"], "selected card checkmark is visible")
require('mark.textContent = "✓"' in files["theme-catalog-v3.js"], "selected family checkmark is visible")

# Expected families and counts.
classic = files["settings-classic-themes-web.js"]
dynamic = files["dynamic-themes-web.js"]
fluid = files["fluid-scenes-v1.js"]
animals = files["dynamic-animals-v1.js"]
nature = files["nature-settings-web.js"]
require(classic.count('["') >= 24, "Core + Metallic catalog remains populated")
require('20 premium moving designs' in dynamic and dynamic.count('["') >= 20, "20 Dynamic themes remain available")
require('high-motion screensaver scenes' in fluid and fluid.count('["') >= 8, "Fluid Motion family remains available")
for key in ["lunar-wolf","storm-dragon","celestial-eagle","obsidian-panther","ember-fox","starfall-owl","astral-whale","silver-stag","night-stallion","aurora-raven"]:
    require(f'key:"{key}"' in animals, f"Living Creature {key} exists")
require(len(re.findall(r'^\s*\["[^"]+","[^"]+","(?:mountain|ocean|desert|canyon|snow|forest|waterfall|aurora|volcano|meadow)"', nature, flags=re.M)) >= 20, "Scenery family retains at least 20 scenes")

# Persistence + family exclusivity. Applying one family must clear other scene state.
require('localStorage.setItem("liferoute_nature_theme_v1"' in nature, "Scenery persists selection")
require('localStorage.setItem(STORAGE_KEY' in dynamic, "Dynamic persists selection")
require('localStorage.setItem(STORE' in fluid, "Fluid persists selection")
require('localStorage.setItem(STORE, theme.key)' in animals, "Living Creatures persist selection")
for token in ["data-fluid-scene","data-animal-theme","data-animal-motion"]:
    require(token in classic, f"classic themes clear competing {token}")
for token in ["data-fluid-scene","data-animal-theme","data-animal-motion"]:
    require(token in dynamic, f"Dynamic clears competing {token}")
for token in ["data-animal-theme","data-animal-motion"]:
    require(token in fluid, f"Fluid clears competing {token}")
for token in ["data-nature-theme","data-dynamic-theme","data-fluid-scene"]:
    require(token in animals, f"Living Creatures clear competing {token}")

# Runtime pressure: no temporary polling loops, no whole-app catalog observer.
for name in ["settings-classic-themes-web.js","dynamic-themes-web.js","fluid-scenes-v1.js","dynamic-animals-v1.js"]:
    require("setInterval(" not in files[name], f"{name} has no polling installer")
require("observer.observe(document.body" not in files["theme-catalog-v3.js"], "theme catalog does not observe whole app")
require("observer.observe(sheet" in files["theme-catalog-v3.js"], "theme catalog watches Settings sheet only")
require("loadHelper(" not in classic, "classic themes do not dynamically inject duplicate core scripts")

# Motion accessibility and pointer safety.
for name in ["photoreal-nature-web.js","dynamic-themes-web.js","fluid-scenes-v1.js","dynamic-animals-v1.js"]:
    require("prefers-reduced-motion:reduce" in files[name], f"{name} honors reduced motion")
require("pointer-events:none" in animals and "pointer-events:none" in fluid and "pointer-events:none" in dynamic, "animated backdrops cannot steal taps")
require("Wikimedia Commons" in animals and "LicenseShortName" in animals, "Living Creature media attribution is preserved")
require("unsplash.com/photos/" in files["photoreal-nature-web.js"], "Scenery photography source is explicit")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute deep theme runtime audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Theme families, persistence, exclusivity, Settings ownership, accessibility, attribution, and runtime pressure passed.")
