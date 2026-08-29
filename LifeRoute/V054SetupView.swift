import SwiftUI
import UIKit

// v0.7.1 Setup disclosure groups: keep every existing control, reduce simultaneous visual load.
private struct LifeRouteSetupDisclosureGroup<Content: View>: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
                LifeRouteHaptics.selection()
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.accent.opacity(isExpanded ? 0.18 : 0.10))
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isExpanded ? palette.accentSecondary : palette.accent)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(isExpanded ? "expanded" : "collapsed")")

            if isExpanded {
                VStack(spacing: 10) {
                    content
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(palette.panel.opacity(0.54), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(isExpanded ? 0.20 : 0.10), lineWidth: 1)
        }
    }
}

struct V054SetupView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
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
            LazyVStack(spacing: 10) {
                hero

                LifeRouteSetupDisclosureGroup(
                    title: "Appearance",
                    subtitle: themeStore.selectedTheme.name,
                    systemImage: "sparkles",
                    isExpanded: $appearanceExpanded
                ) {
                    themeCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Profile & Work",
                    subtitle: rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "RBT identity and organization" : rbtName,
                    systemImage: "person.crop.circle.badge.checkmark",
                    isExpanded: $profileExpanded
                ) {
                    rbtProfileCard
                }

                LifeRouteSetupDisclosureGroup(
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

                LifeRouteSetupDisclosureGroup(
                    title: "Weekly To-Dos",
                    subtitle: "Recurring planning and destinations",
                    systemImage: "checklist",
                    isExpanded: $todosExpanded
                ) {
                    weeklyTodosCard
                    addTodoCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Clinical",
                    subtitle: clientState.clients.isEmpty ? "Client profiles" : "\(clientState.clients.count) saved client profiles",
                    systemImage: "person.2.fill",
                    isExpanded: $clinicalExpanded
                ) {
                    clientCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Privacy",
                    subtitle: "Local-first storage details",
                    systemImage: "lock.shield.fill",
                    isExpanded: $privacyExpanded
                ) {
                    privacyCard
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if homeDraft.isEmpty { homeDraft = routingState.homeAddress }
        }
    }

    private var hero: some View {
        HStack(spacing: 12) {
            // v0.7.0 official branding Setup header.
            LifeRouteBrandMark(variant: .small)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Setup")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Your LifeRoute control center.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(routingState.savedPlaces.count)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                Text("PLACES")
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(13)
        .background(palette.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var rbtProfileCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.16))
                    Text(profileInitials)
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text("RBT Profile")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Registered Behavior Technician" : rbtName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
            }

            Text("Your work identity stays separate from client profiles and is stored locally.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            profileField("Your name", text: $rbtName, contentType: .name)
            profileField("Organization / agency (optional)", text: $rbtOrganization, contentType: .organizationName)
            profileField("RBT credential ID (optional)", text: $rbtCredential, contentType: nil)

            Label("Saved automatically", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.accentSecondary)
        }
        .lifeRouteCard()
    }

    private var navigationAppCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Navigation app", systemImage: "location.north.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(preferredNavigationApp.title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            Text("Choose the app used when you open a route. Estimates remain MapKit-powered inside LifeRoute.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            Picker("Preferred navigation app", selection: $preferredNavigationAppRaw) {
                ForEach(LifeRouteNavigationApp.allCases) { app in
                    Label(app.title, systemImage: app.systemImage)
                        .tag(app.rawValue)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: preferredNavigationAppRaw) { _ in
                LifeRouteHaptics.selection()
            }

            HStack(spacing: 9) {
                Image(systemName: preferredNavigationApp.systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.accentSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open routes with \(preferredNavigationApp.title)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(preferredNavigationApp.detail)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
            }
            .padding(11)
            .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .lifeRouteCard()
    }

    private var themeCard: some View {
        NavigationLink {
            V054ThemeCenterView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeStore.selectedTheme.palette.backgroundGradient)
                    Circle()
                        .fill(themeStore.selectedTheme.palette.accent)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(themeStore.selectedTheme.palette.accentSecondary, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Center")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(themeStore.selectedTheme.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accentSecondary)
                    Text("Color and material system")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(12)
            .background(palette.panel.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var clientCard: some View {
        NavigationLink {
            V054ClientProfilesView(clientState: clientState)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accent.opacity(0.14))
                    Image(systemName: "person.2.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Clients")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(clientState.clients.isEmpty ? "No client profiles yet" : "\(clientState.clients.count) saved client profiles")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .lifeRouteCard()
    }

    private var homeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Home base", systemImage: "house.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text("Routing fallback when live location is unavailable; also powers Return Home.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            V054AddressField("Home address", text: $homeDraft)

            Button {
                do {
                    try routingState.setHomeAddress(homeDraft)
                    message = "Home address saved."
                    LifeRouteHaptics.success()
                } catch {
                    message = error.localizedDescription
                }
            } label: {
                Label("Save home address", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var savedPlacesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Saved places", systemImage: "bookmark.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(routingState.savedPlaces.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            if routingState.savedPlaces.isEmpty {
                Text("Save gyms, stores, parks, work locations, errands, and other useful stops below.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            } else {
                ForEach(routingState.savedPlaces) { place in
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.13))
                            Image(systemName: icon(for: place.kind))
                                .foregroundStyle(palette.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text(place.address)
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(2)
                            if place.useInGapSuggestions {
                                Label("Gap suggestion", systemImage: "sparkles")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(palette.accentSecondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            routingState.removeSavedPlace(id: place.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(place.name)")
                    }
                    .padding(10)
                    .background(palette.panelElevated.opacity(0.27), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .lifeRouteCard()
    }

    private var weeklyTodosCard: some View {
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

            V054AddressField("Location / store (optional)", text: $todoAddress, mode: .todoDestination)

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

    private var addPlaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add place", systemImage: "mappin.and.ellipse")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            TextField("Place name", text: $placeName)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            V054AddressField("Address or place", text: $placeAddress)

            Picker("Type", selection: $placeKind) {
                ForEach(LifeRoutePlaceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Stepper("Useful visit: \(minimumVisitMinutes) min", value: $minimumVisitMinutes, in: 5...240, step: 5)
                .font(.subheadline.weight(.semibold))

            Toggle("Use in gap suggestions", isOn: $gapSuggestion)
                .font(.subheadline.weight(.semibold))

            Button {
                addPlace()
            } label: {
                Label("Save place", systemImage: "plus.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
        }
        .lifeRouteCard()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Local-first setup", systemImage: "lock.shield.fill")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("RBT profile preferences, home, saved places, weekly to-dos, client profiles, and visual supports are stored locally in LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var preferredNavigationApp: LifeRouteNavigationApp {
        LifeRouteNavigationApp(rawValue: preferredNavigationAppRaw) ?? .appleMaps
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
            .padding(12)
            .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
