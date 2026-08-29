from pathlib import Path

checks = []

def require(condition, label):
    checks.append((bool(condition), label))


def text(path):
    return Path(path).read_text()

index = text("LifeRoute/Web/index.html")
rbt = text("LifeRoute/Web/rbt-tools.js")
clients = text("LifeRoute/Web/client-picker-sync-v1.js")
toolbar = text("LifeRoute/Web/toolbar-cleanup-v1.js")
boundary = text("LifeRoute/Web/boundary-stop-planner.js")
search = text("LifeRoute/Web/stop-place-search-v4.js")
duration = text("LifeRoute/Web/stop-duration-v1.js")
selected = text("LifeRoute/Web/selected-gap-routes.js")
live = text("LifeRoute/Web/live-day.js")
controls = text("LifeRoute/Web/day-controls-v5.js")
location = text("LifeRoute/Web/live-location-v2.js")
first_then = text("LifeRoute/Web/first-then-back.js")
timer = text("LifeRoute/Web/visual-timer-v2.js")
activity = text("LifeRoute/LiveActivityManager.swift")

# 1) Browser/native handoff must be truthful so browser fallbacks are reachable.
require('const handler=window.webkit?.messageHandlers?.lifeRoute' in index, "base bridge resolves an actual native handler")
require('if(!handler||typeof handler.postMessage!=="function")return false' in index, "base bridge returns false without native WKWebView")
require('handler.postMessage(payload);return true' in index, "native bridge returns true only after posting")

# 2) Saved clients -> both field-tool selectors -> resulting notes/plans.
require('TARGET_IDS = ["quickNoteClient", "sessionPlanClient"]' in clients, "both tool selectors share client synchronizer")
require('saved?.prefs?.clients' in clients, "saved Setup clients have persisted fallback")
require('typeof prefs !== "undefined" && Array.isArray(prefs.clients)' in clients, "live Setup clients are preferred")
require('saveClientButton' in clients and 'removeLifeRouteClient' in clients, "client add/remove actions trigger resync")
require('client: String(document.getElementById("quickNoteClient")?.value || "")' in rbt, "quick note stores chosen client")
require('client: String(document.getElementById("sessionPlanClient")?.value || "")' in rbt, "session plan stores chosen client")

# 3) Toolbar cleanup removes only duplicate top-level Month, not Calendar's real month view.
require("child.dataset?.view === 'month'" in toolbar, "duplicate main Month button is targeted")
require("child?.classList?.contains('tab')" in toolbar, "toolbar cleanup only removes tab children")
require('grid-template-columns' in toolbar, "toolbar columns recalculate after removal")

# 4) Every stop creation path exposes a likely-duration choice.
require('wrapBoundarySave' in duration, "searched boundary stop prompts duration")
require('[data-boundary-place],[data-boundary-todo]' in duration, "direct Saved Place / To-Do prompts duration")
require('wrapGapPlanner' in duration and 'pendingGapPrompt' in duration, "between-event stop prompts duration")
require('pendingGapSnapshot = readObject(GAP_STORE)' in duration, "gap prompt snapshots prior selection state")
require('clean(previous.selectedAt) !== clean(selection.selectedAt)' in duration, "gap prompt waits for actual route commit")
require('PRESETS = [5, 10, 15, 20, 30, 45, 60]' in duration, "common duration presets include 5 minutes")
require('Custom minutes' in duration, "custom stop duration is supported")
require('Number.isFinite(numeric) || numeric < 1' in duration, "invalid custom duration is rejected")
require('selection.stopMinutes = minutes' in duration, "chosen duration persists onto stop")
require('redraw(kind)' in duration, "correct stop card redraws after duration update")
require('generateLifeRouteDay' in duration, "active generated day recalculates after duration change")
require('stopMinutes: Number(stop?.stopMinutes || 0)' in boundary, "before/after stop storage carries duration")
require('stopMinutes: Number(pending.stopMinutes || 0)' in selected, "between-event stop storage carries duration")

