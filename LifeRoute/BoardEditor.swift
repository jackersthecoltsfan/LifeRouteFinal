import SwiftUI

/// Adapters resolve images through the existing library owner. No file paths,
/// client codes, or source filenames become part of an exported artifact.
extension BoardArtifact {
    static func item(id: UUID, label: String, icon: ClientVisualIcon?) -> Item {
        Item(id: id, label: label, imageID: icon?.imageData == nil ? nil : icon?.id, imageData: icon?.imageData)
    }

    @MainActor static func choice(_ board: ClientChoiceBoard, in store: ClientVisualSupportCore) -> Self {
        Self(id: board.id, kind: .choice, title: board.title, items: board.iconIDs.map { id in
            let icon = store.icon(id: id, for: board.clientCode)
            return item(id: id, label: icon?.label ?? "Image unavailable", icon: icon)
        }, columns: board.columns)
    }

    @MainActor static func schedule(_ schedule: ClientVisualSchedule, in store: ClientVisualSupportCore, firstThen: Bool = false) -> Self {
        Self(id: schedule.id, kind: firstThen || schedule.kind == .firstThen ? .firstThen : .schedule,
             title: schedule.title, items: schedule.steps.map { step in
            item(id: step.id, label: step.label, icon: step.iconID.flatMap { store.icon(id: $0, for: schedule.clientCode) })
        })
    }

    @MainActor static func token(_ board: ClientTokenBoard, in store: ClientVisualSupportCore) -> Self {
        Self(id: board.id, kind: .token, title: board.title, items: [
            item(id: board.id, label: board.rewardLabel,
                 icon: board.rewardIconID.flatMap { store.icon(id: $0, for: board.clientCode) })
        ], tokenCount: board.tokenCount)
    }
}

