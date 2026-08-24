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
new_todo_button = '''          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="chooseLifeRouteGapRoute('${context.date}','${context.previous?.id || ""}','${context.next?.id || ""}','${encodeURIComponent(todo.address)}','${encodeURIComponent(context.next?.address || "")}','${encodeURIComponent(todo.title || todo.address)}',${Number(item.drive || 0)},${Number(item.outDistanceMeters || 0) + Number(item.backDistanceMeters || 0)},${Number(item.duration || 0)})">Choose route</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
'''
todos = replace_once(todos, old_todo_button, new_todo_button, "to-do chosen route persistence")
todos_path.write_text(todos)


# Store branch comparisons already have total route mileage and drive time.
# Persist those exact metrics when a branch is chosen.
stores_path = Path("LifeRoute/Web/grocery-stores.js")
stores = stores_path.read_text()
old_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();routeGapStop('${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}','${encodeURIComponent(request.next?.address || "")}')">${request.next?.address ? "Route + next" : "Route here"}</button></div>
'''
new_store_button = '''        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();chooseLifeRouteGapRoute('${request.dateKey}','${request.previous?.id || ""}','${request.next?.id || ""}','${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}','${encodeURIComponent(request.next?.address || "")}','${encodeURIComponent(item.location.name || item.location.brand || "Store")}',${Number(item.drive || 0)},${Number(item.distanceMeters || 0)},${Number(item.duration || 0)})">Choose route</button></div>
'''
stores = replace_once(stores, old_store_button, new_store_button, "store chosen route persistence")
stores_path.write_text(stores)

print("Gap route choices now persist with travel time and distance.")
