import SwiftUI
import UIKit

struct V054SetupView: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
    @EnvironmentObject private var router: AppRouter
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var clientState: ClientProfileCore

    @AppStorage("liferoute.rbtProfile.name") private var rbtName = ""
    @AppStorage("liferoute.rbtProfile.organization") private var rbtOrganization = ""
    @AppStorage("liferoute.rbtProfile.credential") private var rbtCredential = ""
    @AppStorage("liferoute.preferredNavigationApp") private var preferredNavigationAppRaw = LifeRouteNavigationApp.appleMaps.rawValue

    @State private var homeDraft = ""
    @State private var placeName = ""
    @State private var placeAddress = ""
    @State private var placeKind: LifeRoutePlaceKind = .other
    @State private var minimumVisitMinutes = 30
    @State private var gapSuggestion = true
    @State private var customRouteBufferMinutes = 10
    @State private var customRouteBufferSelected = false
    @State private var message: String?

    // v0.7.1 Setup disclosure groups: Appearance is immediately useful; heavier sections start collapsed.
    @State private var appearanceExpanded = true
    @State private var profileExpanded = false
    @State private var navigationExpanded = false
    @State private var todosExpanded = false
    @State private var clinicalExpanded = false
    @State private var privacyExpanded = false

    @State private var todoTitle = ""
    @State private var todoCategory: LifeRouteTodoCategory = .errand
    @State private var todoDurationMinutes = 30
    @State private var todoSavedPlaceID = ""
    @State private var todoAddress = ""
    @State private var todoPriority: LifeRouteTodoPriority = .normal
    @State private var todoDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var todoNotes = ""
    @State private var todoMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                hero

                ScenicRoyalSetupDisclosureGroup(
                    title: "Appearance",
                    subtitle: themeStore.selectedTheme.name,
                    systemImage: "sparkles",
                    isExpanded: $appearanceExpanded
                ) {
                    themeCard
                }

                ScenicRoyalSetupDisclosureGroup(
                    title: "Profile & Work",
                    subtitle: rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "RBT identity and organization" : rbtName,
                    systemImage: "person.crop.circle.badge.checkmark",
                    isExpanded: $profileExpanded
                ) {
                    rbtProfileCard
                }

                ScenicRoyalSetupDisclosureGroup(
                    title: "Navigation & Places",
                    subtitle: "\(preferredNavigationApp.title) · \(routingState.savedPlaces.count) saved places",
                    systemImage: "location.north.line.fill",
                    isExpanded: $navigationExpanded
                ) {
                    navigationAppCard
                    homeCard
                    savedPlacesCard
                    addPlaceCard
                }

                ScenicRoyalSetupDisclosureGroup(
                    title: "Weekly To-Dos",
                    subtitle: "Recurring planning and destinations",
                    systemImage: "checklist",
                    isExpanded: $todosExpanded
                ) {
                    weeklyTodosCard
                    addTodoCard
                }

                ScenicRoyalSetupDisclosureGroup(
                    title: "Clinical",
                    subtitle: clientState.clients.isEmpty ? "Client profiles" : "\(clientState.clients.count) saved client profiles",
                    systemImage: "person.2.fill",
                    isExpanded: $clinicalExpanded
                ) {
                    clientCard
                }

                ScenicRoyalSetupDisclosureGroup(
                    title: "Privacy",
                    subtitle: "Local-first storage details",
                    systemImage: "lock.shield.fill",
                    isExpanded: $privacyExpanded
                ) {
                    privacyCard
                }
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            router.setBottomToolbarSuppressed(false)
            if homeDraft.isEmpty { homeDraft = routingState.homeAddress }
            if !routeBufferPresets.contains(routingState.routeBufferMinutes) {
                customRouteBufferMinutes = routingState.routeBufferMinutes
                customRouteBufferSelected = true
            }
        }
    }

    private var hero: some View {
        ScenicRoyalSetupHeader(savedPlaceCount: routingState.savedPlaces.count)
    }

    private var rbtProfileCard: some View {
        ScenicRoyalSetupCard(
            title: "RBT Profile",
            subtitle: "Your work identity stays separate from client profiles and is stored locally.",
            systemImage: "person.crop.circle.badge.checkmark"
        ) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ZStack {
                    Circle()
                        .fill(style.accent.opacity(0.16))
                    Text(profileInitials)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(style.accentReflection)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text(rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Registered Behavior Technician" : rbtName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                    Text(rbtOrganization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Organization not set" : rbtOrganization)
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            profileField("Your name", text: $rbtName, contentType: .name)
            profileField("Organization / agency (optional)", text: $rbtOrganization, contentType: .organizationName)
            profileField("RBT credential ID (optional)", text: $rbtCredential, contentType: nil)

            Divider()
                .overlay(style.accent.opacity(0.18))

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Label("Route Buffer", systemImage: "clock.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(style.primaryText)

                Text("Adds one arrival margin before each timed appointment. Raw MapKit drive estimates stay unchanged.")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Route Buffer", selection: routeBufferSelection) {
                    Text("None").tag(0)
                    ForEach(routeBufferPresets.filter { $0 > 0 }, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                    Text("Custom").tag(-1)
                }
                .pickerStyle(.menu)
                .tint(style.accent)
                .scenicRoyalField()

                if customRouteBufferSelected {
                    Stepper(
                        "Custom buffer: \(customRouteBufferMinutes) min",
                        value: $customRouteBufferMinutes,
                        in: 1...180
                    )
                    .font(.subheadline.weight(.semibold))
                    .scenicRoyalField()
                    .onChange(of: customRouteBufferMinutes) { minutes in
                        routingState.setRouteBufferMinutes(minutes)
                    }
                }

                Text(routeBufferSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.accentReflection)
            }

            Label("Saved automatically", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.accentReflection)
        }
    }

    private var navigationAppCard: some View {
        ScenicRoyalSetupCard(
            title: "Navigation app",
            subtitle: "Choose the provider used to launch routes. Estimates remain MapKit-powered inside LifeRoute.",
            systemImage: "location.north.circle.fill"
        ) {
            Picker("Preferred navigation app", selection: $preferredNavigationAppRaw) {
                ForEach(LifeRouteNavigationApp.allCases) { app in
                    Label(app.title, systemImage: app.systemImage)
                        .tag(app.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(style.accent)
            .scenicRoyalField()
            .onChange(of: preferredNavigationAppRaw) { _ in
                LifeRouteHaptics.selection()
            }

            ScenicRoyalInsetRow(role: .ambient) {
                HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    Image(systemName: preferredNavigationApp.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(style.accentReflection)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                        Text("Open routes with \(preferredNavigationApp.title)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(style.primaryText)
                        Text(preferredNavigationApp.detail)
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var themeCard: some View {
        NavigationLink {
            V054ThemeCenterView()
                .lifeRouteDeepDestination()
        } label: {
            ScenicRoyalInsetRow(role: .readability) {
                ScenicRoyalSetupNavigationRow(
                    title: "Theme Center",
                    subtitle: themeStore.selectedTheme.name,
                    detail: "Color, scenery, and material system",
                    systemImage: "sparkles"
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Theme Center")
    }

    private var clientCard: some View {
        NavigationLink {
            V054ClientProfilesView(clientState: clientState)
                .lifeRouteDeepDestination()
        } label: {
            ScenicRoyalInsetRow(role: .readability) {
                ScenicRoyalSetupNavigationRow(
                    title: "Clients",
                    subtitle: clientState.clients.isEmpty ? "No client profiles yet" : "\(clientState.clients.count) saved client profiles",
                    detail: "Manage local client context",
                    systemImage: "person.2.fill"
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens client profiles")
    }

    private var homeCard: some View {
        ScenicRoyalSetupCard(
            title: "Home Base",
            subtitle: "Routing fallback when live location is unavailable; also powers Return Home.",
            systemImage: "house.fill"
        ) {
            V054AddressField("Home address", text: $homeDraft)

            Button(action: saveHomeAddress) {
                Label("Save home address", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())

            if let message {
                ScenicRoyalSetupStatusText(message: message)
            }
        }
    }

    private var savedPlacesCard: some View {
        ScenicRoyalSetupCard(
            title: "Saved Places",
            subtitle: "\(routingState.savedPlaces.count) saved place\(routingState.savedPlaces.count == 1 ? "" : "s") for routing, stops, and gap planning.",
            systemImage: "bookmark.fill"
        ) {
            if routingState.savedPlaces.isEmpty {
                Text("Save gyms, stores, parks, work locations, errands, and other useful stops below.")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    ForEach(routingState.savedPlaces) { place in
                        ScenicRoyalSavedPlaceRow(
                            place: place,
                            systemImage: icon(for: place.kind)
                        ) {
                            routingState.removeSavedPlace(id: place.id)
                        }
                    }
                }
            }
        }
    }

    private var weeklyTodosCard: some View {
        let openTodos = routingState.todos.filter { !$0.completed }
        let completedTodos = routingState.todos.filter(\.completed).prefix(3)

        return ScenicRoyalSetupCard(
            title: "Weekly To-Dos",
            subtitle: "\(openTodos.count) open · flexible errands and tasks LifeRoute can fit around your week.",
            systemImage: "checklist"
        ) {
            if openTodos.isEmpty {
                Text("No open to-dos. Add an errand, shopping trip, pickup, chore, call, or other flexible task below.")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    ForEach(openTodos) { todo in
                        ScenicRoyalTodoRow(
                            todo: todo,
                            onComplete: {
                                routingState.setTodoCompleted(id: todo.id, completed: true)
                                LifeRouteHaptics.success()
                            },
                            onDelete: {
                                routingState.removeTodo(id: todo.id)
                            }
                        )
                    }
                }
            }

            if !completedTodos.isEmpty {
                Divider().overlay(style.secondaryText.opacity(0.24))
                Text("RECENTLY COMPLETED")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(style.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                ForEach(Array(completedTodos)) { todo in
                    ScenicRoyalCompletedTodoRow(todo: todo) {
                        routingState.setTodoCompleted(id: todo.id, completed: false)
                        LifeRouteHaptics.selection()
                    }
                }
            }
        }
    }

    private var addTodoCard: some View {
        ScenicRoyalSetupCard(
            title: "Add To-Do",
            subtitle: "Create a flexible task with optional place and timing context.",
            systemImage: "plus.circle.fill"
        ) {
            TextField("What needs to get done?", text: $todoTitle)
                .submitLabel(.next)
                .scenicRoyalField()

            Picker("Category", selection: $todoCategory) {
                ForEach(LifeRouteTodoCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.systemImage).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(style.accent)
            .scenicRoyalField()

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
            .tint(style.accent)
            .scenicRoyalField()

            Picker("Saved place (optional)", selection: $todoSavedPlaceID) {
                Text("No saved place").tag("")
                ForEach(routingState.savedPlaces) { place in
                    Text(place.name).tag(place.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .tint(style.accent)
            .scenicRoyalField()
            .onChange(of: todoSavedPlaceID) { value in
                guard let id = UUID(uuidString: value),
                      let place = routingState.savedPlaces.first(where: { $0.id == id }) else { return }
                todoAddress = place.address
            }

            V054AddressField("Location / store (optional)", text: $todoAddress, mode: .todoDestination)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    Picker("Priority", selection: $todoPriority) {
                        ForEach(LifeRouteTodoPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("Priority", selection: $todoPriority) {
                        ForEach(LifeRouteTodoPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .tint(style.accent)
            .scenicRoyalField()

            DatePicker("Do by", selection: $todoDueDate, displayedComponents: .date)
                .tint(style.accent)
                .scenicRoyalField()

            TextField("Notes (optional)", text: $todoNotes, axis: .vertical)
                .lineLimit(2...4)
                .scenicRoyalField()

            Button(action: addTodo) {
                Label("Add to-do", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())

            if let todoMessage {
                ScenicRoyalSetupStatusText(message: todoMessage)
            }
        }
    }

    private var addPlaceCard: some View {
        ScenicRoyalSetupCard(
            title: "Add Place",
            subtitle: "Save a reusable stop for routing, Generate Full Day, and gap planning.",
            systemImage: "mappin.and.ellipse"
        ) {
            TextField("Place name", text: $placeName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .scenicRoyalField()

            V054AddressField("Address or place", text: $placeAddress)

            Picker("Type", selection: $placeKind) {
                ForEach(LifeRoutePlaceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .tint(style.accent)
            .scenicRoyalField()

            Stepper("Useful visit: \(minimumVisitMinutes) min", value: $minimumVisitMinutes, in: 5...240, step: 5)
                .font(.subheadline.weight(.semibold))
                .scenicRoyalField()

            Toggle("Use in gap suggestions", isOn: $gapSuggestion)
                .font(.subheadline.weight(.semibold))
                .tint(style.accent)
                .scenicRoyalField()

            Button(action: addPlace) {
                Label("Save place", systemImage: "plus.circle.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())
        }
    }

    private var privacyCard: some View {
        ScenicRoyalSetupCard(
            title: "Local-First Setup",
            subtitle: "Your configuration remains on this device unless an existing system service is explicitly opened.",
            systemImage: "lock.shield.fill"
        ) {
            Text("RBT profile preferences, home, saved places, weekly to-dos, client profiles, and visual supports are stored locally in LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
                .font(.caption)
                .foregroundStyle(style.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var preferredNavigationApp: LifeRouteNavigationApp {
        LifeRouteNavigationApp(rawValue: preferredNavigationAppRaw) ?? .appleMaps
    }

    private var routeBufferPresets: [Int] { [0, 5, 10, 15, 20, 30] }

    private var routeBufferSelection: Binding<Int> {
        Binding(
            get: {
                !customRouteBufferSelected && routeBufferPresets.contains(routingState.routeBufferMinutes)
                    ? routingState.routeBufferMinutes
                    : -1
            },
            set: { selection in
                if selection >= 0 {
                    customRouteBufferSelected = false
                    routingState.setRouteBufferMinutes(selection)
                    return
                }
                customRouteBufferSelected = true
                let custom = routeBufferPresets.contains(routingState.routeBufferMinutes)
                    ? max(1, customRouteBufferMinutes)
                    : routingState.routeBufferMinutes
                customRouteBufferMinutes = custom
                routingState.setRouteBufferMinutes(custom)
            }
        )
    }

    private var routeBufferSummary: String {
        routingState.routeBufferMinutes == 0
            ? "No additional arrival margin"
            : "+\(routingState.routeBufferMinutes) min before each timed appointment"
    }

    private var profileInitials: String {
        let parts = rbtName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
        let initials = parts.compactMap(\.first).map(String.init).joined().uppercased()
        return initials.isEmpty ? "RBT" : initials
    }

    private func profileField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType?) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.words)
            .scenicRoyalField()
    }

    private func saveHomeAddress() {
        do {
            try routingState.setHomeAddress(homeDraft)
            message = "Home address saved."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func addTodo() {
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

    private func addPlace() {
        do {
            try routingState.addSavedPlace(
                name: placeName,
                address: placeAddress,
                kind: placeKind,
                minimumVisitMinutes: minimumVisitMinutes,
                useInGapSuggestions: gapSuggestion
            )
            placeName = ""
            placeAddress = ""
            placeKind = .other
            minimumVisitMinutes = 30
            gapSuggestion = true
            message = "Saved place added."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func icon(for kind: LifeRoutePlaceKind) -> String {
        switch kind {
        case .gym: return "figure.strengthtraining.traditional"
        case .work: return "briefcase.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        case .park: return "leaf.fill"
        case .library: return "books.vertical.fill"
        case .errand: return "checklist"
        case .other: return "mappin.circle.fill"
        }
    }
}
