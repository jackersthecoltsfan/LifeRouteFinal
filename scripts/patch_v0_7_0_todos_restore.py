#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTING = ROOT / "LifeRoute/RoutingLocationDomain.swift"
PERSISTENCE = ROOT / "LifeRoute/PersistenceCore.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 To-Dos restore failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_routing() -> None:
    text = ROUTING.read_text(encoding="utf-8")
    if "v0.7.0 native To-Dos restore" in text:
        return

    saved_place_anchor = '''struct LifeRouteAddressSuggestion: Identifiable, Hashable {\n'''
    todo_models = r'''// v0.7.0 native To-Dos restore: recover the flexible task / errand model that
// existed in the earlier LifeRoute experience, now owned by the native routing core.
enum LifeRouteTodoCategory: String, CaseIterable, Codable, Identifiable {
    case errand = "Errand"
    case shopping = "Shopping"
    case pickup = "Pickup"
    case chore = "Chore"
    case call = "Call"
    case other = "Other"

    var id: Self { self }
}

enum LifeRouteTodoPriority: String, CaseIterable, Codable, Identifiable {
    case high = "High"
    case normal = "Normal"
    case low = "Low"

    var id: Self { self }

    var sortWeight: Int {
        switch self {
        case .high: return 3
        case .normal: return 2
        case .low: return 1
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
        category: LifeRouteTodoCategory = .errand,
        durationMinutes: Int = 30,
        savedPlaceID: UUID? = nil,
        address: String = "",
        priority: LifeRouteTodoPriority = .normal,
        dueDate: Date = Date(),
        notes: String = "",
        completed: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.durationMinutes = min(240, max(5, durationMinutes))
        self.savedPlaceID = savedPlaceID
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.completed = completed
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var isRouteReady: Bool { !address.isEmpty || savedPlaceID != nil }
}

'''
    text = replace_once(text, saved_place_anchor, todo_models + saved_place_anchor, "todo domain models")

    text = replace_once(
        text,
        '''    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []\n    @Published private(set) var routeEstimates: [UUID: LifeRouteRouteEstimate] = [:]\n''',
        '''    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []\n    @Published private(set) var weeklyTodos: [LifeRouteTodo] = []\n    @Published private(set) var routeEstimates: [UUID: LifeRouteRouteEstimate] = [:]\n''',
        "todo published state",
    )

    text = replace_once(
        text,
        '''        self.savedPlaces = restored.savedPlaces\n        self.homeAddress = restored.homeAddress\n''',
        '''        self.savedPlaces = restored.savedPlaces\n        self.weeklyTodos = restored.weeklyTodos\n        self.homeAddress = restored.homeAddress\n''',
        "todo restore",
    )

    remove_place_anchor = '''    func removeSavedPlace(id: UUID) {
        cancelRouteOperation(for: id)
        savedPlaces.removeAll { $0.id == id }
        routeEstimates[id] = nil
        persistRoutingInputs()
    }

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
        guard !cleanTitle.isEmpty else { throw RoutingLocationCoreError.missingName }

        let linkedPlace = savedPlaceID.flatMap { id in savedPlaces.first { $0.id == id } }
        let resolvedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (linkedPlace?.address ?? "")
            : address.trimmingCharacters(in: .whitespacesAndNewlines)

        weeklyTodos.append(
            LifeRouteTodo(
                title: cleanTitle,
                category: category,
                durationMinutes: durationMinutes,
                savedPlaceID: linkedPlace?.id,
                address: resolvedAddress,
                priority: priority,
                dueDate: Calendar.current.startOfDay(for: dueDate),
                notes: notes
            )
        )
        sortTodos()
        persistRoutingInputs()
        publishRouteMessage("To-do saved locally.")
    }

    func completeTodo(id: UUID) {
        guard let index = weeklyTodos.firstIndex(where: { $0.id == id }) else { return }
        weeklyTodos[index].completed = true
        weeklyTodos[index].completedAt = Date()
        sortTodos()
        persistRoutingInputs()
    }

    func reopenTodo(id: UUID) {
        guard let index = weeklyTodos.firstIndex(where: { $0.id == id }) else { return }
        weeklyTodos[index].completed = false
        weeklyTodos[index].completedAt = nil
        sortTodos()
        persistRoutingInputs()
    }

    func removeTodo(id: UUID) {
        weeklyTodos.removeAll { $0.id == id }
        persistRoutingInputs()
    }

    func resolvedAddress(for todo: LifeRouteTodo) -> String {
        if let savedPlaceID = todo.savedPlaceID,
           let place = savedPlaces.first(where: { $0.id == savedPlaceID }) {
            return place.address
        }
        return todo.address
    }

    private func sortTodos() {
        weeklyTodos.sort { left, right in
            if left.completed != right.completed { return !left.completed }
            if left.priority.sortWeight != right.priority.sortWeight {
                return left.priority.sortWeight > right.priority.sortWeight
            }
            if left.dueDate != right.dueDate { return left.dueDate < right.dueDate }
            return left.createdAt < right.createdAt
        }
    }

'''
    text = replace_once(text, remove_place_anchor, remove_place_anchor + todo_methods, "todo mutations")

    text = replace_once(
        text,
        '''    private func persistRoutingInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces)
    }
''',
        '''    private func persistRoutingInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            weeklyTodos: weeklyTodos
        )
    }
''',
        "todo persistence call",
    )

    ROUTING.write_text(text, encoding="utf-8")


