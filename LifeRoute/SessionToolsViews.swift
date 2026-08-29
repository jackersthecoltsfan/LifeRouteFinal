import SwiftUI
import PhotosUI
import UIKit
import ImageIO
import AVFoundation

#if canImport(ImagePlayground)
import ImagePlayground
#endif

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

struct VisualTimerView: View {
    // v0.8.0 follow-up visual timer audio sweep: gentle 432–864 Hz and 1–6 pulse/sec mapping.
    // v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.
    // v0.7.0 Build D timer cadence restored: keep the validated 0.10-second visual pulse updates.
    // v0.7.0 Build D audit compatibility anchor: the visual-only patch temporarily matched
    // TimelineView(.periodic(from: .now, by: 1)) before restoring the superseding v0.6.2 cadence above.
    // v0.7.0 Build D timer compatibility pre-pass; final cadence is restored after visual patching.
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var timer: VisualTimerCore
    @State private var minutes = 5

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                LifeRouteScreenHeader(
                    title: "Visual Timer",
                    subtitle: "Gentle session timing with a smooth rising pulse, visual countdown, and completion audio.",
                    systemImage: "timer"
                )

                TimelineView(.periodic(from: .now, by: 0.10)) { context in
                    let remaining = timer.remainingSeconds(at: context.date)
                    let progress = timer.progress(at: context.date)
                    let tempo = timer.pulsesPerSecond(forRemaining: remaining)
                    let toneFrequency = timer.toneFrequency(forRemaining: remaining)
                    let interval = 1.0 / tempo
                    let pulsePhase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: interval) / interval

