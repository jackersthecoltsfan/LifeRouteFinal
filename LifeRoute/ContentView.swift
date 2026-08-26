import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection = .today

    var body: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                TodayCoreView()
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(AppSection.today)

            NavigationStack {
                ScheduleCoreView()
            }
            .tabItem { Label("Schedule", systemImage: "calendar") }
            .tag(AppSection.schedule)

            NavigationStack {
                SessionToolsCoreView()
            }
            .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            .tag(AppSection.tools)

            NavigationStack {
                ResourcesCoreView()
            }
            .tabItem { Label("Resources", systemImage: "books.vertical") }
            .tag(AppSection.resources)

            NavigationStack {
                SetupCoreView()
            }
            .tabItem { Label("Setup", systemImage: "gearshape") }
            .tag(AppSection.setup)
        }
    }
}

private enum AppSection: Hashable {
    case today
    case schedule
    case tools
    case resources
    case setup
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
    @State private var tapCount = 0

    var body: some View {
        List {
            Section {
                CoreHeader(
                    title: "LifeRoute",
                    subtitle: "v0.5.0 functional core — native interaction checkpoint"
                )
            }

            Section("Interaction test") {
                Button("Test primary action") {
                    tapCount += 1
                }
                Text("Successful taps: \(tapCount)")
                    .foregroundStyle(.secondary)
            }

            Section("Current rebuild state") {
                Label("Direct launch", systemImage: "checkmark.circle")
                Label("Native navigation", systemImage: "checkmark.circle")
                Label("No login gate", systemImage: "checkmark.circle")
                Label("Legacy cosmetic runtime quarantined", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("Today")
    }
}

private struct ScheduleCoreView: View {
    @State private var draftTitle = ""
    @State private var savedTitle = ""

    var body: some View {
        Form {
            Section {
                CoreHeader(
                    title: "Schedule",
                    subtitle: "Minimal form/state test before calendar features return."
                )
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
        }
        .navigationTitle("Schedule")
    }
}

private struct SessionToolsCoreView: View {
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
        }
        .navigationTitle("Session Tools")
    }
}

private struct ResourcesCoreView: View {
    @State private var acknowledged = false

    var body: some View {
        List {
            Section {
                CoreHeader(
                    title: "Resources",
                    subtitle: "Resource links and hubs return after the native shell is proven stable."
                )
            }

            Section("Button test") {
                Button(acknowledged ? "Action received" : "Test resource action") {
                    acknowledged = true
                }
            }
        }
        .navigationTitle("Resources")
    }
}

private struct SetupCoreView: View {
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
        }
        .navigationTitle("Setup")
    }
}

#Preview {
    ContentView()
}
