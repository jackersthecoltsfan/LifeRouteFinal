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

// Superseded by the Scenic Royal implementation in ScenicRoyalVisualTimerView.swift.
// Retained temporarily under the v0.9 legacy-retirement proof policy.
private struct LegacyVisualTimerView: View {
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

                    Stepper("Custom: \(minutes) minutes", value: $minutes, in: 1...VisualTimerDuration.maximumMinutes)
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
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        UI01MarbleText(title: "Quick capture", size: 30, relativeTo: .title)
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
                        .lifeRouteReadableTextSurface()

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
                            .padding(.vertical, 13)
                            .overlay(alignment: .bottom) { UI01Hairline().opacity(0.5) }
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
    @Environment(\.lifeRouteTheme) private var theme
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

                    LazyVStack(spacing: 8) {
                        boardLink("First / Then", subtitle: "Two clear steps", symbol: "arrow.right.circle", kind: .firstThen)
                        boardLink("Choice Board", subtitle: "Choose and arrange saved visuals", symbol: "square.grid.2x2", kind: .choice)
                        boardLink("Visual Schedule", subtitle: "An ordered, reusable sequence", symbol: "list.number", kind: .schedule)
                        boardLink("Token Board", subtitle: "Empty token slots and a reward", symbol: "star.square", kind: .token)
                    }
                }

                HStack(spacing: 8) {
                    VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                    VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count + visualState.schedules(for: selectedClientCode).count + visualState.tokenBoards(for: selectedClientCode).count, label: "Boards")
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
        .navigationTitle("Boards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { validateSelectedLibrary() }
        .onReceive(clientState.$clients) { _ in validateSelectedLibrary() }
    }

    private func boardLink(_ title: String, subtitle: String, symbol: String, kind: BoardArtifact.Kind) -> some View {
        NavigationLink {
            BoardEditor(visualState: visualState, clientCode: selectedClientCode, kind: kind)
                .lifeRouteDeepDestination()
        } label: {
            VisualWorkspaceCard(title: title, subtitle: subtitle, systemImage: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("boards.create.\(kind.rawValue)")
    }

    private var savedVisualLibrary: some View {
        BoardSavedLibrary(visualState: visualState, clientCode: selectedClientCode)
    }

    private var visualHero: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                UI01MarbleText(title: "Boards", size: 30, relativeTo: .title)
                Text("Create, edit, and export First / Then, Choice Boards, Visual Schedules, and Token Boards.")
                    .font(.subheadline)
                    .foregroundStyle(theme.scenicRoyalStyle.contentSecondaryForeground)
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
        ScenicRoyalToolTile(title: title, subtitle: subtitle, systemImage: systemImage)
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

// BEGIN MEDIA VISIBILITY ADMISSION
@MainActor
private final class LifeRouteMediaAdmission: ObservableObject {
    struct Request: Equatable { let id: UUID; let input: UInt64 }
    struct Accepted: Equatable { let id: UUID; let request: Request }
    private(set) var inputRevision: UInt64 = 0
    private(set) var presentationEpoch: UInt64 = 0
    private var signature: [String] = []
    private var request: Request?
    private var accepted: Accepted?
    private var published: UUID?
    func update(_ signature: [String]) {
        guard self.signature != signature else { return }
        self.signature = signature; inputRevision &+= 1; request = nil; accepted = nil
    }
    func begin(_ signature: [String]) -> Request {
        update(signature)
        let value = Request(id: UUID(), input: inputRevision); request = value; return value
    }
    func accepts(_ request: Request, signature: [String]) -> Bool {
        update(signature); return self.request == request && request.input == inputRevision
    }
    func accept(_ request: Request, signature: [String]) -> Accepted? {
        guard accepts(request, signature: signature) else { return nil }
        let value = Accepted(id: UUID(), request: request); accepted = value; return value
    }
    func publish(_ value: Accepted, signature: [String]) -> Bool {
        guard accepts(value.request, signature: signature), accepted == value, published != value.id else { return false }
        published = value.id; return true
    }
    func revokePresentation() { presentationEpoch &+= 1 }
}

private struct LifeRoutePhotoSelection: Equatable {
    let item: PhotosPickerItem
    let client: String
}

private struct LifeRoutePhotoActivity: Equatable {
    let item: PhotosPickerItem?
    let input: [String]
    let active: Bool
}

private struct LifeRouteThumbnailActivity: Equatable {
    let request: ClientVisualThumbnailRequest
    let active: Bool
}
// END MEDIA VISIBILITY ADMISSION

struct ClientVisualIconLibraryView: View {
    @LifeRoutePresentation private var visibility
    @Environment(\.lifeRoutePresentation) private var visibilityScope
    @StateObject private var media = LifeRouteMediaAdmission()
    @State private var loadedPhotoSelection: LifeRoutePhotoSelection?
    @State private var permissionID: UUID?
    @State private var permissionIntent: LifeRoutePresentationIntent?
    @State private var permissionResult: Bool?
    @State private var permissionInput: [String] = []
    @State private var leaveIdentity: [UInt64]?
    @State private var cameraRequest: LifeRouteMediaAdmission.Request?
    private var inputSignature: [String] { [clientCode, label, visualDescription, String(selectedPhotoItem?.hashValue ?? 0), inputMethod.rawValue] }
    private var photoSelection: LifeRoutePhotoSelection? {
        selectedPhotoItem.map { LifeRoutePhotoSelection(item: $0, client: clientCode) }
    }


    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    var embedded = false
    enum Presentation: Equatable { case combined, generator, library }
    var presentation: Presentation = .combined

    private var destinationTitle: String {
        presentation == .generator ? "Image Generator" : "Image Library"
    }
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
                        title: destinationTitle,
                        subtitle: presentation == .library ? "Saved image and text visuals for \(libraryName)." : "Create exact-label photo, text, or illustrated ABA visuals for \(libraryName).",
                        clientCode: libraryName,
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                if presentation != .library {
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

                    TextField("Exact icon label", text: $label, prompt: Text("Exact icon label").foregroundColor(UI01Material.secondary))
                        .focused($focusedInput, equals: .label)
                        .textInputAutocapitalization(.words)
                        .scenicRoyalField()

                    TextField("Optional visual description", text: $visualDescription, prompt: Text("Optional visual description").foregroundColor(UI01Material.secondary), axis: .vertical)
                        .focused($focusedInput, equals: .description)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(2...4)
                        .scenicRoyalField()

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
                            .padding(2)
                            .background(Color.white)
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


                                Text(displayLabel)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(2)
                            .background(Color.white)
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

                }

                if presentation != .generator {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Saved images")
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
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Delete \(icon.label)")
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) { UI01Hairline().opacity(0.5) }
                        }
                    }
                }
                .lifeRouteCard()
                }
            }
            .padding(.horizontal, embedded ? 0 : 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(embedded ? "Visual Supports" : destinationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if presentation != .combined {
                    NavigationLink {
                        ClientVisualIconLibraryView(visualState: visualState, clientCode: clientCode, presentation: presentation == .library ? .generator : .library)
                            .lifeRouteDeepDestination()
                    } label: {
                        Text(presentation == .library ? "Image Generator" : "Image Library")
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedInput = nil }
                    .fontWeight(.semibold)
            }
        }
        .lifeRoutePhotoPickerScope()
        .fullScreenCover(isPresented: $isCameraPresented) {
            VisualSupportCameraPicker { imageData in
                guard let request = cameraRequest,
                      let accepted = media.accept(request, signature: inputSignature) else { return }
                let feedback = visibilityScope?.owner?.presentedFeedbackTicket(for: visibilityScope!.id)
                Task { await prepareReferencePhoto(imageData, sourceMessage: "Camera reference ready.", accepted: accepted, feedback: feedback) }
            } onCancel: {
                if referencePhotoData == nil { inputMethod = .textOnly }
            }
            .ignoresSafeArea()
            .lifeRouteModalScope()
        }
        .lifeRouteReconcile { context in
            let previous = leaveIdentity
            leaveIdentity = context.leaveIdentity
            if (previous != nil && previous != context.leaveIdentity) || !context.alive {
                media.revokePresentation()
                focusedInput = nil
            }
            resumeCameraPermission()
        }
        .onChange(of: inputSignature) { signature in media.update(signature) }
        .onDisappear { media.revokePresentation() }
        .task(id: LifeRoutePhotoActivity(item: selectedPhotoItem,
            input: [clientCode, label, visualDescription], active: visibility.active)) {
            await loadSelectedPhoto()
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        // Nil/cancellation changes bookkeeping only, never accepted artwork.
        guard let selection = photoSelection else { loadedPhotoSelection = nil; return }
        guard visibility.active, selection != loadedPhotoSelection else { return }
        let request = media.begin(inputSignature)
        let feedback = visibilityScope?.feedbackTicket()
        let loadedData = try? await selection.item.loadTransferable(type: Data.self)
        guard !Task.isCancelled, selection == photoSelection,
              media.accepts(request, signature: inputSignature) else { return }
        guard let loadedData else {
            if feedback?.isEligible == true { message = "LifeRoute could not load that photo." }
            return
        }
        inputMethod = .photoLibrary
        let acceptedRequest = media.begin(inputSignature)
        guard let accepted = media.accept(acceptedRequest, signature: inputSignature) else { return }
        // The finite accepted normalization may finish while the origin is
        // hidden. Only successful publication completes this item/client.
        // Pending semantic edits retry; later edits preserve accepted/generated art.
        Task {
            if await prepareReferencePhoto(loadedData, sourceMessage: "Photo Library reference ready.", accepted: accepted, feedback: feedback) {
                loadedPhotoSelection = selection
            }
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
        guard visibility.interaction, let scope = visibilityScope,
              let intent = scope.owner?.intent(for: scope.id) else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            message = "A camera is not available on this device. Text only and Photo Library remain available."
            return
        }
        let request = UUID()
        permissionID = request; permissionIntent = intent; permissionResult = nil; permissionInput = inputSignature
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionResult = true; resumeCameraPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    guard permissionID == request else { return }
                    permissionResult = granted; resumeCameraPermission()
                }
            }
        case .denied, .restricted:
            permissionResult = false; resumeCameraPermission()
        @unknown default:
            permissionResult = false; resumeCameraPermission()
        }
    }

    private func resumeCameraPermission() {
        guard permissionID != nil, let intent = permissionIntent else { return }
        guard intent.isValid, permissionInput == inputSignature else {
            permissionID = nil; permissionIntent = nil; permissionResult = nil; return
        }
        guard intent.isEligible, let granted = permissionResult else { return }
        // Consume the originating intent before native presentation can reenter.
        permissionID = nil; permissionIntent = nil; permissionResult = nil
        if granted {
            focusedInput = nil; selectedPhotoItem = nil; inputMethod = .camera
            cameraRequest = media.begin(inputSignature)
            isCameraPresented = true
        } else {
            message = "Camera access was not granted. Text only and Photo Library remain available."
        }
    }

    @MainActor
    private func prepareReferencePhoto(_ data: Data, sourceMessage: String, accepted: LifeRouteMediaAdmission.Accepted, feedback: LifeRouteFeedbackTicket?) async -> Bool {
        guard !data.isEmpty else {
            if feedback?.isEligible == true { message = "LifeRoute could not load that reference photo." }
            return false
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
        guard !Task.isCancelled, visibilityScope?.context.alive == true, media.publish(accepted, signature: inputSignature) else { return false }
        referencePhotoData = data
        referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
        photoData = data
        isGeneratedArtwork = false
        referencePreviewID = requestID
        photoPreviewID = requestID
        if feedback?.isEligible == true { message = "\(sourceMessage) Review it, save it directly, or generate an illustrated icon." }
        return true
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

    private func receiveGeneratedImage(_ data: Data?, feedback: LifeRouteFeedbackTicket?) {
        guard let data else {
            if feedback?.isEligible == true { message = "LifeRoute could not import that generated image. Try generating again." }
            return
        }
        photoData = data
        photoPreviewID = UUID()
        isGeneratedArtwork = true
        if feedback?.isEligible == true {
            message = "Illustrated ABA visual ready. Review the artwork and exact label before saving."
            LifeRouteHaptics.success()
        }
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
    @Environment(\.lifeRoutePresentation) private var visibilityScope
    @StateObject private var admission = LifeRouteMediaAdmission()
    @State private var request: LifeRouteMediaAdmission.Request?
    @State private var feedback: LifeRouteFeedbackTicket?
    private var inputSignature: [String] { [label, visualDescription, String(referencePhotoData?.hashValue ?? 0)] }

    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingPlayground = false
    @State private var isPreparingResult = false

    let label: String
    let visualDescription: String
    let referencePhotoData: Data?
    let sourceImage: Image?
    let isRegeneration: Bool
    let onImageReady: (Data?, LifeRouteFeedbackTicket?) -> Void

    private var cleanLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private var concepts: [ImagePlaygroundConcept] {
        VisualSupportImagePrompt(
            label: cleanLabel,
            visualDescription: visualDescription,
            hasReference: referencePhotoData != nil
        ).conceptDescriptions.map { .text($0) }
    }

    private var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.personalization = .disabled
        return options
    }

    var body: some View {
        let presentedRequest = request
        VStack(alignment: .leading, spacing: 7) {
            Button {
                guard visibilityScope?.context.interaction == true else { return }
                request = admission.begin(inputSignature)
                feedback = visibilityScope?.feedbackTicket()
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
            .lifeRouteSystemModal(isPresented: showingPlayground)
            .onChange(of: inputSignature) { signature in
                admission.update(signature)
                if request?.input != admission.inputRevision { request = nil; isPreparingResult = false }
            }
            .onDisappear { admission.revokePresentation() }
            .imagePlaygroundSheet(
                isPresented: $showingPlayground,
                concepts: concepts,
                sourceImage: sourceImage,
                onCompletion: { url in
                    guard let presentedRequest, let accepted = admission.accept(presentedRequest, signature: inputSignature) else { return }
                    let originFeedback = feedback
                    let modalFeedback = visibilityScope?.owner?.presentedFeedbackTicket(for: visibilityScope!.id)
                    let epoch = admission.presentationEpoch
                    isPreparingResult = true
                    Task {
                        let data = await ABAVisualSupportImageProcessor.normalizedSquarePNG(from: url)
                        guard visibilityScope?.context.alive == true, admission.publish(accepted, signature: inputSignature) else { return }
                        isPreparingResult = false
                        let eligible = modalFeedback?.isEligible == true ? modalFeedback : (epoch == admission.presentationEpoch ? originFeedback : nil)
                        onImageReady(data, eligible)
                    }
                },
                onCancellation: {
                    if request == presentedRequest { isPreparingResult = false }
                }
            )
            .imagePlaygroundOptions(options)
            .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])

            Text(
                supportsImagePlayground
                    ? "Apple’s Image Playground opens for review. Illustration style, square output, disabled person personalization, and text-free artwork guidance are preconfigured."
                    : "Image generation is unavailable in the current device, language, region, or Apple Intelligence settings."
            )
            .font(.caption)
            .foregroundStyle(palette.textSecondary)
        }
    }
}
#endif