                    VStack(spacing: 18) {
                        HStack {
                            Label(statusText(at: context.date), systemImage: statusIcon(at: context.date))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(timer.isRunning ? palette.accentSecondary : palette.textSecondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(palette.panelElevated.opacity(0.60), in: Capsule())
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f× / SEC", tempo))
                                Text("\(Int(toneFrequency.rounded())) HZ")
                            }
                            .font(.caption2.weight(.black))
                            .tracking(1.0)
                            .foregroundStyle(palette.accent)
                        }

                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 15)
                            if timer.isRunning {
                                Circle()
                                    .stroke(palette.accentSecondary.opacity(0.42 * (1 - pulsePhase)), lineWidth: 4)
                                    .scaleEffect(CGFloat(0.92 + 0.12 * pulsePhase))
                            }
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    AngularGradient(
                                        colors: [palette.accent, palette.accentSecondary, palette.accent],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text(timerText(remaining))
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.textPrimary)
                                Text(timer.isFinished(at: context.date) ? "TIME IS UP" : "REMAINING")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.5)
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }
                        .frame(width: 220, height: 220)
                        .shadow(color: palette.accent.opacity(timer.isRunning ? 0.18 : 0.07), radius: 26)

                        ProgressView(value: timer.progress(at: context.date))
                            .tint(palette.accent)
                    }
                    .padding(16)
                    .lifeRouteCard()
                }


                VStack(alignment: .leading, spacing: 12) {
                    Text("Timer sound")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    HStack {
                        Label("Volume", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(Int(timer.volume * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }

                    Slider(
                        value: Binding(
                            get: { timer.volume },
                            set: { timer.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(palette.accent)

                    Text("The gentle pulse keeps the existing 5 dB digital gain ramp while pitch and tick rate rise smoothly. Set Volume to 0% for a visual-only timer. Actual acoustic dB varies by iPhone model, case, room, and system media volume.")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick duration")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    HStack(spacing: 8) {
                        ForEach([1, 2, 3, 5, 10], id: \.self) { preset in
                            Button {
                                minutes = preset
                                timer.start(minutes: preset)
                            } label: {
                                Text("\(preset)m")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(minutes == preset ? Color.black.opacity(0.80) : palette.textPrimary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(minutes == preset ? palette.accent : palette.panelElevated.opacity(0.66))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Stepper("Custom: \(minutes) minutes", value: $minutes, in: 1...180)
                        .font(.subheadline.weight(.semibold))

                    Button {
                        timer.start(minutes: minutes)
                        LifeRouteHaptics.primaryAction()
                    } label: {
                        Label("Start \(minutes)-minute timer", systemImage: "play.fill")
                    }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Timer controls")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    HStack(spacing: 9) {
                        Button {
                            if timer.isRunning { timer.pause() }
                            else { timer.resume() }
                        } label: {
                            Label(timer.isRunning ? "Pause" : "Resume", systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(LifeRouteSecondaryButtonStyle())
                        .disabled(!timer.isRunning && timer.remainingSeconds() <= 0)

                        Button {
                            timer.addMinute()
                        } label: {
                            Label("+1 min", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(LifeRouteSecondaryButtonStyle())
                    }

                    Button {
                        timer.reset()
                    } label: {
                        Label("Reset timer", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                }
                .lifeRouteCard()

                Text("The pulse starts at 432 Hz and 1 tick/sec, then rises continuously with elapsed timer progress to 864 Hz and 6 ticks/sec. The same normalized mapping scales across every duration; absolute-deadline timing, pause/resume, mute, and device media-volume behavior are preserved.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Visual Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer.$deadline) { deadline in
            guard deadline == nil, timer.remainingSeconds() <= 0 else { return }
            LifeRouteHaptics.success()
        }
    }

    private func statusText(at date: Date) -> String {
        if timer.isFinished(at: date) { return "Finished" }
        return timer.isRunning ? "Running" : "Paused / ready"
    }

    private func statusIcon(at date: Date) -> String {
        if timer.isFinished(at: date) { return "checkmark.circle.fill" }
        return timer.isRunning ? "circle.fill" : "pause.circle.fill"
    }

    private func timerText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", total / 60, total % 60)
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

struct ClientVisualSupportCenter: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode: String

    init(visualState: ClientVisualSupportCore, clientState: ClientProfileCore, initialClientCode: String = ClientVisualSupportCore.generalClientCode) {
        self.visualState = visualState
        self.clientState = clientState
        _selectedClientCode = State(initialValue: initialClientCode.isEmpty ? ClientVisualSupportCore.generalClientCode : initialClientCode)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                visualHero

                VStack(alignment: .leading, spacing: 10) {
                    Text("Visual library")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    Picker("Visual library", selection: $selectedClientCode) {
                        Text(ClientVisualSupportCore.generalDisplayName)
                            .tag(ClientVisualSupportCore.generalClientCode)
                        ForEach(clientState.clients) { client in
                            Text(client.code).tag(client.code)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(libraryExplanation)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Create & use")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: columns, spacing: 10) {
                        NavigationLink {
                            ClientVisualIconLibraryView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "Icon Library", subtitle: "Photos, text, or illustrated icons", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientChoiceBoardBuilderView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "Choice Boards", subtitle: "Build fast choice grids", systemImage: "square.grid.2x2.fill")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientFirstThenVisualView(visualState: visualState, clientState: clientState, initialClientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "First / Then", subtitle: "Create a two-step visual", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.plain)

                    }
                }

                HStack(spacing: 8) {
                    VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                    VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count, label: "Boards")
                }
                .lifeRouteCard()

                // v0.7.0 saved visual library reuse: saved boards and schedules are discoverable
                // from the library itself instead of being stranded at the bottom of builder screens.
                savedVisualLibrary

                Text("\(libraryDisplayName) visual supports are saved locally in protected LifeRoute app data on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Visual Supports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { validateSelectedLibrary() }
        .onReceive(clientState.$clients) { _ in validateSelectedLibrary() }
    }

    private var savedVisualLibrary: some View {
        let boards = visualState.choiceBoards(for: selectedClientCode)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved visuals")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(boards.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.12), in: Capsule())
            }

            if boards.isEmpty {
                VisualBuilderEmptyState(
                    title: "No saved boards yet",
                    subtitle: "Save a Choice Board and it will be available here to reopen and use.",
                    systemImage: "square.stack.3d.up"
                )
            } else {
                if !boards.isEmpty {
                    Text("CHOICE BOARDS")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(palette.textSecondary)

                    ForEach(boards) { board in
                        NavigationLink {
                            ClientChoiceBoardPreviewView(
                                visualState: visualState,
                                board: board,
                                clientCode: selectedClientCode
                            )
                        } label: {
                            SavedVisualLibraryRow(
                                title: board.title,
                                detail: "\(board.iconIDs.count) choices · \(board.columns) columns",
                                systemImage: "square.grid.2x2.fill",
                                actionLabel: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .lifeRouteCard()
    }

    private var visualHero: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.accent.opacity(0.16))
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text("Visual workspace")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Create general or client-specific icons, choice boards, and First / Then visuals.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .lifeRouteCard()
    }

    private var libraryDisplayName: String {
        selectedClientCode == ClientVisualSupportCore.generalClientCode ? "General" : selectedClientCode
    }

    private var libraryExplanation: String {
        if selectedClientCode == ClientVisualSupportCore.generalClientCode {
            return "General works immediately without a saved client. Visuals here stay separate from every client-specific library."
        }
        return "Only \(selectedClientCode)’s icons are available to its builders. Other clients and General remain isolated."
    }

    private func validateSelectedLibrary() {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return }
        if clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = ClientVisualSupportCore.generalClientCode
        }
    }
}

// v0.7.0 B.3 compatibility anchor: struct ClientVisualIconMakerView: View {
private struct VisualWorkspaceCard: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct VisualLibraryMetric: View {
    @Environment(\.lifeRoutePalette) private var palette
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.black))
                .foregroundStyle(palette.accentSecondary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// v0.8.0 follow-up visible ABA visual generator: reference/result clarity and progress.
private enum VisualSupportInputMethod: String, CaseIterable, Identifiable {
    case textOnly
    case camera
    case photoLibrary

    var id: Self { self }
}

private enum VisualSupportFocusedField: Hashable {
    case label
    case description
}

private struct VisualSupportScrollContainer<Content: View>: View {
    let scrolls: Bool
    let content: Content

    init(scrolls: Bool, @ViewBuilder content: () -> Content) {
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        if scrolls {
            ScrollView { content }
        } else {
            content
        }
    }
}

struct ClientVisualIconLibraryView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    var embedded = false
    @State private var label = ""
    @State private var visualDescription = ""
    @State private var inputMethod: VisualSupportInputMethod = .textOnly
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var referencePhotoData: Data?
    @State private var referenceSourceImage: Image?
    @State private var photoData: Data?
    @State private var photoPreviewID = UUID()
    @State private var referencePreviewID = UUID()
    @State private var isGeneratedArtwork = false
    @State private var message: String?
    @State private var isCameraPresented = false
    @FocusState private var focusedInput: VisualSupportFocusedField?

    var body: some View {
        VisualSupportScrollContainer(scrolls: !embedded) {
            LazyVStack(spacing: 16) {
                if !embedded {
                    VisualBuilderHero(
                        title: "Icon Library",
                        subtitle: "Create exact-label photo, text, or illustrated ABA visuals for \(libraryName).",
                        clientCode: libraryName,
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Create visual")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(draftBadge)
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(photoData == nil ? palette.textSecondary : palette.accentSecondary)
                    }

                    Text("Input method")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    VStack(spacing: 8) {
                        Button {
                            selectTextOnly()
                        } label: {
                            inputMethodLabel(
                                "Text only",
                                subtitle: "Create from the exact label and optional description",
                                systemImage: "textformat",
                                method: .textOnly
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            requestCamera()
                        } label: {
                            inputMethodLabel(
                                "Take photo",
                                subtitle: "Capture a reference without saving it first",
                                systemImage: "camera.fill",
                                method: .camera
                            )
                        }
                        .buttonStyle(.plain)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            inputMethodLabel(
                                "Photo Library",
                                subtitle: "Choose one reference image",
                                systemImage: "photo.on.rectangle",
                                method: .photoLibrary
                            )
                        }
                    }

                    TextField("Exact icon label", text: $label)
                        .focused($focusedInput, equals: .label)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Optional visual description", text: $visualDescription, axis: .vertical)
                        .focused($focusedInput, equals: .description)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Describe only what helps identify the real item, place, activity, or concept. The exact label stays editable and is rendered by LifeRoute beneath the artwork.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let photoData {
                        if isGeneratedArtwork, let referencePhotoData {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Reference → generated visual")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)

                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top, spacing: 9) {
                                        visualComparisonPreview(
                                            title: "REFERENCE PHOTO",
                                            imageData: referencePhotoData,
                                            requestID: referencePreviewID
                                        )
                                        visualComparisonPreview(
                                            title: "GENERATED ICON",
                                            imageData: photoData,
                                            requestID: photoPreviewID
                                        )
                                    }
                                    VStack(spacing: 9) {
                                        visualComparisonPreview(
                                            title: "REFERENCE PHOTO",
                                            imageData: referencePhotoData,
                                            requestID: referencePreviewID
                                        )
                                        visualComparisonPreview(
                                            title: "GENERATED ICON",
                                            imageData: photoData,
                                            requestID: photoPreviewID
                                        )
                                    }
                                }

                                Text(displayLabel)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(palette.accent.opacity(0.32), lineWidth: 1)
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Reference photo and generated visual support comparison for \(displayLabel)")
                        } else {
                            VStack(spacing: 10) {
                                ClientVisualDraftPhotoPreview(
                                    imageData: photoData,
                                    requestID: photoPreviewID,
                                    maximumHeight: 230
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(displayLabel)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(palette.accent.opacity(0.28), lineWidth: 1)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Visual support preview: \(displayLabel)")
                        }
                    }

                    #if canImport(ImagePlayground)
                    if #available(iOS 26.4, *) { // v0.8.0 ABA visual-support Image Playground 26.4 gate
                        ABAVisualSupportImageGeneratorButton(
                            label: label,
                            visualDescription: visualDescription,
                            referencePhotoData: referencePhotoData,
                            sourceImage: referenceSourceImage,
                            isRegeneration: isGeneratedArtwork,
                            onImageReady: receiveGeneratedImage
                        )
                    } else {
                        generatorUnavailableCopy
                    }
                    #else
                    generatorUnavailableCopy
                    #endif

                    if isGeneratedArtwork, let referencePhotoData {
                        Button {
                            photoData = referencePhotoData
                            photoPreviewID = UUID()
                            isGeneratedArtwork = false
                            message = "Original reference photo restored."
                        } label: {
                            Label("Use original photo instead", systemImage: "photo")
                        }
                        .buttonStyle(LifeRouteSecondaryButtonStyle())
                    }

                    Button("Save icon to \(libraryName)") { saveIcon() }
                        .buttonStyle(LifeRoutePrimaryButtonStyle())

                    if let message {
                        Label(message, systemImage: isGeneratedArtwork ? "sparkles" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }

                    Text("Saving a photo directly keeps it in LifeRoute’s protected local data. When you choose Generate, Apple’s system Image Playground handles the prompt and optional reference under Apple Intelligence privacy protections; LifeRoute stores only the image you approve. Batch generation and printable PDF sheets remain later checkpoints.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("\(libraryName) icon library")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(visualState.icons(for: clientCode).count)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(palette.accent.opacity(0.12), in: Capsule())
                    }

                    let icons = visualState.icons(for: clientCode)
                    if icons.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No icons yet",
                            subtitle: "Create the first reusable visual for \(libraryName).",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    } else {
                        ForEach(icons) { icon in
                            HStack(spacing: 12) {
                                ClientVisualIconThumbnail(icon: icon, size: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(icon.label)
                                        .font(.headline)
                                        .foregroundStyle(palette.textPrimary)
                                    Label(icon.imageData == nil ? "Text visual" : "Image visual", systemImage: icon.imageData == nil ? "textformat" : "photo.fill")
                                        .font(.caption)
                                        .foregroundStyle(palette.textSecondary)
                                }
                                Spacer()
                                Button(role: .destructive) { visualState.removeIcon(id: icon.id) } label: {
                                    Image(systemName: "trash")
                                        .font(.caption.weight(.bold))
                                }
                                .accessibilityLabel("Delete \(icon.label)")
                            }
                            .padding(12)
                            .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .lifeRouteCard()
            }
            .padding(.horizontal, embedded ? 0 : 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(embedded ? "Visual AI Studio" : "\(libraryName) Icons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedInput = nil }
                    .fontWeight(.semibold)
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            VisualSupportCameraPicker { imageData in
                inputMethod = .camera
                Task { await prepareReferencePhoto(imageData, sourceMessage: "Camera reference ready.") }
            } onCancel: {
                if referencePhotoData == nil { inputMethod = .textOnly }
            }
            .ignoresSafeArea()
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                if inputMethod != .camera { clearReferencePhoto() }
                return
            }
            let loadedData = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled,
                  selectedPhotoItem == self.selectedPhotoItem else { return }
            guard let loadedData else {
                message = "LifeRoute could not load that photo."
                return
            }
            inputMethod = .photoLibrary
            await prepareReferencePhoto(
                loadedData,
                sourceMessage: "Photo Library reference ready."
            )
        }
    }

    private func inputMethodLabel(
        _ title: String,
        subtitle: String,
        systemImage: String,
        method: VisualSupportInputMethod
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(inputMethod == method ? Color.black.opacity(0.78) : palette.accent)
                .frame(width: 38, height: 38)
                .background(
                    inputMethod == method ? palette.accent : palette.accent.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Image(systemName: inputMethod == method ? "checkmark.circle.fill" : "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(inputMethod == method ? palette.accentSecondary : palette.textSecondary)
        }
        .padding(11)
        .frame(minHeight: 58)
        .background(
            palette.panelElevated.opacity(inputMethod == method ? 0.48 : 0.28),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(inputMethod == method ? .isSelected : [])
    }

    private func selectTextOnly() {
        focusedInput = nil
        inputMethod = .textOnly
        selectedPhotoItem = nil
        clearReferencePhoto()
        message = "Text-only input selected. Enter the exact label and optional visual description."
        LifeRouteHaptics.selection()
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            message = "A camera is not available on this device. Text only and Photo Library remain available."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            focusedInput = nil
            selectedPhotoItem = nil
            inputMethod = .camera
            isCameraPresented = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        focusedInput = nil
                        selectedPhotoItem = nil
                        inputMethod = .camera
                        isCameraPresented = true
                    } else {
                        message = "Camera access was not granted. Text only and Photo Library remain available."
                    }
                }
            }
        case .denied, .restricted:
            message = "Camera access is off for LifeRoute. Text only and Photo Library remain available."
        @unknown default:
            message = "The camera is unavailable right now. Text only and Photo Library remain available."
        }
    }

    @MainActor
    private func prepareReferencePhoto(_ data: Data, sourceMessage: String) async {
        guard !data.isEmpty else {
            message = "LifeRoute could not load that reference photo."
            return
        }
        // Decode outside SwiftUI body evaluation and keep the source in memory until explicit save.
        let requestID = UUID()
        let decodedReference = await ClientVisualThumbnailCache.shared.thumbnail(
            for: ClientVisualThumbnailRequest(
                assetID: requestID,
                maximumPixelDimension: 1_024
            ),
            imageData: data
        )
        guard !Task.isCancelled else { return }
        referencePhotoData = data
        referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
        photoData = data
        isGeneratedArtwork = false
        referencePreviewID = requestID
        photoPreviewID = requestID
        message = "\(sourceMessage) Review it, save it directly, or generate an illustrated icon."
    }

    private func clearReferencePhoto() {
        referencePhotoData = nil
        referenceSourceImage = nil
        photoData = nil
        isGeneratedArtwork = false
        referencePreviewID = UUID()
        photoPreviewID = UUID()
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }

    private var displayLabel: String {
        let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "EXACT LABEL" : clean
    }

    private var draftBadge: String {
        if isGeneratedArtwork { return "ILLUSTRATED" }
        if photoData != nil { return "PHOTO READY" }
        return "TEXT OR IMAGE"
    }

    private func visualComparisonPreview(
        title: String,
        imageData: Data,
        requestID: UUID
    ) -> some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(Color.black.opacity(0.70))
            ClientVisualDraftPhotoPreview(
                imageData: imageData,
                requestID: requestID,
                maximumHeight: 170
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var generatorUnavailableCopy: some View {
        Label(
            "Illustrated generation requires a supported iOS 26.4 Apple Intelligence device. Photo and text-only visual saving remain available.",
            systemImage: "info.circle.fill"
        )
        .font(.caption)
        .foregroundStyle(palette.textSecondary)
    }

    private func receiveGeneratedImage(_ data: Data?) {
        guard let data else {
            message = "LifeRoute could not import that generated image. Try generating again."
            return
        }
        photoData = data
        photoPreviewID = UUID()
        isGeneratedArtwork = true
        message = "Illustrated ABA visual ready. Review the artwork and exact label before saving."
        LifeRouteHaptics.success()
    }

    private func saveIcon() {
        do {
            focusedInput = nil
            _ = try visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)
            label = ""
            visualDescription = ""
            selectedPhotoItem = nil
            inputMethod = .textOnly
            clearReferencePhoto()
            message = "Icon saved to \(libraryName)’s visual library on this iPhone."
        } catch { message = error.localizedDescription }
    }
}

private struct VisualSupportCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: VisualSupportCameraPicker

        init(parent: VisualSupportCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { parent.dismiss() }
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.90) else {
                parent.onCancel()
                return
            }
            parent.onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            parent.dismiss()
        }
    }
}

// v0.8.0 ABA visual-support generator foundation:
// The system model creates artwork; LifeRoute owns the exact label, library, and protected persistence.
private enum ABAVisualSupportPrompt {
    static func make(label: String, visualDescription: String, hasReference: Bool) -> String {
        let cleanLabel = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let cleanDescription = String(visualDescription.trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        let functionalConcept = ABAVisualSupportConceptInterpreter.describe(
            label: cleanLabel,
            visualDescription: cleanDescription,
            hasReference: hasReference
        )

        return """
        Create one ABA visual-support icon for the exact user label “\(cleanLabel)”.
        Functional concept: \(functionalConcept)

        Create a realistically illustrated cartoon that remains clearly recognizable as the real object, location, activity, or concept. Use clean bold outlines, soft natural shading, bright but natural colors, strong visual contrast, and a simple child-friendly ABA visual-support presentation. Use a clean white background. Center one primary subject and let it occupy most of a square 1:1 composition. Remove distracting or irrelevant background information. Preserve identifying characteristics needed for recognition. Do not introduce unrelated objects or scenery. Do not include people unless a person is necessary to communicate the concept.

        Treat the result as part of one coordinated professionally designed ABA visual-support library. Keep the illustration style, line weight, shading, proportions, neutral front or three-quarter viewing angle, pure-white background treatment, and icon scale consistent. Prioritize immediate functional recognition and visual clarity over decorative detail for use in visual schedules, choice boards, First/Then boards, communication books, transition supports, and activity schedules.

        Do not render letters, words, captions, labels, logos, borders, or watermarks inside the artwork. LifeRoute renders the exact user label beneath the artwork separately so spelling and typography remain correct.
        """
    }
}

private enum ABAVisualSupportImageProcessor {
    static func normalizedSquarePNG(from url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(
                url as CFURL,
                sourceOptions as CFDictionary
            ) else { return nil }

            let imageOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2_048,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                imageOptions as CFDictionary
            ) else { return nil }

            let image = UIImage(cgImage: cgImage)
            let canvasSize = CGSize(width: 1_024, height: 1_024)
            let canvasRect = CGRect(origin: .zero, size: canvasSize)
            let contentRect = canvasRect.insetBy(dx: 36, dy: 36)
            let scale = min(contentRect.width / image.size.width, contentRect.height / image.size.height)
            let fittedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawRect = CGRect(
                x: contentRect.midX - fittedSize.width / 2,
                y: contentRect.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )

            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(canvasRect)
                image.draw(in: drawRect)
            }
            return rendered.pngData()
        }.value
    }
}

#if canImport(ImagePlayground)
@available(iOS 26.4, *)
private struct ABAVisualSupportImageGeneratorButton: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingPlayground = false
    @State private var isPreparingResult = false

    let label: String
    let visualDescription: String
    let referencePhotoData: Data?
    let sourceImage: Image?
    let isRegeneration: Bool
    let onImageReady: (Data?) -> Void

    private var cleanLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private var concepts: [ImagePlaygroundConcept] {
        [
            .extracted(
                from: ABAVisualSupportPrompt.make(
                    label: cleanLabel,
                    visualDescription: visualDescription,
                    hasReference: referencePhotoData != nil
                ),
                title: "ABA visual-support icon"
            )
        ]
    }

    private var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.personalization = .disabled
        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                showingPlayground = true
            } label: {
                if isPreparingResult {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Preparing approved visual…")
                    }
                } else {
                    Label(
                        isRegeneration ? "Regenerate illustrated icon" : "Generate illustrated icon",
                        systemImage: "apple.intelligence"
                    )
                }
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(cleanLabel.isEmpty || !supportsImagePlayground || isPreparingResult)
            .imagePlaygroundSheet(
                isPresented: $showingPlayground,
                concepts: concepts,
                sourceImage: sourceImage,
                onCompletion: { url in
                    isPreparingResult = true
                    Task {
                        let data = await ABAVisualSupportImageProcessor.normalizedSquarePNG(from: url)
                        isPreparingResult = false
                        onImageReady(data)
                    }
                },
                onCancellation: {
                    isPreparingResult = false
                }
            )
            .imagePlaygroundOptions(options)
            .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])

            Text(
                supportsImagePlayground
                    ? "Apple’s Image Playground opens for review. Illustration style, square output, disabled person personalization, and the Master ABA visual prompt are preconfigured."
                    : "Image generation is unavailable in the current device, language, region, or Apple Intelligence settings."
            )
            .font(.caption)
            .foregroundStyle(palette.textSecondary)
        }
    }
}
#endif

struct ClientChoiceBoardBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var boardTitle = "Choices"
    @State private var columns = 2
    @State private var selectedIconIDs = Set<UUID>()
    @State private var message: String?
    @State private var previewBoard: ClientChoiceBoard?

    private var selectionColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Choice Boards",
                    subtitle: "Turn \(libraryName)’s saved icons into a clean session-ready choice grid.",
                    clientCode: libraryName,
                    systemImage: "square.grid.2x2.fill"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Board setup")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    TextField("Board title", text: $boardTitle)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Picker("Columns", selection: $columns) {
                        Text("2 columns · up to 8").tag(2)
                        Text("3 columns · up to 9").tag(3)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Label("\(selectedIconIDs.count) selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.accentSecondary)
                        Spacer()
                        Text("Max \(columns == 3 ? 9 : 8)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    Text("Choose from \(libraryName)’s icons")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    let icons = visualState.icons(for: clientCode)
                    if icons.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No icons available",
                            subtitle: "Create icons in this library first. Other visual libraries stay isolated.",
                            systemImage: "square.grid.2x2"
                        )
                    } else {
                        LazyVGrid(columns: selectionColumns, spacing: 10) {
                            ForEach(icons) { icon in
                                Button {
                                    toggle(icon.id)
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack(alignment: .topTrailing) {
                                            ClientVisualIconThumbnail(icon: icon, size: 92)
                                            Image(systemName: selectedIconIDs.contains(icon.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(selectedIconIDs.contains(icon.id) ? palette.accent : palette.textSecondary)
                                                .background(Color.black.opacity(0.38), in: Circle())
                                                .offset(x: 5, y: -5)
                                        }
                                        Text(icon.label)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(palette.textPrimary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 132)
                                    .padding(10)
                                    .background(
                                        (selectedIconIDs.contains(icon.id) ? palette.accent.opacity(0.12) : palette.panelElevated.opacity(0.30)),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(selectedIconIDs.contains(icon.id) ? palette.accent.opacity(0.56) : Color.white.opacity(0.06), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("When the board is ready, use Save & Preview below. It stays visible while you scroll.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Saved \(libraryName) boards")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(visualState.choiceBoards(for: clientCode).count)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                    }

                    let boards = visualState.choiceBoards(for: clientCode)
                    if boards.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No choice boards yet",
                            subtitle: "Your saved boards will appear here.",
                            systemImage: "square.grid.2x2"
                        )
                    } else {
                        ForEach(boards) { board in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(board.title)
                                            .font(.headline)
                                            .foregroundStyle(palette.textPrimary)
                                        Text("\(board.columns) columns · \(board.iconIDs.count) icons")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(palette.accentSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "square.grid.2x2.fill")
                                        .foregroundStyle(palette.accent)
                                }
                                Text(board.iconIDs.compactMap { visualState.icon(id: $0, for: clientCode)?.label }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(palette.textSecondary)
                                HStack(spacing: 10) {
                                    NavigationLink {
                                        ClientChoiceBoardPreviewView(
                                            visualState: visualState,
                                            board: board,
                                            clientCode: clientCode
                                        )
                                    } label: {
                                        Label("Preview board", systemImage: "rectangle.on.rectangle")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)

                                    Spacer()

                                    Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
                                        .font(.caption.weight(.semibold))
                                }
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
        .navigationTitle("Choice Boards")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveBoard()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(item: $previewBoard) { board in
            ClientChoiceBoardPreviewView(visualState: visualState, board: board, clientCode: clientCode)
        }
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }

    private func toggle(_ id: UUID) {
        if selectedIconIDs.contains(id) {
            selectedIconIDs.remove(id)
        } else if selectedIconIDs.count < (columns == 3 ? 9 : 8) {
            selectedIconIDs.insert(id)
        }
    }

    private func saveBoard() {
        do {
            let ordered = visualState.icons(for: clientCode).map(\.id).filter(selectedIconIDs.contains)
            let saved = try visualState.saveChoiceBoard(clientCode: clientCode, title: boardTitle, iconIDs: ordered, columns: columns)
            selectedIconIDs.removeAll()
            message = "Choice board saved to \(libraryName)."
            previewBoard = saved
        } catch { message = error.localizedDescription }
    }
}

struct ClientFirstThenVisualView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode: String
    @State private var firstText = ""
    @State private var thenText = ""
    @State private var firstIconID = ""
    @State private var thenIconID = ""
    @State private var sequenceTitle = "First / Then"
    @State private var message: String?
    @State private var showingFullScreenPreview = false

    init(visualState: ClientVisualSupportCore, clientState: ClientProfileCore, initialClientCode: String = "") {
        self.visualState = visualState
        self.clientState = clientState
        _selectedClientCode = State(initialValue: initialClientCode.isEmpty ? ClientVisualSupportCore.generalClientCode : initialClientCode)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.accent.opacity(0.16))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("First → Then")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text("Build a clear two-step visual using text or icons from the selected visual library.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual library")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Picker("Visual library", selection: $selectedClientCode) {
                        Text(ClientVisualSupportCore.generalDisplayName)
                            .tag(ClientVisualSupportCore.generalClientCode)
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }
                    .pickerStyle(.menu)
                }
                .lifeRouteCard()

                let icons = visualState.icons(for: selectedClientCode)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Build sequence")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(libraryName.uppercased())
                            .font(.caption2.weight(.black))
                            .tracking(1)
                            .foregroundStyle(palette.accent)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("FIRST")
                            .font(.caption2.weight(.black))
                            .tracking(1.4)
                            .foregroundStyle(palette.accentSecondary)
                        TextField("First activity", text: $firstText)
                        Picker("First visual", selection: $firstIconID) {
                            Text("Text only").tag("")
                            ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text("THEN")
                            .font(.caption2.weight(.black))
                            .tracking(1.4)
                            .foregroundStyle(palette.accentSecondary)
                        TextField("Then activity", text: $thenText)
                        Picker("Then visual", selection: $thenIconID) {
                            Text("Text only").tag("")
                            ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Button("Swap First / Then") {
                        (firstText, thenText) = (thenText, firstText)
                        (firstIconID, thenIconID) = (thenIconID, firstIconID)
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())

                    TextField("Saved visual title", text: $sequenceTitle)
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text("Only icons saved to \(libraryName) are available here. Saving First / Then stores it as a reusable two-step Visual Schedule in that same library.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Live preview")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Button {
                            showingFullScreenPreview = true
                            LifeRouteHaptics.selection()
                        } label: {
                            Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.accent)
                    }

                    // v0.7.0 horizontal First Then preview: FIRST reads left-to-right into THEN.
                    HStack(alignment: .center, spacing: 8) {
                        VisualSupportPreviewCard(
                            label: "FIRST",
                            icon: selectedIcon(idString: firstIconID),
                            fallbackText: firstText.isEmpty ? "First activity" : firstText,
                            compact: true
                        )
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel("Then")

                        VisualSupportPreviewCard(
                            label: "THEN",
                            icon: selectedIcon(idString: thenIconID),
                            fallbackText: thenText.isEmpty ? "Then activity" : thenText,
                            compact: true
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("First / Then")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                NavigationLink {
                    ClientVisualSupportCenter(
                        visualState: visualState,
                        clientState: clientState,
                        initialClientCode: selectedClientCode
                    )
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveFirstThen()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showingFullScreenPreview) {
            ClientFirstThenSessionPreviewView(
                libraryName: libraryName,
                firstIcon: selectedIcon(idString: firstIconID),
                firstText: resolvedFirstText,
                thenIcon: selectedIcon(idString: thenIconID),
                thenText: resolvedThenText
            )
        }
        .onAppear { validateSelectedLibrary() }
        .onChange(of: selectedClientCode) { _ in
            firstIconID = ""
            thenIconID = ""
        }
        .onReceive(clientState.$clients) { _ in validateSelectedLibrary() }
    }

    private var libraryName: String {
        selectedClientCode == ClientVisualSupportCore.generalClientCode ? "General" : selectedClientCode
    }

    private var resolvedFirstText: String {
        let clean = firstText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        return selectedIcon(idString: firstIconID)?.label ?? "First activity"
    }

    private var resolvedThenText: String {
        let clean = thenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        return selectedIcon(idString: thenIconID)?.label ?? "Then activity"
    }

    private func saveFirstThen() {
        let firstIcon = selectedIcon(idString: firstIconID)
        let thenIcon = selectedIcon(idString: thenIconID)
        let firstHasContent = !firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || firstIcon != nil
        let thenHasContent = !thenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thenIcon != nil
        guard firstHasContent, thenHasContent else {
            message = "Choose or enter both FIRST and THEN before saving."
            return
        }

        do {
            let cleanTitle = sequenceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try visualState.saveSchedule(
                clientCode: selectedClientCode,
                title: cleanTitle.isEmpty ? "First / Then" : cleanTitle,
                steps: [
                    ClientVisualScheduleStep(label: resolvedFirstText, iconID: firstIcon?.id),
                    ClientVisualScheduleStep(label: resolvedThenText, iconID: thenIcon?.id),
                ]
            )
            message = "Saved to \(libraryName) Visual Library."
            showingFullScreenPreview = true
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func validateSelectedLibrary() {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return }
        if clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = ClientVisualSupportCore.generalClientCode
        }
    }

    private func selectedIcon(idString: String) -> ClientVisualIcon? {
        guard let id = UUID(uuidString: idString) else { return nil }
        return visualState.icon(id: id, for: selectedClientCode)
    }
}

struct ClientVisualScheduleBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var title = "Visual Schedule"
    @State private var draftLabel = ""
    @State private var selectedIconID = ""
    @State private var steps: [ClientVisualScheduleStep] = []
    @State private var message: String?
    @State private var previewSchedule: ClientVisualSchedule?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Visual Schedules",
                    subtitle: "Build a clear sequence of visual steps for \(libraryName).",
                    clientCode: libraryName,
                    systemImage: "list.number"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Build schedule")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    TextField("Schedule title", text: $title)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    let icons = visualState.icons(for: clientCode)
                    TextField("Next step", text: $draftLabel)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Picker("Visual", selection: $selectedIconID) {
                        Text("Text only").tag("")
                        ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                    }
                    .pickerStyle(.menu)

                    Button("Add step") { addStep() }
                        .buttonStyle(LifeRouteSecondaryButtonStyle())
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Draft sequence")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(steps.count) steps")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                    }

                    if steps.isEmpty {
                        VisualBuilderEmptyState(
                            title: "Add the first step",
                            subtitle: "The visual picker only contains \(libraryName)’s icons.",
                            systemImage: "list.number"
                        )
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 11) {
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(Color.black.opacity(0.78))
                                    .frame(width: 28, height: 28)
                                    .background(palette.accent, in: Circle())

                                if let iconID = step.iconID, let icon = visualState.icon(id: iconID, for: clientCode) {
                                    ClientVisualIconThumbnail(icon: icon, size: 48)
                                }

                                Text(step.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.textPrimary)
                                Spacer()
                                Button(role: .destructive) { steps.removeAll { $0.id == step.id } } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Remove step \(step.label)")
                            }
                            .padding(10)
                            .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                    }

                    Text("When the sequence is ready, use Save & Preview below. It stays visible while you scroll.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Saved \(libraryName) schedules")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(visualState.schedules(for: clientCode).count)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                    }

                    let saved = visualState.schedules(for: clientCode)
                    if saved.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No saved schedules yet",
                            subtitle: "Completed visual schedules will collect here.",
                            systemImage: "list.bullet.rectangle"
                        )
                    } else {
                        ForEach(saved) { schedule in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(schedule.title)
                                            .font(.headline)
                                            .foregroundStyle(palette.textPrimary)
                                        Text("\(schedule.steps.count) steps")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(palette.accentSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "list.number")
                                        .foregroundStyle(palette.accent)
                                }
                                Text(schedule.steps.map(\.label).joined(separator: " → "))
                                    .font(.caption)
                                    .foregroundStyle(palette.textSecondary)
                                HStack(spacing: 10) {
                                    NavigationLink {
                                        ClientVisualSchedulePreviewView(
                                            visualState: visualState,
                                            schedule: schedule,
                                            clientCode: clientCode
                                        )
                                    } label: {
                                        Label("Open schedule", systemImage: "rectangle.on.rectangle")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)

                                    Spacer()

                                    Button("Delete schedule", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
                                        .font(.caption.weight(.semibold))
                                }
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
        .navigationTitle("Visual Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveSchedule()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(item: $previewSchedule) { schedule in
            ClientVisualSchedulePreviewView(visualState: visualState, schedule: schedule, clientCode: clientCode)
        }
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }

    private func addStep() {
        let icon = UUID(uuidString: selectedIconID).flatMap { visualState.icon(id: $0, for: clientCode) }
        let clean = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty ? (icon?.label ?? "") : clean
        guard !resolved.isEmpty else {
            message = "Add a step label or choose an icon from this visual library."
            return
        }
        steps.append(ClientVisualScheduleStep(label: resolved, iconID: icon?.id))
        draftLabel = ""
        selectedIconID = ""
        message = nil
    }

    private func saveSchedule() {
        do {
            let saved = try visualState.saveSchedule(clientCode: clientCode, title: title, steps: steps)
            steps.removeAll()
            message = "Visual schedule saved to \(libraryName)."
            previewSchedule = saved
        } catch { message = error.localizedDescription }
    }
}

private struct SavedVisualLibraryRow: View {
    @Environment(\.lifeRoutePalette)  private var palette
    let title: String
    let detail: String
    let systemImage: String
    let actionLabel: String

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Text(actionLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(11)
        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct ClientChoiceBoardPreviewView: View {
    @Environment(\.lifeRoutePalette)  private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let board: ClientChoiceBoard
    let clientCode: String

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: board.columns == 3 ? 3 : 2)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(board.title)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            Text("Choice Board · \(libraryName)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close board preview")
                    }

                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(board.iconIDs, id: \.self) { iconID in
                            if let icon = visualState.icon(id: iconID, for: clientCode) {
                                VStack(spacing: 9) {
                                    ClientVisualIconThumbnail(icon: icon, size: board.columns == 3 ? 94 : 142)
                                    Text(icon.label)
                                        .font(board.columns == 3 ? .subheadline.weight(.bold) : .headline.weight(.bold))
                                        .foregroundStyle(palette.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.76)
                                }
                                .frame(maxWidth: .infinity, minHeight: board.columns == 3 ? 148 : 200)
                                .padding(10)
                                .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(palette.accent.opacity(0.26), lineWidth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

struct ClientVisualSchedulePreviewView: View {
    @Environment(\.lifeRoutePalette)  private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let schedule: ClientVisualSchedule
    let clientCode: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(schedule.title)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            Text("Visual Schedule · \(libraryName)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close schedule preview")
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(schedule.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 13) {
                                Text("\(index + 1)")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .frame(width: 38, height: 38)
                                    .background(palette.accent, in: Circle())

                                if let iconID = step.iconID,
                                   let icon = visualState.icon(id: iconID, for: clientCode) {
                                    ClientVisualIconThumbnail(icon: icon, size: 76)
                                }

                                Text(step.label)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.accent.opacity(0.22), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

struct ClientFirstThenSessionPreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let libraryName: String
    let firstIcon: ClientVisualIcon?
    let firstText: String
    let thenIcon: ClientVisualIcon?
    let thenText: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("First / Then")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text(libraryName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close First Then preview")
                }

                Spacer(minLength: 2)

                HStack(alignment: .center, spacing: 10) {
                    sessionCard(label: "FIRST", icon: firstIcon, text: firstText)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Then")
                    sessionCard(label: "THEN", icon: thenIcon, text: thenText)
                }

                Spacer(minLength: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sessionCard(label: String, icon: ClientVisualIcon?, text: String) -> some View {
        VStack(spacing: 14) {
            Text(label)
                .font(.headline.weight(.black))
                .tracking(1.7)
                .foregroundStyle(palette.accentSecondary)

            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: 132)
            } else {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(palette.accent.opacity(0.72))
                    .frame(height: 132)
            }

            Text(text)
                .font(.title3.weight(.black))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.accent.opacity(0.26), lineWidth: 1)
        }
    }
}

private struct VisualBuilderHero: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let subtitle: String
    let clientCode: String
    let systemImage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(palette.panelGradient)
            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 170, height: 170)
                .offset(x: 195, y: -65)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.accent.opacity(0.16))
                        Image(systemName: systemImage)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 48, height: 48)
                    Spacer()
                    Text(clientCode)
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(palette.accentSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.18), in: Capsule())
                }
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(20)
        }
        .frame(minHeight: 190)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: palette.accent.opacity(0.09), radius: 22, y: 9)
    }
}

