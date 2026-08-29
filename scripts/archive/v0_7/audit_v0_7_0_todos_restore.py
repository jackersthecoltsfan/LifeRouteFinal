#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 To-Dos restore audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    routing = read("LifeRoute/RoutingLocationDomain.swift")
    store = read("LifeRoute/PersistenceCore.swift")
    setup = read("LifeRoute/V054SetupView.swift")
    today = read("LifeRoute/V054TodayView.swift")
    prepare = read("scripts/prepare_build.sh")

    require_all(
        routing,
        [
            "v0.7.0 native weekly To-Dos restore",
            "enum LifeRouteTodoCategory",
            "enum LifeRouteTodoPriority",
            "struct LifeRouteTodo: Identifiable, Codable, Hashable",
            "@Published private(set) var todos: [LifeRouteTodo]",
            "func addTodo(",
            "func setTodoCompleted(id: UUID, completed: Bool)",
            "func removeTodo(id: UUID)",
            "persistTodoInputs()",
        ],
        "native To-Do domain",
    )

    for field in ["title", "category", "durationMinutes", "savedPlaceID", "address", "priority", "dueDate", "notes", "completed"]:
        require(field in routing, f"legacy To-Do field must be represented natively: {field}")

    require_all(
        store,
        [
            "var todos: [LifeRouteTodo]",
            "decodeIfPresent([LifeRouteTodo].self, forKey: .todos) ?? []",
            "todos: state.todos",
            "func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace], todos: [LifeRouteTodo])",
            "sanitizedTodos(input.todos",
        ],
        "protected To-Do persistence",
    )

    require_all(
        setup,
        [
            "private var weeklyTodosCard: some View",
            "private var addTodoCard: some View",
            'Label("Weekly To-Dos", systemImage: "checklist")',
            'TextField("What needs to get done?", text: $todoTitle)',
            'Picker("Category", selection: $todoCategory)',
            'Picker("Estimated task time", selection: $todoDurationMinutes)',
            'Picker("Saved place (optional)", selection: $todoSavedPlaceID)',
            'Picker("Priority", selection: $todoPriority)',
            'DatePicker("Do by", selection: $todoDueDate, displayedComponents: .date)',
            'TextField("Notes (optional)", text: $todoNotes, axis: .vertical)',
            "routingState.setTodoCompleted",
            "routingState.removeTodo",
        ],
        "Setup weekly To-Do workflow",
    )
    require(
        'V054AddressField("Location / store (optional)", text: $todoAddress)' in setup
        or 'V054AddressField("Location / store (optional)", text: $todoAddress, mode: .todoDestination)' in setup,
        "Setup weekly To-Do workflow must retain the reviewed location field or its superseding flexible-destination mode",
    )

    require_all(
        today,
        [
            "v0.7.0 restored To-Do gap fillers",
            "let openTodos = routingState.todos.filter { !$0.completed }",
            "ForEach(openTodos.prefix(3))",
            "todo.category.systemImage",
            "routingState.setTodoCompleted(id: todo.id, completed: true)",
        ],
        "Home To-Do gap fillers",
    )

    require("LifeRouteWebView" not in routing + store + setup + today, "restored To-Dos must remain native and must not reactivate WebView")
    require("python3 scripts/patch_v0_7_0_todos_restore.py" in prepare, "canonical preparation must materialize restored To-Dos")
    require("python3 scripts/audit_v0_7_0_todos_restore.py" in prepare, "canonical preparation must audit restored To-Dos")

    print("LifeRoute v0.7.0 To-Dos restore audit passed: the legacy flexible weekly task model is restored natively beside Saved Places, persists safely, supports completion/undo, and surfaces on Home as gap-filler work; the location field may use its reviewed flexible-destination supersession.")


if __name__ == "__main__":
    main()
