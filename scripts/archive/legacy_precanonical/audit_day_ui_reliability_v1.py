from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"

catalog = (WEB / "theme-catalog-v3.js").read_text()
assistant = (WEB / "ai-assistant-v1.js").read_text()
planning = (WEB / "ai-planning-v1.js").read_text()
index = (WEB / "index.html").read_text()
swift = (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text()
controls = (WEB / "day-controls-v5.js").read_text()
selected = (WEB / "selected-gap-routes.js").read_text()
boundary = (WEB / "boundary-stop-planner.js").read_text()

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

# Theme cards match Dynamic / Fluid visual grammar.
check("Metallic uses shared two-column theme grid", 'grid.className = "lrThemeGrid lrMetallicThemeGrid"' in catalog)
check("Metallic uses preview surface + shared theme name", "lrMetallicPreview" in catalog and "lrThemeName" in catalog)
check("Metallic no longer forces one-column iPhone rows", '@media(max-width:560px){.lrMetallicThemeGrid{grid-template-columns:1fr}}' not in catalog)
check("Metallic selected state remains visible", ".lrMetallicThemeCard.active" in catalog)

# Generate Day facts are local-display only and route insight is deterministic.
check("Day AI prompt forbids invention", "Never infer, invent, recommend, or add meals, breaks, cafes, errands" in assistant)
check("Day AI prompt forbids timezone conversion", "Never convert time zones" in assistant)
check("Day AI receives local start/end strings", "startTime: friendlyTime(block.start)" in planning and "endTime: friendlyTime(block.end)" in planning)
check("Day AI receives local leave strings", "leaveTime: block.leaveAt ? friendlyTime(block.leaveAt)" in planning)
check("Day AI payload no longer uses ISO event times", "start: block.start instanceof Date ? block.start.toISOString()" not in planning and "leaveAt: block.leaveAt instanceof Date ? block.leaveAt.toISOString()" not in planning)
check("Generate Day does not feed saved places into prose", "events: fixed, places" not in planning)
check("route insight is deterministic", "const deterministicRoute = nextAction" in planning and "scrubDisplayText(deterministicRoute)" in planning)
check("Generate Day no longer asks AI to invent route prose", "window.LifeRouteAI?.routeBrief?.(routeFacts)" not in planning)

# Zoom lock prevention across HTML and WKWebView.
check("viewport prevents app-shell zoom", "maximum-scale=1, user-scalable=no" in index)
check("mobile fields are 16px to prevent iOS focus zoom", "input,select,textarea{font-size:16px!important}" in index)
check("touch action allows pan but not pinch zoom", "html,body{touch-action:pan-x pan-y}" in index)
check("WKWebView pinch recognizer disabled", "pinchGestureRecognizer?.isEnabled = false" in swift)
check("WKWebView zoom scale fixed", "minimumZoomScale = 1.0" in swift and "maximumZoomScale = 1.0" in swift)
check("WKWebView resets scale after navigation", "setZoomScale(1.0, animated: false)" in swift)

# Clear day only clears selected date's generated route plan.
check("Clear day confirmation says route-only scope", "Clear only this day's generated routes and planned stops" in controls)
check("Clear day no longer deletes manual events", "window.events = window.events.filter" not in controls)
check("Clear day no longer persists unrelated event mutations", "try { window.persist?.(); }" not in controls.split("const clearDay = () => {",1)[1].split("const clearAll = () => {",1)[0])
check("selected gap routes clear in-memory by day prefix", "window.clearLifeRouteGapRoutesForDay" in selected and "key.startsWith(prefix)" in selected)
check("boundary routes clear in-memory by day prefix", "window.clearLifeRouteBoundaryStopsForDay" in boundary and "key.startsWith(prefix)" in boundary)
check("Clear day calls scoped gap clear", "clearLifeRouteGapRoutesForDay(day)" in controls)
check("Clear day calls scoped boundary clear", "clearLifeRouteBoundaryStopsForDay(day)" in controls)
check("Clear all still retains broad reset behavior", 'key.startsWith("liferoute_")' in controls)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute Day/UI reliability audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit(1)