def patch_persistence() -> None:
    text = PERSISTENCE.read_text(encoding="utf-8")
    if "weeklyTodos: [LifeRouteTodo]" in text and "schemaVersion: Int = 5" in text:
        return

    text = replace_once(
        text,
        '''struct RestoredRoutingPersistenceState {
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]

    static let empty = RestoredRoutingPersistenceState(homeAddress: "", savedPlaces: [])
}
''',
        '''struct RestoredRoutingPersistenceState {
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]
    var weeklyTodos: [LifeRouteTodo]

    static let empty = RestoredRoutingPersistenceState(homeAddress: "", savedPlaces: [], weeklyTodos: [])
}
''',
        "restored routing todos",
    )

    text = replace_once(
        text,
        '''        var homeAddress: String
        var savedPlaces: [LifeRouteSavedPlace]
        var manualCalendarEvents: [LifeRouteCalendarEvent]
''',
        '''        var homeAddress: String
        var savedPlaces: [LifeRouteSavedPlace]
        var weeklyTodos: [LifeRouteTodo]
        var manualCalendarEvents: [LifeRouteCalendarEvent]
''',
        "native state todo property",
    )

    text = replace_once(text, "            schemaVersion: Int = 4,\n", "            schemaVersion: Int = 5,\n", "schema version")

    text = replace_once(
        text,
        '''            homeAddress: String = "",
            savedPlaces: [LifeRouteSavedPlace] = [],
            manualCalendarEvents: [LifeRouteCalendarEvent] = [],
''',
        '''            homeAddress: String = "",
            savedPlaces: [LifeRouteSavedPlace] = [],
            weeklyTodos: [LifeRouteTodo] = [],
            manualCalendarEvents: [LifeRouteCalendarEvent] = [],
''',
        "native init todo parameter",
    )

    text = replace_once(
        text,
        '''            self.homeAddress = homeAddress
            self.savedPlaces = savedPlaces
            self.manualCalendarEvents = manualCalendarEvents
''',
        '''            self.homeAddress = homeAddress
            self.savedPlaces = savedPlaces
            self.weeklyTodos = weeklyTodos
            self.manualCalendarEvents = manualCalendarEvents
''',
        "native init todo assignment",
    )

    text = replace_once(
        text,
        '''            case homeAddress
            case savedPlaces
            case manualCalendarEvents
''',
        '''            case homeAddress
            case savedPlaces
            case weeklyTodos
            case manualCalendarEvents
''',
        "todo coding key",
    )

    text = replace_once(
        text,
        '''            homeAddress = try container.decodeIfPresent(String.self, forKey: .homeAddress) ?? ""
            savedPlaces = try container.decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces) ?? []
            manualCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents) ?? []
''',
        '''            homeAddress = try container.decodeIfPresent(String.self, forKey: .homeAddress) ?? ""
            savedPlaces = try container.decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces) ?? []
            weeklyTodos = try container.decodeIfPresent([LifeRouteTodo].self, forKey: .weeklyTodos) ?? []
            manualCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents) ?? []
''',
        "backward-compatible todo decode",
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
    }
