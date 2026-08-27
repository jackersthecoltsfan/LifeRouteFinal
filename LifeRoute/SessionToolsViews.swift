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
                Button("+1 minute") { timer.addMinute() }
                Button("Reset") { timer.reset() }
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
                    ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                }
                TextEditor(text: $noteText).frame(minHeight: 100)
                Button("Save note") {
                    do {
                        try toolsState.addNote(text: noteText, clientCode: selectedClientCode)
                        noteText = ""
                        message = "Scratch note saved for this app session."
                    } catch { message = error.localizedDescription }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
            }

            Section("Recent notes") {
                if toolsState.notes.isEmpty {
                    Text("No scratch notes yet").foregroundStyle(.secondary)
                } else {
                    ForEach(toolsState.notes.reversed()) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(note.clientCode ?? "General").font(.caption.bold())
                                Spacer()
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(note.text)
                            Button("Delete note", role: .destructive) { toolsState.removeNote(id: note.id) }
                        }.padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Quick Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Client-specific visual supports

struct ClientVisualSupportCenter: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode = ""

    var body: some View {
        Form {
            if clientState.clients.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Add a client first",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Visual supports are always saved to a specific ABA-style client code.")
                    )
                }
            } else {
                Section("Client") {
                    Picker("Visual library", selection: $selectedClientCode) {
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }
                    Text("Only \(selectedClientCode.isEmpty ? "the selected client’s" : selectedClientCode + "’s") icons will appear in the builders below.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if !selectedClientCode.isEmpty {
                    Section("Build") {
                        NavigationLink {
                            ClientVisualIconLibraryView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            Label("Icon Library", systemImage: "photo.on.rectangle")
                        }
                        NavigationLink {
                            ClientChoiceBoardBuilderView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            Label("Choice Boards", systemImage: "square.grid.2x2")
                        }
                        NavigationLink {
                            ClientFirstThenVisualView(visualState: visualState, clientState: clientState, initialClientCode: selectedClientCode)
                        } label: {
                            Label("First / Then", systemImage: "arrow.right")
                        }
                        NavigationLink {
                            ClientVisualScheduleBuilderView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            Label("Visual Schedules", systemImage: "list.number")
                        }
                    }

                    Section("\(selectedClientCode) library") {
                        LabeledContent("Icons", value: "\(visualState.icons(for: selectedClientCode).count)")
                        LabeledContent("Choice boards", value: "\(visualState.choiceBoards(for: selectedClientCode).count)")
                        LabeledContent("Schedules", value: "\(visualState.schedules(for: selectedClientCode).count)")
                    }
                }

                Section {
                    Text("Visual supports for \(selectedClientCode) are saved locally in protected LifeRoute app data on this iPhone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Visual Supports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectDefaultClientIfNeeded() }
    }

    private func selectDefaultClientIfNeeded() {
        if selectedClientCode.isEmpty || clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = clientState.clients.first?.code ?? ""
        }
    }
}

struct ClientVisualIconLibraryView: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var label = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreviewID = UUID()
    @State private var message: String?

    var body: some View {
        Form {
            Section("New \(clientCode) icon") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(photoData == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                }
                if let photoData {
                    ClientVisualDraftPhotoPreview(
                        imageData: photoData,
                        requestID: photoPreviewID,
                        maximumHeight: 220
                    )
                }
                TextField("Icon label", text: $label)
                    .textInputAutocapitalization(.words)
                Button("Save icon to \(clientCode)") { saveIcon() }
                if let message { Text(message).foregroundStyle(.secondary) }
                Text("A photo is optional; a text-only visual card can also be saved. Selected photos are stored locally in LifeRoute’s protected app data and are not uploaded.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("\(clientCode) icon library") {
                let icons = visualState.icons(for: clientCode)
                if icons.isEmpty {
                    Text("No icons saved for \(clientCode) yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(icons) { icon in
                        HStack(spacing: 12) {
                            ClientVisualIconThumbnail(icon: icon, size: 58)
                            VStack(alignment: .leading) {
                                Text(icon.label).font(.headline)
                                Text(icon.imageData == nil ? "Text visual" : "Photo visual")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { visualState.removeIcon(id: icon.id) } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
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
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var boardTitle = "Choices"
    @State private var columns = 2
    @State private var selectedIconIDs = Set<UUID>()
    @State private var message: String?

    var body: some View {
        Form {
            Section("Board") {
                TextField("Board title", text: $boardTitle)
                Picker("Columns", selection: $columns) {
                    Text("2 columns · up to 8").tag(2)
                    Text("3 columns · up to 9").tag(3)
                }
            }

            Section("Choose from \(clientCode)’s icons") {
                let icons = visualState.icons(for: clientCode)
                if icons.isEmpty {
                    Text("Create icons for \(clientCode) first. No other client’s icons are shown here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(icons) { icon in
                        Button {
                            toggle(icon.id)
                        } label: {
                            HStack(spacing: 12) {
                                ClientVisualIconThumbnail(icon: icon, size: 52)
                                Text(icon.label).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selectedIconIDs.contains(icon.id) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("\(selectedIconIDs.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Save board to \(clientCode)") { saveBoard() }
                if let message { Text(message).foregroundStyle(.secondary) }
            }

            Section("Saved \(clientCode) boards") {
                let boards = visualState.choiceBoards(for: clientCode)
                if boards.isEmpty {
                    Text("No choice boards saved for \(clientCode) yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(boards) { board in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(board.title).font(.headline)
                            Text(board.iconIDs.compactMap { visualState.icon(id: $0, for: clientCode)?.label }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(board.columns) columns · \(board.iconIDs.count) icons")
                                .font(.caption2).foregroundStyle(.secondary)
                            Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
                        }.padding(.vertical, 3)
                    }
                }
            }
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
        Form {
            if clientState.clients.isEmpty {
                Section { Text("Add a client in Setup before using client visual supports.").foregroundStyle(.secondary) }
            } else {
                Section("Client") {
                    Picker("Client", selection: $selectedClientCode) {
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }
                }

                if !selectedClientCode.isEmpty {
                    Section("Build") {
                        let icons = visualState.icons(for: selectedClientCode)
                        TextField("First activity", text: $firstText)
                        Picker("First visual", selection: $firstIconID) {
                            Text("Text only").tag("")
                            ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                        }
                        TextField("Then activity", text: $thenText)
                        Picker("Then visual", selection: $thenIconID) {
                            Text("Text only").tag("")
                            ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                        }
                        Button("Swap First / Then") {
                            (firstText, thenText) = (thenText, firstText)
                            (firstIconID, thenIconID) = (thenIconID, firstIconID)
                        }
                        Text("Only icons saved to \(selectedClientCode) are available here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("FIRST") {
                        VisualSupportPreviewCard(icon: selectedIcon(idString: firstIconID), fallbackText: firstText.isEmpty ? "First activity" : firstText)
                    }
                    Section("THEN") {
                        VisualSupportPreviewCard(icon: selectedIcon(idString: thenIconID), fallbackText: thenText.isEmpty ? "Then activity" : thenText)
                    }
                }
            }
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
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var title = "Visual Schedule"
    @State private var draftLabel = ""
    @State private var selectedIconID = ""
    @State private var steps: [ClientVisualScheduleStep] = []
    @State private var message: String?

    var body: some View {
        Form {
            Section("Schedule") {
                TextField("Schedule title", text: $title)
                let icons = visualState.icons(for: clientCode)
                TextField("Next step", text: $draftLabel)
                Picker("Visual", selection: $selectedIconID) {
                    Text("Text only").tag("")
                    ForEach(icons) { icon in Text(icon.label).tag(icon.id.uuidString) }
                }
                Button("Add step") { addStep() }
            }

            Section("Steps") {
                if steps.isEmpty {
                    Text("Add the first step. The visual picker only contains \(clientCode)’s icons.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(steps) { step in
                        HStack(spacing: 10) {
                            if let iconID = step.iconID, let icon = visualState.icon(id: iconID, for: clientCode) {
                                ClientVisualIconThumbnail(icon: icon, size: 48)
                            }
                            Text(step.label)
                            Spacer()
                            Button(role: .destructive) { steps.removeAll { $0.id == step.id } } label: { Image(systemName: "trash") }
                        }
                    }
                }
                Button("Save schedule to \(clientCode)") { saveSchedule() }
                if let message { Text(message).foregroundStyle(.secondary) }
            }

            Section("Saved \(clientCode) schedules") {
                let saved = visualState.schedules(for: clientCode)
                if saved.isEmpty {
                    Text("No visual schedules saved for \(clientCode) yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(saved) { schedule in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(schedule.title).font(.headline)
                            Text(schedule.steps.map(\.label).joined(separator: " → "))
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Delete schedule", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
                        }.padding(.vertical, 3)
                    }
                }
            }
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
    let icon: ClientVisualIcon?
    let fallbackText: String

    var body: some View {
        VStack(spacing: 12) {
            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: 170)
                Text(fallbackText == "First activity" || fallbackText == "Then activity" ? icon.label : fallbackText)
                    .font(.title.bold())
            } else {
                Text(fallbackText).font(.title.bold())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 10)
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
                    ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                }
                Picker("Session length", selection: $durationMinutes) {
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                    Text("4 hours").tag(240)
                }
                if !selectedClientCode.isEmpty {
                    Button("Load saved client profile") { loadClientProfile() }
                }
            }

            Section("Supervisor-approved targets / priorities") {
                TextEditor(text: $targetsText).frame(minHeight: 110)
            }

            Section("Known reinforcers / useful activities") {
                TextEditor(text: $reinforcersText).frame(minHeight: 90)
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
                    } catch { message = error.localizedDescription }
                }
                Text("This tool only organizes information you enter or load from the client profile. Follow the supervising clinician’s approved prompting, reinforcement, behavior, and treatment procedures.")
                    .font(.caption).foregroundStyle(.secondary)
                if let message { Text(message).foregroundStyle(.secondary) }
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
