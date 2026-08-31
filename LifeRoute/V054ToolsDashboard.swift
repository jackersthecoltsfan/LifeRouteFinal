import SwiftUI
import Foundation

struct V054ToolsDashboard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle

    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore

    @StateObject private var visualState = ClientVisualSupportCore()

    private var toolColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard)]
        }
        return [
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                ScenicRoyalScreenHeader(
                    title: "Tools",
                    subtitle: "Practical support for clearer, calmer sessions."
                ) {
                    ScenicRoyalIconBadge(systemImage: "wrench.and.screwdriver")
                }

                readinessCard

                ScenicRoyalSectionHeader(
                    "Session toolkit",
                    subtitle: "Choose a focused tool and keep your current client context.",
                    systemImage: "square.grid.2x2"
                )

                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    LazyVGrid(columns: toolColumns, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        NavigationLink {
                            VisualTimerView(timer: toolsState.timer)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Visual Timer",
                                subtitle: "A calm countdown with visual, tone, and haptic choices.",
                                systemImage: "timer"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "First / Then",
                                subtitle: "Build a clear two-step visual sequence.",
                                systemImage: "arrow.right.square"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Visual Supports",
                                subtitle: "Create and reuse icons, boards, and ABA visuals.",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Quick Notes",
                                subtitle: "Capture useful session details with minimal friction.",
                                systemImage: "note.text"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            AISessionPlanBuilderView(clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "AI Session Plan",
                                subtitle: "Organize approved targets and reinforcers into a flow.",
                                systemImage: "brain.head.profile"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "AI Session Note",
                                subtitle: "Create an evidence-bound draft for review and editing.",
                                systemImage: "doc.text.magnifyingglass"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                clientContextCard

                Label(
                    "AI drafts use Apple’s on-device model when available. Review every clinical output before use.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(scenicStyle.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.hairline)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
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

    private var readinessCard: some View {
        ScenicRoyalInsetRow(role: .readability) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        readinessStatus
                        manageClientsButton
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        readinessStatus
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.hairline)
                        manageClientsButton
                    }
                }
            }
        }
    }

    private var readinessStatus: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Image(systemName: clientState.clients.isEmpty ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(scenicStyle.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(clientState.clients.isEmpty ? "General mode ready" : "Client context ready")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scenicStyle.primaryText)
                Text(clientState.clients.isEmpty ? "No client profile required for core tools." : "\(clientState.clients.count) saved client profile\(clientState.clients.count == 1 ? "" : "s") available.")
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var manageClientsButton: some View {
        Button("Manage clients") {
            LifeRouteHaptics.selection()
            router.select(.setup)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(scenicStyle.accent)
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
            alignment: .leading
        )
        .accessibilityHint("Opens Setup to manage client profiles")
    }

    private var clientContextCard: some View {
        ScenicRoyalCard(role: .card) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: "person.2")
                    .foregroundStyle(scenicStyle.accent)
                    .frame(width: 34, height: 34)
                    .scenicRoyalSurface(role: .ambient, cornerRadius: 17)
                    .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Client context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scenicStyle.primaryText)
                Text(clientState.clients.isEmpty ? "General tools only" : "General + saved ABA client codes")
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
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

    var body: some View {
        studioContent
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
                scheduleMessage = nil
            }
    }

    private var studioContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero
                libraryCard
                iconAICard
                builderAccessCard
                manualWorkspaceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
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

    // v0.8.2 physical-QA correction: keep the useful generator controls on this screen.
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

            ClientVisualIconLibraryView(
                visualState: visualState,
                clientCode: selectedClientCode,
                embedded: true
            )
            .id(selectedClientCode)
        }
        .lifeRouteCard()
    }

    private var builderAccessCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Build with saved visuals")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)

            NavigationLink {
                ClientChoiceBoardBuilderView(
                    visualState: visualState,
                    clientCode: selectedClientCode
                )
            } label: {
                visualBuilderLinkLabel("Choice Boards", systemImage: "square.grid.2x2.fill")
            }
            .buttonStyle(.plain)

            NavigationLink {
                ClientFirstThenVisualView(
                    visualState: visualState,
                    clientState: clientState,
                    initialClientCode: selectedClientCode
                )
            } label: {
                visualBuilderLinkLabel("First / Then", systemImage: "arrow.right.square.fill")
            }
            .buttonStyle(.plain)
        }
        .lifeRouteCard()
    }

    private func visualBuilderLinkLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(11)
        .frame(minHeight: 54)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
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

    private func validateSelectedLibrary() {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return }
        if clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = ClientVisualSupportCore.generalClientCode
        }
    }
}