''',
        '''    func loadRoutingState() -> RestoredRoutingPersistenceState {
        return RestoredRoutingPersistenceState(
            homeAddress: state.homeAddress,
            savedPlaces: state.savedPlaces,
            weeklyTodos: state.weeklyTodos
        )
    }

    func saveRoutingState(
        homeAddress: String,
        savedPlaces: [LifeRouteSavedPlace],
        weeklyTodos: [LifeRouteTodo]
    ) {
        var next = state
        next.homeAddress = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        next.savedPlaces = Self.sanitizedSavedPlaces(savedPlaces)
        next.weeklyTodos = Self.sanitizedWeeklyTodos(weeklyTodos, savedPlaces: next.savedPlaces)
        state = next
        persist()
    }
''',
        "routing persistence boundary",
    )

    text = replace_once(
        text,
        '''        let homeAddress = input.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlaces = sanitizedSavedPlaces(input.savedPlaces)
        let manualCalendarEvents = sanitizedManualCalendarEvents(input.manualCalendarEvents)
''',
        '''        let homeAddress = input.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlaces = sanitizedSavedPlaces(input.savedPlaces)
        let weeklyTodos = sanitizedWeeklyTodos(input.weeklyTodos, savedPlaces: savedPlaces)
        let manualCalendarEvents = sanitizedManualCalendarEvents(input.manualCalendarEvents)
''',
        "sanitize todos",
    )

    text = replace_once(
        text,
        '''            schemaVersion: max(4, input.schemaVersion),
            clients: clients,
            visualIcons: icons,
            choiceBoards: boards,
            visualSchedules: schedules,
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            manualCalendarEvents: manualCalendarEvents,
''',
        '''            schemaVersion: max(5, input.schemaVersion),
            clients: clients,
            visualIcons: icons,
            choiceBoards: boards,
            visualSchedules: schedules,
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            weeklyTodos: weeklyTodos,
            manualCalendarEvents: manualCalendarEvents,
