import SwiftUI

struct ContentView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedSection) {
            NavigationStack(path: $router.todayPath) {
                TodayCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
            .tag(AppSection.today)

            NavigationStack(path: $router.schedulePath) {
                ScheduleCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
            .tag(AppSection.schedule)

            NavigationStack(path: $router.toolsPath) {
                SessionToolsCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
            .tag(AppSection.tools)

            NavigationStack(path: $router.resourcesPath) {
                ResourcesCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
            .tag(AppSection.resources)

            NavigationStack(path: $router.setupPath) {
                SetupCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
            .tag(AppSection.setup)
        }
    }
}

private struct CoreHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var tapCount = 0

    var body: some View {
        List {
            Section {
                CoreHeader(
                    title: "LifeRoute",
                    subtitle: "v0.5.0 native functional core"
                )
            }

            Section("Interaction test") {
                Button("Test primary action") {
                    tapCount += 1
                }
                Text("Successful taps: \(tapCount)")
                    .foregroundStyle(.secondary)
            }

            Section("Navigation ownership") {
                NavigationLink("Open Today detail", value: AppRoute.todayDetails)
                Button("Open Schedule detail") {
                    router.open(.scheduleDetails, in: .schedule)
                }
                Button("Open Setup detail") {
                    router.open(.setupDetails, in: .setup)
                }
            }

            Section("Current rebuild state") {
                Label("Direct launch", systemImage: "checkmark.circle")
                Label("One native router", systemImage: "checkmark.circle")
                Label("No login gate", systemImage: "checkmark.circle")
                Label("Legacy WebView runtime quarantined", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("Today")
    }
}

private enum ScheduleRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: Self { self }
}

private struct ScheduleCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var selectedRange: ScheduleRange = .day
    @State private var draftTitle = ""
    @State private var savedTitle = ""

    var body: some View {
        Form {
            Section {
                CoreHeader(
                    title: "Schedule",
                    subtitle: "Native Day / Week / Month state before calendar data returns."
                )
            }

            Section("Range") {
                Picker("Schedule range", selection: $selectedRange) {
                    ForEach(ScheduleRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Text("Selected: \(selectedRange.rawValue)")
                    .foregroundStyle(.secondary)
            }

            Section("Form test") {
                TextField("Appointment title", text: $draftTitle)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)

                Button("Save test value") {
                    savedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !savedTitle.isEmpty {
                    Text("Saved: \(savedTitle)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Stack test") {
                NavigationLink("Open Schedule detail", value: AppRoute.scheduleDetails)
                Button("Return to Today tab") {
                    router.select(.today)
                }
            }
        }
        .navigationTitle("Schedule")
    }
}

private struct SessionToolsCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var toolEnabled = false

    var body: some View {
        List {
            Section {
                CoreHeader(
                    title: "Session Tools",
                    subtitle: "Tool features will be migrated here one audited batch at a time."
                )
            }

            Section("State test") {
                Toggle("Enable test tool", isOn: $toolEnabled)
                Text(toolEnabled ? "Test tool is on" : "Test tool is off")
                    .foregroundStyle(.secondary)
            }

            Section("Stack test") {
                NavigationLink("Open Tools detail", value: AppRoute.toolsDetails)
                Button("Open Resources") {
                    router.select(.resources)
                }
            }
        }
        .navigationTitle("Session Tools")
    }
}

private struct ResourcesCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var acknowledged = false

    var body: some View {
        List {
            Section {
                CoreHeader(
                    title: "Resources",
                    subtitle: "Resource links return after their native ownership is reviewed."
                )
            }

            Section("Button test") {
                Button(acknowledged ? "Action received" : "Test resource action") {
                    acknowledged = true
                }
            }

            Section("Stack test") {
                NavigationLink("Open Resources detail", value: AppRoute.resourcesDetails)
                Button("Open Session Tools") {
                    router.select(.tools)
                }
            }
        }
        .navigationTitle("Resources")
    }
}

private struct SetupCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var displayName = ""
    @State private var locationEnabled = false
    @State private var savedSummary = "Not saved yet"

    var body: some View {
        Form {
            Section {
                CoreHeader(
                    title: "Setup",
                    subtitle: "Native fields only. No PIN or password gate."
                )
            }

            Section("Form and state test") {
                TextField("Name", text: $displayName)
                    .textContentType(.name)
                Toggle("Use location when available", isOn: $locationEnabled)
                Button("Save test setup") {
                    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    savedSummary = "\(name.isEmpty ? "No name" : name) · location \(locationEnabled ? "on" : "off")"
                }
                Text(savedSummary)
                    .foregroundStyle(.secondary)
            }

            Section("Stack test") {
                NavigationLink("Open Setup detail", value: AppRoute.setupDetails)
                Button("Reset Setup navigation path") {
                    router.resetPath(for: .setup)
                }
            }
        }
        .navigationTitle("Setup")
    }
}

private struct RouteDetailView: View {
    let route: AppRoute
    @ObservedObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Label(route.title, systemImage: route.systemImage)
                    .font(.headline)
                Text(route.subtitle)
                    .foregroundStyle(.secondary)
            }

            Section("Native navigation test") {
                Button("Close") {
                    dismiss()
                }
                Button("Go to Today") {
                    router.select(.today)
                }
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
