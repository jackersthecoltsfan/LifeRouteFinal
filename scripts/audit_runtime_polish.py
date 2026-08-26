from pathlib import Path

ROOT = Path("LifeRoute/Web")
PREPARE = Path("scripts/prepare_build.sh").read_text()
INDEX = (ROOT / "index.html").read_text()
FIRST_THEN = (ROOT / "first-then-back.js").read_text()
LOCATION_JS = (ROOT / "live-location-v2.js").read_text()
LOCATION_PATCH = Path("scripts/patch_location_context.py").read_text()
VISUAL = (ROOT / "visual-object-focus-v2.js").read_text()
ANIMALS = (ROOT / "dynamic-animals-v1.js").read_text()
SWIFT = Path("LifeRoute/LifeRouteWebView.swift").read_text()
AESTHETIC = (ROOT / "aesthetic-polish-v1.js").read_text()
PREMIUM = (ROOT / "premium-interactions-v1.js").read_text()
LIQUID = (ROOT / "interaction-liquid-v4.js").read_text()
THEMES = (ROOT / "theme-experience-v4.js").read_text()
AUTOCOMPLETE = (ROOT / "universal-autocomplete-v2.js").read_text()
VISUAL_SCHEDULE = (ROOT / "visual-schedule-v1.js").read_text()
WELCOME = (ROOT / "welcome.js").read_text()

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

for script in ["first-then-back.js", "photo-source-picker-web.js", "visual-object-focus-v2.js", "live-location-v2.js"]:
    check(f"native startup loads {script}", f'"{script}"' in PREPARE and f'<script src="{script}"></script>' in INDEX)

for script in ["interaction-liquid-v4.js", "premium-interactions-v1.js", "theme-experience-v4.js", "universal-autocomplete-v2.js", "visual-schedule-v1.js", "welcome.js"]:
    check(f"experience loader includes {script}", script in AESTHETIC)
    check(f"experience module exists {script}", (ROOT / script).is_file() and (ROOT / script).stat().st_size > 300)

check("First Then external escape exists", "lifeRouteFirstThenEscape" in FIRST_THEN)
check("First Then escape mounted on body", "document.body.appendChild(button)" in FIRST_THEN)
check("First Then close cancels delayed opens", "cancelOpenTimers()" in FIRST_THEN and "openRequested = false" in FIRST_THEN)
check("First Then close captures event", '"#lifeRouteFirstThenEscape,#firstThenClose"' in FIRST_THEN and "stopImmediatePropagation" in FIRST_THEN)
check("First Then supports Escape key", 'event.key !== "Escape"' in FIRST_THEN)
check("First Then old triple reopen removed", "[0, 30, 120]" not in FIRST_THEN)
check("First Then generated visual motion is subtle", "lrFirstThenLivingVisual" in FIRST_THEN)
check("First Then motion honors reduced motion", "prefers-reduced-motion:reduce" in FIRST_THEN)

for token in [
    'case "startLiveLocation"', 'case "stopLiveLocation"', "startUpdatingLocation()", "stopUpdatingLocation()",
    "kCLLocationAccuracyNearestTenMeters", "distanceFilter = live ? 50", '"streaming": liveLocationStreaming',
    "CLLocationManager.locationServicesEnabled()", "allowsBackgroundLocationUpdates = false",
    "showsBackgroundLocationIndicator = false", "locationManager.requestLocation()", "manager.requestLocation()",
    "locations.reversed().first(where: { $0.horizontalAccuracy >= 0 })"
]:
    check(f"live location native marker {token}", token in LOCATION_PATCH)
check("location unknown is nonfatal", "CLError" in LOCATION_PATCH and ".locationUnknown" in LOCATION_PATCH)
check("native stream reports locating before first fix", 'payload: ["status": "locating"]' in LOCATION_PATCH)
check("live location enabled only after user opt-in", "liferoute_live_location_enabled_v2" in LOCATION_JS and "rememberEnabled" in LOCATION_JS)
check("live location follows app visibility", "visibilitychange" in LOCATION_JS and "pagehide" in LOCATION_JS)
check("live location starts native stream", "startLiveLocation" in LOCATION_JS and "postNative" in LOCATION_JS)
check("live location stops native stream", "stopLiveLocation" in LOCATION_JS and "postNative" in LOCATION_JS)
check("web location has watch fallback", "watchPosition" in LOCATION_JS and "clearWatch" in LOCATION_JS)
check("location freshness tracked", "locationUpdatedAt" in LOCATION_JS and "freshnessMs" in LOCATION_JS)
check("native acquisition has watchdog fallback", "NATIVE_FIX_TIMEOUT_MS" in LOCATION_JS and "armNativeWatchdog" in LOCATION_JS and "startWebFallback" in LOCATION_JS)
check("native bridge presence is verified", "nativeBridgeAvailable" in LOCATION_JS and "messageHandlers?.lifeRoute" in LOCATION_JS)
check("location helper has no external network dependency", "fetch(" not in LOCATION_JS and "http://" not in LOCATION_JS and "https://" not in LOCATION_JS)