struct ClientChoiceBoardBuilderView: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    var body: some View {
        BoardEditor(visualState: visualState, clientCode: clientCode, kind: .choice)
    }
}

struct ClientFirstThenVisualView: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    var initialClientCode = ClientVisualSupportCore.generalClientCode
    var body: some View {
        BoardEditor(visualState: visualState, clientCode: initialClientCode, kind: .firstThen, clientState: clientState)
    }
}

struct ClientVisualScheduleBuilderView: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    var body: some View {
        BoardEditor(visualState: visualState, clientCode: clientCode, kind: .schedule)
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
    @ObservedObject var visualState: ClientVisualSupportCore
    let board: ClientChoiceBoard
    let clientCode: String
    var body: some View {
        BoardArtifactPreview(board: .choice(
            visualState.choiceBoards(for: clientCode).first(where: { $0.id == board.id }) ?? board,
            in: visualState
        ))
    }
}

struct ClientVisualSchedulePreviewView: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let schedule: ClientVisualSchedule
    let clientCode: String
    var body: some View {
        BoardArtifactPreview(board: .schedule(
            visualState.schedules(for: clientCode).first(where: { $0.id == schedule.id }) ?? schedule,
            in: visualState
        ))
    }
}

private struct VisualBuilderHero: View {
    let title: String
    let subtitle: String
    let clientCode: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(UI01Material.gold)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text(clientCode)
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(UI01Material.goldLight)
            }

            UI01MarbleText(title: title, size: 34, relativeTo: .largeTitle)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(UI01Material.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui01OpenSection()
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
    @LifeRoutePresentation private var visibility
    @State private var completedRequest: ClientVisualThumbnailRequest?
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
        .task(id: LifeRouteThumbnailActivity(request: request, active: visibility.active)) {
            guard visibility.active, completedRequest != request else { return }
            let decoded = await ClientVisualThumbnailCache.shared.thumbnail(
                for: request,
                imageData: imageData
            )
            guard !Task.isCancelled else { return }
            completedRequest = request
            preview = decoded
        }
    }
}

