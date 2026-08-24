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

print("Gap route choices now persist with exact outbound/return legs, distance, selectable start point, and safe store-name encoding.")
