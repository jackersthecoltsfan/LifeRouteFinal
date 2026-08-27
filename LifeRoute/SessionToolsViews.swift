import SwiftUI
import PhotosUI
import UIKit
import ImageIO

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

                Text("Visual supports are client-specific and saved locally on this iPhone.")
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
                Text("\(clientState.clients.count) saved client profiles available to session tools")
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
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var timer: VisualTimerCore
    @State private var minutes = 5

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = timer.remainingSeconds(at: context.date)
                    let progress = timer.progress(at: context.date)

                    VStack(spacing: 18) {
                        HStack {
                            Label(statusText(at: context.date), systemImage: statusIcon(at: context.date))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(timer.isRunning ? palette.accentSecondary : palette.textSecondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(palette.panelElevated.opacity(0.60), in: Capsule())
                            Spacer()
                            Text("\(minutes) MIN")
                                .font(.caption2.weight(.black))
                                .tracking(1.2)
                                .foregroundStyle(palette.accent)
                        }

                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 15)
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
                                    .font(.system(size: 58, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.textPrimary)
                                Text(timer.isFinished(at: context.date) ? "TIME IS UP" : "REMAINING")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.5)
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }
                        .frame(width: 245, height: 245)
                        .shadow(color: palette.accent.opacity(timer.isRunning ? 0.18 : 0.07), radius: 26)

                        ProgressView(value: timer.progress(at: context.date))
                            .tint(palette.accent)
                    }
                    .padding(20)
                    .lifeRouteCard()
                }

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

                Text("The timer stays accurate from its absolute deadline. During an active countdown it plays a 0.25-second rising chime, then gives a distinct completion chime and haptic at zero.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 3)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Visual Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer.$deadline) { deadline in
            guard deadline == nil, timer.remainingSeconds() <= 0 else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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

// MARK: - Client-specific visual supports

struct ClientVisualSupportCenter: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                visualHero

                if clientState.clients.isEmpty {
                    ContentUnavailableView(
                        "Add a client first",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Visual supports are always saved to a specific ABA-style client code.")
                    )
                    .lifeRouteCard()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Client library")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)

                        Picker("Visual library", selection: $selectedClientCode) {
                            ForEach(clientState.clients) { client in
                                Text(client.code).tag(client.code)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("Only \(selectedClientCode.isEmpty ? "the selected client’s" : selectedClientCode + "’s") icons will appear in the builders below.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    .lifeRouteCard()

                    if !selectedClientCode.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Create & use")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            LazyVGrid(columns: columns, spacing: 10) {
                                NavigationLink {
                                    ClientVisualIconLibraryView(visualState: visualState, clientCode: selectedClientCode)
                                } label: {
                                    VisualWorkspaceCard(title: "Icon Library", subtitle: "Photos or text visuals", systemImage: "photo.on.rectangle.angled")
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

                                NavigationLink {
                                    ClientVisualScheduleBuilderView(visualState: visualState, clientCode: selectedClientCode)
                                } label: {
                                    VisualWorkspaceCard(title: "Schedules", subtitle: "Sequence visual steps", systemImage: "list.number")
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 8) {
                            VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                            VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count, label: "Boards")
                            VisualLibraryMetric(value: visualState.schedules(for: selectedClientCode).count, label: "Schedules")
                        }
                        .lifeRouteCard()
                    }

                    Text("Visual supports for \(selectedClientCode) are saved locally in protected LifeRoute app data on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Visual Supports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectDefaultClientIfNeeded() }
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
                Text("Create client-specific icons, choice boards, First / Then visuals, and schedules.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .lifeRouteCard()
    }

    private func selectDefaultClientIfNeeded() {
        if selectedClientCode.isEmpty || clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = clientState.clients.first?.code ?? ""
        }
    }
}

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

struct ClientVisualIconLibraryView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var label = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreviewID = UUID()
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Icon Library",
                    subtitle: "Create reusable photo or text visuals for \(clientCode).",
                    clientCode: clientCode,
                    systemImage: "photo.on.rectangle.angled"
                )

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Create visual")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(photoData == nil ? "TEXT OR PHOTO" : "PHOTO READY")
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(photoData == nil ? palette.textSecondary : palette.accentSecondary)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.accent.opacity(0.14))
                                Image(systemName: photoData == nil ? "photo.badge.plus" : "photo.fill")
                                    .foregroundStyle(palette.accent)
                            }
                            .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(photoData == nil ? "Choose photo" : "Change photo")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Optional · stored only on this iPhone")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let photoData {
                        ClientVisualDraftPhotoPreview(
                            imageData: photoData,
                            requestID: photoPreviewID,
                            maximumHeight: 220
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.accent.opacity(0.22), lineWidth: 1)
                        }
                    }

                    TextField("Icon label", text: $label)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button("Save icon to \(clientCode)") { saveIcon() }
                        .buttonStyle(LifeRoutePrimaryButtonStyle())

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }

                    Text("A photo is optional; a text-only visual card can also be saved. Selected photos are stored locally in LifeRoute’s protected app data and are not uploaded.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("\(clientCode) icon library")
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
                            subtitle: "Create the first reusable visual for \(clientCode).",
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
                                    Label(icon.imageData == nil ? "Text visual" : "Photo visual", systemImage: icon.imageData == nil ? "textformat" : "photo.fill")
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
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("\(clientCode) Icons")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                photoData = nil
                photoPreviewID = UUID()
                return
            }
            let loadedData = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled,
                  selectedPhotoItem == self.selectedPhotoItem else { return }
            photoPreviewID = UUID()
            photoData = loadedData
        }
    }

    private func saveIcon() {
        do {
            _ = try visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)
            label = ""
            selectedPhotoItem = nil
            photoData = nil
            message = "Icon saved to \(clientCode)’s visual library on this iPhone."
        } catch { message = error.localizedDescription }
    }
}

