import SwiftUI

struct V054ClientProfilesView: View {
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ScenicRoyalClientHeader(clientCount: clientState.clients.count)

                ScenicRoyalClientAddRow {
                    V054ClientEditorView(clientState: clientState, profile: nil)
                }

                ScenicRoyalSectionHeader(
                    "Client Context",
                    subtitle: "Private, reusable context for session and visual-support workflows.",
                    systemImage: "person.text.rectangle"
                )
                .padding(.top, ScenicRoyalDesignSystem.Spacing.hairline)

                if clientState.clients.isEmpty {
                    ScenicRoyalClientEmptyState()
                } else {
                    ForEach(clientState.clients) { profile in
                        ScenicRoyalClientSummaryCard(
                            profile: profile,
                            destination: {
                                V054ClientEditorView(clientState: clientState, profile: profile)
                            },
                            onRemove: {
                                clientState.removeClient(id: profile.id)
                            }
                        )
                    }
                }

                ScenicRoyalClientPrivacyNote()
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious)
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct V054ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var style

    @ObservedObject var clientState: ClientProfileCore

    private let profileID: UUID?

    @State private var first2: String
    @State private var last2: String
    @State private var address: String
    @State private var preferredActivities: String
    @State private var currentTargets: String
    @State private var behaviorsOfConcern: String
    @State private var communicationNotes: String
    @State private var promptingNotes: String
    @State private var caregiverNotes: String
    @State private var clinicalNotes: String
    @State private var message: String?
    @State private var isSaving = false

    init(clientState: ClientProfileCore, profile: LifeRouteClientProfile?) {
        self.clientState = clientState
        self.profileID = profile?.id
        _first2 = State(initialValue: profile?.first2 ?? "")
        _last2 = State(initialValue: profile?.last2 ?? "")
        _address = State(initialValue: profile?.address ?? "")
        _preferredActivities = State(initialValue: profile?.preferredActivities.joined(separator: "\n") ?? "")
        _currentTargets = State(initialValue: profile?.currentTargets.joined(separator: "\n") ?? "")
        _behaviorsOfConcern = State(initialValue: profile?.behaviorsOfConcern.joined(separator: "\n") ?? "")
        _communicationNotes = State(initialValue: profile?.communicationNotes ?? "")
        _promptingNotes = State(initialValue: profile?.promptingNotes ?? "")
        _caregiverNotes = State(initialValue: profile?.caregiverNotes ?? "")
        _clinicalNotes = State(initialValue: profile?.clinicalNotes ?? "")
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                codeCard
                locationCard
                sessionSupportsCard
                clinicalContextCard
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, 104)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ScenicRoyalClientSaveBar(
                isSaving: isSaving,
                message: message,
                action: save
            )
        }
    }

    private var codePreview: String {
        let first = ClientProfileCore.normalizedPair(first2)
        let last = ClientProfileCore.normalizedPair(last2)
        let code = first + last
        return code.count == 4 ? code : "—"
    }

    private var codeCard: some View {
        ScenicRoyalLabeledCard(
            title: "ABA client code",
            subtitle: "Use first two + last two initials only.",
            systemImage: "person.text.rectangle"
        ) {
            HStack(alignment: .center, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Text("Code preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.secondaryText)

                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)

                Text(codePreview)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(style.accent)
                    .frame(minWidth: 64, minHeight: 44)
                    .scenicRoyalSurface(
                        role: .selectedControl,
                        cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                    )
                    .accessibilityLabel("Client code preview")
                    .accessibilityValue(codePreview == "—" ? "Incomplete" : codePreview)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        codeField(title: "First two initials", placeholder: "Ab", text: $first2)
                        codeField(title: "Last two initials", placeholder: "Cd", text: $last2)
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        codeField(title: "First two initials", placeholder: "Ab", text: $first2)
                        codeField(title: "Last two initials", placeholder: "Cd", text: $last2)
                    }
                }
            }
        }
    }

    private var locationCard: some View {
        ScenicRoyalLabeledCard(
            title: "Service location",
            subtitle: "Start typing and choose a MapKit suggestion, or keep a manual address.",
            systemImage: "mappin.and.ellipse"
        ) {
            V054AddressField("Client address / service location", text: $address)
        }
    }

    private var sessionSupportsCard: some View {
        ScenicRoyalLabeledCard(
            title: "Session supports",
            subtitle: "One item per line, comma, or semicolon.",
            systemImage: "list.bullet.rectangle"
        ) {
            ScenicRoyalClientTextEditor(title: "Preferred activities / reinforcers", text: $preferredActivities, minimumHeight: 96)
            ScenicRoyalClientTextEditor(title: "Current targets / programs", text: $currentTargets, minimumHeight: 96)
            ScenicRoyalClientTextEditor(title: "Behaviors of concern", text: $behaviorsOfConcern, minimumHeight: 96)
        }
    }

    private var clinicalContextCard: some View {
        ScenicRoyalLabeledCard(
            title: "Clinical context",
            subtitle: "Keep only concise context needed during sessions.",
            systemImage: "note.text"
        ) {
            ScenicRoyalClientTextEditor(title: "Communication / FCT notes", text: $communicationNotes, minimumHeight: 80)
            ScenicRoyalClientTextEditor(title: "Prompting / reinforcement notes", text: $promptingNotes, minimumHeight: 80)
            ScenicRoyalClientTextEditor(title: "Caregiver / setting notes", text: $caregiverNotes, minimumHeight: 80)
            ScenicRoyalClientTextEditor(title: "Other clinical notes", text: $clinicalNotes, minimumHeight: 80)
        }
    }

    private func codeField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.accentReflection)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .scenicRoyalField()
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try clientState.saveProfile(
                id: profileID,
                first2: first2,
                last2: last2,
                address: address,
                preferredActivities: preferredActivities,
                currentTargets: currentTargets,
                behaviorsOfConcern: behaviorsOfConcern,
                communicationNotes: communicationNotes,
                promptingNotes: promptingNotes,
                caregiverNotes: caregiverNotes,
                clinicalNotes: clinicalNotes
            )
            LifeRouteHaptics.success()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
