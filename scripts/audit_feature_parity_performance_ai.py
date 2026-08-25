from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"

checks = []

def require(value, label):
    checks.append((bool(value), label))

def read(path):
    return Path(path).read_text(errors="ignore")

prepare = read(PREPARE)
index = read(WEB / "index.html")
day = read(WEB / "day-controls-v5.js")
end_home = read(WEB / "end-home-route-web.js")
mileage = read(WEB / "mileage-tracker-web.js")
resources = read(WEB / "resources-hub-web.js")
quality = read(WEB / "visual-quality-web.js")
visual = read(WEB / "visual-object-focus-v2.js")
ui = read(WEB / "ui-simplify-v4.js")
refined = read(WEB / "refined-ui-v2.js")
stability = read(WEB / "stability-runtime.js")
preview = read(ROOT / "scripts" / "web-preview.js")
swift = read(SWIFT)

# 1) Feature parity: these are product features, not browser-only adapters.
shared = [
    "end-home-route-web.js",
    "mileage-tracker-web.js",
    "resources-hub-web.js",
    "visual-quality-web.js",
]
for name in shared:
    require(f'<script src="{name}"></script>' in index, f"shared prepared app loads {name}")
    require(index.count(f'<script src="{name}"></script>') == 1, f"{name} loads exactly once")

require('id = "mileageToolCard"' in mileage or 'id="mileageToolCard"' in mileage, "Mileage tracker card still exists")
require('button.dataset.view = "resources"' in resources, "Resources hub tab still exists")
require('id = "endHomeOption"' in end_home or 'id="endHomeOption"' in end_home, "End-at-Home control still exists")
require('endDayAtHome' in end_home and 'Route home' in end_home, "End-at-Home preference and route action remain")
require('window.prefs?.endDayAtHome' in read(WEB / "day-controls-v5.js"), "Live Activity includes End-at-Home state")
require('cleanup' in quality and 'shower' in quality, "strict visual-quality profiles remain")

# 2) Clear Day must act in native WKWebView without JS alert/confirm UI and
# must clear only the selected date's route-plan state.
require('window.selectedDate || (typeof selectedDate !== "undefined" ? selectedDate : "")' in day, "Clear Day resolves selected date robustly")
clear_day_segment = day[day.find("const clearDay ="):day.find("const clearAll =")]
require("window.confirm" not in clear_day_segment, "Clear Day no longer depends on native JavaScript confirm")
require('window.endLifeRouteDay?.()' in clear_day_segment, "Clear Day ends active Live Day state")
require('clearDateKeys(GENERATED_STORE, day)' in clear_day_segment, "Clear Day clears generated state for selected day")
require('clearLifeRouteGapRoutesForDay(day)' in clear_day_segment, "Clear Day clears selected-day gap routes through owning module")
require('clearLifeRouteBoundaryStopsForDay(day)' in clear_day_segment, "Clear Day clears selected-day boundary stops through owning module")
require('window.events = window.events.filter' not in clear_day_segment, "Clear Day preserves all calendar/manual appointments")
require('window.persist?.()' not in clear_day_segment, "Clear Day does not persist unrelated event mutations")
require('liferoute:day-cleared' in clear_day_segment and 'Cleared ✓' in clear_day_segment, "Clear Day gives visible completion feedback")
require('appointments and saved data kept' in clear_day_segment, "Clear Day status explicitly confirms preserved data")

# 3) Native speed: remove obsolete startup retries/polling and broad UI observers.
for data, label in [
    (end_home, "End-at-Home"),
    (mileage, "Mileage"),
    (resources, "Resources"),
]:
    require("[600, 1200, 2400]" not in data and "[1000,2000,4000]" not in data and "[700, 1400, 2600]" not in data, f"{label} has no multi-second startup retry fanout")
require("setInterval(" not in quality, "Visual-quality helper has no polling interval")
require('observer.observe(document.body' not in ui, "UI simplifier no longer watches entire document")
require('observer.observe(document.body' not in refined, "Refined UI no longer watches entire document")
require('document.getElementById("today")' in ui, "UI simplifier is scoped to Today")
require('document.getElementById("today")' in refined and 'requestAnimationFrame' in refined, "Refined UI is Today-scoped and frame-coalesced")
require('html[data-life-route-runtime="native"] .card' in stability and 'backdrop-filter:none!important' in stability, "native cards avoid per-card backdrop compositing")
require('html[data-life-route-runtime="native"] body{background-attachment:scroll!important}' in stability, "native background avoids fixed attachment compositing")
require('[100, 350, 900, 1800]' not in stability, "bottom toolbar has no redundant startup retry fanout")
for name in shared:
    require(f'loadPreviewScript("{name}")' not in preview, f"web preview does not dynamically reload shared {name}")
require('loadPreviewScript("first-then-back.js")' not in preview, "web preview does not duplicate-load First/Then")
require('loadPreviewScript("photo-source-picker-web.js")' not in preview, "web preview does not duplicate-load photo picker")
require('loadPreviewScript("nature-settings-web.js")' not in preview, "web preview does not duplicate-load shared theme runtime")

# 4) Free/private AI assist: Apple Vision on device, with local browser fallback.
require("import Vision" in swift, "native build imports Apple Vision")
require('case "analyzeVisualSubject":' in swift, "native bridge exposes visual subject analysis")
require("VNGenerateObjectnessBasedSaliencyImageRequest" in swift, "Apple Vision objectness saliency drives subject detection")
require('"engine": "apple-vision-saliency"' in swift, "native result identifies Apple Vision engine")
require('case "openExternalURL":' in swift and "UIApplication.shared.open(url)" in swift, "native Resources links open outside LifeRoute")
require('action: "analyzeVisualSubject"' in visual, "photo pipeline requests on-device AI when native")
require('requestVisionCrop' in visual and 'heuristicSubjectCrop' in visual, "photo pipeline has AI path and local fallback")
require('visionPending' in visual and '1500' in visual, "AI request is bounded and cannot hang photo generation")
require('toDataURL("image/jpeg", .74)' in visual, "AI analysis uses a bounded compressed local image")
require('fetch(' not in visual and 'https://' not in visual, "photo AI pipeline sends no image to a network service")
require('Main subject focused with on-device AI' in visual, "user-visible status distinguishes on-device AI focus")

# 5) Shared startup remains deterministic and feature patches/audit are mandatory.
tags = re.findall(r'<script\s+src="([^"?]+\.js)(?:\?[^\"]*)?"></script>', index)
require(len(tags) == len(set(tags)), "prepared shared runtime has no duplicate script tags")
require('patch_feature_regressions_v2.py' in prepare, "feature regression patch is mandatory")
require('patch_performance_cleanup_v2.py' in prepare, "performance cleanup patch is mandatory")
require('patch_visual_ai_v1.py' in prepare, "visual AI patch is mandatory")
require('audit_feature_parity_performance_ai.py' in prepare, "feature parity/performance/AI audit is mandatory")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute feature parity/performance/AI audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print("FAIL:", label)
    raise SystemExit(1)
print("Feature parity, route-scoped Clear Day, native compositing/performance cleanup, and free on-device Apple Vision photo AI passed.")
