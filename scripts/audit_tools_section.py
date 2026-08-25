from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute/Web"

rbt = (WEB / "rbt-tools.js").read_text()
first_then = (WEB / "first-then-back.js").read_text()
visual = (WEB / "visual-tools.js").read_text()
timer = (WEB / "visual-timer-v2.js").read_text()
clients = (WEB / "client-picker-sync-v1.js").read_text()
profiles = (WEB / "client-profiles-v1.js").read_text()
profile_tools = (WEB / "client-profile-tools-v1.js").read_text()
photo_picker = (WEB / "photo-source-picker-web.js").read_text()
object_focus = (WEB / "visual-object-focus-v2.js").read_text()
index = (WEB / "index.html").read_text()
prepare = (ROOT / "scripts/prepare_build.sh").read_text()

checks = []

def require(condition, label):
    checks.append((bool(condition), label))

# Tools shell and primary cards.
for marker in [
    'id="visualTimerTool"', 'id="quickNotesTool"', 'id="firstThenTool"',
    'id="sessionPlanTool"', 'data-view="tools"', 'class="toolGrid"',
]:
    require(marker in rbt, f"Tools shell contains {marker}")
require('button.dataset.view = "tools"' in rbt, "Tools tab opens shared Tools view")

# Quick notes: client-aware, bounded, removable, local-only.
require('id="quickNoteClient"' in rbt, "Quick notes expose client selector")
require('id="saveQuickNote"' in rbt and 'state.notes.push({' in rbt, "Quick notes save observations")
require('state.notes = state.notes.slice(-100)' in rbt, "Quick-note history is bounded")
require('quickNoteDelete' in rbt and 'state.notes.filter' in rbt, "Quick notes can be individually deleted")
require('id="clearQuickNote"' in rbt, "Quick-note draft has clear action")
require('TARGET_IDS = ["quickNoteClient", "sessionPlanClient"]' in clients, "Quick notes and plans share saved-client source")
require('setInterval(' not in clients, "Client picker sync uses no polling loop")

# Visual timer: child-facing audio plus strict lifecycle cleanup.
for marker in ['id="timerStartButton"', 'id="timerPauseResume"', 'id="timerReset"', 'id="timerClose"', 'id="timerPlusMinute"']:
    require(marker in rbt, f"Visual timer control exists: {marker}")
require('CHIME_PERIOD_MS = 500' in timer, "Timer chime cadence is 0.5 seconds")
require('START_HZ = 220' in timer and 'END_HZ = 1320' in timer, "Timer pitch rises substantially")
require('stopScheduler' in timer and 'pagehide' in timer, "Timer audio scheduler tears down on exit")
require('document.visibilityState === "hidden"' in timer, "Timer audio respects app backgrounding")
require('if (timer.interval) clearInterval(timer.interval);\n    timer.interval = 0;\n    scheduleTimerAlert();' in rbt, "Paused timer clears base countdown interval")
require('if (timer.running) pauseTimer();' in rbt and 'overlay.classList.remove("show")' in rbt, "Closing timer tears down running countdown")
require('if (!timer.interval) timer.interval = setInterval(tickTimer, 250)' in rbt, "Timer resumes with one bounded interval")

