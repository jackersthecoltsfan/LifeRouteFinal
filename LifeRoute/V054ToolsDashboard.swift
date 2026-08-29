import SwiftUI
import Foundation
import UIKit

#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct V054ToolsDashboard: View {
    // v0.7.0 Build D Tools/ABA: clinical-first hierarchy with all existing tools preserved.
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @StateObject private var visualState = ClientVisualSupportCore()

    private var sessionColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }
        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                toolsHeader
                readinessStrip

                LifeRouteSectionLabel(title: "Clinical")
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)
                        .lifeRouteDeepDestination()
                } label: {
                    clinicalCard(
                        title: "Session Note",
                        subtitle: "Turn supplied session facts into a reviewable ABA draft.",
                        systemImage: "sparkles.rectangle.stack.fill",
                        eyebrow: "DOCUMENTATION"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                NavigationLink {
                    AISessionPlanBuilderView(clientState: clientState)
                        .lifeRouteDeepDestination()
                } label: {
                    clinicalCard(
                        title: "Session Plan",
                        subtitle: "Organize approved targets, reinforcers, and session time into a usable flow.",
                        systemImage: "brain.head.profile",
                        eyebrow: "PREP"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                LifeRouteSectionLabel(title: "In Session")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                LazyVGrid(columns: sessionColumns, spacing: 10) {
                    NavigationLink {
                        VisualTimerView(timer: toolsState.timer)
                            .lifeRouteDeepDestination()
                    } label: {
                        sessionToolCard("Visual Timer", "Reliable timing", "timer")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                            .lifeRouteDeepDestination()
                    } label: {
                        sessionToolCard("Quick Notes", "Capture details fast", "note.text")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                            .lifeRouteDeepDestination()
                    } label: {
                        sessionToolCard("First / Then", "Clear visual sequence", "arrow.right.circle.fill")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)
                            .lifeRouteDeepDestination()
                    } label: {
                        sessionToolCard("Visual Supports", "Icons, boards, and ABA visuals", "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.plain)
                }

                clientContextCard

                Label(
                    "AI drafts use Apple’s on-device model when available. Review clinical output before use.",
                    systemImage: "lock.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            router.setBottomToolbarSuppressed(false)
            visualState.retainClients(clientState.clients)
        }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var toolsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tools")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("ABA workflow, ready when you are.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            LifeRouteIconBadge(systemImage: "wrench.and.screwdriver.fill", prominent: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readinessStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: clientState.clients.isEmpty ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(clientState.clients.isEmpty ? "General mode ready" : "Client context ready")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty ? "No client profile required for core tools." : "\(clientState.clients.count) saved client profile\(clientState.clients.count == 1 ? "" : "s") available.")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 4)

            Button("Manage") {
                LifeRouteHaptics.selection()
                router.select(.setup)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accent)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func clinicalCard(title: String, subtitle: String, systemImage: String, eyebrow: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption2.weight(.black))
                    .tracking(0.9)
                    .foregroundStyle(palette.accentSecondary)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel.opacity(0.64), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func sessionToolCard(_ title: String, _ subtitle: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            LifeRouteIconBadge(systemImage: systemImage, prominent: true)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(12)
        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var clientContextCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Client context")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty ? "General tools only" : "General + saved ABA client codes")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 48)
        .background(palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct VisualAIAssistedStudioView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore

    @State private var selectedClientCode = ClientVisualSupportCore.generalClientCode
    @State private var scheduleTitle = "Visual Schedule"
    @State private var scheduleRequest = ""
    @State private var generatedSteps: [String] = []
    @State private var isDraftingSchedule = false
    @State private var scheduleMessage: String?

    @State private var iconLabel = ""
    @State private var iconPrompt = ""
    @State private var generatedImageData: Data?
    @State private var imageMessage: String?
    @State private var showImagePlayground = false

    var body: some View {
        imagePlaygroundContainer
            .navigationTitle("Visual AI Studio")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                visualState.retainClients(clientState.clients)
                validateSelectedLibrary()
            }
            .onReceive(clientState.$clients) { clients in
                visualState.retainClients(clients)
                validateSelectedLibrary()
            }
            .onChange(of: selectedClientCode) { _ in
                generatedSteps.removeAll()
                generatedImageData = nil
                scheduleMessage = nil
                imageMessage = nil
            }
    }

    @ViewBuilder
    private var imagePlaygroundContainer: some View {
        #if canImport(ImagePlayground)
        if #available(iOS 18.2, *) {
            studioContent
                .imagePlaygroundSheet(
                    isPresented: $showImagePlayground,
                    concept: resolvedIconPrompt,
                    sourceImage: nil,
                    onCompletion: { url in
                        captureGeneratedImage(at: url)
                    },
                    onCancellation: {
                        imageMessage = "Image creation cancelled. Your manual icon tools are unchanged."
                    }
                )
        } else {
            studioContent
        }
        #else
        studioContent
        #endif
    }

    private var studioContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero
                libraryCard
                iconAICard
                manualWorkspaceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Visual Supports",
                subtitle: "Create and reuse client-scoped or General icons, choice boards, and visual supports.",
                systemImage: "photo.on.rectangle.angled"
            )

            Label("AI + MANUAL WORKSPACE", systemImage: "wand.and.stars")
                .font(.caption2.weight(.black))
                .tracking(0.7)
                .foregroundStyle(palette.accentSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 11) {
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

            Text("Anything saved here goes into \(libraryDisplayName)’s existing local visual library. Client libraries remain isolated from each other.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var scheduleAICard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Visual Schedule")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Describe the routine naturally; edit every step before saving.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "list.number")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
            }

            TextField("Schedule title", text: $scheduleTitle)
                .padding(12)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $scheduleRequest)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if scheduleRequest.isEmpty {
                    Text("Example: First wash hands, then sit at the table, eat lunch, clean up, and go outside.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary.opacity(0.72))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            Button {
                Task { await draftSchedule() }
            } label: {
                Label(isDraftingSchedule ? "Drafting…" : "Draft steps with AI", systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isDraftingSchedule || scheduleRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !generatedSteps.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Editable draft")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(generatedSteps.count) steps")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accentSecondary)
                    }

                    ForEach(generatedSteps.indices, id: \.self) { index in
                        HStack(spacing: 9) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .frame(width: 28, height: 28)
                                .background(palette.accent, in: Circle())

                            TextField("Step \(index + 1)", text: $generatedSteps[index])
                                .textInputAutocapitalization(.sentences)

                            VStack(spacing: 2) {
                                Button {
                                    moveStep(from: index, offset: -1)
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .disabled(index == 0)

                                Button {
                                    moveStep(from: index, offset: 1)
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .disabled(index == generatedSteps.count - 1)
                            }
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.textSecondary)

                            Button(role: .destructive) {
                                generatedSteps.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .font(.caption.weight(.bold))
                        }
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button("Add another step") {
                        generatedSteps.append("")
                        LifeRouteHaptics.selection()
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())

                    Button("Save AI draft to \(libraryDisplayName)") {
                        saveGeneratedSchedule()
                    }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())
                }
            }

            if let scheduleMessage {
                Label(scheduleMessage, systemImage: generatedSteps.isEmpty ? "info.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("AI only organizes the routine you supply. It is not allowed to add treatment targets, prompting procedures, behavior protocols, or reinforcement rules.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    // v0.8.0 follow-up visible ABA visual generator:
    // Route the primary Visual Supports experience to the real photo/text illustrated workflow.
    private var iconAICard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Illustrated Icon Generator")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Turn a text description or reference photo into a consistent ABA visual-support icon.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
            }

            HStack(spacing: 8) {
                visualGeneratorModeBadge("TEXT ONLY", systemImage: "textformat")
                visualGeneratorModeBadge("PHOTO", systemImage: "photo.fill")
                visualGeneratorModeBadge("REGENERATE", systemImage: "arrow.clockwise")
            }

            HStack(spacing: 10) {
                VStack(spacing: 7) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(palette.textSecondary)
                    Text("REFERENCE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 94)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.title2)
                        .foregroundStyle(palette.accent)
                    Text("ILLUSTRATED ICON")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 94)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reference photo or text becomes an illustrated ABA visual-support icon")

            NavigationLink {
                ClientVisualIconLibraryView(
                    visualState: visualState,
                    clientCode: selectedClientCode
                )
            } label: {
                HStack {
                    Label("Open Illustrated Icon Generator", systemImage: "apple.intelligence")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

            Text("The generator opens directly in \(libraryDisplayName)’s existing visual library. LifeRoute keeps the exact label separate from the artwork, shows the reference and generated result clearly, and saves only after your review.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private func visualGeneratorModeBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.black))
            .foregroundStyle(palette.accentSecondary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(palette.panelElevated.opacity(0.34), in: Capsule())
            .accessibilityLabel(title.capitalized)
    }

    private var manualWorkspaceCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Full manual visual workspace", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)

            Text("Your existing icon library, photo/text creator, choice boards, First / Then tools, and manual visual-support workspace are still here and unchanged.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            NavigationLink {
                ClientVisualSupportCenter(visualState: visualState, clientState: clientState)
            } label: {
                HStack {
                    Text("Open Manual Workspace")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(palette.textPrimary)
                .padding(13)
                .background(palette.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
        }
        .lifeRouteCard()
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return nil }
        return clientState.client(code: selectedClientCode)
    }

    private var libraryDisplayName: String {
        selectedClientCode == ClientVisualSupportCore.generalClientCode ? "General" : selectedClientCode
    }

    private var resolvedIconPrompt: String {
        let custom = iconPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = iconLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return ABAVisualSupportConceptInterpreter.describe(
            label: label,
            visualDescription: custom,
            hasReference: false
        )
    }

    private var imagePlaygroundAvailable: Bool {
        #if canImport(ImagePlayground)
        if #available(iOS 18.2, *) {
            return ImagePlaygroundViewController.isAvailable
        }
        #endif
        return false
    }

    @MainActor
    private func draftSchedule() async {
        guard !isDraftingSchedule else { return }
        isDraftingSchedule = true
        scheduleMessage = nil
        defer { isDraftingSchedule = false }

        do {
            generatedSteps = try await LifeRouteIntelligenceCore.generateVisualScheduleDraft(
                description: scheduleRequest,
                client: selectedClient
            )
            scheduleMessage = "Draft ready — review and edit every step before saving."
            LifeRouteHaptics.success()
        } catch {
            scheduleMessage = error.localizedDescription
        }
    }

    private func saveGeneratedSchedule() {
        let cleaned = generatedSteps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            let steps = cleaned.map { label in
                ClientVisualScheduleStep(label: label, iconID: matchingIconID(for: label))
            }
            _ = try visualState.saveSchedule(
                clientCode: selectedClientCode,
                title: scheduleTitle,
                steps: steps
            )
            scheduleMessage = "Visual schedule saved to \(libraryDisplayName). Matching saved icons were attached automatically when labels matched exactly."
            LifeRouteHaptics.success()
        } catch {
            scheduleMessage = error.localizedDescription
        }
    }

    private func matchingIconID(for label: String) -> UUID? {
        visualState.icons(for: selectedClientCode)
            .first { $0.label.caseInsensitiveCompare(label) == .orderedSame }?
            .id
    }

    private func moveStep(from index: Int, offset: Int) {
        let destination = index + offset
        guard generatedSteps.indices.contains(index), generatedSteps.indices.contains(destination) else { return }
        generatedSteps.swapAt(index, destination)
        LifeRouteHaptics.selection()
    }

    private func saveGeneratedIcon() {
        guard let generatedImageData else { return }
        do {
            _ = try visualState.addIcon(
                clientCode: selectedClientCode,
                label: iconLabel,
                imageData: generatedImageData
            )
            imageMessage = "Generated icon saved to \(libraryDisplayName)’s visual library."
            self.generatedImageData = nil
            iconPrompt = ""
            LifeRouteHaptics.success()
        } catch {
            imageMessage = error.localizedDescription
        }
    }

    private func captureGeneratedImage(at url: URL) {
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url)
                }.value
                guard UIImage(data: data) != nil else {
                    imageMessage = "Image Playground returned an image LifeRoute could not read."
                    return
                }
                generatedImageData = data
                imageMessage = "Image ready — review it, then save it to \(libraryDisplayName)."
                LifeRouteHaptics.success()
            } catch {
                imageMessage = "LifeRoute could not import the generated image: \(error.localizedDescription)"
            }
        }
    }

    private func validateSelectedLibrary() {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return }
        if clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = ClientVisualSupportCore.generalClientCode
        }
    }
}
