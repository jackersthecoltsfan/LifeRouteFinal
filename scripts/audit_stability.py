from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
INDEX = WEB / "index.html"
TESTFLIGHT = ROOT / ".github" / "workflows" / "testflight.yml"
AUTO_TESTFLIGHT = ROOT / ".github" / "workflows" / "auto-testflight.yml"
PREVIEW = ROOT / "scripts" / "web-preview.js"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
PAGES = ROOT / ".github" / "workflows" / "pages.yml"
IOS_CI = ROOT / ".github" / "workflows" / "ios-ci.yml"

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


swift = read(SWIFT)
index = read(INDEX)
stability = read(WEB / "stability-runtime.js")
themes = read(WEB / "live-themes.js")
refined = read(WEB / "refined-ui-v2.js")
live_day = read(WEB / "live-day.js")
boundary = read(WEB / "boundary-stop-planner.js")
day_route = read(WEB / "day-route-experience.js")
day_nav = read(WEB / "day-navigation-runtime.js")
photo = read(WEB / "photoreal-nature-web.js")
visual_timer = read(WEB / "visual-timer-v2.js")
first_then = read(WEB / "first-then-back.js")
preview = read(PREVIEW)
testflight = read(TESTFLIGHT)
auto_testflight = read(AUTO_TESTFLIGHT)
prepare = read(PREPARE)
pages = read(PAGES)
ios_ci = read(IOS_CI)

# Native scroll/touch correctness: prevent the exact rubber-band state that can
# expose a transparent WKWebView background above the real UI.
for marker in [
    "webView.scrollView.bounces = false",
    "webView.scrollView.alwaysBounceVertical = false",
    "webView.scrollView.alwaysBounceHorizontal = false",
    "webView.scrollView.delaysContentTouches = false",
    "webView.scrollView.isDirectionalLockEnabled = true",
    "webView.scrollView.contentInset = .zero",
    "webView.scrollView.scrollIndicatorInsets = .zero",
    "lifeRouteNativeRuntimeBootstrap",
]:
    check(marker in swift, f"native stability: {marker}")

# Bottom actions must resolve to real functions and get durable listeners.
check("function refreshCalendars(){" in index, "base Refresh action is defined")
check("function optimizeWeek(){" in index, "base Find gaps action is defined")
check("window.refreshCalendars = function lifeRouteStableRefreshCalendars" in stability, "stable Refresh action installed")
check("window.optimizeWeek = function lifeRouteStableOptimizeWeek" in stability, "stable Find gaps action installed")
check("removeAttribute(\"onclick\")" in stability and "lifeRouteStableBound" in stability, "bottom buttons use durable event listeners")
check(".bottom,.bottomin,.bottomin button{pointer-events:auto!important}" in stability, "bottom controls cannot lose pointer events")

# Find-a-stop controls keep both a direct fallback and delegated capture handler.
check("data-lr-boundary-open" in day_route and "lifeRouteOpenBoundaryPlanner" in day_route, "Find a stop direct fallback exists")
check('document.addEventListener("click", handleClick, true)' in boundary, "Find a stop delegated capture handler exists")
check(".lrBoundaryGap,.lrBoundarySummary,.lrBoundaryOpen,.lrBoundaryGap button{pointer-events:auto!important}" in stability, "Find-a-stop touch targets stay interactive")
check(".lrBoundaryOpen,.lrBoundaryGap button{position:relative;z-index:2}" in stability, "Find-a-stop targets sit above decorative layers")
check("Store search unavailable" in boundary and "Search timed out" in boundary, "store lookup never fails silently")
check("routeReadyPlaces" in boundary and "routeReadyTodos" in boundary, "boundary planner has both Saved Places and errands")

# Performance: native metallic background must not run a permanent 60-FPS DOM
# mutation loop; global presentation polishing is frame-coalesced.
check("__lifeRouteThemePerformanceV2" in themes, "metallic background uses performance-v2 loop")
check("const shouldAnimate = () => !nativeRuntime" in themes, "native metallic background animation is static")
check("timestamp - lastFrame < 50" in themes, "web metallic animation is capped near 20 FPS")
check("queuePolish" in refined and "new MutationObserver(queuePolish)" in refined, "UI mutation polishing is frame-coalesced")
check("document.hidden || !document.querySelector(\"[data-live-day-countdown]\")" in live_day, "Live Day ticker sleeps when idle")
check("attempts > 80" not in day_nav and "[100, 300, 800]" in day_nav, "Day navigation avoids long startup polling")
check("attempts >= 30" not in boundary and "[180, 550, 1400]" in boundary, "Boundary planner avoids long startup polling")
check('html[data-life-route-runtime="native"] #lifeRouteThemeFX .fxOrb' in stability, "native legacy theme FX have explicit performance rules")
check("animation:none!important;will-change:auto!important" in stability, "native legacy theme FX do not animate continuously")