/// One editing flow with four bounded configurations. Persistent models remain
/// owned by ClientVisualSupportCore; cancellation never mutates a saved board.
struct BoardEditor: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientState: ClientProfileCore?
    let kind: BoardArtifact.Kind
    let editingID: UUID?
    @State private var clientCode: String
    @State private var title: String
    @State private var steps: [ClientVisualScheduleStep]
    @State private var choiceIDs: [UUID]
    @State private var columns: Int
    @State private var tokenCount: Int
    @State private var rewardLabel: String
    @State private var rewardID: UUID?
    @State private var message: String?
    @State private var preview: BoardArtifact?
    @State private var savedID: UUID?
    @State private var pickingStep: UUID?
    @State private var pickingReward = false
    @State private var saving = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(visualState: ClientVisualSupportCore, clientCode: String, kind: BoardArtifact.Kind,
         clientState: ClientProfileCore? = nil, choice: ClientChoiceBoard? = nil,
         schedule: ClientVisualSchedule? = nil, token: ClientTokenBoard? = nil) {
        self.visualState = visualState
        self.clientState = clientState
        self.kind = kind
        let id = choice?.id ?? schedule?.id ?? token?.id
        editingID = id
        _savedID = State(initialValue: id)
        _clientCode = State(initialValue: clientCode.isEmpty ? ClientVisualSupportCore.generalClientCode : clientCode)
        _title = State(initialValue: choice?.title ?? schedule?.title ?? token?.title ?? kind.title)
        _steps = State(initialValue: schedule?.steps ?? (kind == .firstThen ? [ClientVisualScheduleStep(label: ""), ClientVisualScheduleStep(label: "")] : []))
        _choiceIDs = State(initialValue: choice?.iconIDs ?? [])
        _columns = State(initialValue: choice?.columns ?? 2)
        _tokenCount = State(initialValue: token?.tokenCount ?? 5)
        _rewardLabel = State(initialValue: token?.rewardLabel ?? "")
        _rewardID = State(initialValue: token?.rewardIconID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(kind.title).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
                Text(instructions).font(.subheadline).foregroundStyle(UI01Material.secondary)
                if let clientState, savedID == nil {
                    Picker("Visual library", selection: $clientCode) {
                        Text(ClientVisualSupportCore.generalDisplayName).tag(ClientVisualSupportCore.generalClientCode)
                        ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
                    }.pickerStyle(.menu)
                }
                TextField("Board title", text: $title).scenicRoyalField()
                    .accessibilityLabel("Board title")

                if kind == .choice { choiceEditor }
                else if kind == .token { tokenEditor }
                else { sequenceEditor }

                if let message {
                    Text(message).font(.callout).foregroundStyle(UI01Material.secondary)
                        .accessibilityLabel(message)
                }
            }
            .padding(14)
            .foregroundStyle(UI01Material.silver)
        }
        .navigationTitle(savedID == nil ? kind.title : "Edit \(kind.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .disabled(saving)
        .safeAreaInset(edge: .bottom) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                Button { showPreview() } label: { Label("Preview", systemImage: "eye") }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                Button { save() } label: {
                    if saving { ProgressView("Saving") }
                    else { Label("Save & Preview", systemImage: "checkmark") }
                }
                    .buttonStyle(UI01GoldButtonStyle(compact: true))
                    .disabled(saving)
            }
            .padding(.horizontal, 14).padding(.vertical, 8).background(UI01Material.navy)
        }
        .fullScreenCover(item: $preview) { artifact in
            BoardArtifactPreview(board: artifact).lifeRouteModalScope()
        }
        .sheet(isPresented: Binding(get: { pickingStep != nil || pickingReward }, set: { if !$0 { pickingStep = nil; pickingReward = false } })) {
            BoardImagePicker(visualState: visualState, clientCode: clientCode) { icon in
                if pickingReward {
                    rewardID = icon.id
                    if rewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { rewardLabel = icon.label }
                } else if let id = pickingStep, let index = steps.firstIndex(where: { $0.id == id }) {
                    steps[index].iconID = icon.id
                    if steps[index].label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { steps[index].label = icon.label }
                }
                pickingStep = nil
                pickingReward = false
            }.lifeRouteModalScope()
        }
        .onChange(of: clientCode) { _ in
            // Drafts never carry references across library ownership boundaries.
            choiceIDs = []
            steps = kind == .firstThen ? [ClientVisualScheduleStep(label: ""), ClientVisualScheduleStep(label: "")] : []
            rewardID = nil; rewardLabel = ""
            message = nil
        }
        .onChange(of: steps) { _ in message = nil }
        .onChange(of: choiceIDs) { _ in message = nil }
    }

    private var instructions: String {
        switch kind {
        case .firstThen: return "Choose two saved visuals or enter labels. FIRST and THEN stay in this order."
        case .choice: return "Choose up to nine saved visuals. Arrange their order below."
        case .schedule: return "Arrange saved visuals and labels in a vertical sequence. Longer schedules export as ordered pages."
        case .token: return "Create a reusable board with empty token slots and a reward visual or label."
        }
    }

    private var choiceEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Columns", selection: Binding(get: { columns }, set: { requested in
                if requested == 2 && choiceIDs.count > 8 {
                    message = "Remove one choice before choosing 2 columns. All nine images remain selected."
                } else { columns = requested }
            })) {
                Text("2 columns").tag(2); Text("3 columns").tag(3)
            }.pickerStyle(.segmented)
            Text("\(choiceIDs.count) of \(columns == 3 ? 9 : 8) visuals selected").font(.subheadline)
            let icons = visualState.icons(for: clientCode)
            if icons.isEmpty { emptyLibrary }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 12) {
                ForEach(icons) { icon in
                    Button {
                        if choiceIDs.contains(icon.id) { choiceIDs.removeAll { $0 == icon.id } }
                        else if choiceIDs.count < (columns == 3 ? 9 : 8) { choiceIDs.append(icon.id) }
                    } label: {
                        VStack(spacing: 5) {
                            BoardLibraryImage(icon: icon)
                            Label(icon.label, systemImage: choiceIDs.contains(icon.id) ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.label)
                    .accessibilityValue(choiceIDs.contains(icon.id) ? "Selected" : "Not selected")
                    .accessibilityAddTraits(choiceIDs.contains(icon.id) ? .isSelected : [])
                }
            }
            if !choiceIDs.isEmpty {
                Text("Choice order").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(Array(choiceIDs.enumerated()), id: \.element) { index, id in
                    HStack {
                        Text("\(index + 1). \(visualState.icon(id: id, for: clientCode)?.label ?? "Image unavailable")")
                        Spacer()
                        reorderButtons(index: index, count: choiceIDs.count) { destination in choiceIDs.swapAt(index, destination) }
                    }
                }
            }
        }
    }

    private var sequenceEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(kind == .firstThen ? (index == 0 ? "FIRST" : "THEN") : "Step \(index + 1)")
                            .font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if kind == .schedule {
                            reorderButtons(index: index, count: steps.count) { destination in steps.swapAt(index, destination) }
                            Button(role: .destructive) { steps.removeAll { $0.id == step.id } } label: {
                                Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                            }.accessibilityLabel("Remove step \(index + 1)")
                        }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        if let id = step.iconID, let icon = visualState.icon(id: id, for: clientCode) {
                            BoardLibraryImage(icon: icon).frame(width: 116)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Step label", text: stepLabel(id: step.id)).scenicRoyalField()
                                .accessibilityLabel(kind == .firstThen ? (index == 0 ? "First activity" : "Then activity") : "Step \(index + 1) label")
                            Button { pickingStep = step.id } label: { Label("Choose image", systemImage: "photo").frame(minHeight: 44) }
                                .accessibilityLabel("Choose image for step \(index + 1)")
                            if step.iconID != nil {
                                Button("Use label only") {
                                    if let current = steps.firstIndex(where: { $0.id == step.id }) { steps[current].iconID = nil }
                                }.font(.subheadline).frame(minHeight: 44)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            if kind == .schedule {
                Button { steps.append(ClientVisualScheduleStep(label: "")) } label: { Label("Add step", systemImage: "plus") }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
            } else {
                Button("Swap First / Then") { if steps.count == 2 { steps.swapAt(0, 1) } }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
    }

    private var tokenEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Token slots", selection: $tokenCount) {
                ForEach(3...10, id: \.self) { count in Text("\(count) empty slots").tag(count) }
            }.pickerStyle(.menu).frame(minHeight: 44)
            TextField("Reward label", text: $rewardLabel).scenicRoyalField().accessibilityLabel("Reward label")
            if let id = rewardID, let icon = visualState.icon(id: id, for: clientCode) {
                BoardLibraryImage(icon: icon).frame(maxWidth: 240)
                Button("Use label only") { rewardID = nil }.frame(minHeight: 44)
            }
            Button { pickingReward = true } label: { Label("Choose reward image", systemImage: "photo") }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
        }
    }

    private var emptyLibrary: some View {
        Text("No saved images in this library yet. Save a visual in Image Generator, then return here to choose it.")
            .font(.callout).foregroundStyle(UI01Material.secondary)
    }

    private func reorderButtons(index: Int, count: Int, move: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            Button { move(index - 1) } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
                .disabled(index == 0).accessibilityLabel("Move item \(index + 1) earlier")
            Button { move(index + 1) } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }
                .disabled(index + 1 == count).accessibilityLabel("Move item \(index + 1) later")
        }
    }

    private func stepLabel(id: UUID) -> Binding<String> {
        Binding(get: { steps.first(where: { $0.id == id })?.label ?? "" }, set: { value in
            if let index = steps.firstIndex(where: { $0.id == id }) { steps[index].label = value }
        })
    }

    private func validatedDraft() throws -> BoardArtifact {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }
        let id = savedID ?? UUID()
        if kind == .choice {
            guard !choiceIDs.isEmpty else { throw ClientVisualSupportError.noIcons }
            guard choiceIDs.count <= (columns == 3 ? 9 : 8) else { throw BoardEditorError.tooManyChoices }
            let items = try choiceIDs.map { id -> BoardArtifact.Item in
                guard let icon = visualState.icon(id: id, for: clientCode) else { throw ClientVisualSupportError.crossClientReference }
                return BoardArtifact.item(id: id, label: icon.label, icon: icon)
            }
            return BoardArtifact(id: id, kind: kind, title: cleanTitle, items: items, columns: columns)
        }
        if kind == .token {
            let label = rewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw ClientVisualSupportError.missingRewardLabel }
            let icon = rewardID.flatMap { visualState.icon(id: $0, for: clientCode) }
            if rewardID != nil && icon == nil { throw ClientVisualSupportError.crossClientReference }
            return BoardArtifact(id: id, kind: kind, title: cleanTitle,
                items: [BoardArtifact.item(id: id, label: label, icon: icon)], tokenCount: tokenCount)
        }
        guard !steps.isEmpty else { throw ClientVisualSupportError.noSteps }
        let items = try steps.map { step -> BoardArtifact.Item in
            let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw ClientVisualSupportError.missingLabel }
            let icon = step.iconID.flatMap { visualState.icon(id: $0, for: clientCode) }
            if step.iconID != nil && icon == nil { throw ClientVisualSupportError.crossClientReference }
            return BoardArtifact.item(id: step.id, label: label, icon: icon)
        }
        return BoardArtifact(id: id, kind: kind, title: cleanTitle, items: items)
    }

    private func showPreview() {
        do { preview = try validatedDraft(); message = nil }
        catch { message = error.localizedDescription }
    }

    private func save() {
        guard !saving else { return }
        saving = true
        Task { @MainActor in
        defer { saving = false }
        do {
            _ = try validatedDraft()
            let artifact: BoardArtifact
            switch kind {
            case .choice:
                let board: ClientChoiceBoard
                if let id = savedID { board = try visualState.updateChoiceBoard(id: id, clientCode: clientCode, title: title, iconIDs: choiceIDs, columns: columns) }
                else { board = try visualState.saveChoiceBoard(clientCode: clientCode, title: title, iconIDs: choiceIDs, columns: columns) }
                savedID = board.id; artifact = .choice(board, in: visualState)
            case .schedule, .firstThen:
                let type: ClientVisualScheduleKind = kind == .firstThen ? .firstThen : .visualSchedule
                let schedule: ClientVisualSchedule
                if let id = savedID { schedule = try visualState.updateSchedule(id: id, clientCode: clientCode, title: title, steps: steps, kind: type) }
                else { schedule = try visualState.saveSchedule(clientCode: clientCode, title: title, steps: steps, kind: type) }
                savedID = schedule.id; artifact = .schedule(schedule, in: visualState)
            case .token:
                let board: ClientTokenBoard
                if let id = savedID { board = try visualState.updateTokenBoard(id: id, clientCode: clientCode, title: title, tokenCount: tokenCount, rewardIconID: rewardID, rewardLabel: rewardLabel) }
                else { board = try visualState.saveTokenBoard(clientCode: clientCode, title: title, tokenCount: tokenCount, rewardIconID: rewardID, rewardLabel: rewardLabel) }
                savedID = board.id; artifact = .token(board, in: visualState)
            }
            try await visualState.confirmSavedBoards()
            preview = artifact
            message = "Board saved."
        } catch { message = error.localizedDescription }
        }
    }
}

