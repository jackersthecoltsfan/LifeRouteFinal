from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TIMER = ROOT / "LifeRoute" / "Web" / "visual-timer-v2.js"
RBT = ROOT / "LifeRoute" / "Web" / "rbt-tools.js"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
PAGES = ROOT / ".github" / "workflows" / "pages.yml"
WEB_ARTIFACT = ROOT / "scripts" / "audit_web_artifact.py"

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


timer = read(TIMER)
rbt = read(RBT)
prepare = read(PREPARE)
pages = read(PAGES)
web_artifact = read(WEB_ARTIFACT)
first_then = read(ROOT / "LifeRoute" / "Web" / "first-then-back.js")

# Core timer remains deadline-based so app switching does not make the visual time drift.
check("deadline: 0" in rbt and "timer.deadline - Date.now()" in rbt, "timer uses absolute deadline")
check("setInterval(tickTimer, 250)" in rbt, "base countdown refresh remains responsive")
check("scheduleToolTimer" in rbt, "native completion notification remains wired")

# Audible half-second chime requirements.
check("CHIME_PERIOD_MS = 500" in timer, "chime cadence is exactly 0.5 seconds")
check("START_HZ = 220" in timer, "chime begins at a gentle low pitch")
check("END_HZ = 1320" in timer, "chime rises substantially toward completion")
check("Math.pow(END_HZ / START_HZ" in timer, "pitch progression is exponential rather than abrupt")
check("AudioContext" in timer and "webkitAudioContext" in timer, "Web Audio supports Safari/WKWebView")
check('fundamental.type = "sine"' in timer and 'shimmer.type = "sine"' in timer, "timer uses gentle chime synthesis rather than ticking/noise")
check("0.052 * gainScale" in timer, "chime gain is deliberately gentle")
check("playCompletion" in timer, "timer has a distinct completion chime")
check("Sound on" in timer and "Sound off" in timer, "timer sound can be muted by caregiver")
check("liferoute_visual_timer_sound_v2" in timer, "sound preference persists locally")

# Audio lifecycle + smoothness.
check("document.visibilityState === \"hidden\"" in timer, "timer audio stops while app/page is hidden")
check("stopScheduler" in timer and "pagehide" in timer, "timer scheduler shuts down when leaving page")
check("if (scheduler || !overlay()?.classList.contains(\"show\")) return" in timer, "sound scheduler runs only while timer overlay is visible")
check("POLL_MS = 70" in timer, "scheduler uses lightweight polling rather than frame-rate audio work")
check("overlayObserver.observe(host" in timer and 'attributeFilter: ["class"]' in timer, "timer observes only its own overlay visibility")
check("bodyObserver.disconnect()" in timer, "temporary lazy-overlay observer disconnects after initialization")
check("prefers-reduced-motion:reduce" in timer, "timer visual motion honors reduced-motion accessibility")

# Futuristic presentation markers.
for marker in [
    "lrVisualTimerV2",
    "lrTimerTelemetry",
    "lrTimerInnerGrid",
    "lrTimerHalo",
    "lrTimerOrbit",
    "CHIME 220 HZ · RISING",
    "0.5 SEC PULSE",
]:
    check(marker in timer, f"futuristic timer UI: {marker}")

# First/Then crash/smoothness cleanup: the external Back control only needs to
# observe the overlay's open/closed class. Watching generated child content can
# self-trigger when visual generation inserts/replaces images in WKWebView.
check('observer.observe(document.body, { childList: true, subtree: true, attributes: true' not in first_then, "First/Then no longer observes every document class mutation")
check("overlayClassObserver.observe(overlay" in first_then and 'attributeFilter: ["class"]' in first_then, "First/Then class observer is scoped to overlay")
check("overlayContentObserver" not in first_then and "childList: true" not in first_then and "subtree: true" not in first_then, "First/Then has no recursive visual-content observer")

# Both native/TestFlight preparation and web Pages carry and verify the same timer module.
check('"visual-timer-v2.js"' in prepare, "prepared shared runtime includes visual timer v2")
check('"visual-timer-v2.js"' in web_artifact and "CHIME_PERIOD_MS = 500" in web_artifact, "final web artifact audit validates timer v2 sound contract")
check("python3 scripts/audit_web_artifact.py" in pages, "Pages runs dedicated final browser artifact audit")
check("python3 scripts/audit_visual_timer.py" in prepare, "prepare build runs focused timer audit")

print(f"LifeRoute visual timer audit: {len(passes)} passed, {len(failures)} failed")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)
print("LifeRoute visual timer sound, design, lifecycle, performance, and final-artifact audit passed.")