struct ClientChoiceBoardBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var boardTitle = "Choices"
    @State private var columns = 2
    @State private var selectedIconIDs = Set<UUID>()
    @State private var message: String?

    private var selectionColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Choice Boards",
                    subtitle: "Turn \(clientCode)’s saved icons into a clean session-ready choice grid.",
                    clientCode: clientCode,
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
                    Text("Choose from \(clientCode)’s icons")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    let icons = visualState.icons(for: clientCode)
                    if icons.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No icons available",
                            subtitle: "Create icons for \(clientCode) first. No other client’s icons are shown here.",
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

                    Button("Save board to \(clientCode)") { saveBoard() }
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
                        Text("Saved \(clientCode) boards")
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
                                Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
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
        .navigationTitle("Choice Boards")
        .navigationBarTitleDisplayMode(.inline)
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
            _ = try visualState.saveChoiceBoard(clientCode: clientCode, title: boardTitle, iconIDs: ordered, columns: columns)
            selectedIconIDs.removeAll()
            message = "Choice board saved to \(clientCode)."
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

    init(visualState: ClientVisualSupportCore, clientState: ClientProfileCore, initialClientCode: String = "") {
        self.visualState = visualState
        self.clientState = clientState
        _selectedClientCode = State(initialValue: initialClientCode)
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
                        Text("Build a clear two-step visual using text or the selected client’s saved icons.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .lifeRouteCard()

                if clientState.clients.isEmpty {
                    ContentUnavailableView(
                        "Add a client first",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a client in Setup before using client visual supports.")
                    )
                    .lifeRouteCard()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Picker("Client", selection: $selectedClientCode) {
                            ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                        }
                        .pickerStyle(.menu)
                    }
                    .lifeRouteCard()

                    if !selectedClientCode.isEmpty {
                        let icons = visualState.icons(for: selectedClientCode)

                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text("Build sequence")
                                    .font(.headline)
                                    .foregroundStyle(palette.textPrimary)
                                Spacer()
                                Text(selectedClientCode)
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

                            Text("Only icons saved to \(selectedClientCode) are available here.")
                                .font(.caption)
                                .foregroundStyle(palette.textSecondary)
                        }
                        .lifeRouteCard()

                        VStack(alignment: .leading, spacing: 11) {
                            Text("Live preview")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.textPrimary)

                            VStack(spacing: 10) {
                                VisualSupportPreviewCard(
                                    label: "FIRST",
                                    icon: selectedIcon(idString: firstIconID),
                                    fallbackText: firstText.isEmpty ? "First activity" : firstText
                                )
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(palette.accent)
                                VisualSupportPreviewCard(
                                    label: "THEN",
                                    icon: selectedIcon(idString: thenIconID),
                                    fallbackText: thenText.isEmpty ? "Then activity" : thenText
                                )
                            }
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("First / Then")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectDefaultClientIfNeeded() }
        .onChange(of: selectedClientCode) { _ in
            firstIconID = ""
            thenIconID = ""
        }
    }

    private func selectDefaultClientIfNeeded() {
        if selectedClientCode.isEmpty || clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = clientState.clients.first?.code ?? ""
        }
    }

    private func selectedIcon(idString: String) -> ClientVisualIcon? {
        guard let id = UUID(uuidString: idString), !selectedClientCode.isEmpty else { return nil }
        return visualState.icon(id: id, for: selectedClientCode)
    }
}

