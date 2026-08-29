#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTING = ROOT / "LifeRoute/RoutingLocationDomain.swift"
STORE = ROOT / "LifeRoute/PersistenceCore.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 To-Dos restore patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_routing() -> None:
    text = ROUTING.read_text(encoding="utf-8")
    if "v0.7.0 native weekly To-Dos restore" in text:
        return

    todo_types = r'''
// v0.7.0 native weekly To-Dos restore: recovers the flexible task/errand model
// that existed in the pre-native LifeRoute experience without reactivating WebView.
enum LifeRouteTodoCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case errand = "Errand"
    case shopping = "Shopping"
    case pickup = "Pickup"
    case chore = "Chore"
    case call = "Call"
    case other = "Other"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .errand: return "bag.fill"
        case .shopping: return "cart.fill"
        case .pickup: return "shippingbox.fill"
        case .chore: return "checklist"
        case .call: return "phone.fill"
        case .other: return "checkmark.circle.fill"
        }
    }
}

enum LifeRouteTodoPriority: String, CaseIterable, Codable, Identifiable, Hashable {
    case low
    case normal
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    var sortWeight: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        }
    }
}

struct LifeRouteTodo: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: LifeRouteTodoCategory
    var durationMinutes: Int
    var savedPlaceID: UUID?
    var address: String
    var priority: LifeRouteTodoPriority
    var dueDate: Date
    var notes: String
    var completed: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: LifeRouteTodoCategory,
        durationMinutes: Int,
        savedPlaceID: UUID?,
        address: String,
        priority: LifeRouteTodoPriority,
        dueDate: Date,
        notes: String,
        completed: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.durationMinutes = max(5, min(240, durationMinutes))
        self.savedPlaceID = savedPlaceID
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.completed = completed
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
'''
    text = replace_once(
        text,
        "struct LifeRouteAddressSuggestion: Identifiable, Hashable {",
        todo_types + "\nstruct LifeRouteAddressSuggestion: Identifiable, Hashable {",
        "To-Do domain types",
    )

    text = replace_once(
        text,
        "    case routeUnavailable\n",
        "    case routeUnavailable\n    case missingTodoTitle\n",
        "To-Do validation error",
    )
    text = replace_once(
        text,
        '''        case .routeUnavailable: return "A route could not be calculated for that destination."
''',
        '''        case .routeUnavailable: return "A route could not be calculated for that destination."
        case .missingTodoTitle: return "Add what you need to get done."
''',
        "To-Do validation message",
    )

    text = replace_once(
        text,
        "    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []\n",
        "    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []\n    @Published private(set) var todos: [LifeRouteTodo] = []\n",
        "published To-Dos",
    )
    text = replace_once(
        text,
        "        self.savedPlaces = restored.savedPlaces\n        self.homeAddress = restored.homeAddress\n",
        "        self.savedPlaces = restored.savedPlaces\n        self.todos = restored.todos\n        self.homeAddress = restored.homeAddress\n",
        "restore To-Dos",
    )

    methods_anchor = '''    func calculateRoute(to place: LifeRouteSavedPlace, mode: LifeRouteTransportMode) {
'''
    todo_methods = r'''    func addTodo(
        title: String,
        category: LifeRouteTodoCategory,
        durationMinutes: Int,
        savedPlaceID: UUID?,
        address: String,
        priority: LifeRouteTodoPriority,
        dueDate: Date,
        notes: String
    ) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw RoutingLocationCoreError.missingTodoTitle }

        let linkedPlace = savedPlaceID.flatMap { id in savedPlaces.first(where: { $0.id == id }) }
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAddress = cleanAddress.isEmpty ? (linkedPlace?.address ?? "") : cleanAddress

        todos.append(
            LifeRouteTodo(
                title: cleanTitle,
                category: category,
                durationMinutes: durationMinutes,
                savedPlaceID: linkedPlace?.id,
                address: resolvedAddress,
                priority: priority,
                dueDate: dueDate,
                notes: notes
            )
        )
        sortTodos()
        persistTodoInputs()
    }

    func setTodoCompleted(id: UUID, completed: Bool) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].completed = completed
        todos[index].completedAt = completed ? Date() : nil
        sortTodos()
        persistTodoInputs()
    }

    func removeTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        persistTodoInputs()
    }

    private func sortTodos() {
        todos.sort { lhs, rhs in
            if lhs.completed != rhs.completed { return !lhs.completed }
            if lhs.priority.sortWeight != rhs.priority.sortWeight {
                return lhs.priority.sortWeight > rhs.priority.sortWeight
            }
            if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
            return lhs.createdAt < rhs.createdAt
        }
    }

'''
    text = replace_once(text, methods_anchor, todo_methods + methods_anchor, "To-Do mutation methods")

    persist_anchor = '''    private func persistRoutingInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces)
    }
'''
    persist_replacement = '''    private func persistRoutingInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos
        )
    }

    private func persistTodoInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos
        )
    }
'''
    text = replace_once(text, persist_anchor, persist_replacement, "To-Do persistence bridge")

    ROUTING.write_text(text, encoding="utf-8")


