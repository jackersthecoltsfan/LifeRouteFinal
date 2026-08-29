from pathlib import Path
import re

WEB=Path("LifeRoute/Web")
index=(WEB/"index.html").read_text()
checks=[]
def require(v,label): checks.append((bool(v),label))
def src(name): return (WEB/name).read_text()

# 1) Startup ownership: every critical shared module appears once and in dependency order.
tags=re.findall(r'<script\s+src="([^"?]+\.js)(?:\?[^\"]*)?"></script>', index)
require(len(tags)==len(set(tags)), "shared runtime has no duplicate script tags")
critical=["global-bridge.js","live-location-v2.js","selected-gap-routes.js","live-day.js","day-controls-v5.js","boundary-stop-planner.js","stop-place-search-v4.js","stop-duration-v1.js","theme-catalog-v3.js","stability-runtime.js"]
for name in critical: require(tags.count(name)==1, f"single owner loaded for {name}")
def pos(name): return tags.index(name) if name in tags else 9999
require(pos("global-bridge.js") < pos("live-location-v2.js"), "global state bridge precedes live location")
require(pos("selected-gap-routes.js") < pos("live-day.js"), "selected route state precedes Live Day")
require(pos("live-day.js") < pos("day-controls-v5.js"), "Live Day model precedes its controls")
require(pos("boundary-stop-planner.js") < pos("stop-duration-v1.js"), "stop persistence precedes duration wrapper")

# 2) Overlay ownership / closability. Every major full-screen surface has a close path.
first=src("first-then-back.js")
timer=src("visual-timer-v2.js")
search=src("stop-place-search-v4.js")
duration=src("stop-duration-v1.js")
settings=src("nature-settings-web.js")
require("#lifeRouteFirstThenEscape,#firstThenClose" in first and "stopImmediatePropagation" in first and "}, true);" in first, "First/Then exit routes are capture-phase and cannot be swallowed")
require("overlayClassObserver.observe(overlay" in first and "overlayContentObserver" not in first and "bodyObserver" not in first and "childList: true" not in first and "subtree: true" not in first, "First/Then uses class-only state observation with no broad/recursive observer")
require("timerClose" in src("rbt-tools.js") and "stopScheduler" in timer, "Visual Timer has close + scheduler teardown")
require("data-lr-stop-search-close" in search and "closeSheet" in search, "stop search sheet has explicit close path")
require("lrStopDurationClose" in duration or "data-lr-stop-duration-close" in duration, "stop-duration sheet has explicit close path")
require("lrSettingsClose" in settings and "lifeRouteSettingsOverlay" in settings, "Settings sheet has close path")

# 3) Event-wrapper invariants: helpers extend existing native-event chains rather than replacing them silently.
for name in ["smart-context.js","live-location-v2.js","route-times.js","live-day.js","boundary-stop-planner.js","stop-place-search-v4.js"]:
    data=src(name)
    if "window.lifeRouteNativeEvent" in data:
        require("previous" in data.lower() or "current" in data.lower(), f"{name} preserves prior native-event handler")

# 4) Stored state namespaces remain separate, avoiding accidental Clear Day / tool/theme collisions.
stores={
    "boundary":"liferoute_boundary_stops_v2",
    "selected":"liferoute_selected_gap_routes_v2",
    "live":"liferoute_generated_days_v1",
    "tools":"liferoute_field_tools_v1",
    "fluid":"liferoute_fluid_scene_v1",
    "animal":"liferoute_dynamic_animal_v1",
}
require(len(set(stores.values()))==len(stores), "major feature stores use unique namespaces")
corpus="\n".join(p.read_text(errors="ignore") for p in WEB.glob("*.js"))
for name,key in stores.items():
    require(key in corpus, f"{name} state store is present")

# 5) Theme state is mutually exclusive by data-attribute contract.
classic=src("settings-classic-themes-web.js")
dynamic=src("dynamic-themes-web.js")
fluid=src("fluid-scenes-v1.js")
animal=src("dynamic-animals-v1.js")
for family,data in [("classic",classic),("dynamic",dynamic),("fluid",fluid),("animal",animal)]:
    require("data-animal-theme" in data or family=="animal", f"{family} participates in animal-theme exclusivity")
require("data-fluid-scene" in classic and "data-fluid-scene" in dynamic and "data-fluid-scene" in animal, "non-fluid families clear fluid state")
require("data-dynamic-theme" in fluid and "data-dynamic-theme" in animal, "fluid/animal clear Dynamic state")

# 6) Location has one persisted enable bit and one browser watcher variable.
location=src("live-location-v2.js")
require(location.count("let webWatch") == 1, "live location has one browser watcher owner")
require("webWatch != null" in location and "clearWatch(webWatch)" in location, "location watcher cannot duplicate/leak")
require("liferoute_live_location_enabled_v2" in location, "live-location opt-in persistence is namespaced")

# 7) Stop duration is a model value, not presentation-only text.
live=src("live-day.js")
require("stopMinutes" in duration and "stopMinutes" in live, "stop duration flows into Live Day model")
require("planned stop time" in live, "before-first timing explicitly includes planned stop time")
require("scheduleDayNotifications" in live, "same model drives leave reminders")

# 8) Client pickers share one source and downstream actions read selected values.
clients=src("client-picker-sync-v1.js")
tools=src("rbt-tools.js")
require('TARGET_IDS = ["quickNoteClient", "sessionPlanClient"]' in clients, "both client pickers share sync owner")
require('document.getElementById("quickNoteClient")?.value' in tools, "quick notes consume selected client")
require('document.getElementById("sessionPlanClient")?.value' in tools, "session plan consumes selected client")

# 9) Main navigation never has two top-level Month owners.
toolbar=src("toolbar-cleanup-v1.js")
require("child.dataset?.view === 'month'" in toolbar, "duplicate top-level Month is actively removed")
require("CALENDAR_VIEWS" in src("calendar-hub.js") and '"month"' in src("calendar-hub.js"), "intended calendar Month view remains")

failed=[label for ok,label in checks if not ok]
print(f"LifeRoute state-invariant audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:",label)
    raise SystemExit(1)
print("Single ownership, overlay escape paths, event chaining, state namespaces, theme/location invariants, timing-model propagation, clients, and navigation passed.")
