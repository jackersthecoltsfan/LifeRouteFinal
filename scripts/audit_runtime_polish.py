from pathlib import Path

ROOT = Path("LifeRoute/Web")
PREPARE = Path("scripts/prepare_build.sh").read_text()
INDEX = (ROOT / "index.html").read_text()
FIRST_THEN = (ROOT / "first-then-back.js").read_text()
LOCATION_JS = (ROOT / "live-location-v2.js").read_text()
LOCATION_PATCH = Path("scripts/patch_location_context.py").read_text()
VISUAL = (ROOT / "visual-object-focus-v2.js").read_text()
ANIMALS = (ROOT / "dynamic-animals-v1.js").read_text()

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

# Native/TestFlight startup owns the fixes rather than relying on Pages-only helpers.
for script in ["first-then-back.js", "photo-source-picker-web.js", "visual-object-focus-v2.js", "live-location-v2.js"]:
    check(f"native startup loads {script}", f'"{script}"' in PREPARE and f'<script src="{script}"></script>' in INDEX)

# First/Then close lifecycle: escape lives outside generated overlay and owns the click in capture phase.
check("First Then external escape exists", "lifeRouteFirstThenEscape" in FIRST_THEN)
check("First Then escape mounted on body", "document.body.appendChild(button)" in FIRST_THEN)
check("First Then close cancels delayed opens", "cancelOpenTimers()" in FIRST_THEN and "openRequested = false" in FIRST_THEN)
check("First Then close captures event", '"#lifeRouteFirstThenEscape,#firstThenClose"' in FIRST_THEN and "stopImmediatePropagation" in FIRST_THEN)
check("First Then supports Escape key", 'event.key !== "Escape"' in FIRST_THEN)
check("First Then old triple reopen removed", "[0, 30, 120]" not in FIRST_THEN)
check("First Then generated visual motion is subtle", "lrFirstThenLivingVisual" in FIRST_THEN)
check("First Then motion honors reduced motion", "prefers-reduced-motion:reduce" in FIRST_THEN)

# CoreLocation is a foreground stream after consent, not just one requestLocation call.
for token in [
    'case "startLiveLocation"', 'case "stopLiveLocation"', "startUpdatingLocation()", "stopUpdatingLocation()",
    "kCLLocationAccuracyNearestTenMeters", "distanceFilter = live ? 50", '"streaming": liveLocationStreaming'
]:
    check(f"live location native marker {token}", token in LOCATION_PATCH)
check("location unknown is nonfatal", "CLError" in LOCATION_PATCH and ".locationUnknown" in LOCATION_PATCH)
check("live location enabled only after user opt-in", "liferoute_live_location_enabled_v2" in LOCATION_JS and "rememberEnabled" in LOCATION_JS)
check("live location follows app visibility", "visibilitychange" in LOCATION_JS and "pagehide" in LOCATION_JS)
check("live location starts native stream", 'action: "startLiveLocation"' in LOCATION_JS)
check("live location stops native stream", 'action: "stopLiveLocation"' in LOCATION_JS)
check("web location has watch fallback", "watchPosition" in LOCATION_JS and "clearWatch" in LOCATION_JS)
check("location freshness tracked", "locationUpdatedAt" in LOCATION_JS and "freshnessMs" in LOCATION_JS)
check("location helper has no network dependency", "fetch(" not in LOCATION_JS and "http://" not in LOCATION_JS and "https://" not in LOCATION_JS)

# User photo preprocessing is local, subject-forward, and feeds a replacement File to visual-tools.
check("visual focus is local only", "fetch(" not in VISUAL and "XMLHttpRequest" not in VISUAL and "http://" not in VISUAL and "https://" not in VISUAL)
check("visual focus computes saliency", "subjectCrop" in VISUAL and "getImageData" in VISUAL and "threshold" in VISUAL and "saturation" in VISUAL)
check("visual focus uses edge energy", "const dx" in VISUAL and "const dy" in VISUAL)
check("visual focus recenters crop", "focusX" in VISUAL and "focusY" in VISUAL and "crop.left" in VISUAL and "crop.top" in VISUAL)
check("visual focus de-emphasizes background", 'blur(28px) saturate(.62)' in VISUAL and 'rgba(255,255,255,.56)' in VISUAL)
check("visual focus keeps sharp subject layer", 'saturate(1.13) contrast(1.08)' in VISUAL)
check("visual focus creates normalized 1024 image", "canvas.width = 1024" in VISUAL and "canvas.height = 1024" in VISUAL)
check("visual focus returns local JPEG File", 'canvas.toBlob(resolve, "image/jpeg"' in VISUAL and "new File([blob]" in VISUAL)
check("visual focus safely re-dispatches input", "new DataTransfer()" in VISUAL and 'input.dispatchEvent(new Event("change"' in VISUAL)
check("visual focus intercepts original once", "stopImmediatePropagation" in VISUAL and "lrObjectFocusBypass" in VISUAL)
check("visual focus draft motion honors reduced motion", "lrVisualDraftLiving" in VISUAL and "prefers-reduced-motion:reduce" in VISUAL)

# Creature themes are now living media scenes, not odd vector silhouettes.
check("living creatures have ten keys", ANIMALS.count(" key:\"") == 10)
check("living creatures contain wolf", 'key:"lunar-wolf"' in ANIMALS)
check("living creatures contain dragon", 'key:"storm-dragon"' in ANIMALS)
check("animal silhouettes absent", "<svg" not in ANIMALS and "SHAPES" not in ANIMALS)
check("animal media resolution uses Commons", "commons.wikimedia.org/w/api.php" in ANIMALS)
check("animal scene uses photographic layer", "lrAnimalScenePhoto" in ANIMALS and "background-size:cover" in ANIMALS)
check("animal scene has living atmosphere", "lrAnimalMist" in ANIMALS and "lrAnimalLight" in ANIMALS and "lrAnimalStars" in ANIMALS)
check("animal scene rejects junk media", all(word in ANIMALS for word in ['"logo"','"statue"','"sculpture"','"toy"','"taxidermy"']))
check("animal scene shows source attribution", "Wikimedia Commons" in ANIMALS and "LicenseShortName" in ANIMALS)
check("animal motion honors reduced motion", "prefers-reduced-motion:reduce" in ANIMALS)

failed = [name for name, ok in checks if not ok]
print(f"LifeRoute runtime polish audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)
print("LifeRoute First/Then, live-location, subject-focus visual generation, and living-scene audits passed.")
