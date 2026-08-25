from pathlib import Path
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
INDEX = DIST / "index.html"
checks = []


def require(value, label):
    checks.append((bool(value), label))


def read(name):
    path = DIST / name
    return path.read_text(errors="ignore") if path.is_file() else ""


require(DIST.is_dir(), "dist directory exists")
require(INDEX.is_file(), "dist/index.html exists")
html = INDEX.read_text(errors="ignore") if INDEX.is_file() else ""
expected_sha = (os.environ.get("GITHUB_SHA") or os.environ.get("BUILD_SHA") or "")[:8]
if expected_sha:
    require(f'name="liferoute-web-build" content="{expected_sha}"' in html, "web build marker matches exact SHA")

core = [
    "global-bridge.js", "calendar-hub.js", "auth-gate.js", "route-times.js", "smart-context.js",
    "live-location-v2.js", "selected-gap-routes.js", "saved-place-gap-options.js", "live-day.js",
    "end-home-route-web.js", "day-controls-v5.js", "rbt-tools.js", "client-picker-sync-v1.js",
    "client-profiles-v1.js", "client-profile-tools-v1.js", "mileage-tracker-web.js",
    "resources-hub-web.js", "toolbar-cleanup-v1.js", "visual-timer-v2.js", "first-then-back.js",
    "visual-resolver.js", "visual-quality-web.js", "visual-tools.js", "photo-source-picker-web.js",
    "visual-object-focus-v2.js", "visual-resolver-bridge.js", "day-route-experience.js",
    "boundary-stop-planner.js", "stop-place-search-v4.js", "stop-duration-v1.js",
    "day-navigation-runtime.js", "nature-settings-web.js", "settings-classic-themes-web.js",
    "photoreal-nature-web.js", "dynamic-themes-web.js", "fluid-scenes-v1.js",
    "dynamic-animals-v1.js", "theme-catalog-v3.js", "ui-simplify-v4.js",
    "refined-ui-v2.js", "aesthetic-polish-v1.js", "stability-runtime.js",
]
for name in core:
    require((DIST / name).is_file(), f"final artifact contains {name}")
    require(len(re.findall(rf'<script src="{re.escape(name)}(?:\?[^\"]*)?"></script>', html)) == 1,
            f"final HTML loads {name} exactly once")

browser = [
    "web-preview.js", "welcome.js", "nav-cleanup.js", "icloud-calendar-web.js",
    "google-calendar-web.js", "google-calendar-stability.js", "google-calendar-persistence-web.js",
    "web-routing-bridge.js", "web-store-search-fallback.js", "web-routing-resilience.js",
    "web-store-late-guard.js", "web-store-direct-v2.js", "web-store-panel-persistence.js",
]
for name in browser:
    require((DIST / name).is_file(), f"browser artifact contains {name}")
require(len(re.findall(r'<script src="web-preview\.js(?:\?[^\"]*)?"></script>', html)) == 1,
        "web-preview bootstrap loads exactly once")

# Syntax-check every deployed JavaScript file, not just the known feature list.
for path in sorted(DIST.glob("*.js")):
    result = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
    require(result.returncode == 0, f"JavaScript syntax valid: {path.name}")

# End-to-end feature contracts in the exact deployable artifact.
markers = {
    "client-picker-sync-v1.js": ["quickNoteClient", "sessionPlanClient", "refreshLifeRouteToolClients"],
    "client-profiles-v1.js": ["LifeRouteClientProfilesV1", "clientPreferredActivities", "clientCurrentTargets", "clientBehaviorsOfConcern", "liferoute:clients-changed"],
    "client-profile-tools-v1.js": ["applyLifeRouteClientProfileToTools", "sessionPlanTargets", "sessionPlanReinforcers", "profileAutofill"],
    "toolbar-cleanup-v1.js": ["LifeRouteToolbarCleanupV1", "child.dataset?.view === 'month'"],
    "stop-duration-v1.js": ["LifeRouteStopDurationV1", "stopMinutes"],
    "live-day.js": ["planned stop time", "scheduleDayNotifications"],
    "end-home-route-web.js": ["endDayAtHome", "End day at Home", "Route home", "endHomeRouteCard"],
    "day-controls-v5.js": ["startLiveDayActivity", "const clearDay = () =>", "data-lr-clear-day", "data-lr-clear-all", "liferoute:day-cleared", "Cleared ✓"],
    "mileage-tracker-web.js": ["Mileage tracker", "mileageToolCard", "LifeRoute-mileage-"],
    "resources-hub-web.js": ["WORK RESOURCE HUB", "openExternalURL", "noopener,noreferrer", "does not sign in to these services or store their credentials"],
    "live-location-v2.js": ["watchPosition", "clearWatch", "startLiveLocation", "freshnessMs"],
    "first-then-back.js": ["lifeRouteFirstThenEscape", "stopImmediatePropagation", "cancelOpenTimers", "overlayClassObserver"],
    "visual-timer-v2.js": ["CHIME_PERIOD_MS = 500", "START_HZ = 220", "END_HZ = 1320", "webkitAudioContext"],
    "visual-quality-web.js": ["cleanup", "shower", "strictCommonsSearch"],
    "visual-object-focus-v2.js": ["LifeRouteVisualObjectFocus", "requestVisionCrop", "heuristicSubjectCrop", "apple-vision-saliency", "getImageData", "toBlob"],
    "dynamic-animals-v1.js": ["Lunar Wolf", "Storm Dragon", "Wikimedia Commons", "prefers-reduced-motion:reduce"],
    "theme-catalog-v3.js": ["lifeRouteSettingsButton", "lrThemeSelectedMark"],
    "google-calendar-web.js": ["calendar.readonly", "AbortController"],
    "web-routing-bridge.js": ["requestRouteTimes", "searchStoreLocations", "AbortController"],
}
for name, required in markers.items():
    data = read(name)
    for marker in required:
        require(marker in data, f"{name} preserves {marker}")