private struct ClientVisualIconThumbnail: View {
    @LifeRoutePresentation private var visibility
    @State private var completedRequest: ClientVisualThumbnailRequest?
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
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                    Text(icon.label.prefix(2).uppercased()).font(.headline)
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: LifeRouteThumbnailActivity(request: request, active: visibility.active)) {
            guard visibility.active, completedRequest != request else { return }
            guard let imageData = icon.imageData else {
                thumbnail = nil
                return
            }
            let decoded = await ClientVisualThumbnailCache.shared.thumbnail(
                for: request,
                imageData: imageData
            )
            guard !Task.isCancelled else { return }
            completedRequest = request
            thumbnail = decoded
        }
    }
}

private struct VisualSupportPreviewCard: View {
    let label: String
    let icon: ClientVisualIcon?
    let fallbackText: String
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.black))
                .tracking(1.6)
                .foregroundStyle(UI01Material.gold)

            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: compact ? 96 : 150)
                Text(fallbackText == "First activity" || fallbackText == "Then activity" ? icon.label : fallbackText)
                    .font(compact ? .headline.weight(.black) : .title2.weight(.black))
                    .foregroundStyle(UI01Material.silver)
            } else {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(UI01Material.secondary)
                Text(fallbackText)
                    .font(compact ? .headline.weight(.black) : .title2.weight(.black))
                    .foregroundStyle(UI01Material.silver)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 158 : 190)
        .padding(2)
        .fixedSize(horizontal: false, vertical: true)
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
                        .accessibilityLabel("Supervisor-approved targets and priorities")
                        .overlay(alignment: .topLeading) {
                            if targetsText.isEmpty {
                                Text("Enter approved targets, one per line.")
                                    .foregroundStyle(palette.textSecondary)
                                    .padding(.horizontal, 5).padding(.vertical, 8)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
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
                        .accessibilityLabel("Known reinforcers and useful activities")
                        .overlay(alignment: .topLeading) {
                            if reinforcersText.isEmpty {
                                Text("Enter known reinforcers or useful activities.")
                                    .foregroundStyle(palette.textSecondary)
                                    .padding(.horizontal, 5).padding(.vertical, 8)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
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
