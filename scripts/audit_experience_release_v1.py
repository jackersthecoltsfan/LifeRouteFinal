from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"

files = {
    "liquid": (WEB / "interaction-liquid-v4.js").read_text(),
    "auto": (WEB / "universal-autocomplete-v2.js").read_text(),
    "theme": (WEB / "theme-experience-v4.js").read_text(),
    "schedule": (WEB / "visual-schedule-v1.js").read_text(),
    "welcome": (WEB / "welcome.js").read_text(),
    "aesthetic": (WEB / "aesthetic-polish-v1.js").read_text(),
}
checks = []

def require(condition, label):
    checks.append((bool(condition), label))

# One canonical experience owner per domain.
for marker in [
    "interaction-liquid-v4.js",
    "theme-experience-v4.js",
    "universal-autocomplete-v2.js",
    "visual-schedule-v1.js",
    "welcome.js",
]:
    require(marker in files["aesthetic"], f"experience loader includes {marker}")
require("liquid-interactions-v1.js" not in files["aesthetic"], "legacy duplicate Liquid layer is not loaded")
require("form-autocomplete-v2.js" not in files["aesthetic"], "legacy duplicate autocomplete layer is not loaded")

# Liquid selection movement + true submenu transitions.
for marker in [
    ".lrLiquidIndicator",
    "TAB_HOST_SELECTOR",
    ".lrThemeCategoryTabs",
    "const transitionTarget = (() =>",
    "host.matches('.lrPlaceCategories')",
    "host.matches('.lrContextTabs')",
    "host.matches('.lrThemeCategoryTabs')",
    ".lrSlideFromRight{animation:",
    ".lrSlideFromLeft{animation:",
    "prefers-reduced-motion: reduce",
]:
    require(marker in files["liquid"], f"Liquid interaction contains {marker}")

# Haptics should extend beyond plain buttons without creating another button-haptic owner.
require("input[type=\"checkbox\"]" in files["liquid"] and "input[type=\"range\"]" in files["liquid"],
        "selection haptics cover toggles and range controls")
require("document.addEventListener('change'" in files["liquid"], "selection haptics are event-driven")

# Universal autocomplete + web search, with private/sensitive exclusions.
for marker in [
    "input,textarea",
    "resourceSearch",
    "duckduckgo.com/ac/",
    "en.wikipedia.org/w/api.php",
    "Search the web for",
    "https://www.google.com/search?q=",
    "session note|clinical note",
    "input instanceof HTMLTextAreaElement && value.length > 80",
]:
    require(marker in files["auto"], f"universal autocomplete contains {marker}")
require("#lifeRouteAuthGate" in files["auto"], "auth credentials are excluded from autocomplete")

# Themes: clean category browser, distinct motion signatures, and interaction-pressure pause.
for marker in [
    ".lrThemeCategoryTabs",
    ".lrThemeChoiceGrid",
    "#lifeRouteThemeSignature",
    "lrObsidianSweep",
    "lrTidePulse",
    "lrHeatBreathe",
    "html.lrInteractionBusy #lifeRouteThemeSignature",
    "prefers-reduced-motion:reduce",
]:
    require(marker in files["theme"], f"theme experience contains {marker}")

# Interactive walkthrough and replay path.
for marker in [
    "liferoute_welcome_tour_v2_seen",
    "Show me around",
    "lrTourSpotlight",
    "Visual Schedule",
    "live web suggestions",
    "Replay",
    "prefers-reduced-motion:reduce",
]:
    require(marker in files["welcome"], f"welcome walkthrough contains {marker}")

# Visual Schedule is a real local tool, not a placeholder.
for marker in [
    "visualScheduleTool",
    "liferoute_visual_schedule_v1",
    "const MAX_STEPS = 12;",
    "Present schedule",
    "data-lr-step-up",
    "data-lr-step-down",
    "data-lr-step-done",
    "LifeRouteToolbarCleanupV1",
]:
    require(marker in files["schedule"], f"Visual Schedule contains {marker}")

# Hard no-programmatic-document-scroll contract for every newly introduced experience layer.
for name in ["liquid", "auto", "theme", "schedule", "welcome"]:
    source = files[name]
    for forbidden in ["scrollIntoView(", "window.scrollTo(", "window.scrollBy("]:
        require(forbidden not in source, f"{name} never calls {forbidden}")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute unified experience audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print("FAIL:", label)
    raise SystemExit(1)
print("Liquid navigation, submenu slides, haptics, privacy-safe universal autocomplete, unique themes, walkthrough, Visual Schedule, and no-auto-scroll passed.")
