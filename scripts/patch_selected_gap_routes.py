from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    return text.replace(old, new, 1)


# Keep distance for ordinary to-do detours so the selected gap card can show
# both travel time and mileage after the user chooses it.
todos_path = Path("LifeRoute/Web/todos.js")
todos = todos_path.read_text()

todos = replace_once(
    todos,
    '''      outMinutes: 0,
      backMinutes: 0,
      expectedLegs: 0,
''',
    '''      outMinutes: 0,
      backMinutes: 0,
      outDistanceMeters: 0,
      backDistanceMeters: 0,
      expectedLegs: 0,
''',
    "to-do route distance state",
)

todos = replace_once(
    todos,
    '''      if (leg === "out") candidate.outMinutes = Number(result.minutes || 0);
      if (leg === "back") candidate.backMinutes = Number(result.minutes || 0);
''',
    '''      if (leg === "out") {
        candidate.outMinutes = Number(result.minutes || 0);
        candidate.outDistanceMeters = Number(result.distanceMeters || 0);
      }
      if (leg === "back") {
        candidate.backMinutes = Number(result.minutes || 0);
        candidate.backDistanceMeters = Number(result.distanceMeters || 0);
      }
''',
    "to-do route distance results",
)

old_todo_button = '''          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="routeGapStop('${encodeURIComponent(todo.address)}','${encodeURIComponent(context.next?.address || "")}')">${context.next?.address ? "Route + next" : "Route there"}</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
'''
new_todo_button = '''          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="planLifeRouteGapRoute('${context.date}','${context.previous?.id || ""}','${context.next?.id || ""}','${encodeURIComponent(todo.address).replace(/'/g,"%27")}','${encodeURIComponent(context.next?.address || "").replace(/'/g,"%27")}','${encodeURIComponent(todo.title || todo.address).replace(/'/g,"%27")}',${Number(item.drive || 0)},${Number(item.outDistanceMeters || 0) + Number(item.backDistanceMeters || 0)},${Number(item.duration || 0)},'${encodeURIComponent(context.previous?.address || "").replace(/'/g,"%27")}','${encodeURIComponent(context.previous?.title || "Previous client").replace(/'/g,"%27")}', '',${Number(item.outMinutes || 0)},${Number(item.backMinutes || 0)},${Number(item.outDistanceMeters || 0)},${Number(item.backDistanceMeters || 0)})">Choose route</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
'''
todos = replace_once(todos, old_todo_button, new_todo_button, "to-do chosen route persistence")
todos_path.write_text(todos)


# Store branch comparisons already have total route mileage and drive time.
# Persist those exact metrics and the exact MapKit POI key when a branch is chosen.
# Percent-escape apostrophes too because names such as BJ's appear inside an
# inline onclick attribute and raw apostrophes would break the handler.
stores_path = Path("LifeRoute/Web/grocery-stores.js")
stores = stores_path.read_text()
old_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();routeGapStop('${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}','${encodeURIComponent(request.next?.address || "")}')">${request.next?.address ? "Route + next" : "Route here"}</button></div>
'''
new_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();planLifeRouteGapRoute('${request.dateKey}','${request.previous?.id || ""}','${request.next?.id || ""}','${encodeURIComponent(item.location.address || item.location.name || item.location.brand).replace(/'/g,"%27")}','${encodeURIComponent(request.next?.address || "").replace(/'/g,"%27")}','${encodeURIComponent(item.location.name || item.location.brand || "Store").replace(/'/g,"%27")}',${Number(item.drive || 0)},${Number(item.distanceMeters || 0)},${Number(item.duration || 0)},'${encodeURIComponent(request.previous?.address || "").replace(/'/g,"%27")}','${encodeURIComponent(request.previous?.title || "Previous client").replace(/'/g,"%27")}','${encodeURIComponent(item.location.mapItemKey || "").replace(/'/g,"%27")}',${Number(item.out?.minutes || 0)},${Number(item.back?.minutes || 0)},${Number(item.out?.distanceMeters || 0)},${Number(item.back?.distanceMeters || 0)})">Choose route</button></div>
'''
stores = replace_once(stores, old_store_button, new_store_button, "store chosen route persistence")
stores_path.write_text(stores)


# A gap choice is a planning action, not a navigation action. One tap should
# save the exact stop into the Day timeline using the previous appointment as
# the route origin. Maps only opens later from the saved card's Open route button.
selected_path = Path("LifeRoute/Web/selected-gap-routes.js")
selected = selected_path.read_text()

selected = replace_once(
    selected,
    '''    if (typeof setStatus === "function") setStatus(`Route selected · ${selection.label}`);
    if (originMode === "current") requestCurrentLocationMetrics(selection);
    openRouteForSelection(selection);
''',
    '''    if (typeof setStatus === "function") setStatus(`Saved to Day · ${selection.label}`);
    if (originMode === "current") requestCurrentLocationMetrics(selection);
    try { localStorage.setItem("liferoute_calendar_view", "today"); } catch (_) {}
    try { window.showView?.("today"); } catch (_) {}
    requestAnimationFrame(() => window.decorateLifeRouteSelectedGaps?.());
''',
    "chosen gap stays in Day instead of launching Maps",
)

selected = replace_once(
    selected,
    '''    const live = typeof nativeState !== "undefined" ? nativeState.currentLocation : null;
    const hasLive = live?.latitude != null && live?.longitude != null;
    if (!hasLive || !pending.previousAddress) {
      commitSelection(pending, pending.previousAddress ? "previous" : "current");
      return;
    }

    const overlay = ensurePlanner();
    const copy = overlay.querySelector("#gapRoutePlannerCopy");
    const previousButton = overlay.querySelector("#gapRouteStartPrevious");
    if (copy) copy.innerHTML = `Your live location is available. For planning ahead, you can instead start from <b>${safeText(pending.previousLabel)}</b>.`;
    if (previousButton) previousButton.innerHTML = `${icon("pin", 15)} Start from ${safeText(pending.previousLabel)}`;
    overlay.classList.add("show");

    const close = () => overlay.classList.remove("show");
    overlay.querySelector("#gapRouteStartCurrent").onclick = () => { close(); commitSelection(pending, "current"); };
    overlay.querySelector("#gapRouteStartPrevious").onclick = () => { close(); commitSelection(pending, "previous"); };
    overlay.querySelector("#gapRouteStartCancel").onclick = close;
    overlay.onclick = event => { if (event.target === overlay) close(); };
''',
    '''    // Mid-day gaps already have a known route origin: the previous event.
    // Save immediately so Choose route is a true one-tap planning action.
    commitSelection(pending, pending.previousAddress ? "previous" : "current");
''',
    "one-tap gap route save",
)

selected_path.write_text(selected)

print("Gap route choices now persist directly in Day with exact outbound/return legs, distance, and safe store-name encoding; navigation opens only on demand.")