# Liquid interaction architecture: selected indicator remains, while page motion is
# owned by one compositor-friendly premium transition instead of duplicate directional classes.
check("liquid selection indicator exists", "lrLiquidIndicator" in LIQUID and "layoutIndicator" in LIQUID)
check("indicator follows top and contextual tabs", all(token in LIQUID for token in [".tabs", ".lrContextTabs", ".lrPlaceCategories", ".setupSubnav"]))
check("tab screens receive lightweight page motion", "lrPremiumViewEnter" in PREMIUM and "translate3d(0,7px,0)" in PREMIUM)
check("liquid navigation avoids forced directional restart", "void pane.offsetWidth" not in LIQUID and "lrSlideFromRight" not in LIQUID)
check("liquid glass is concentrated on navigation hosts", "backdrop-filter:blur(8px)" in LIQUID and "--lr-glass-fill" in LIQUID and "@media(max-width:680px)" in LIQUID and "backdrop-filter:none!important" in LIQUID)
check("liquid motion honors Reduce Motion", "prefers-reduced-motion:reduce" in LIQUID)
check("liquid runtime has no global mutation observer", "observer.observe(document.body" not in LIQUID)
check("non-button controls get selection haptics", "input[type=\"checkbox\"]" in LIQUID and "nativeHaptic('selection')" in LIQUID)
check("aesthetic layer does not duplicate button haptics", "__lifeRouteHapticAt" not in AESTHETIC and "hapticStyle = control" not in AESTHETIC)
check("aesthetic layer does not duplicate page motion", "lrPageEnter" not in AESTHETIC)

check("theme categories exist", all(label in THEMES for label in ["Core", "Metal", "Scenery", "Dynamic", "Fluid", "Creatures"]))
check("classic selects become touch choice grids", "lrThemeChoiceGrid" in THEMES and "lrThemeSourceSelect" in THEMES)
check("theme signature backdrop exists", "lifeRouteThemeSignature" in THEMES)
for marker in ["lrObsidianSweep", "lrTidePulse", "lrHeatBreathe", 'data-theme="aurora"', 'data-theme="carbon"', 'data-theme="midnight"']:
    check(f"distinct theme motion marker {marker}", marker in THEMES)
check("theme dynamics pause during interaction", "html.lrInteractionBusy #lifeRouteThemeSignature" in THEMES)
check("theme dynamics honor Reduce Motion", "prefers-reduced-motion:reduce" in THEMES)

check("form autocomplete persists recent values", "liferoute_form_autocomplete_v2" in AUTOCOMPLETE and "remember = input" in AUTOCOMPLETE)
check("sensitive fields excluded", all(token in AUTOCOMPLETE for token in ["password", "passcode", "secret", "token", "lifeRouteAuthGate"]))
check("address autocomplete remains separately owned", "lrAddressAutocomplete" in AUTOCOMPLETE and "street-address" in AUTOCOMPLETE)
check("search fields request live web suggestions", "duckduckgo.com/ac/" in AUTOCOMPLETE and "en.wikipedia.org/w/api.php" in AUTOCOMPLETE)
check("resource search has web action", "resourceSearch" in AUTOCOMPLETE and "Search the web" in AUTOCOMPLETE)
check("autocomplete requests are debounced", "webTimer" in AUTOCOMPLETE and "setTimeout(()=>fetchWebSuggestions" in AUTOCOMPLETE)

