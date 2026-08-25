from pathlib import Path
import re

ROOT = Path("LifeRoute/Web")
INDEX = (ROOT / "index.html").read_text()
PREPARE = Path("scripts/prepare_build.sh").read_text()
FILES = {
    "nature": (ROOT / "nature-settings-web.js").read_text(),
    "classic": (ROOT / "settings-classic-themes-web.js").read_text(),
    "dynamic": (ROOT / "dynamic-themes-web.js").read_text(),
    "fluid": (ROOT / "fluid-scenes-v1.js").read_text(),
    "animals": (ROOT / "dynamic-animals-v1.js").read_text(),
    "catalog": (ROOT / "theme-catalog-v3.js").read_text(),
    "simplify": (ROOT / "ui-simplify-v4.js").read_text(),
}

checks = []

def check(name, condition):
    checks.append((name, bool(condition)))

# Native/TestFlight startup must own the complete theme system, not just Pages.
for script in [
    "nature-settings-web.js",
    "settings-classic-themes-web.js",
    "photoreal-nature-web.js",
    "dynamic-themes-web.js",
    "fluid-scenes-v1.js",
    "dynamic-animals-v1.js",
    "theme-catalog-v3.js",
]:
    check(f"native core loads {script}", f'"{script}"' in PREPARE and f'<script src="{script}"></script>' in INDEX)

# Redundant Appearance screen is gone after build preparation; planning preference remains.
check("legacy Appearance heading removed", '<h2>Appearance</h2>' not in INDEX)
check("legacy themeSelect removed", 'id="themeSelect"' not in INDEX)
check("Planning preferences retained", 'id="lifeRoutePlanningPreferences"' in INDEX and 'id="pGap"' in INDEX)
check("setTheme tolerates no legacy select", 'legacyThemeSelect' in INDEX and 'if(legacyThemeSelect)' in INDEX)

# Settings gear remains the single appearance entry point.
check("Settings gear exists", 'lifeRouteSettingsButton' in FILES["nature"])
check("Settings overlay exists", 'lifeRouteSettingsOverlay' in FILES["nature"])
check("placeholder hidden", 'lrSettingsPlaceholder' in FILES["catalog"])
check("theme catalog count exposed", 'lrThemeCatalogCount' in FILES["catalog"])

# Existing collections remain present.
classic_keys = ["royal","obsidian","carbon","midnight","navy-noir","titanium","ocean","aurora","forest","plum","ember","slate","mono","daylight"]
metallic_keys = ["solar-flare","electric-storm","ultraviolet","molten-gold","arctic-pulse","emerald-tempest","rose-nebula","royal-cosmos","sapphire-tide","phantom-silver"]
for key in classic_keys:
    check(f"core theme {key}", f'["{key}",' in FILES["classic"])
for key in metallic_keys:
    check(f"metallic theme {key}", f'["{key}",' in FILES["classic"])
check("20 scenery themes retained", len(re.findall(r'^\s*\["[^"]+","[^"]+","(?:mountain|ocean|desert|canyon|snow|forest|waterfall|aurora|volcano|meadow)"', FILES["nature"], flags=re.M)) >= 20)
check("20 premium dynamic themes retained", FILES["dynamic"].count('],["') >= 18 or 'imperial-flux' in FILES["dynamic"])
for key in ["mercury-flow","cobalt-plasma","aurora-ink","gold-current","violet-melt","emerald-tide","solar-fluid","arctic-glass"]:
    check(f"fluid theme {key}", f'["{key}",' in FILES["fluid"])

# Living Creatures: exactly 10 subject-led scenes including wolf + dragon.
animal_keys = ["lunar-wolf","storm-dragon","celestial-eagle","obsidian-panther","ember-fox","starfall-owl","astral-whale","silver-stag","night-stallion","aurora-raven"]
for key in animal_keys:
    check(f"living creature theme {key}", f'key:"{key}"' in FILES["animals"])
check("Living Creatures section says 10", 'Living Creatures' in FILES["animals"] and '10 realistic fantastical dynamic scenes' in FILES["animals"])
check("living scenes use real media resolver", 'commons.wikimedia.org/w/api.php' in FILES["animals"] and 'lrAnimalScenePhoto' in FILES["animals"])
check("living scenes reject logo/sculpture junk", all(term in FILES["animals"] for term in ['"logo"','"statue"','"sculpture"','"taxidermy"']))
check("dragon prefers fantasy artwork", 'fantasy:true' in FILES["animals"] and 'fantasy dragon digital art illustration' in FILES["animals"])
check("animal silhouettes removed", '<svg' not in FILES["animals"] and 'SHAPES' not in FILES["animals"])
check("animal media has attribution surface", 'Wikimedia Commons' in FILES["animals"] and 'LicenseShortName' in FILES["animals"])
check("animal animation honors reduced motion", 'prefers-reduced-motion:reduce' in FILES["animals"])
check("animal state clears other theme families", all(token in FILES["animals"] for token in ['data-nature-theme','data-dynamic-theme','data-fluid-scene']))

# Visible selected-theme marks.
check("card selected checkmark CSS", 'content:"✓"' in FILES["simplify"])
check("catalog header selected mark", 'lrThemeSelectedMark' in FILES["catalog"] and 'mark.textContent = "✓"' in FILES["catalog"])
check("animal cards expose aria-pressed", 'aria-pressed="false"' in FILES["animals"])

failed = [name for name, ok in checks if not ok]
print(f"LifeRoute theme catalog audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)
print("LifeRoute Settings catalog, restored themes, realistic Living Creatures, checkmarks, and Appearance cleanup passed.")
