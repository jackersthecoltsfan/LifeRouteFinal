import SwiftUI

struct SessionToolsNativeView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Session Tools")
                        .font(.largeTitle.bold())
                    Text("Native, deterministic tools for direct session work. No AI or cosmetic runtime is required for these controls.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Tools") {
                NavigationLink(value: SessionToolRoute.visualTimer) {
                    Label("Visual Timer", systemImage: "timer")
                }
                NavigationLink(value: SessionToolRoute.quickNotes) {
                    Label("Quick Session Notes", systemImage: "note.text")
                }
                NavigationLink(value: SessionToolRoute.firstThen) {
                    Label("First / Then", systemImage: "arrow.right")
                }
                NavigationLink(value: SessionToolRoute.sessionPlan) {
                    Label("Session Plan Organizer", systemImage: "list.bullet.rectangle")
                }
            }

            Section("Client context") {
                Text("\(clientState.clients.count) saved client profiles available to session tools")
                    .foregroundStyle(.secondary)
                Button("Manage clients in Setup") {
                    router.select(.setup)
                }
            }

            Section {
                Text("Scratch notes and plans are session-only until the persistence checkpoint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tools")
        .navigationDestination(for: SessionToolRoute.self) { route in
            switch route {
            case .visualTimer:
                VisualTimerView(timer: toolsState.timer)
            case .quickNotes:
                QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
            case .firstThen:
                FirstThenNativeView()
            case .sessionPlan:
                SessionPlanOrganizerView(toolsState: toolsState, clientState: clientState)
            }
        }
    }
}

struct VisualTimerView: View {
    @ObservedObject var timer: VisualTimerCore
    @State private var minutes = 5

    var body: some View {
        Form {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = timer.remainingSeconds(at: context.date)
                    VStack(spacing: 14) {
                        Text(timerText(remaining))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                        ProgressView(value: timer.progress(at: context.date))
                        Text(timer.isFinished(at: context.date) ? "Time is up" : (timer.isRunning ? "Time remaining" : "Paused / ready"))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                }
            }

            Section("Duration") {
                HStack {
                    ForEach([1, 2, 3, 5, 10], id: \.self) { preset in
                        Button("\(preset)m") {
                            minutes = preset
                            timer.start(minutes: preset)
                        }
                    }
                }
                Stepper("Custom: \(minutes) minutes", value: $minutes, in: 1...180)
                Button("Start timer") {
                    timer.start(minutes: minutes)
                }
            }

            Section("Controls") {
                Button(timer.isRunning ? "Pause" : "Resume") {
                    if timer.isRunning { timer.pause() }
                    else { timer.resume() }
                }
                .disabled(!timer.isRunning && timer.remainingSeconds() <= 0)
                Button("+1 minute") {
                    timer.addMinute()
                }
                Button("Reset") {
                    timer.reset()
                }
            }

            Section {
                Text("The timer uses an absolute deadline, so returning from another app does not require a polling loop to catch up. Alerts and haptics are intentionally deferred to later layers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Visual Timer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func timerText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct QuickSessionNotesView: View {
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""
    @State private var noteText = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("New scratch note") {
                Picker("Client", selection: $selectedClientCode) {
                    Text("General / no client").tag("")
                    ForEach(clientState.clients) { client in
                        Text(client.code).tag(client.code)
                    }
                }
                TextEditor(text: $noteText)
                    .frame(minHeight: 100)
                Button("Save note") {
                    do {
                        try toolsState.addNote(text: noteText, clientCode: selectedClientCode)
                        noteText = ""
                        message = "Scratch note saved for this app session."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recent notes") {
                if toolsState.notes.isEmpty {
                    Text("No scratch notes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(toolsState.notes.reversed()) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(note.clientCode ?? "General")
                                    .font(.caption.bold())
                                Spacer()
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(note.text)
                            Button("Delete note", role: .destructive) {
                                toolsState.removeNote(id: note.id)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Quick Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FirstThenNativeView: View {
    @State private var first = ""
    @State private var then = ""

    var body: some View {
        Form {
            Section("Build board") {
                TextField("First activity", text: $first)
                TextField("Then activity", text: $then)
                Button("Swap") {
                    (first, then) = (then, first)
                }
            }

            Section("FIRST") {
                Text(first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "First activity" : first)
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            }

            Section("THEN") {
                Text(then.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Then activity" : then)
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            }
        }
        .navigationTitle("First / Then")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SessionPlanOrganizerView: View {
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""
    @State private var durationMinutes = 120
    @State private var targetsText = ""
    @State private var reinforcersText = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("Session context") {
                Picker("Client", selection: $selectedClientCode) {
                    Text("General / no client").tag("")
                    ForEach(clientState.clients) { client in
                        Text(client.code).tag(client.code)
                    }
                }
                Picker("Session length", selection: $durationMinutes) {
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                    Text("4 hours").tag(240)
                }
                if !selectedClientCode.isEmpty {
                    Button("Load saved client profile") {
                        loadClientProfile()
                    }
                }
            }

            Section("Supervisor-approved targets / priorities") {
                TextEditor(text: $targetsText)
                    .frame(minHeight: 110)
            }

            Section("Known reinforcers / useful activities") {
                TextEditor(text: $reinforcersText)
                    .frame(minHeight: 90)
            }

            Section {
                Button("Build plan") {
                    do {
                        _ = try toolsState.buildPlan(
                            clientCode: selectedClientCode,
                            durationMinutes: durationMinutes,
                            targetsText: targetsText,
                            reinforcersText: reinforcersText
                        )
                        message = "Plan organized from the information you supplied."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                Text("This tool only organizes information you enter or load from the client profile. Follow the supervising clinician’s approved prompting, reinforcement, behavior, and treatment procedures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            if let plan = toolsState.lastPlan {
                Section("Current plan") {
                    LabeledContent("Client", value: plan.clientCode ?? "General")
                    LabeledContent("Session length", value: "\(plan.durationMinutes) min")
                    ForEach(Array(plan.targets.enumerated()), id: \.offset) { index, target in
                        LabeledContent("Target \(index + 1)", value: target)
                    }
                    if !plan.reinforcers.isEmpty {
                        ForEach(Array(plan.reinforcers.enumerated()), id: \.offset) { index, reinforcer in
                            LabeledContent("Reinforcer \(index + 1)", value: reinforcer)
                        }
                    }
                }
            }
        }
        .navigationTitle("Session Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadClientProfile() {
        guard let client = clientState.client(code: selectedClientCode) else {
            message = "That client profile is not available."
            return
        }
        targetsText = client.currentTargets.joined(separator: "\n")
        reinforcersText = client.preferredActivities.joined(separator: "\n")
        message = "Loaded \(client.code)’s saved targets and preferred activities."
    }
}