def patch_store() -> None:
    text = STORE.read_text(encoding="utf-8")
    if "var todos: [LifeRouteTodo]" in text:
        return

    text = replace_once(
        text,
        '''struct RestoredRoutingPersistenceState {
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]

    static let empty = RestoredRoutingPersistenceState(homeAddress: "", savedPlaces: [])
}''',
        '''struct RestoredRoutingPersistenceState {
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]
    var todos: [LifeRouteTodo]

    static let empty = RestoredRoutingPersistenceState(homeAddress: "", savedPlaces: [], todos: [])
}''',
        "restored routing To-Dos",
    )

    text = replace_once(
        text,
        "        var savedPlaces: [LifeRouteSavedPlace]\n        var manualCalendarEvents: [LifeRouteCalendarEvent]\n",
        "        var savedPlaces: [LifeRouteSavedPlace]\n        var todos: [LifeRouteTodo]\n        var manualCalendarEvents: [LifeRouteCalendarEvent]\n",
        "native state To-Dos",
    )
    text = replace_once(
        text,
        "            savedPlaces: [LifeRouteSavedPlace] = [],\n            manualCalendarEvents: [LifeRouteCalendarEvent] = [],\n",
        "            savedPlaces: [LifeRouteSavedPlace] = [],\n            todos: [LifeRouteTodo] = [],\n            manualCalendarEvents: [LifeRouteCalendarEvent] = [],\n",
        "native initializer To-Dos parameter",
    )
    text = replace_once(
        text,
        "            self.savedPlaces = savedPlaces\n            self.manualCalendarEvents = manualCalendarEvents\n",
        "            self.savedPlaces = savedPlaces\n            self.todos = todos\n            self.manualCalendarEvents = manualCalendarEvents\n",
        "native initializer To-Dos assignment",
    )
    text = replace_once(
        text,
        "            case savedPlaces\n            case manualCalendarEvents\n",
        "            case savedPlaces\n            case todos\n            case manualCalendarEvents\n",
        "native coding key To-Dos",
    )
    text = replace_once(
        text,
        "            savedPlaces = try container.decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces) ?? []\n            manualCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents) ?? []\n",
        "            savedPlaces = try container.decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces) ?? []\n            todos = try container.decodeIfPresent([LifeRouteTodo].self, forKey: .todos) ?? []\n            manualCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents) ?? []\n",
        "backward-compatible To-Dos decoding",
    )

    text = replace_once(
        text,
        '''    func loadRoutingState() -> RestoredRoutingPersistenceState {
        return RestoredRoutingPersistenceState(homeAddress: state.homeAddress, savedPlaces: state.savedPlaces)
    }

    func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace]) {
        var next = state
        next.homeAddress = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        next.savedPlaces = Self.sanitizedSavedPlaces(savedPlaces)
        state = next
        persist()
    }''',
        '''    func loadRoutingState() -> RestoredRoutingPersistenceState {
        return RestoredRoutingPersistenceState(
            homeAddress: state.homeAddress,
            savedPlaces: state.savedPlaces,
            todos: state.todos
        )
    }

    // Keep the existing persistence API available for older call sites and audits.
    func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace]) {
        saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces, todos: state.todos)
    }

    func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace], todos: [LifeRouteTodo]) {
        var next = state
        next.homeAddress = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        next.savedPlaces = Self.sanitizedSavedPlaces(savedPlaces)
        next.todos = todos
        state = Self.sanitized(next)
        persist()
    }''',
        "routing To-Dos persistence API",
    )

    text = replace_once(
        text,
        '''        let homeAddress = input.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlaces = sanitizedSavedPlaces(input.savedPlaces)
        let manualCalendarEvents = sanitizedManualCalendarEvents(input.manualCalendarEvents)''',
        '''        let homeAddress = input.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlaces = sanitizedSavedPlaces(input.savedPlaces)
        let savedPlaceIDs = Set(savedPlaces.map(\.id))
        let todos = sanitizedTodos(input.todos, savedPlaceIDs: savedPlaceIDs)
        let manualCalendarEvents = sanitizedManualCalendarEvents(input.manualCalendarEvents)''',
        "sanitize To-Dos",
    )
    text = replace_once(
        text,
        "            savedPlaces: savedPlaces,\n            manualCalendarEvents: manualCalendarEvents,\n",
        "            savedPlaces: savedPlaces,\n            todos: todos,\n            manualCalendarEvents: manualCalendarEvents,\n",
        "sanitized native To-Dos return",
    )

    sanitize_anchor = '''    private static func sanitizedManualCalendarEvents(_ input: [LifeRouteCalendarEvent]) -> [LifeRouteCalendarEvent] {
'''
    sanitize_todos = r'''    private static func sanitizedTodos(_ input: [LifeRouteTodo], savedPlaceIDs: Set<UUID>) -> [LifeRouteTodo] {
        var seenTodoIDs = Set<UUID>()
        return input.compactMap { todo -> LifeRouteTodo? in
            let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenTodoIDs.insert(todo.id).inserted else { return nil }
            let safeSavedPlaceID = todo.savedPlaceID.flatMap { savedPlaceIDs.contains($0) ? $0 : nil }
            return LifeRouteTodo(
                id: todo.id,
                title: title,
                category: todo.category,
                durationMinutes: todo.durationMinutes,
                savedPlaceID: safeSavedPlaceID,
                address: todo.address,
                priority: todo.priority,
                dueDate: todo.dueDate,
                notes: todo.notes,
                completed: todo.completed,
                createdAt: todo.createdAt,
                completedAt: todo.completed ? todo.completedAt : nil
            )
        }.sorted { lhs, rhs in
            if lhs.completed != rhs.completed { return !lhs.completed }
            if lhs.priority.sortWeight != rhs.priority.sortWeight {
                return lhs.priority.sortWeight > rhs.priority.sortWeight
            }
            if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
            return lhs.createdAt < rhs.createdAt
        }
    }

'''
    text = replace_once(text, sanitize_anchor, sanitize_todos + sanitize_anchor, "To-Do sanitization helper")

    STORE.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    if "private var weeklyTodosCard: some View" in text:
        return

    text = replace_once(
        text,
        "    @State private var gapSuggestion = true\n    @State private var message: String?\n",
        '''    @State private var gapSuggestion = true
    @State private var message: String?

    @State private var todoTitle = ""
    @State private var todoCategory: LifeRouteTodoCategory = .errand
    @State private var todoDurationMinutes = 30
    @State private var todoSavedPlaceID = ""
    @State private var todoAddress = ""
    @State private var todoPriority: LifeRouteTodoPriority = .normal
    @State private var todoDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var todoNotes = ""
    @State private var todoMessage: String?
''',
        "Setup To-Do draft state",
    )

    text = replace_once(
        text,
        "                savedPlacesCard\n                addPlaceCard\n",
        "                savedPlacesCard\n                weeklyTodosCard\n                addTodoCard\n                addPlaceCard\n",
        "Setup To-Dos placement near Saved Places",
    )

    text = replace_once(
        text,
        'Text("Your RBT profile, navigation app, appearance, clients, home base, and saved places — all in one place.")',
        'Text("Your RBT profile, navigation app, appearance, clients, home base, saved places, and weekly to-dos — all in one place.")',
        "Setup hero To-Dos copy",
    )

    add_place_anchor = '''    private var addPlaceCard: some View {
'''
    todo_views = r'''    private var weeklyTodosCard: some View {
        let openTodos = routingState.todos.filter { !$0.completed }
        let completedTodos = routingState.todos.filter(\.completed).prefix(3)

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Weekly To-Dos", systemImage: "checklist")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(openTodos.count) open")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            Text("Flexible errands and tasks LifeRoute can fit around the rest of your week.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            if openTodos.isEmpty {
                Text("No open to-dos. Add an errand, shopping trip, pickup, chore, call, or other flexible task below.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            } else {
                ForEach(openTodos) { todo in
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(palette.accent.opacity(0.13))
                            Image(systemName: todo.category.systemImage)
                                .foregroundStyle(palette.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("\(todo.category.rawValue) · \(todo.durationMinutes) min · due \(todo.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            if !todo.address.isEmpty {
                                Label(todo.address, systemImage: "mappin.and.ellipse")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                            if todo.priority == .high {
                                Text("HIGH PRIORITY")
                                    .font(.caption2.weight(.black))
                                    .tracking(0.6)
                                    .foregroundStyle(palette.accentSecondary)
                            }
                        }

                        Spacer(minLength: 6)

                        VStack(spacing: 9) {
                            Button {
                                routingState.setTodoCompleted(id: todo.id, completed: true)
                                LifeRouteHaptics.success()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(palette.accentSecondary)
                            .accessibilityLabel("Complete \(todo.title)")

                            Button(role: .destructive) {
                                routingState.removeTodo(id: todo.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(todo.title)")
                        }
                    }
                    .padding(10)
                    .background(palette.panelElevated.opacity(0.27), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if !completedTodos.isEmpty {
                Divider().overlay(palette.textSecondary.opacity(0.18))
                Text("RECENTLY COMPLETED")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(palette.textSecondary)

                ForEach(Array(completedTodos)) { todo in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.accentSecondary)
                        Text(todo.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                            .strikethrough()
                        Spacer()
                        Button("Undo") {
                            routingState.setTodoCompleted(id: todo.id, completed: false)
                            LifeRouteHaptics.selection()
                        }
                        .font(.caption.weight(.bold))
                    }
                }
            }
        }
        .lifeRouteCard()
    }

    private var addTodoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add to-do", systemImage: "plus.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            TextField("What needs to get done?", text: $todoTitle)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Picker("Category", selection: $todoCategory) {
                ForEach(LifeRouteTodoCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.systemImage).tag(category)
                }
            }
            .pickerStyle(.menu)

            Picker("Estimated task time", selection: $todoDurationMinutes) {
                Text("10 min").tag(10)
                Text("15 min").tag(15)
                Text("20 min").tag(20)
                Text("30 min").tag(30)
                Text("45 min").tag(45)
                Text("1 hour").tag(60)
                Text("1.5 hours").tag(90)
            }
            .pickerStyle(.menu)

            Picker("Saved place (optional)", selection: $todoSavedPlaceID) {
                Text("No saved place").tag("")
                ForEach(routingState.savedPlaces) { place in
                    Text(place.name).tag(place.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: todoSavedPlaceID) { value in
                guard let id = UUID(uuidString: value),
                      let place = routingState.savedPlaces.first(where: { $0.id == id }) else { return }
                todoAddress = place.address
            }

            V054AddressField("Location / store (optional)", text: $todoAddress)

            Picker("Priority", selection: $todoPriority) {
                ForEach(LifeRouteTodoPriority.allCases) { priority in
                    Text(priority.title).tag(priority)
                }
            }
            .pickerStyle(.segmented)

            DatePicker("Do by", selection: $todoDueDate, displayedComponents: .date)

            TextField("Notes (optional)", text: $todoNotes, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                addTodo()
            } label: {
                Label("Add to-do", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())

            if let todoMessage {
                Text(todoMessage)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

'''
    text = replace_once(text, add_place_anchor, todo_views + add_place_anchor, "Setup To-Do cards")

    helper_anchor = '''    private func addPlace() {
'''
    add_todo_helper = r'''    private func addTodo() {
        do {
            try routingState.addTodo(
                title: todoTitle,
                category: todoCategory,
                durationMinutes: todoDurationMinutes,
                savedPlaceID: UUID(uuidString: todoSavedPlaceID),
                address: todoAddress,
                priority: todoPriority,
                dueDate: todoDueDate,
                notes: todoNotes
            )
            todoTitle = ""
            todoCategory = .errand
            todoDurationMinutes = 30
            todoSavedPlaceID = ""
            todoAddress = ""
            todoPriority = .normal
            todoDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            todoNotes = ""
            todoMessage = "To-do added for this week."
            LifeRouteHaptics.success()
        } catch {
            todoMessage = error.localizedDescription
        }
    }

'''
    text = replace_once(text, helper_anchor, add_todo_helper + helper_anchor, "Setup add To-Do helper")

    text = text.replace(
        "RBT profile preferences, home, saved places, client profiles, and visual supports are stored locally in LifeRoute app data.",
        "RBT profile preferences, home, saved places, weekly to-dos, client profiles, and visual supports are stored locally in LifeRoute app data.",
    )

    SETUP.write_text(text, encoding="utf-8")


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 restored To-Do gap fillers" in text:
        return

    text = replace_once(
        text,
        '''            let suggestions = routingState.savedPlaces.filter(\.useInGapSuggestions)
            if suggestions.isEmpty {
                Text("Mark saved places as gap suggestions in Setup and they’ll surface here.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lifeRouteCard()
            } else {
                ForEach(suggestions.prefix(4)) { place in''',
        '''            // v0.7.0 restored To-Do gap fillers: flexible weekly tasks surface before saved-place ideas.
            let openTodos = routingState.todos.filter { !$0.completed }
            let suggestions = routingState.savedPlaces.filter(\.useInGapSuggestions)
            if openTodos.isEmpty && suggestions.isEmpty {
                Text("Add a weekly to-do or mark saved places as gap suggestions in Setup and they’ll surface here.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lifeRouteCard()
            } else {
                ForEach(openTodos.prefix(3)) { todo in
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.15))
                            Image(systemName: todo.category.systemImage)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("\(todo.durationMinutes) min · due \(todo.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            if !todo.address.isEmpty {
                                Text(todo.address)
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            routingState.setTodoCompleted(id: todo.id, completed: true)
                            LifeRouteHaptics.success()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(todo.title)")
                    }
                    .lifeRouteCard()
                }

                ForEach(suggestions.prefix(openTodos.isEmpty ? 4 : 2)) { place in''',
        "Home To-Do gap suggestions",
    )

    TODAY.write_text(text, encoding="utf-8")


def main() -> None:
    patch_routing()
    patch_store()
    patch_setup()
    patch_today()
    print("LifeRoute v0.7.0 native To-Dos restored: weekly flexible tasks persist locally, live beside Saved Places in Setup, support the legacy task metadata, completion/undo, and surface in Home gap fillers.")


if __name__ == "__main__":
    main()
