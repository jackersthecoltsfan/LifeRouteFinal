from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Could not patch {label}: expected source not found")
    return text.replace(old, new, 1)


live_path = Path("LifeRoute/Web/live-day.js")
live = live_path.read_text()

live = replace_once(
    live,
    '''  const selectionFor = (dateKey, previous, next) =>
    typeof window.lifeRouteSelectedGapFor === "function"
      ? window.lifeRouteSelectedGapFor(dateKey, String(previous?.id || ""), String(next?.id || ""))
      : null;
''',
    '''  const selectionFor = (dateKey, previous, next) =>
    typeof window.lifeRouteSelectedGapFor === "function"
      ? window.lifeRouteSelectedGapFor(dateKey, String(previous?.id || ""), String(next?.id || ""))
      : null;

  const boundaryFor = (dateKey, mode) => {
    try {
      const saved = JSON.parse(localStorage.getItem("liferoute_boundary_stops_v2") || "{}");
      return saved && typeof saved === "object" ? saved[`${dateKey}|${mode}`] || null : null;
    } catch (_) { return null; }
  };
''',
    "live-day boundary reader"
)

live = replace_once(
    live,
    '''    const blocks = [];
    const leaveActions = [];

    list.forEach((event, index) => {
''',
    '''    const blocks = [];
    const leaveActions = [];
    const beforeBoundary = boundaryFor(dateKey, "before");

    list.forEach((event, index) => {
''',
    "live-day before-boundary state"
)

old_first = '''      if (index === 0) {
        travelMinutes = Math.max(0, Number(event.drive || 0));
        if (event.address && travelMinutes > 0) {
          leaveAt = addMinutes(start, -(travelMinutes + buffer));
          leaveActions.push({
            id: `${dateKey}-first-${event.id}`,
            time: leaveAt,
            title: `Leave for ${event.title}`,
            destination: event.address,
            detail: `${typeof fmt === "function" ? fmt(travelMinutes) : travelMinutes + "m"} travel${buffer ? ` + ${buffer}m buffer` : ""}`
          });
        }
      } else {
'''
new_first = '''      if (index === 0) {
        if (beforeBoundary?.address) {
          const outMinutes = Math.max(0, Number(beforeBoundary.outMinutes || 0));
          const backMinutes = Math.max(0, Number(beforeBoundary.backMinutes || event.drive || 0));
          const stopMinutes = Math.max(1, Number(beforeBoundary.stopMinutes || 5));
          const stopDistanceOut = Number(beforeBoundary.outDistanceMeters || 0);
          const stopDistanceBack = Number(beforeBoundary.backDistanceMeters || 0);
          const arrivalDeadline = addMinutes(start, -buffer);
          const leaveStopAt = addMinutes(arrivalDeadline, -backMinutes);
          const stopStart = addMinutes(leaveStopAt, -stopMinutes);
          const leaveForStopAt = addMinutes(stopStart, -outMinutes);

          blocks.push({
            type: "stop",
            id: `boundary-before-${dateKey}`,
            start: stopStart,
            end: leaveStopAt,
            title: beforeBoundary.label || "Planned stop",
            address: beforeBoundary.address || "",
            subtitle: `${typeof fmt === "function" ? fmt(stopMinutes) : stopMinutes + "m"} planned stop`,
            travelIn: outMinutes,
            travelOut: backMinutes,
            distanceIn: stopDistanceOut,
            distanceOut: stopDistanceBack,
            approximate: false,
            leaveStopAt,
            nextTitle: event.title
          });

          leaveActions.push({
            id: `${dateKey}-boundary-before-in`,
            time: leaveForStopAt,
            title: `Leave for ${beforeBoundary.label || "planned stop"}`,
            destination: beforeBoundary.address || "",
            detail: `${outMinutes ? (typeof fmt === "function" ? fmt(outMinutes) : outMinutes + "m") + " travel + " : ""}${typeof fmt === "function" ? fmt(stopMinutes) : stopMinutes + "m"} stop${backMinutes ? ` + ${typeof fmt === "function" ? fmt(backMinutes) : backMinutes + "m"} onward` : ""}${buffer ? ` + ${buffer}m buffer` : ""}`
          });
          if (event.address) {
            leaveActions.push({
              id: `${dateKey}-boundary-before-out`,
              time: leaveStopAt,
              title: `Leave for ${event.title}`,
              destination: event.address,
              detail: `${backMinutes ? (typeof fmt === "function" ? fmt(backMinutes) : backMinutes + "m") + " travel" : "Route ready in Maps"}${buffer ? ` + ${buffer}m arrival buffer` : ""}`
            });
          }

          leaveAt = leaveStopAt;
          travelMinutes = backMinutes;
          travelDistanceMeters = stopDistanceBack;
          leaveOrigin = beforeBoundary.label || "Planned stop";
        } else {
          travelMinutes = Math.max(0, Number(event.drive || 0));
          if (event.address && travelMinutes > 0) {
            leaveAt = addMinutes(start, -(travelMinutes + buffer));
            leaveActions.push({
              id: `${dateKey}-first-${event.id}`,
              time: leaveAt,
              title: `Leave for ${event.title}`,
              destination: event.address,
              detail: `${typeof fmt === "function" ? fmt(travelMinutes) : travelMinutes + "m"} travel${buffer ? ` + ${buffer}m buffer` : ""}`
            });
          }
        }
      } else {
'''
live = replace_once(live, old_first, new_first, "first appointment stop-aware departure")

live = replace_once(
    live,
    'Leave times automatically include route time and arrival buffer.',
    'Leave times include travel, planned stop time, and arrival buffer.',
    "live-day timing copy"
)

live_path.write_text(live)

controls_path = Path("LifeRoute/Web/day-controls-v5.js")
controls = controls_path.read_text()
controls = replace_once(
    controls,
    '''      const back = Math.max(0, Number(before.backMinutes || 0));
      const duration = Math.max(1, Number(before.stopMinutes || 30));
      const out = Math.max(0, Number(before.outMinutes || 0));
      const end = addMinutes(firstStart, -back);
      const start = addMinutes(end, -duration);
''',
    '''      const firstBuffer = Math.max(0, Number(events[0]?.buffer || 10));
      const back = Math.max(0, Number(before.backMinutes || events[0]?.drive || 0));
      const duration = Math.max(1, Number(before.stopMinutes || 5));
      const out = Math.max(0, Number(before.outMinutes || 0));
      const end = addMinutes(firstStart, -(back + firstBuffer));
      const start = addMinutes(end, -duration);
''',
    "Live Activity before-stop timing"
)
controls = replace_once(
    controls,
    '''      let leaveAt = Number(event.drive || 0) > 0 ? addMinutes(start, -(Number(event.drive || 0) + buffer)) : null;

      if (index > 0 && typeof window.lifeRouteSelectedGapFor === "function") {
''',
    '''      let leaveAt = Number(event.drive || 0) > 0 ? addMinutes(start, -(Number(event.drive || 0) + buffer)) : null;
      if (index === 0 && before) {
        const boundaryBack = Math.max(0, Number(before.backMinutes || event.drive || 0));
        leaveAt = addMinutes(start, -(boundaryBack + buffer));
      }

      if (index > 0 && typeof window.lifeRouteSelectedGapFor === "function") {
''',
    "Live Activity first appointment departure"
)
controls_path.write_text(controls)

print("Boundary stop duration now drives Live Day countdown, reminders, and Live Activity timing.")
