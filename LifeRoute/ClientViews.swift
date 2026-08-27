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
            Text("Add a client for client-specific context, or keep using General session and visual tools without one.")
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
            LazyVStack(spacing: 16) {
                editorHero
                clientCodeCard
                serviceLocationCard
                sessionSupportsCard
                clinicalContextCard
                saveCard

                Text("Client profiles stay in protected local LifeRoute app data on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var editorHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.panelElevated.opacity(0.96), palette.panel.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 180, height: 180)
                .offset(x: 190, y: -70)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 118, weight: .black))
                .foregroundStyle(palette.accentSecondary.opacity(0.055))
                .offset(x: 190, y: 54)

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(palette.accent.opacity(0.16))
                    Text(codePreview == "—" ? "••••" : codePreview)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text(profileID == nil ? "New client profile" : "Edit \(codePreview)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text("Privacy-first ABA context for sessions and visual tools.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(minHeight: 170)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.26), lineWidth: 1)
        }
    }

    private var clientCodeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(
                title: "ABA client code",
                subtitle: "Use only the first two and last two initials.",
                systemImage: "person.text.rectangle.fill"
            )

            HStack(spacing: 10) {
                editorField(title: "FIRST 2") {
                    TextField("Ab", text: $first2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3.weight(.bold))
                }

                editorField(title: "LAST 2") {
                    TextField("Cd", text: $last2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3.weight(.bold))
                }
            }

            HStack {
                Text("PREVIEW")
                    .font(.caption2.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text(codePreview)
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accentSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(palette.accentSecondary.opacity(0.10), in: Capsule())
            }
        }
        .lifeRouteCard()
    }

    private var serviceLocationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Service location",
                subtitle: "Optional location context for your workday.",
                systemImage: "mappin.and.ellipse"
            )

            TextField("Client address / service location", text: $address)
                .textContentType(.fullStreetAddress)
                .padding(12)
                .background(fieldBackground)
        }
        .lifeRouteCard()
    }

    private var sessionSupportsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Session supports",
                subtitle: "One item per line works well for lists.",
                systemImage: "square.grid.2x2.fill"
            )

            editorArea(title: "Preferred activities / reinforcers", systemImage: "star.fill") {
                TextEditor(text: $preferredActivities)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(palette.textPrimary)
            }

            editorArea(title: "Current targets / programs", systemImage: "target") {
                TextEditor(text: $currentTargets)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(palette.textPrimary)
            }

            editorArea(title: "Behaviors of concern", systemImage: "exclamationmark.triangle.fill") {
                TextEditor(text: $behaviorsOfConcern)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .lifeRouteCard()
    }

    private var clinicalContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Clinical context",
                subtitle: "Keep concise working context available to session tools.",
                systemImage: "cross.case.fill"
            )

            clinicalField("Communication / FCT notes", text: $communicationNotes, systemImage: "bubble.left.and.bubble.right.fill")
            clinicalField("Prompting / reinforcement notes", text: $promptingNotes, systemImage: "hand.point.up.left.fill")
            clinicalField("Caregiver / setting notes", text: $caregiverNotes, systemImage: "house.and.flag.fill")
            clinicalField("Other clinical notes", text: $clinicalNotes, systemImage: "note.text")
        }
        .lifeRouteCard()
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button {
                save()
            } label: {
                Label(
                    isSaving ? "Saving…" : (profileID == nil ? "Save client" : "Save changes"),
                    systemImage: isSaving ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill"
                )
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isSaving)

            if let message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private func sectionHeader(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.accent.opacity(0.13))
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(palette.textSecondary)
            content()
                .foregroundStyle(palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(fieldBackground)
    }

    private func editorArea<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldHeader(title: title, systemImage: systemImage)
            content()
        }
        .padding(12)
        .background(fieldBackground)
    }

    private func clinicalField(_ title: String, text: Binding<String>, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accentSecondary)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...5)
                .foregroundStyle(palette.textPrimary)
        }
        .padding(12)
        .background(fieldBackground)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(palette.panelElevated.opacity(0.36))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            }
    }

    private var codePreview: String {
        let code = ClientProfileCore.normalizedPair(first2) + ClientProfileCore.normalizedPair(last2)
        return code.count == 4 ? code : "—"
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        message = nil
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