# Overlay/runtime lifecycle checks: tools should do work only while they are active.
check("if (scheduler || !overlay()?.classList.contains(\"show\")) return" in visual_timer, "visual timer scheduler starts only while visible")
check("document.visibilityState === \"hidden\"" in visual_timer and "stopScheduler" in visual_timer, "visual timer sleeps in background")
check("bodyObserver.disconnect()" in visual_timer, "visual timer lazy DOM observer disconnects")
check("overlayClassObserver.observe(overlay" in first_then and 'attributeFilter: ["class"]' in first_then, "First/Then class observer is overlay-scoped")
check("overlayContentObserver" not in first_then and "childList: true" not in first_then and "subtree: true" not in first_then, "First/Then has no recursive content observer")
check("bodyObserver" not in first_then, "First/Then has no document-wide mutation observer")
check("will-change:transform,filter" not in first_then, "First/Then avoids permanent filter compositing hint")

# Shared mobile compositing/overscroll guardrails.
for marker in [
    "overscroll-behavior-x:none",
    "overscroll-behavior-y:none",
    'root.dataset.lifeRouteRuntime = isNative ? "native" : "web"',
    'html[data-life-route-runtime="native"] .bottom',
    '@media(max-width:700px) and (pointer:coarse)',
    'html[data-life-route-runtime="web"] .dynC{display:none!important}',
]:
    check(marker in stability, f"shared runtime guardrail: {marker}")

# Core build wiring: stability fixes are only useful if both release surfaces
# actually include them after build preparation.
check('"stability-runtime.js"' in prepare, "prepared iPhone/web core includes stability runtime")
check('"visual-timer-v2.js"' in prepare, "prepared iPhone/web core includes visual timer v2")
check("patch_stability.py" in prepare, "prepared build applies native stability patch")
check("python3 scripts/audit_stability.py" in prepare, "prepare build runs stability audit")
check("python3 scripts/audit_visual_timer.py" in prepare, "prepare build runs visual timer audit")
check("python3 scripts/audit_liferoute_build.py" in ios_ci, "iOS CI runs full regression audit")
check("python3 scripts/audit_liferoute_build.py" in pages, "Pages runs full regression audit")
check("stability-runtime.js" in pages and "visual-timer-v2.js" in pages, "Pages artifact validates stability and timer runtimes")

# Web helper order and mobile asset cost.
check("script.async = false" in preview, "web helper scripts execute deterministically")
try:
    check(preview.index('loadPreviewScript("web-routing-bridge.js")') < preview.index('loadPreviewScript("google-calendar-web.js")'), "web routing bridge loads before calendar helpers")
except ValueError:
    check(False, "web routing bridge loads before calendar helpers")
check("w=1800" in photo and "w=2400" not in photo, "web scenery photos use bounded high-resolution assets")

# Release safety: TestFlight itself stays manually dispatchable, while a separate
# guarded dispatcher may start it only after the current main commit passes CI.
check("workflow_dispatch" in testflight, "TestFlight remains manually dispatchable")
check(not re.search(r"^\s*push\s*:", testflight, flags=re.M), "TestFlight has no direct push trigger")
check(AUTO_TESTFLIGHT.is_file(), "automatic TestFlight dispatcher exists")
check('workflows: ["iOS Build Check"]' in auto_testflight, "automatic TestFlight waits for iOS Build Check")
check("github.event.workflow_run.conclusion == 'success'" in auto_testflight, "automatic TestFlight requires successful CI")
check("github.event.workflow_run.head_branch == 'main'" in auto_testflight, "automatic TestFlight only accepts main")
check("CURRENT_SHA" in auto_testflight and "VALIDATED_SHA" in auto_testflight, "automatic TestFlight rejects stale validated commits")
check('COMMIT_MESSAGE" == *"[web-only]"*' in auto_testflight or "[web-only]" in auto_testflight, "automatic TestFlight honors web-only release guard")
check('COMMIT_MESSAGE" == *"[no-testflight]"*' in auto_testflight or "[no-testflight]" in auto_testflight, "automatic TestFlight honors no-TestFlight release guard")
check("gh workflow run testflight.yml" in auto_testflight, "automatic dispatcher invokes the audited TestFlight workflow")

print(f"LifeRoute stability audit: {len(passes)} passed, {len(failures)} failed")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)
print("LifeRoute native + web stability audit passed.")
