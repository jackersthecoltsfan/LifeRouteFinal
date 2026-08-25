from pathlib import Path

checks = []

def require(condition, label):
    checks.append((bool(condition), label))

stop = Path("LifeRoute/Web/stop-duration-v1.js").read_text()
live = Path("LifeRoute/Web/live-day.js").read_text()
controls = Path("LifeRoute/Web/day-controls-v5.js").read_text()
boundary = Path("LifeRoute/Web/boundary-stop-planner.js").read_text()
selected = Path("LifeRoute/Web/selected-gap-routes.js").read_text()

# Duration chooser UI and persistence.
require("LifeRouteStopDurationV1" in stop, "duration controller exported")
require("STOP LENGTH" in stop, "duration sheet heading")
for minutes in (5, 10, 15, 20, 30, 45, 60):
    require(str(minutes) in stop, f"{minutes} minute preset available")
require("Custom minutes" in stop, "custom duration supported")
require('liferoute_boundary_stops_v2' in stop, "boundary stop duration persistence")
require('liferoute_selected_gap_routes_v2' in stop, "between-event duration persistence")
require("data-lr-boundary-duration" in stop, "boundary planned-card duration control")
require("data-lr-gap-duration" in stop, "gap planned-card duration control")
require("generateLifeRouteDay" in stop, "active Live Day refresh after duration change")
require("observer.observe(document.body" not in stop, "duration observer is not page-wide")
require("setInterval(" not in stop, "duration module has no permanent polling")

# Existing route selections must carry stop duration.
require("stopMinutes: Number(stop?.stopMinutes || 0)" in boundary, "boundary selection stores stop duration")
require("stopMinutes: Number(pending.stopMinutes || 0)" in selected, "gap selection stores stop duration")

# First-stop timing must include BOTH route legs, dwell time, and event buffer.
require('boundaryFor(dateKey, "before")' in live, "Live Day reads before-first selection")
require("const stopMinutes = Math.max(1, Number(beforeBoundary.stopMinutes || 5))" in live, "Live Day uses chosen dwell time")
require("const arrivalDeadline = addMinutes(start, -buffer)" in live, "arrival buffer applied before appointment")
require("const leaveStopAt = addMinutes(arrivalDeadline, -backMinutes)" in live, "second route leg applied")
require("const stopStart = addMinutes(leaveStopAt, -stopMinutes)" in live, "stop dwell applied")
require("const leaveForStopAt = addMinutes(stopStart, -outMinutes)" in live, "first route leg applied")
require("boundary-before-in" in live, "first departure reminder created")
require("boundary-before-out" in live, "stop-to-appointment reminder created")
require("travel, planned stop time, and arrival buffer" in live, "Live Day timing copy matches behavior")

# Lock Screen Live Activity uses the same timing model.
require("const firstBuffer = Math.max(0, Number(events[0]?.buffer || 10))" in controls, "Live Activity reads first-event buffer")
require("Number(before.stopMinutes || 5)" in controls, "Live Activity uses chosen dwell time")
require("addMinutes(firstStart, -(back + firstBuffer))" in controls, "Live Activity applies route leg plus buffer")
require("addMinutes(end, -duration)" in controls, "Live Activity subtracts stop duration")
require("addMinutes(start, -out)" in controls, "Live Activity subtracts inbound route")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute stop-duration audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print("LifeRoute planned-stop duration, countdown, reminders, and Live Activity timing audit passed.")