# Performance/lifecycle invariants after final bundling.
require("setInterval(" not in read("client-picker-sync-v1.js"), "client picker has no polling loop")
require("fetch(" not in read("client-profiles-v1.js"), "rich client profile storage has no network fetch")
require("https://" not in read("client-profiles-v1.js") and "http://" not in read("client-profiles-v1.js"), "rich client profile storage has no remote endpoint")
require("fetch(" not in read("client-profile-tools-v1.js"), "client profile tool bridge has no network fetch")
require("https://" not in read("client-profile-tools-v1.js") and "http://" not in read("client-profile-tools-v1.js"), "client profile tool bridge has no remote endpoint")
require("observer.observe(document.body" not in read("theme-catalog-v3.js"), "theme catalog is not page-wide")
require("observer.observe(document.body" not in read("ui-simplify-v4.js"), "UI simplifier is not page-wide")
require("observer.observe(document.body" not in read("refined-ui-v2.js"), "refined UI is not page-wide")
require("characterData: true" not in read("ui-simplify-v4.js"), "UI simplifier ignores live text churn")
require("fetch(" not in read("visual-object-focus-v2.js"), "photo subject focusing stays local/on-device")
require("https://" not in read("visual-object-focus-v2.js"), "photo subject focusing has no remote endpoint")
require("setInterval(" not in read("visual-quality-web.js"), "visual-quality helper has no polling loop")
require("[600, 1200, 2400]" not in read("end-home-route-web.js"), "End-at-Home has no startup retry fanout")
require("[1000,2000,4000]" not in read("mileage-tracker-web.js"), "Mileage has no startup retry fanout")
require("[700, 1400, 2600]" not in read("resources-hub-web.js"), "Resources has no startup retry fanout")
require("SHAPES =" not in read("dynamic-animals-v1.js"), "Living Creatures does not restore flat silhouette system")

# Shared modules must not be dynamically loaded a second time by web-preview.
preview = read("web-preview.js")
for name in [
    "first-then-back.js", "visual-quality-web.js", "photo-source-picker-web.js",
    "end-home-route-web.js", "mileage-tracker-web.js", "resources-hub-web.js",
    "nature-settings-web.js", "settings-classic-themes-web.js",
    "photoreal-nature-web.js", "dynamic-themes-web.js",
]:
    require(f'loadPreviewScript("{name}")' not in preview, f"web preview does not duplicate-load {name}")

# Tools crash/lifecycle guarantees in the actual deployable artifact.
first_then = read("first-then-back.js")
rbt = read("rbt-tools.js")
visual_tools = read("visual-tools.js")
require("overlayContentObserver" not in first_then, "First/Then final artifact has no child-tree observer")
require("bodyObserver" not in first_then, "First/Then final artifact has no page-wide observer")
require("childList: true" not in first_then and "subtree: true" not in first_then, "First/Then final artifact cannot recurse on child mutation")
require('overlayClassObserver.observe(overlay, { attributes: true, attributeFilter: ["class"] })' in first_then, "First/Then final artifact observes class only")
require('if (timer.interval) clearInterval(timer.interval);\n    timer.interval = 0;\n    scheduleTimerAlert();' in rbt, "Paused visual timer clears base interval")
require('if (timer.running) pauseTimer();' in rbt, "Closing visual timer pauses and tears down countdown")
require('if (!overlay?.classList.contains("show")) return;' in visual_tools, "Hidden First/Then visuals do no regeneration work")

# Final artifact privacy/security checks. Detailed personal-fixture checks already
# run before this step; these protect against build-stage secrets or credentials.
corpus = "\n".join(path.read_text(errors="ignore") for path in DIST.rglob("*") if path.is_file())
for forbidden in [
    "BEGIN PRIVATE KEY", "BEGIN RSA PRIVATE KEY", "BEGIN EC PRIVATE KEY",
    "client_secret", "APPLE_PRIVATE_KEY", "MATCH_PASSWORD", "FASTLANE_PASSWORD",
]:
    require(forbidden.lower() not in corpus.lower(), f"artifact contains no {forbidden}")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute final web artifact audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print("FAIL:", label)
    raise SystemExit(1)
print("Final browser artifact feature parity, Clear Day, AI-assisted visuals, performance, crash-safe Tools, lifecycle, and privacy/security passed.")