check("visual schedule local state exists", "liferoute_visual_schedule_v1" in VISUAL_SCHEDULE)
check("visual schedule reuses visual library", "liferoute_visual_tools_v2" in VISUAL_SCHEDULE and "iconById" in VISUAL_SCHEDULE)
check("visual schedule supports reorder", "data-lr-step-up" in VISUAL_SCHEDULE and "data-lr-step-down" in VISUAL_SCHEDULE)
check("visual schedule supports completion", "toggleDone" in VISUAL_SCHEDULE and "data-lr-display-done" in VISUAL_SCHEDULE)
check("visual schedule has presentation mode", "lifeRouteVisualScheduleOverlay" in VISUAL_SCHEDULE and "Present schedule" in VISUAL_SCHEDULE)
check("visual schedule joins Visuals tool group", "openToolGroup" in VISUAL_SCHEDULE and "key === 'visuals'" in VISUAL_SCHEDULE)

check("welcome is first-run persistent", "liferoute_welcome_tour_v2_seen" in WELCOME and "markSeen" in WELCOME)
check("welcome waits for auth unlock", "liferoute-auth-unlocked" in WELCOME and "lifeRouteAuthGate" in WELCOME)
check("walkthrough drives real app tabs", all(token in WELCOME for token in ['data-view="today"', 'data-view="tools"', 'data-view="resources"', 'data-view="setup"']))
check("walkthrough highlights actual targets", "getBoundingClientRect" in WELCOME and "lrTourSpotlight" in WELCOME)
check("walkthrough can be replayed", "lrReplayTourButton" in WELCOME and "Replay" in WELCOME)
check("welcome motion honors Reduce Motion", "prefers-reduced-motion:reduce" in WELCOME)

for name, text in [("liquid",LIQUID),("premium",PREMIUM),("themes",THEMES),("autocomplete",AUTOCOMPLETE),("visual schedule",VISUAL_SCHEDULE),("welcome",WELCOME)]:
    for forbidden in ["scrollIntoView(", "scrollIntoView?.(", "window.scrollTo(", "window.scrollBy("]:
        check(f"{name} does not call {forbidden}", forbidden not in text)

check("visual focus is local only", "fetch(" not in VISUAL and "XMLHttpRequest" not in VISUAL and "http://" not in VISUAL and "https://" not in VISUAL)
check("visual focus has local saliency fallback", "heuristicSubjectCrop" in VISUAL and "getImageData" in VISUAL and "threshold" in VISUAL and "saturation" in VISUAL)
check("visual focus uses edge energy", "const dx" in VISUAL and "const dy" in VISUAL)
check("visual focus recenters crop", "focusX" in VISUAL and "focusY" in VISUAL and "crop.left" in VISUAL and "crop.top" in VISUAL)
check("visual focus uses Apple Vision when native", "requestVisionCrop" in VISUAL and 'action: "analyzeVisualSubject"' in VISUAL and "VNGenerateObjectnessBasedSaliencyImageRequest" in SWIFT)
check("visual focus AI has bounded fallback", "visionPending" in VISUAL and "1500" in VISUAL and "return heuristicSubjectCrop(image)" in VISUAL)
check("visual focus creates normalized 1024 image", "canvas.width = 1024" in VISUAL and "canvas.height = 1024" in VISUAL)
check("visual focus safely re-dispatches input", "new DataTransfer()" in VISUAL and 'input.dispatchEvent(new Event("change"' in VISUAL)
check("visual focus draft motion honors reduced motion", "lrVisualDraftLiving" in VISUAL and "prefers-reduced-motion:reduce" in VISUAL)

check("living creatures have ten keys", ANIMALS.count(" key:\"") == 10)
check("living creatures contain wolf", 'key:"lunar-wolf"' in ANIMALS)
check("living creatures contain dragon", 'key:"storm-dragon"' in ANIMALS)
check("animal silhouettes absent", "<svg" not in ANIMALS and "SHAPES" not in ANIMALS)
check("animal media resolution uses Commons", "commons.wikimedia.org/w/api.php" in ANIMALS)
check("animal scene uses photographic layer", "lrAnimalScenePhoto" in ANIMALS and "background-size:cover" in ANIMALS)
check("animal scene has living atmosphere", "lrAnimalMist" in ANIMALS and "lrAnimalLight" in ANIMALS and "lrAnimalStars" in ANIMALS)
check("animal motion honors reduced motion", "prefers-reduced-motion:reduce" in ANIMALS)

failed = [name for name, ok in checks if not ok]
print(f"LifeRoute runtime polish audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)
print("LifeRoute live location, optimized Liquid Glass navigation, premium motion, themes, autocomplete, Visual Schedule, walkthrough, and established runtime polish audits passed.")
