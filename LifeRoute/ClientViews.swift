import SwiftUI

struct ClientProfilesView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                clientHero
                addClientCard

                if clientState.clients.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved clients")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(clientState.clients) { profile in
                            clientCard(profile)
                        }
                    }
                }

                Text("Client profiles are saved locally in protected LifeRoute app data on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .padding(18)
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var clientHero: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.accent.opacity(0.15))
                Image(systemName: "person.2.crop.square.stack.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text("Client hub")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Keep the session context you actually need, without putting full client names into LifeRoute.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Text("Full names are not required.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentSecondary)
            }

            Spacer(minLength: 0)
        }
        .lifeRouteCard()
    }

    private var addClientCard: some View {
        NavigationLink {
            ClientEditorView(clientState: clientState, profile: nil)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.16))
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add client")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("Create a four-letter ABA-style profile")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
            }
        }
        .buttonStyle(.plain)
        .lifeRouteCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("No client profiles yet")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("Add a client to unlock client-specific session tools and visual-support libraries.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .lifeRouteCard()
    }

    private func clientCard(_ profile: LifeRouteClientProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.26), palette.accentSecondary.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(profile.code)
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.code)
                        .font(.title3.weight(.black))
                        .foregroundStyle(palette.textPrimary)

                    Label(
                        profile.address.isEmpty ? "No service location" : profile.address,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                ClientMetricChip(value: profile.currentTargets.count, label: "Targets")
                ClientMetricChip(value: profile.preferredActivities.count, label: "Preferred")
                ClientMetricChip(value: profile.behaviorsOfConcern.count, label: "Behaviors")
            }

            HStack(spacing: 9) {
                NavigationLink {
                    ClientEditorView(clientState: clientState, profile: profile)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button("Remove", role: .destructive) {
                    clientState.removeClient(id: profile.id)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.red.opacity(0.09), in: RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous))
            }
        }
        .lifeRouteCard()
    }
}

private struct ClientMetricChip: View {
    @Environment(\.lifeRoutePalette) private var palette
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.subheadline.weight(.black))
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(palette.panelElevated.opacity(0.50), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
    }
}

struct ClientEditorView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore
    let profileID: UUID?

    @Environment(\.dismiss) private var dismiss
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
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.accent.opacity(0.16))
                        Text(codePreview == "—" ? "••••" : codePreview)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(palette.accentSecondary)
                    }
                    .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileID == nil ? "New client profile" : "Edit \(codePreview)")
                            .font(.title3.weight(.bold))
                        Text("Privacy-first ABA context for sessions and visual tools.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }

            Section("ABA client code") {
                TextField("First 2 initials", text: $first2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Last 2 initials", text: $last2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("Preview", value: codePreview)
            }

            Section("Service location") {
                TextField("Client address / service location", text: $address)
                    .textContentType(.fullStreetAddress)
            }

            Section("Session supports") {
                EditorFieldHeader(title: "Preferred activities / reinforcers", systemImage: "star.fill")
                TextEditor(text: $preferredActivities)
                    .frame(minHeight: 92)

                EditorFieldHeader(title: "Current targets / programs", systemImage: "target")
                TextEditor(text: $currentTargets)
                    .frame(minHeight: 92)

                EditorFieldHeader(title: "Behaviors of concern", systemImage: "exclamationmark.triangle.fill")
                TextEditor(text: $behaviorsOfConcern)
                    .frame(minHeight: 92)
            }

            Section("Clinical context") {
                TextField("Communication / FCT notes", text: $communicationNotes, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Prompting / reinforcement notes", text: $promptingNotes, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Caregiver / setting notes", text: $caregiverNotes, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Other clinical notes", text: $clinicalNotes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                Button {
                    save()
                } label: {
                    Label(profileID == nil ? "Save client" : "Save changes", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())

                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var codePreview: String {
        let code = ClientProfileCore.normalizedPair(first2) + ClientProfileCore.normalizedPair(last2)
        return code.count == 4 ? code : "—"
    }

    private func save() {
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
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct EditorFieldHeader: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accentSecondary)
    }
}