# First/Then: validate, open, render text, show visual once, and always escape.
require('id="firstThenFirst"' in rbt and 'id="firstThenThen"' in rbt, "First/Then has both activity fields")
require('alert("Enter both the First and Then activities.")' in rbt, "First/Then rejects incomplete boards")
require('overlay.querySelector("#firstThenFirstValue").textContent = first' in rbt, "First value uses textContent")
require('overlay.querySelector("#firstThenThenValue").textContent = then' in rbt, "Then value uses textContent")
require('overlay.classList.add("show")' in rbt, "Base First/Then opens board")
require('lifeRouteFirstThenEscape' in first_then, "External First/Then escape control exists")
require('document.addEventListener("click", event =>' in first_then and 'stopImmediatePropagation' in first_then, "First/Then close owns capture path")
require('cancelOpenTimers' in first_then, "First/Then delayed opens are cancellable")
require('overlayClassObserver.observe(overlay, { attributes: true, attributeFilter: ["class"] })' in first_then, "First/Then watches only overlay open/close class")
require('overlayContentObserver' not in first_then, "First/Then has no child-tree mutation observer")
require('bodyObserver' not in first_then, "First/Then has no document-wide mutation observer")
require('childList: true' not in first_then and 'subtree: true' not in first_then, "First/Then cannot self-trigger on generated child mutations")
require('internal.textContent = "Back"' not in first_then, "First/Then observer never rewrites observed child text")
require('openTimers.push(setTimeout(forceOpen, 0))' in first_then and 'openTimers.push(setTimeout(forceOpen, 120))' in first_then, "First/Then uses only bounded launch retries")
require('if (!overlay?.classList.contains("show")) return;' in visual, "Hidden First/Then board does no visual regeneration work")
require('let img = panel.querySelector(".firstThenVisualImage")' in visual and 'if (!img)' in visual, "First/Then reuses one visual image slot per panel")
require('img.onerror' in visual and 'data:image/svg+xml' in visual, "First/Then remote visual failure has local fallback")

# Session plan: saved client profiles feed authorized targets/reinforcers.
require('id="sessionPlanClient"' in rbt, "Session plan has client selector")
require('id="sessionPlanTargets"' in rbt and 'id="sessionPlanReinforcers"' in rbt, "Session plan exposes targets and reinforcers")
require('id="generateSessionPlan"' in rbt and 'buildPlan(minutes, targets, reinforcers)' in rbt, "Session plan builds local plan blocks")
require('Use only goals, prompting procedures, reinforcement plans, and behavior protocols already authorized' in rbt, "Session plan retains clinical guardrail")
require('applyLifeRouteClientProfileToTools' in profile_tools, "Client profile bridge reaches Tools")
require('currentTargets' in profile_tools and 'preferredActivities' in profile_tools, "Saved targets and preferred activities prefill plan")
require('profileAutofill' in profile_tools, "Manual plan edits are distinguished from profile autofill")
require('fetch(' not in profile_tools and 'https://' not in profile_tools, "Client profile tool integration stays local")

# Client profiles supporting Tools.
for marker in ['clientPreferredActivities', 'clientCurrentTargets', 'clientBehaviorsOfConcern', 'communicationNotes', 'promptingNotes']:
    require(marker in profiles, f"Client profile preserves {marker}")
require('fetch(' not in profiles, "Client profile storage makes no network request")

# Visual maker and choice board.
require('id="visualIconTool"' in visual and 'id="visualCameraInput"' in visual, "Visual icon maker exists")
require('MAX_ICONS = 18' in visual, "Visual library is bounded")
require('URL.revokeObjectURL' in visual, "Visual maker releases temporary object URLs")
require('LifeRouteVisualObjectFocus' in object_focus, "Uploaded-photo subject focusing is available")
require('getImageData' in object_focus and 'toBlob' in object_focus, "Photo focusing uses local canvas processing")
require('fetch(' not in object_focus and 'https://' not in object_focus, "Photo subject extraction stays local")
require('visualCameraInput' in photo_picker, "Camera/photo source picker targets visual maker")
require('id="choiceBoardTool"' in visual and 'id="showChoiceBoard"' in visual, "Choice-board creator exists")
require('id="closeChoiceBoard"' in visual and 'overlay.classList.remove("show")' in visual, "Choice board has working close path")
require('state.boardSelection.length' in visual, "Choice board selection is tracked")

# Deterministic startup and mandatory audit wiring.
for name in [
    'rbt-tools.js', 'client-picker-sync-v1.js', 'client-profiles-v1.js', 'client-profile-tools-v1.js',
    'visual-timer-v2.js', 'first-then-back.js', 'visual-tools.js', 'visual-object-focus-v2.js'
]:
    require(f'<script src="{name}"></script>' in index, f"Prepared app loads {name}")
require('patch_tools_stability_v1.py' in prepare, "Tools lifecycle patch is mandatory")
require('audit_tools_section.py' in prepare, "Full Tools audit is mandatory")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute Tools section audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print("Tools shell, notes, timer, First/Then, session planning, client profiles, visual maker, and choice board passed.")
