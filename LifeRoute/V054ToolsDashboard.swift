import SwiftUI
import Foundation
import UIKit

#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct V054ToolsDashboard: View {
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
                hero

                LazyVGrid(columns: columns, spacing: 10) {
                    NavigationLink {
                        VisualTimerView(timer: toolsState.timer)
                    } label: {
                        toolCard("Visual Timer", "Reliable session timing", "timer", palette.accent)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    NavigationLink {
                        ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                    } label: {
                        toolCard("First / Then", "Build a clear visual sequence", "arrow.right.circle.fill", palette.accentSecondary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    NavigationLink {
                        VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)
                    } label: {
                        toolCard("Visual Supports", "AI + manual icons and schedules", "photo.on.rectangle.angled", palette.accent)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    NavigationLink {
                        QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                    } label: {
                        toolCard("Quick Notes", "Capture scratch notes fast", "note.text", palette.accentSecondary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    NavigationLink {
                        AISessionPlanBuilderView(clientState: clientState)
                    } label: {
                        toolCard("AI Session Plan", "Build a real session flow", "brain.head.profile.fill", palette.accentSecondary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    NavigationLink {
                        AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)
                    } label: {
                        toolCard("AI Session Note", "Draft from supplied facts", "sparkles.rectangle.stack.fill", palette.accent)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                }

                clientContextCard

                Text("AI features use Apple’s on-device Foundation Model when Apple Intelligence is available. Clinical drafts still require review before use.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { visualState.retainClients(clientState.clients) }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(palette.panelGradient)

            LinearGradient(
                colors: [palette.accent.opacity(0.20), .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 130, weight: .black))
                .foregroundStyle(palette.accent.opacity(0.055))
                .offset(x: 190, y: 48)

            VStack(alignment: .leading, spacing: 9) {
                Text("SESSION TOOLS")
                    .font(.caption.weight(.black))
                    .tracking(2)
                    .foregroundStyle(palette.accent)
                Text("Your session command center.")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Visual supports, quick capture, smarter planning, and documentation assistance in one place.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(21)
        }
        .frame(minHeight: 205)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func toolCard(_ title: String, _ subtitle: String, _ systemImage: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            Spacer(minLength: 0)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.07), radius: 14, y: 7)
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
                Text(clientState.clients.isEmpty ? "General tools ready · no client required" : "\(clientState.clients.count) client profiles + General mode")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Button("Manage") {
                LifeRouteHaptics.selection()
                router.select(.setup)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accent)
        }
        .lifeRouteCard()
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
            LazyVStack(spacing: 16) {
                hero
                libraryCard
                scheduleAICard
                iconAICard
                manualWorkspaceCard
            }
            .padding(18)
            .padding(.bottom, 28)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(palette.panelGradient)
            Circle()
                .fill(palette.accent.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: 205, y: -70)

            VStack(alignment: .leading, spacing: 9) {
                Label("AI + MANUAL", systemImage: "apple.intelligence")
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(palette.accent)
                Text("Visual Support Studio")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Draft visual schedules with on-device AI, create icon artwork with Image Playground, or open the full manual visual workspace anytime.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(21)
        }
        .frame(minHeight: 205)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.27), lineWidth: 1)
        }
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

    private var iconAICard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Icon Creator")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Create clear visual artwork, then save it into the existing icon library.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
            }

            TextField("Icon label · e.g. Brush Teeth", text: $iconLabel)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("Optional image description", text: $iconPrompt, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let generatedImageData, let image = UIImage(data: generatedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.accent.opacity(0.25), lineWidth: 1)
                    }
            }

            Button {
                imageMessage = nil
                showImagePlayground = true
                LifeRouteHaptics.selection()
            } label: {
                Label(generatedImageData == nil ? "Create with Image Playground" : "Create another image", systemImage: "apple.intelligence")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(iconLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !imagePlaygroundAvailable)

            if generatedImageData != nil {
                Button("Save generated icon to \(libraryDisplayName)") {
                    saveGeneratedIcon()
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            if let imageMessage {
                Label(imageMessage, systemImage: generatedImageData == nil ? "info.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            if !imagePlaygroundAvailable {
                Text("Image Playground is not available on this device right now. The original photo and text icon creator remains available in the manual workspace below.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text("Image generation stays inside Apple’s Image Playground experience. You approve the image before LifeRoute receives it.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var manualWorkspaceCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Full manual visual workspace", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)

            Text("Your existing icon library, photo/text creator, choice boards, First / Then tools, and manual visual-schedule builder are still here and unchanged.")
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
        if !custom.isEmpty { return custom }
        let label = iconLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return "A clear, friendly visual support icon showing \(label). Simple centered subject, uncluttered background, easy to understand at a glance."
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
