import SwiftUI

struct V054ClientProfilesView: View {
    // v0.7.0 Build E Client Hub: code-first, compact, privacy-first presentation.
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 11) {
                HStack(spacing: 12) {
                    LifeRouteIconBadge(systemImage: "person.2.fill", prominent: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clients")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text("ABA-style client codes and practical session context.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 9) {
                    Label("\(clientState.clients.count) SAVED", systemImage: "person.crop.circle.fill")
                    Label("LOCAL-FIRST", systemImage: "lock.fill")
                }
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.accentSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: nil)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(width: 34, height: 34)
                            .background(palette.accentGradient, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Client")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("First two + last two initials only")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 56)
                    .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                LifeRouteSectionLabel(title: "Client Context")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                if clientState.clients.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                        Text("No client profiles yet")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Text("General session and visual tools still work without a client profile.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(palette.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                } else {
                    ForEach(clientState.clients) { profile in
                        clientCard(profile)
                    }
                }

                Text("Store only the minimum client context needed for LifeRoute workflows. Avoid full names or unnecessary identifying information.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clientCard(_ profile: LifeRouteClientProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Text(profile.code)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accentSecondary)
                    .frame(width: 64, height: 46)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.code)
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Label(profile.address.isEmpty ? "No service address" : profile.address, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: profile)
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
                .accessibilityLabel("Edit \(profile.code)")
            }

            HStack(spacing: 6) {
                metric(profile.currentTargets.count, "Targets")
                metric(profile.preferredActivities.count, "Preferred")
                metric(profile.behaviorsOfConcern.count, "Behaviors")
            }

            HStack {
                Text("CLIENT CONTEXT")
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Button(role: .destructive) {
                    clientState.removeClient(id: profile.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption.weight(.bold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.caption.weight(.black))
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
            LazyVStack(spacing: 12) {
                codeCard
                locationCard
                listCard
                contextCard
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 92)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                Button {
                    save()
                } label: {
                    Label(isSaving ? "Saving…" : "Save Client", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
                .disabled(isSaving)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(palette.panel.opacity(0.94))
        }
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ABA CLIENT CODE")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(palette.accentSecondary)
                    Text("Use first two + last two initials only.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Text(codePreview)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accentSecondary)
                    .frame(minWidth: 58, minHeight: 40)
            }

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
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.16), lineWidth: 1)
        }
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