struct ClientVisualScheduleBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var title = "Visual Schedule"
    @State private var draftLabel = ""
    @State private var selectedIconID = ""
    @State private var steps: [ClientVisualScheduleStep] = []
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Visual Schedules",
                    subtitle: "Build a clear sequence of visual steps for \(clientCode).",
                    clientCode: clientCode,
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
                            subtitle: "The visual picker only contains \(clientCode)’s icons.",
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

                    Button("Save schedule to \(clientCode)") { saveSchedule() }
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
                        Text("Saved \(clientCode) schedules")
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
                                Button("Delete schedule", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
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
        .navigationTitle("Visual Schedules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addStep() {
        let icon = UUID(uuidString: selectedIconID).flatMap { visualState.icon(id: $0, for: clientCode) }
        let clean = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty ? (icon?.label ?? "") : clean
        guard !resolved.isEmpty else {
            message = "Add a step label or choose one of \(clientCode)’s icons."
            return
        }
        steps.append(ClientVisualScheduleStep(label: resolved, iconID: icon?.id))
        draftLabel = ""
        selectedIconID = ""
        message = nil
    }

    private func saveSchedule() {
        do {
            _ = try visualState.saveSchedule(clientCode: clientCode, title: title, steps: steps)
            steps.removeAll()
            message = "Visual schedule saved to \(clientCode)."
        } catch { message = error.localizedDescription }
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

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.caption2.weight(.black))
                .tracking(1.6)
                .foregroundStyle(palette.accent)

            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: 150)
                Text(fallbackText == "First activity" || fallbackText == "Then activity" ? icon.label : fallbackText)
                    .font(.title2.weight(.black))
                    .foregroundStyle(palette.textPrimary)
            } else {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Text(fallbackText)
                    .font(.title2.weight(.black))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(16)
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
                            ForEach(Array(plan.targets.enumerated()), id: \.offset) { index, target in
                                HStack(alignment: .top, spacing: 9) {
                                    Text("\(index + 1)")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(Color.black.opacity(0.78))
                                        .frame(width: 24, height: 24)
                                        .background(palette.accent, in: Circle())
                                    Text(target)
                                        .foregroundStyle(palette.textPrimary)
                                    Spacer()
                                }
                            }
                        }

                        if !plan.reinforcers.isEmpty {
                            Divider().overlay(Color.white.opacity(0.08))
                            VStack(alignment: .leading, spacing: 8) {
                                Text("REINFORCERS")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.4)
                                    .foregroundStyle(palette.textSecondary)
                                ForEach(Array(plan.reinforcers.enumerated()), id: \.offset) { index, reinforcer in
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