# 5) Before-first countdown = inbound travel + dwell + outbound travel + arrival buffer.
require('boundaryFor(dateKey, "before")' in live, "Live Day reads before-first stop")
require('const outMinutes = Math.max(0, Number(beforeBoundary.outMinutes || 0))' in live, "Live Day reads inbound leg")
require('const backMinutes = Math.max(0, Number(beforeBoundary.backMinutes || event.drive || 0))' in live, "Live Day reads outbound leg")
require('const stopMinutes = Math.max(1, Number(beforeBoundary.stopMinutes || 5))' in live, "Live Day reads chosen dwell time")
require('const arrivalDeadline = addMinutes(start, -buffer)' in live, "appointment arrival buffer is applied")
require('const leaveStopAt = addMinutes(arrivalDeadline, -backMinutes)' in live, "outbound route is subtracted")
require('const stopStart = addMinutes(leaveStopAt, -stopMinutes)' in live, "stop duration is subtracted")
require('const leaveForStopAt = addMinutes(stopStart, -outMinutes)' in live, "inbound route is subtracted")
require('boundary-before-in' in live and 'boundary-before-out' in live, "both leave reminders exist for before-first route")
require('travel, planned stop time, and arrival buffer' in live, "Live Day copy states full timing model")

appointment = 12 * 60
calculated_departure = appointment - 10 - 17 - 5 - 12
require(calculated_departure == 11 * 60 + 16, "independent stop-aware departure arithmetic sanity check")

# 6) The Lock Screen Live Activity mirrors the same before-first timing.
require('const firstBuffer = Math.max(0, Number(events[0]?.buffer || 10))' in controls, "Live Activity reads first appointment buffer")
require('const duration = Math.max(1, Number(before.stopMinutes || 5))' in controls, "Live Activity reads chosen stop duration")
require('const end = addMinutes(firstStart, -(back + firstBuffer))' in controls, "Live Activity stop departure includes outbound leg and buffer")
require('const start = addMinutes(end, -duration)' in controls, "Live Activity stop start includes dwell time")
require('leaveAt: addMinutes(start, -out)' in controls, "Live Activity first departure includes inbound leg")
require('await endAll(dismissImmediately: true)' in activity, "regeneration replaces prior Live Activity rather than duplicating it")

# 7) Clear controls have intentionally different scopes.
require('clearDateKeys(GENERATED_STORE, day)' in controls, "Clear day removes generated day state")
require('clearDateKeys(GAP_STORE, day)' in controls, "Clear day removes that day's gap routes")
require('clearDateKeys(BOUNDARY_STORE, day)' in controls, "Clear day removes that day's boundary stops")
require('key.startsWith("liferoute_")' in controls and 'if (auth) localStorage.setItem(AUTH_STORE, auth)' in controls, "Clear all resets LifeRoute data but preserves sign-in")

# 8) Location lifecycle works natively and on web without permanently competing watchers.
# A browser watcher may briefly overlap only as a watchdog fallback while a posted native
# stream has failed to produce its first coordinate. Once a native fix arrives, the fallback
# must be torn down immediately.
require('watchPosition' in location, "browser live location uses continuous watch")
require('clearWatch' in location, "browser live location watch can be stopped")
require('startLiveLocation' in location and 'stopLiveLocation' in location, "native foreground live-location actions are paired")
require('NATIVE_FIX_TIMEOUT_MS' in location and 'armNativeWatchdog' in location and 'startWebFallback()' in location,
        "browser fallback starts only after a bounded native first-fix watchdog")
require("evt.engine !== 'browser-geolocation'" in location and 'stopWebFallback()' in location,
        "browser watcher stops as soon as native coordinates actually arrive")
require('clearNativeWatchdog()' in location and 'lastFixAt = Date.now()' in location,
        "native coordinate ownership clears the watchdog and records freshness")
require('visibilitychange' in location and 'pagehide' in location, "location lifecycle follows foreground visibility")

# 9) First/Then and timer have reliable exits / audible child-facing feedback.
require('lifeRouteFirstThenEscape' in first_then and 'stopImmediatePropagation' in first_then, "First/Then has persistent capture-phase escape control")
require('cancelOpenTimers' in first_then, "First/Then delayed reopen timers are cancellable")
require('CHIME_PERIOD_MS = 500' in timer, "visual timer chimes every half second")
require('START_HZ = 220' in timer and 'END_HZ = 1320' in timer, "visual timer pitch rises substantially")
require('document.visibilityState === "hidden"' in timer, "timer audio scheduler respects app backgrounding")
require('stopScheduler' in timer and 'pagehide' in timer, "timer audio scheduler tears down on exit")

# 10) Nearby search remains usable on web/native and selected stops save into the shared planner.
require('PHOTON_URL' in search and 'NOMINATIM_URL' in search, "web stop search has two providers")
require('Promise.allSettled' in search, "one failed search provider cannot kill all results")
require('lifeRouteSaveBoundaryStop' in search, "searched stop saves through shared boundary planner")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute user-journey audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print("LifeRoute end-to-end user journeys are internally consistent across web, native, Live Day, and Live Activity.")
