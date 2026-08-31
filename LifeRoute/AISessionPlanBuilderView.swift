import SwiftUI
import Foundation

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
            LazyVStack(spacing: 12) {
                hero
                contextCard
                inputsCard
                actionCard
                if !generatedPlan.isEmpty { resultCard }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Session Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedClientCode) { _ in loadClientContext() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Plan",
                subtitle: "Shape approved targets, known reinforcers, client context, and session time into a practical flow.",
                systemImage: "brain.head.profile"
            )

            Label("SUPERVISOR-APPROVED INPUTS ONLY", systemImage: "checkmark.shield.fill")
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.accentSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
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
                .frame(minHeight: 250)
                .lifeRouteReadableTextSurface()
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
                .lifeRouteReadableTextSurface()
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
