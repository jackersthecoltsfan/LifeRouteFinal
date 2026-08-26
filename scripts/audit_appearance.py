from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PREPARE = ROOT / "scripts" / "prepare_build.sh"

failures: list[str] = []
passes: list[str] = []


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        failures.append(f"read {path.relative_to(ROOT)}: {exc}")
        return ""


def check(condition: bool, label: str) -> None:
    (passes if condition else failures).append(label)


index = read(WEB / "index.html")
refined = read(WEB / "refined-ui-v2.js")
simplify = read(WEB / "ui-simplify-v4.js")
day = read(WEB / "day-controls-v5.js")
timer = read(WEB / "visual-timer-v2.js")
first_then = read(WEB / "first-then-back.js")
themes = read(WEB / "theme-catalog-v3.js")
animals = read(WEB / "dynamic-animals-v1.js")
fluid = read(WEB / "fluid-scenes-v1.js")
polish = read(WEB / "aesthetic-polish-v1.js")
premium = read(WEB / "premium-interactions-v1.js")
accordion = read(WEB / "theme-accordion-v1.js")
prepare = read(PREPARE)

# Core visual system and readable color tokens.
for marker in ["--bg:", "--panel:", "--text:", "--muted:", "--blue:", "--gold:"]:
    check(marker in index, f"base visual token exists: {marker}")
check("font-family:Inter" in index and "-apple-system" in index, "system-native typography stack exists")
check("max-width:860px" in refined, "refined content width stays focused")
check("--lr-radius:17px" in refined, "consistent refined corner radius exists")
check("backdrop-filter:blur(18px)" in refined, "navigation glass treatment exists")

# Day screen must stay visually minimal.
check("#today .hero.lrDayHeroRemoved{display:none!important}" in day, "redundant Day hero is removed")
check("background:transparent!important" in day and "lrDayCommandStrip" in day, "Day command strip is visually lightweight")
check("lrClearAll" in day and "var(--red)" in day, "destructive Clear all is visually distinguished")
check("lrEndHomeCompact" in day, "End at Home control uses compact treatment")

# Theme selection should be legible and selected state obvious.
check('content:"✓"' in simplify, "selected theme cards show a checkmark")
check("lrThemeSelectedMark" in simplify, "theme select sections show selected mark")
check("lifeRouteDynamicAnimalSection" in themes, "living-creature theme family is catalogued in Settings")
check("prefers-reduced-motion:reduce" in animals, "living creature scenes respect reduced motion")
check("prefers-reduced-motion:reduce" in fluid, "fluid scenes respect reduced motion")

# Premium interaction system.
for marker in [
    "lifeRoutePremiumInteractionsV1Styles",
    "lrPremiumIconSpin",
    "lrPremiumIconPulse",
    "lrPremiumIconAdvance",
    "lrPremiumViewEnter",
    "lrPremiumSheetIn",
    "LifeRoutePremiumInteractions",
    "prefers-reduced-motion:reduce",
]:
    check(marker in premium, f"premium interaction contract exists: {marker}")
check("window.scrollTo" not in premium and ".scrollTo(" not in premium, "premium interactions never programmatically move document scroll")
check("action:'haptic'" in premium, "premium interaction layer can reach native haptics")
check("observer.observe(document.body" not in premium and "subtree:true" not in premium, "premium interaction observer never watches the whole document subtree")
check("offsetWidth" not in premium and "getBoundingClientRect" not in premium, "premium interactions avoid forced synchronous layout reads")
check("filter:blur(2px)" not in premium and "filter:brightness" not in premium, "premium tap and navigation motion avoids expensive animated filters")
check("syncCalendarSelection" in premium and "aria-selected" in premium, "Day Week Month selected state updates immediately")
check("#lifeRouteThemeFX .fxOrb" in premium and "animation:none!important" in premium, "mobile theme effects are reduced to protect frame rate")

# Categorized theme accordions.
for marker in [
    "lifeRouteThemeAccordionV1Styles",
    "lrThemeAccordionHead",
    "lrThemeAccordionBody",
    "aria-expanded",
    "['lifeRouteCoreThemeSection',['Classic'",
    "['lifeRouteMetallicWaveThemeSection',['Metallic'",
    "['lifeRouteDynamicThemeSection',['Dynamic'",
    "['lifeRouteFluidSceneSection',['Fluid'",
    "['lifeRouteDynamicAnimalSection',['Living'",
    "['Scenery','Nature-inspired visual environments']",
    "prefers-reduced-motion:reduce",
]:
    check(marker in accordion, f"theme accordion contract exists: {marker}")
check("isActiveSection(section)" in accordion and "section.classList.add('isOpen')" in accordion, "active theme category opens automatically")
check("observer.observe(document.body" not in accordion, "theme accordion never watches the whole document")
check("observer.observe(overlay" in accordion and "queueSync" in accordion, "theme accordion observation is Settings-scoped and frame-coalesced")
check("backdrop-filter:none!important" in accordion, "theme accordion removes expensive mobile glass blur")

# Visual Timer / First-Then overlays should look intentional rather than utility-default.
check("lrVisualTimerV2" in timer and "linear-gradient(155deg,#030913" in timer, "visual timer has dedicated futuristic presentation")
check("font-variant-numeric:tabular-nums" in timer, "timer digits remain visually stable")
check("lifeRouteFirstThenEscape" in first_then, "First/Then has a persistent polished Back control")

# Final shared aesthetic polish and mobile ergonomics.
for marker in [
    "overflow-x:hidden",
    "-webkit-font-smoothing:antialiased",
    "button:focus-visible",
    "outline:2px solid",
    "min-height:44px!important",
    "input,select{min-height:44px!important}",
    "overflow-wrap:anywhere",
    "pointer-events:none!important",
    "prefers-reduced-motion:reduce",
]:
    check(marker in polish, f"final aesthetic guardrail: {marker}")
check("premium-interactions-v1.js" in polish, "premium interactions are wired into shared startup")
check("theme-accordion-v1.js" in polish, "theme accordions are wired into shared startup")

# Smoothness: appearance work stays structural, but is scoped to the UI it owns
# instead of traversing every Tools/Resources/overlay change in the application.
check("characterData: true" not in simplify, "appearance observer ignores live text-only mutations")
check('observer.observe(document.body' not in simplify, "appearance simplifier does not watch entire document")
check('document.getElementById("today")' in simplify and 'document.getElementById("lifeRouteSettingsOverlay")' in simplify, "appearance simplifier watches Today and Settings only")
check('observer.observe(document.body' not in refined, "refined UI does not watch entire document")
check('document.getElementById("today")' in refined and "requestAnimationFrame" in refined, "refined UI is Today-scoped and frame-coalesced")

# Shared build wiring. Web and native/TestFlight must receive the same final appearance layer.
check('"aesthetic-polish-v1.js"' in prepare, "prepared build includes final aesthetic polish")
try:
    check(prepare.index('"refined-ui-v2.js"') < prepare.index('"aesthetic-polish-v1.js"') < prepare.index('"stability-runtime.js"'), "aesthetic polish loads after refined UI and before stability runtime")
except ValueError:
    check(False, "aesthetic polish loads after refined UI and before stability runtime")
check("python3 scripts/audit_appearance.py" in prepare, "appearance audit is enforced during build preparation")

print(f"LifeRoute appearance audit: {len(passes)} passed, {len(failures)} failed")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)
print("LifeRoute appearance, premium interactions, categorized themes, mobile ergonomics, smoothness, and aesthetic consistency audit passed.")