''',
        "persist sanitized todos",
    )

    helper_anchor = '''    private static func sanitizedManualCalendarEvents(_ input: [LifeRouteCalendarEvent]) -> [LifeRouteCalendarEvent] {\n'''
    todo_sanitizer = r'''    private static func sanitizedWeeklyTodos(
        _ input: [LifeRouteTodo],
        savedPlaces: [LifeRouteSavedPlace]
    ) -> [LifeRouteTodo] {
        let validPlaceIDs = Set(savedPlaces.map(\.id))
        var seenIDs = Set<UUID>()
        let calendar = Calendar.current

        return input.compactMap { todo -> LifeRouteTodo? in
            let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenIDs.insert(todo.id).inserted else { return nil }
            let savedPlaceID = todo.savedPlaceID.flatMap { validPlaceIDs.contains($0) ? $0 : nil }
            return LifeRouteTodo(
                id: todo.id,
                title: title,
                category: todo.category,
                durationMinutes: todo.durationMinutes,
                savedPlaceID: savedPlaceID,
                address: todo.address,
                priority: todo.priority,
                dueDate: calendar.startOfDay(for: todo.dueDate),
                notes: todo.notes,
                completed: todo.completed,
                createdAt: todo.createdAt,
                completedAt: todo.completed ? todo.completedAt : nil
            )
        }.sorted { left, right in
            if left.completed != right.completed { return !left.completed }
            if left.priority.sortWeight != right.priority.sortWeight {
                return left.priority.sortWeight > right.priority.sortWeight
            }
            if left.dueDate != right.dueDate { return left.dueDate < right.dueDate }
            return left.createdAt < right.createdAt
        }
    }

'''
    text = replace_once(text, helper_anchor, todo_sanitizer + helper_anchor, "todo sanitizer")

    PERSISTENCE.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    if "v0.7.0 restored weekly To-Dos" in text:
        return

    text = replace_once(
        text,
        '''    @State private var gapSuggestion = true
    @State private var message: String?
''',
        '''    @State private var gapSuggestion = true
    @State private var todoTitle = ""
    @State private var todoCategory: LifeRouteTodoCategory = .errand
    @State private var todoDurationMinutes = 30
    @State private var todoSavedPlaceID = ""
    @State private var todoAddress = ""
    @State private var todoPriority: LifeRouteTodoPriority = .normal
    @State private var todoDueDate = Date()
    @State private var todoNotes = ""
    @State private var message: String?
''',
        "setup todo draft state",
    )

    text = replace_once(
        text,
        '''                savedPlacesCard
                addPlaceCard
                privacyCard
''',
        '''                savedPlacesCard
                addPlaceCard
                weeklyTodosCard
                addTodoCard
                privacyCard
''',
        "setup todo placement",
    )

    text = replace_once(
        text,
        '''                Text("Your RBT profile, navigation app, appearance, clients, home base, and saved places — all in one place.")
''',
        '''                Text("Your RBT profile, navigation app, appearance, clients, home base, saved places, and weekly to-dos — all in one place.")
''',
        "setup hero todo copy",
    )

    privacy_anchor = '''    private var privacyCard: some View {\n'''
    todo_cards = r'''    // v0.7.0 restored weekly To-Dos: native version of the earlier flexible errands feature.
    private var weeklyTodosCard: some View {
        let open = routingState.weeklyTodos.filter { !$0.completed }
        let completed = routingState.weeklyTodos.filter(\.completed).prefix(4)
        let dueThisWeek = open.filter(isDueThisWeek).count
        let routeReady = open.filter { !$0.address.isEmpty || $0.savedPlaceID != nil }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weekly To-Dos", systemImage: "checklist")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(open.count) open")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            Text("Flexible errands and tasks LifeRoute can fit around your schedule. Add a location when the task should be route-ready.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: 8) {
                todoMetric(value: "\(open.count)", label: "Open")
                todoMetric(value: "\(dueThisWeek)", label: "Due this week")
                todoMetric(value: "\(routeReady)", label: "Route-ready")
            }

            if open.isEmpty {
                Text("No open to-dos. Add an errand or flexible task below.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(open) { todo in
                    todoRow(todo, completed: false)
                }
            }

            if !completed.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                Text("RECENTLY COMPLETED")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(palette.textSecondary)
                ForEach(Array(completed)) { todo in
                    todoRow(todo, completed: true)
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

            HStack(spacing: 10) {
                Picker("Category", selection: $todoCategory) {
                    ForEach(LifeRouteTodoCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)

                Picker("Priority", selection: $todoPriority) {
                    ForEach(LifeRouteTodoPriority.allCases) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }
                .pickerStyle(.menu)
            }

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

            DatePicker("Do by", selection: $todoDueDate, displayedComponents: .date)
                .font(.subheadline.weight(.semibold))

            TextField("Notes (optional)", text: $todoNotes)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                addTodo()
            } label: {
                Label("Add to-do", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
        }
        .lifeRouteCard()
    }

    private func todoMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(palette.accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func todoRow(_ todo: LifeRouteTodo, completed: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if completed {
                    routingState.reopenTodo(id: todo.id)
                } else {
                    routingState.completeTodo(id: todo.id)
                }
                LifeRouteHaptics.success()
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(completed ? palette.accent : palette.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(completed ? "Reopen \(todo.title)" : "Complete \(todo.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .strikethrough(completed)
                Text("\(todo.category.rawValue) · \(todo.durationMinutes) min · \(todo.priority.rawValue)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.accentSecondary)
                Text(todoDueLabel(todo))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                if !routingState.resolvedAddress(for: todo).isEmpty {
                    Label(routingState.resolvedAddress(for: todo), systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Button(role: .destructive) {
                routingState.removeTodo(id: todo.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(todo.title)")
        }
        .padding(10)
        .background(palette.panelElevated.opacity(completed ? 0.18 : 0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(completed ? 0.72 : 1)
    }

'''
    text = replace_once(text, privacy_anchor, todo_cards + privacy_anchor, "weekly todos cards")

    text = replace_once(
        text,
        '''            Text("RBT profile preferences, home, saved places, client profiles, and visual supports are stored locally in LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
''',
        '''            Text("RBT profile preferences, home, saved places, weekly to-dos, client profiles, and visual supports are stored locally in LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
''',
        "todo privacy copy",
    )

    add_place_anchor = '''    private func addPlace() {\n'''
    todo_helpers = r'''    private func addTodo() {
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
            todoDueDate = Date()
            todoNotes = ""
            message = "To-do added."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func isDueThisWeek(_ todo: LifeRouteTodo) -> Bool {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return true }
        return interval.contains(todo.dueDate)
    }

    private func todoDueLabel(_ todo: LifeRouteTodo) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: todo.dueDate)
        if due < today { return "Overdue · \(due.formatted(date: .abbreviated, time: .omitted))" }
        if calendar.isDateInToday(due) { return "Due today" }
        return "Due \(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
    }

'''
    text = replace_once(text, add_place_anchor, todo_helpers + add_place_anchor, "todo setup helpers")

    SETUP.write_text(text, encoding="utf-8")


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 restored To-Dos gap fillers" in text:
        return

    text = replace_once(
        text,
        '''                overviewMetric(
                    value: "\\(routingState.savedPlaces.filter(\\.useInGapSuggestions).count)",
                    label: "Gap-ready",
                    detail: "Saved",
                    systemImage: "sparkles"
                )
''',
        '''                overviewMetric(
                    value: "\\(gapReadyCount)",
                    label: "Gap-ready",
                    detail: "Places + tasks",
                    systemImage: "sparkles"
                )
''',
        "gap-ready metric",
    )

    gap_anchor = '''    private var gapSuggestions: some View {\n'''
    gap_helpers = r'''    // v0.7.0 restored To-Dos gap fillers: recover the earlier flexible-task concept
    // without displacing saved-place suggestions.
    private var openGapTodos: [LifeRouteTodo] {
        routingState.weeklyTodos
            .filter { !$0.completed }
            .sorted { left, right in
                if left.priority.sortWeight != right.priority.sortWeight {
                    return left.priority.sortWeight > right.priority.sortWeight
                }
                if left.dueDate != right.dueDate { return left.dueDate < right.dueDate }
                return left.createdAt < right.createdAt
            }
    }

    private var gapReadyCount: Int {
        routingState.savedPlaces.filter(\.useInGapSuggestions).count
            + openGapTodos.filter { !routingState.resolvedAddress(for: $0).isEmpty }.count
    }

'''
    text = replace_once(text, gap_anchor, gap_helpers + gap_anchor, "todo gap helpers")

    old_gap_body = '''            let suggestions = routingState.savedPlaces.filter(\\.useInGapSuggestions)
            if suggestions.isEmpty {
                Text("Mark saved places as gap suggestions in Setup and they’ll surface here.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lifeRouteCard()
            } else {
                ForEach(suggestions.prefix(4)) { place in
                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.accent.opacity(0.15))
                                Image(systemName: placeIcon(place.kind))
                                    .foregroundStyle(palette.accentSecondary)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Useful visit: \\(place.minimumVisitMinutes) min")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                    .lifeRouteCard()
                }
            }
'''
    new_gap_body = '''            let suggestions = routingState.savedPlaces.filter(\\.useInGapSuggestions)
            let todos = Array(openGapTodos.prefix(2))

            if suggestions.isEmpty && todos.isEmpty {
                Text("Add weekly To-Dos or mark saved places as gap suggestions in Setup and they’ll surface here.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lifeRouteCard()
            } else {
                ForEach(todos) { todo in
                    Button {
                        LifeRouteHaptics.selection()
                        router.select(.setup)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(brandGold.opacity(0.15))
                                Image(systemName: "checklist")
                                    .foregroundStyle(brandGold)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(todo.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                    Text("TO-DO")
                                        .font(.system(size: 8, weight: .black))
                                        .tracking(0.8)
                                        .foregroundStyle(Color.black.opacity(0.78))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(brandGold, in: Capsule())
                                }
                                Text("\\(todo.durationMinutes) min · \\(todo.priority.rawValue) priority · \\(todoDueLabel(todo))")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .lifeRouteCard()
                }

                ForEach(suggestions.prefix(max(0, 4 - todos.count))) { place in
                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(routeBlue.opacity(0.15))
                                Image(systemName: placeIcon(place.kind))
                                    .foregroundStyle(routeBlue)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Useful visit: \\(place.minimumVisitMinutes) min")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                    .lifeRouteCard()
                }
            }
'''
    text = replace_once(text, old_gap_body, new_gap_body, "todo + place gap suggestions")

    time_anchor = '''    private func timeRemaining(to target: Date, now: Date) -> String {\n'''
    due_helper = r'''    private func todoDueLabel(_ todo: LifeRouteTodo) -> String {
        let calendar = Calendar.current
        let due = calendar.startOfDay(for: todo.dueDate)
        let today = calendar.startOfDay(for: Date())
        if due < today { return "overdue" }
        if calendar.isDateInToday(due) { return "due today" }
        return "due \(due.formatted(.dateTime.weekday(.abbreviated)))"
    }

'''
    text = replace_once(text, time_anchor, due_helper + time_anchor, "todo due label")

    TODAY.write_text(text, encoding="utf-8")


def main() -> None:
    patch_routing()
    patch_persistence()
    patch_setup()
    patch_today()
    print(
        "LifeRoute v0.7.0 To-Dos restored: the earlier flexible task/errand model is native again, persisted with routing inputs, visible beside Saved Places in Setup, completable/reopenable, and surfaced in Today gap fillers."
    )


if __name__ == "__main__":
    main()
