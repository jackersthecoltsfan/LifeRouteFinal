import SwiftUI
import Foundation
import UIKit
import ImageIO

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

struct SavedVisualLibraryRow: View {
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

struct VisualBuilderHero: View {
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

struct VisualBuilderEmptyState: View {
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

struct ClientVisualThumbnailRequest: Hashable, Sendable {
    let assetID: UUID
    let maximumPixelDimension: Int
}

actor ClientVisualThumbnailCache {
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

struct ClientVisualDraftPhotoPreview: View {
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

struct ClientVisualIconThumbnail: View {
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
