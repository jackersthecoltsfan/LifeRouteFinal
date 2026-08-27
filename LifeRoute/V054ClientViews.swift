import SwiftUI

struct V054ClientProfilesView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("CLIENT HUB", systemImage: "person.2.fill")
                        .font(.caption.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(palette.accent)
                    Text("Privacy-first client context.")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text("Save only the first two and last two initials, plus the session context LifeRoute tools need.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add client")
                                .font(.headline)
                                .foregroundStyle(palette.textPrimary)
                            Text("Create an ABA-style four-letter profile")
                                .font(.caption)
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .lifeRouteCard()

                if clientState.clients.isEmpty {
                    ContentUnavailableView(
                        "No clients yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("General session and visual tools still work without a client profile.")
                    )
                } else {
                    ForEach(clientState.clients) { profile in
                        clientCard(profile)
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clientCard(_ profile: LifeRouteClientProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.accent.opacity(0.15))
                    Text(profile.code)
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.code)
                        .font(.title3.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Label(
                        profile.address.isEmpty ? "No service address" : profile.address,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                metric(profile.currentTargets.count, "Targets")
                metric(profile.preferredActivities.count, "Preferred")
                metric(profile.behaviorsOfConcern.count, "Behaviors")
            }

            HStack(spacing: 9) {
                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: profile)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button(role: .destructive) {
                    clientState.removeClient(id: profile.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.black))
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct V054ClientEditorView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
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
            LazyVStack(spacing: 15) {
                codeCard
                locationCard
                listCard
                contextCard
                saveCard
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABA client code")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text("Use the first two and last two initials only.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: 10) {
                labeledField("FIRST 2") {
                    TextField("Ab", text: $first2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                labeledField("LAST 2") {
                    TextField("Cd", text: $last2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            HStack {
                Text("Preview")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text(codePreview)
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accentSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Service location", systemImage: "mappin.and.ellipse")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text("Start typing and tap a MapKit suggestion.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
            V054AddressField("Client address / service location", text: $address)
        }
        .lifeRouteCard()
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Session supports")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            editor("Preferred activities / reinforcers", text: $preferredActivities)
            editor("Current targets / programs", text: $currentTargets)
            editor("Behaviors of concern", text: $behaviorsOfConcern)
        }
        .lifeRouteCard()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Clinical context")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            editor("Communication / FCT notes", text: $communicationNotes, height: 80)
            editor("Prompting / reinforcement notes", text: $promptingNotes, height: 80)
            editor("Caregiver / setting notes", text: $caregiverNotes, height: 80)
            editor("Other clinical notes", text: $clinicalNotes, height: 80)
        }
        .lifeRouteCard()
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                save()
            } label: {
                Label(isSaving ? "Saving…" : "Save client", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isSaving)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var codePreview: String {
        let first = ClientProfileCore.normalizedPair(first2)
        let last = ClientProfileCore.normalizedPair(last2)
        let code = first + last
        return code.count == 4 ? code : "—"
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

    private func editor(_ title: String, text: Binding<String>, height: CGFloat = 96) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.7)
                .foregroundStyle(palette.accentSecondary)
            TextEditor(text: text)
                .frame(minHeight: height)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(palette.accentSecondary)
            content()
                .padding(12)
                .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}