private enum BoardEditorError: LocalizedError {
    case tooManyChoices
    var errorDescription: String? {
        "Two columns support up to eight choices. Choose three columns or remove one image before saving."
    }
}

struct BoardLibraryImage: View {
    let icon: ClientVisualIcon
    @State private var image: UIImage?
    var body: some View {
        Color.white.aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFit().padding(2) }
                else { Text(icon.label).font(.headline).foregroundStyle(.black).multilineTextAlignment(.center).padding(8) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 0.75))
            .accessibilityHidden(true)
            .task(id: icon.id) {
                let artifact = BoardArtifact(id: icon.id, kind: .choice, title: "", items: [.init(id: icon.id, label: icon.label, imageID: icon.imageData == nil ? nil : icon.id, imageData: icon.imageData)])
                image = try? await BoardImageLoader.shared.load(artifact, pixels: 600)[icon.id]
            }
    }
}

struct BoardImagePicker: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    let select: (ClientVisualIcon) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationStack {
            ScrollView {
                let icons = visualState.icons(for: clientCode)
                if icons.isEmpty { Text("No saved images in this library. Save an image in Image Generator first.").padding() }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(icons) { icon in
                        Button { select(icon); dismiss() } label: {
                            VStack {
                                BoardLibraryImage(icon: icon)
                                Text(icon.label).font(.headline).fixedSize(horizontal: false, vertical: true)
                            }
                        }.buttonStyle(.plain).accessibilityLabel(icon.label)
                    }
                }.padding(12)
            }
            .navigationTitle("Choose saved image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct BoardSavedLibrary: View {
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var preview: BoardArtifact?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved boards").font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            let choices = visualState.choiceBoards(for: clientCode)
            if let warning = visualState.boardSaveWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(UI01Material.goldLight)
            }
            let schedules = visualState.schedules(for: clientCode)
            let tokens = visualState.tokenBoards(for: clientCode)
            if choices.isEmpty && schedules.isEmpty && tokens.isEmpty {
                Text("Save a board to reopen, edit, and export it here.").font(.subheadline)
            }
            ForEach(choices) { board in
                VStack(alignment: .leading, spacing: 8) {
                    title(board.title, detail: "Choice Board · \(board.iconIDs.count) choices")
                    HStack {
                        Button { preview = .choice(board, in: visualState) } label: { Text("Open").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Open Choice Board \(board.title)").accessibilityIdentifier("boards.choice.open.\(board.id)")
                        NavigationLink {
                            BoardEditor(visualState: visualState, clientCode: clientCode, kind: .choice, choice: board).lifeRouteDeepDestination()
                        } label: { Text("Edit").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Edit Choice Board \(board.title)").accessibilityIdentifier("boards.choice.edit.\(board.id)")
                        Spacer()
                        Menu {
                            Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("More actions for \(board.title)")
                    }
                    UI01Hairline()
                }
            }
            ForEach(schedules) { schedule in
                let kindName = schedule.kind == .firstThen ? "First / Then" : "Visual Schedule"
                VStack(alignment: .leading, spacing: 8) {
                    title(schedule.title, detail: "\(schedule.kind == .firstThen ? "First / Then" : "Visual Schedule") · \(schedule.steps.count) steps")
                    HStack {
                        Button { preview = .schedule(schedule, in: visualState) } label: { Text("Open").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Open \(kindName) \(schedule.title)").accessibilityIdentifier("boards.schedule.open.\(schedule.id)")
                        NavigationLink {
                            BoardEditor(visualState: visualState, clientCode: clientCode,
                                kind: schedule.kind == .firstThen ? .firstThen : .schedule, schedule: schedule).lifeRouteDeepDestination()
                        } label: { Text("Edit").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Edit \(kindName) \(schedule.title)").accessibilityIdentifier("boards.schedule.edit.\(schedule.id)")
                        Spacer()
                        Menu {
                            Button("Delete board", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("More actions for \(schedule.title)")
                    }
                    if schedule.kind == nil && schedule.steps.count == 2 {
                        // Legacy storage did not distinguish two-step schedules.
                        // The user explicitly chooses this presentation; no guess
                        // or migration rewrites the original record on load.
                        NavigationLink("Edit as First / Then") {
                            BoardEditor(visualState: visualState, clientCode: clientCode, kind: .firstThen, schedule: schedule).lifeRouteDeepDestination()
                        }.font(.subheadline).frame(minHeight: 44)
                        Button("Open as First / Then") { preview = .schedule(schedule, in: visualState, firstThen: true) }
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    UI01Hairline()
                }
            }
            ForEach(tokens) { board in
                VStack(alignment: .leading, spacing: 8) {
                    title(board.title, detail: "Token Board · \(board.tokenCount) slots")
                    HStack {
                        Button { preview = .token(board, in: visualState) } label: { Text("Open").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Open Token Board \(board.title)").accessibilityIdentifier("boards.token.open.\(board.id)")
                        NavigationLink {
                            BoardEditor(visualState: visualState, clientCode: clientCode, kind: .token, token: board).lifeRouteDeepDestination()
                        } label: { Text("Edit").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Edit Token Board \(board.title)").accessibilityIdentifier("boards.token.edit.\(board.id)")
                        Spacer()
                        Menu {
                            Button("Delete board", role: .destructive) { visualState.removeTokenBoard(id: board.id) }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("More actions for \(board.title)")
                    }
                    UI01Hairline()
                }
            }
        }
        .foregroundStyle(UI01Material.silver)
        .fullScreenCover(item: $preview) { board in BoardArtifactPreview(board: board).lifeRouteModalScope() }
    }

    private func title(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(UI01Material.secondary)
        }
    }
}
