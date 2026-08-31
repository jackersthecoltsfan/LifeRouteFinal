import SwiftUI

// Retained for the excluded historical ContentView.swift compatibility shell.
// The shipping Tools root is V054ToolsDashboard.
struct SessionToolsNativeView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @StateObject private var visualState = ClientVisualSupportCore()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 17) {
                toolsHero

                VStack(alignment: .leading, spacing: 10) {
                    Text("Session command center")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: columns, spacing: 10) {
                        NavigationLink(value: SessionToolRoute.visualTimer) {
                            SessionToolCard(
                                title: "Visual Timer",
                                subtitle: "Fast, reliable session timing",
                                systemImage: "timer",
                                accent: palette.accent
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: SessionToolRoute.quickNotes) {
                            SessionToolCard(
                                title: "Quick Notes",
                                subtitle: "Capture session scratch notes",
                                systemImage: "note.text",
                                accent: palette.accentSecondary
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientVisualSupportCenter(visualState: visualState, clientState: clientState)
                        } label: {
                            SessionToolCard(
                                title: "Visual Supports",
                                subtitle: "Icons, boards, and schedules",
                                systemImage: "square.grid.2x2.fill",
                                accent: palette.accent
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: SessionToolRoute.firstThen) {
                            SessionToolCard(
                                title: "First / Then",
                                subtitle: "Build a clear visual sequence",
                                systemImage: "arrow.right.circle.fill",
                                accent: palette.accentSecondary
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: SessionToolRoute.sessionPlan) {
                            SessionToolCard(
                                title: "Session Plan",
                                subtitle: "Organize approved priorities",
                                systemImage: "list.bullet.clipboard.fill",
                                accent: palette.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                clientContextCard

                Text("Visual supports can be saved in a General library or scoped to a specific client profile. All visual data stays local on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SessionToolRoute.self) { route in
            switch route {
            case .visualTimer:
                VisualTimerView(timer: toolsState.timer)
            case .quickNotes:
                QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
            case .firstThen:
                ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
            case .sessionPlan:
                SessionPlanOrganizerView(toolsState: toolsState, clientState: clientState)
            }
        }
        .onAppear {
            visualState.retainClients(clientState.clients)
        }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var toolsHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.panelElevated.opacity(0.92), palette.panel.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.accent.opacity(0.20))
                .frame(width: 190, height: 190)
                .offset(x: 190, y: -72)

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.accent.opacity(0.16))
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 50, height: 50)

                Text("Ready for session.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Everything you need in the moment, without digging through setup screens.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(21)
        }
        .frame(minHeight: 210)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: palette.accent.opacity(0.10), radius: 24, y: 10)
    }

    private var clientContextCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.14))
                Image(systemName: "person.2.fill")
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Client context")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty
                     ? "General tools are ready · no client profile required"
                     : "\(clientState.clients.count) saved client profiles plus General tools")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Button("Manage") {
                router.select(.setup)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accent)
        }
        .lifeRouteCard()
    }
}

private struct SessionToolCard: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.15))
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 46, height: 46)

            Spacer(minLength: 0)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(palette.panelGradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.30), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 7)
    }
}