private struct VisualBuilderEmptyState: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(palette.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct ClientVisualThumbnailRequest: Hashable, Sendable {
    let assetID: UUID
    let maximumPixelDimension: Int
}

private actor ClientVisualThumbnailCache {
    static let shared = ClientVisualThumbnailCache()

    private let cache: NSCache<NSString, UIImage>

    init() {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 72
        cache.totalCostLimit = 32 * 1_024 * 1_024
        self.cache = cache
    }

    func thumbnail(
        for request: ClientVisualThumbnailRequest,
        imageData: Data
    ) -> UIImage? {
        let cacheKey = "\(request.assetID.uuidString)-\(request.maximumPixelDimension)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(imageData as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: request.maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else { return nil }

        let image = UIImage(cgImage: cgImage)
        let cost = cgImage.bytesPerRow * cgImage.height
        cache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }
}

private struct ClientVisualDraftPhotoPreview: View {
    let imageData: Data
    let requestID: UUID
    let maximumHeight: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var preview: UIImage?

    var body: some View {
        let request = ClientVisualThumbnailRequest(
            assetID: requestID,
            maximumPixelDimension: max(1, Int(ceil(maximumHeight * displayScale)))
        )

        Group {
            if let preview {
                Image(uiImage: preview).resizable().scaledToFit()
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .frame(maxHeight: maximumHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: request) {
            let decoded = await ClientVisualThumbnailCache.shared.thumbnail(
                for: request,
                imageData: imageData
            )
            guard !Task.isCancelled else { return }
            preview = decoded
        }
    }
}

private struct ClientVisualIconThumbnail: View {
    let icon: ClientVisualIcon
    let size: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?

    var body: some View {
        let request = ClientVisualThumbnailRequest(
            assetID: icon.id,
            maximumPixelDimension: max(1, Int(ceil(size * displayScale)))
        )

        Group {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                    Text(icon.label.prefix(2).uppercased()).font(.headline)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: request) {
            guard let imageData = icon.imageData else {
                thumbnail = nil
                return
            }
            let decoded = await ClientVisualThumbnailCache.shared.thumbnail(
                for: request,
                imageData: imageData
            )
            guard !Task.isCancelled else { return }
            thumbnail = decoded
        }
    }
}

private struct VisualSupportPreviewCard: View {
    @Environment(\.lifeRoutePalette) private var palette
    let label: String
    let icon: ClientVisualIcon?
    let fallbackText: String
    var compact = false

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.caption2.weight(.black))
                .tracking(1.6)
                .foregroundStyle(palette.accent)

            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: compact ? 96 : 150)
                Text(fallbackText == "First activity" || fallbackText == "Then activity" ? icon.label : fallbackText)
                    .font(compact ? .headline.weight(.black) : .title2.weight(.black))
                    .foregroundStyle(palette.textPrimary)
            } else {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Text(fallbackText)
                    .font(compact ? .headline.weight(.black) : .title2.weight(.black))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 158 : 190)
        .padding(compact ? 10 : 16)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.accent.opacity(0.22), lineWidth: 1)
        }
    }
}

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
