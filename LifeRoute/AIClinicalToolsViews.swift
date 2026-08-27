import SwiftUI
import PhotosUI

struct AISessionNoteGeneratorView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore
    @ObservedObject var toolsState: SessionToolsCore

    @State private var selectedClientCode = ""
    @State private var narrative = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var generatedNote = ""
    @State private var message: String?
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                inputCard
                actionCard
                if !generatedNote.isEmpty { resultCard }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("AI Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                screenshotData = nil
                return
            }
            let data = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled, selectedPhotoItem == self.selectedPhotoItem else { return }
            screenshotData = data
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.accent.opacity(0.16))
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 52, height: 52)
                Spacer()
                Label("ON-DEVICE", systemImage: "apple.intelligence")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(palette.accentSecondary)
            }

            Text("Session Note Generator")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Text("Turn your session facts and an optional data screenshot into a concise ABA note draft. The generator is instructed to use supplied facts only.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Session facts")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            Picker("Client", selection: $selectedClientCode) {
                Text("General / no client").tag("")
                ForEach(clientState.clients) { client in
                    Text(client.code).tag(client.code)
                }
            }
            .pickerStyle(.menu)

            Menu {
                if matchingScratchNotes.count > 1 {
                    Button("Append all \(matchingScratchNotes.count) matching notes") {
                        let combined = matchingScratchNotes
                            .reversed()
                            .map(\.text)
                            .joined(separator: "\n\n")
                        appendToNarrative(combined)
                        message = "Matching scratch notes added to session facts."
                        LifeRouteHaptics.selection()
                    }
                }

                ForEach(matchingScratchNotes.prefix(12)) { note in
                    Button {
                        appendToNarrative(note.text)
                        message = "Scratch note added to session facts."
                        LifeRouteHaptics.selection()
                    } label: {
                        Text("\(note.createdAt.formatted(date: .omitted, time: .shortened)) · \(String(note.text.prefix(56)))")
                    }
                }

                if matchingScratchNotes.isEmpty {
                    Text("No matching scratch notes")
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pull from Scratch Notes")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(scratchNoteStatus)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .disabled(matchingScratchNotes.isEmpty)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $narrative)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if narrative.isEmpty {
                    Text("Type or paste what happened during the session…")
                        .foregroundStyle(palette.textSecondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 11) {
                    Image(systemName: screenshotData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshotData == nil ? "Attach data screenshot" : "Data screenshot ready")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Optional · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if let selectedClient {
                Text("Saved context for \(selectedClient.code) can help the model understand terminology, but it is explicitly told not to claim a target or behavior occurred unless your session facts support it.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "Drafting…" : "Draft note with AI", systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isGenerating || (narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && screenshotData == nil))

            if let message {
                Label(message, systemImage: generatedNote.isEmpty ? "info.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("Review every sentence before using a generated draft for documentation or billing.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Editable draft")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    UIPasteboard.general.string = generatedNote
                    LifeRouteHaptics.success()
                    message = "Draft copied."
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption.weight(.bold))
            }

            TextEditor(text: $generatedNote)
                .frame(minHeight: 260)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await generate() }
            } label: {
                Label("Regenerate from current facts", systemImage: "arrow.clockwise")
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(isGenerating)
        }
        .lifeRouteCard()
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard !selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: selectedClientCode)
    }

    private var matchingScratchNotes: [QuickSessionNote] {
        let selectedCode = selectedClientCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return toolsState.notes
            .filter { note in
                if selectedCode.isEmpty { return note.clientCode == nil }
                return note.clientCode?.caseInsensitiveCompare(selectedCode) == .orderedSame
            }
            .reversed()
    }

    private var scratchNoteStatus: String {
        let count = matchingScratchNotes.count
        if count == 0 {
            return selectedClientCode.isEmpty ? "No General scratch notes yet" : "No scratch notes for \(selectedClientCode)"
        }
        return "\(count) matching note\(count == 1 ? "" : "s") · appends without overwriting"
    }

    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            narrative = clean
        } else {
            narrative += "\n\n\(clean)"
        }
    }

    @MainActor
    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        message = nil
        defer { isGenerating = false }

        do {
            generatedNote = try await LifeRouteIntelligenceCore.generateABASessionNote(
                narrative: narrative,
                screenshotData: screenshotData,
                client: selectedClient
            )
            message = "Draft generated on device."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct AISessionPlanBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    @State private var selectedClientCode = ""
    @State private var durationMinutes = 120
    @State private var targetsText = ""
    @State private var reinforcersText = ""
    @State private var additionalContext = ""
    @State private var generatedPlan = ""
    @State private var message: String?
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                contextCard
                inputsCard
                actionCard
                if !generatedPlan.isEmpty { resultCard }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("AI Session Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedClientCode) { _ in loadClientContext() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("SMART SESSION FLOW", systemImage: "brain.head.profile.fill")
                .font(.caption.weight(.black))
                .tracking(1.2)
                .foregroundStyle(palette.accent)
            Text("Build the plan, not a mirror.")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Text("AI turns your approved targets, known reinforcers, client context, and session length into a proposed sequence of time blocks while staying inside the information you supply.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Client", selection: $selectedClientCode) {
                Text("General / no client").tag("")
                ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
            }
            .pickerStyle(.menu)

            Picker("Session length", selection: $durationMinutes) {
                Text("1 hr").tag(60)
                Text("1.5 hr").tag(90)
                Text("2 hr").tag(120)
                Text("2.5 hr").tag(150)
                Text("3 hr").tag(180)
                Text("4 hr").tag(240)
                Text("6 hr").tag(360)
            }
            .pickerStyle(.menu)
        }
        .lifeRouteCard()
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            plannerEditor(title: "Approved targets / priorities", text: $targetsText, minHeight: 120)
            plannerEditor(title: "Known reinforcers / preferred activities", text: $reinforcersText, minHeight: 100)
            plannerEditor(title: "Additional context for this session", text: $additionalContext, minHeight: 90)

            if selectedClient != nil {
                Button("Reload saved client context") { loadClientContext() }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "Building plan…" : "Build session plan with AI", systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isGenerating || SessionToolsCore.list(from: targetsText).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("This organizes supervisor-approved information. It does not create new treatment targets, behavior protocols, prompting procedures, or reinforcement schedules.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proposed session flow")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    UIPasteboard.general.string = generatedPlan
                    LifeRouteHaptics.success()
                    message = "Plan copied."
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption.weight(.bold))
            }

            TextEditor(text: $generatedPlan)
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .lifeRouteCard()
    }

    private func plannerEditor(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accentSecondary)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard !selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: selectedClientCode)
    }

    private func loadClientContext() {
        guard let client = selectedClient else {
            targetsText = ""
            reinforcersText = ""
            return
        }
        targetsText = client.currentTargets.joined(separator: "\n")
        reinforcersText = client.preferredActivities.joined(separator: "\n")
    }

    @MainActor
    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        message = nil
        defer { isGenerating = false }

        do {
            generatedPlan = try await LifeRouteIntelligenceCore.generateSessionPlan(
                client: selectedClient,
                durationMinutes: durationMinutes,
                targets: SessionToolsCore.list(from: targetsText),
                reinforcers: SessionToolsCore.list(from: reinforcersText),
                additionalContext: additionalContext
            )
            message = "Session flow generated on device."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }
}