struct QuickSessionNotesView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""
    @State private var noteText = ""
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.accent.opacity(0.16))
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Quick capture")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text("Hold onto session details without interrupting the flow of your work.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("New scratch note")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(selectedClientCode.isEmpty ? "GENERAL" : selectedClientCode)
                            .font(.caption2.weight(.black))
                            .tracking(1.1)
                            .foregroundStyle(palette.accent)
                    }

                    Picker("Client", selection: $selectedClientCode) {
                        Text("General / no client").tag("")
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }
                    .pickerStyle(.menu)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }

                    Button("Save note") {
                        do {
                            try toolsState.addNote(text: noteText, clientCode: selectedClientCode)
                            noteText = ""
                            message = "Scratch note saved for this app session."
                        } catch { message = error.localizedDescription }
                    }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Recent notes")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(toolsState.notes.count)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(palette.accent.opacity(0.12), in: Capsule())
                    }

                    if toolsState.notes.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "note.text")
                                .font(.title2)
                                .foregroundStyle(palette.accent)
                            Text("No scratch notes yet")
                                .font(.headline)
                                .foregroundStyle(palette.textPrimary)
                            Text("Your newest session observations will collect here.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    } else {
                        ForEach(toolsState.notes.reversed()) { note in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(note.clientCode ?? "General", systemImage: "person.crop.circle")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.accentSecondary)
                                    Spacer()
                                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(palette.textSecondary)
                                }

                                Text(note.text)
                                    .font(.body)
                                    .foregroundStyle(palette.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button("Delete note", role: .destructive) {
                                    toolsState.removeNote(id: note.id)
                                }
                                .font(.caption.weight(.semibold))
                            }
                            .padding(13)
                            .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .lifeRouteCard()
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Quick Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - General + client-specific visual supports
// v0.7.0 B.2 save and fullscreen preview: real-device visual-support QA.
// v0.7.0 B.3 visual presentation workflow: editors hide the app tab bar, expose Library + Save actions, and First/Then presents full screen.

struct SessionPlanOrganizerView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""
    @State private var durationMinutes = 120
    @State private var targetsText = ""
    @State private var reinforcersText = ""
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.accent.opacity(0.16))
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Shape the session")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text("Organize approved targets and known reinforcers into one clean working view.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Session context")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    Picker("Client", selection: $selectedClientCode) {
                        Text("General / no client").tag("")
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }
                    .pickerStyle(.menu)

                    Picker("Session length", selection: $durationMinutes) {
                        Text("1 hour").tag(60)
                        Text("1.5 hours").tag(90)
                        Text("2 hours").tag(120)
                        Text("3 hours").tag(180)
                        Text("4 hours").tag(240)
                    }
                    .pickerStyle(.segmented)

                    if !selectedClientCode.isEmpty {
                        Button("Load saved client profile") { loadClientProfile() }
                            .buttonStyle(LifeRouteSecondaryButtonStyle())
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 9) {
                    Label("Supervisor-approved targets / priorities", systemImage: "target")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    TextEditor(text: $targetsText)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 9) {
                    Label("Known reinforcers / useful activities", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    TextEditor(text: $reinforcersText)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    Button("Build plan") {
                        do {
                            _ = try toolsState.buildPlan(
                                clientCode: selectedClientCode,
                                durationMinutes: durationMinutes,
                                targetsText: targetsText,
                                reinforcersText: reinforcersText
                            )
                            message = "Plan organized from the information you supplied."
                        } catch { message = error.localizedDescription }
                    }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())

                    Text("This tool only organizes information you enter or load from the client profile. Follow the supervising clinician’s approved prompting, reinforcement, behavior, and treatment procedures.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                if let plan = toolsState.lastPlan {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current plan")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text(plan.clientCode ?? "General")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.accent)
                            }
                            Spacer()
                            Label("\(plan.durationMinutes) min", systemImage: "clock.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.accentSecondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGETS")
                                .font(.caption2.weight(.black))
                                .tracking(1.4)
                                .foregroundStyle(palette.textSecondary)
                            ForEach(plan.targets, id: \.self) { target in
                                Label(target, systemImage: "target")
                                    .foregroundStyle(palette.textPrimary)
                            }
                        }

                        if !plan.reinforcers.isEmpty {
                            Divider().overlay(Color.white.opacity(0.08))
                            VStack(alignment: .leading, spacing: 8) {
                                Text("REINFORCERS")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.4)
                                    .foregroundStyle(palette.textSecondary)
                                ForEach(plan.reinforcers, id: \.self) { reinforcer in
                                    Label(reinforcer, systemImage: "star.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(palette.textPrimary)
                                }
                            }
                        }
                    }
                    .lifeRouteCard()
                }
            }
            .padding(18)
            .padding(.bottom, 24)
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
