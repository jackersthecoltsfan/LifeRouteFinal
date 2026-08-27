import SwiftUI

struct ClientProfilesView: View {
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        List {
            Section {
                Text("Use a four-letter ABA-style code: first two letters of the first name + first two letters of the last name. Full names are not required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    ClientEditorView(clientState: clientState, profile: nil)
                } label: {
                    Label("Add client", systemImage: "person.badge.plus")
                }
            }

            Section("Saved clients") {
                if clientState.clients.isEmpty {
                    Text("No client profiles yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(clientState.clients) { profile in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(profile.code)
                                .font(.headline)
                            Text(profile.address.isEmpty ? "No service location" : profile.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(profile.currentTargets.count) targets · \(profile.preferredActivities.count) preferred activities · \(profile.behaviorsOfConcern.count) behaviors of concern")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                NavigationLink("Edit") {
                                    ClientEditorView(clientState: clientState, profile: profile)
                                }
                                Button("Remove", role: .destructive) {
                                    clientState.removeClient(id: profile.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Text("Client profiles are saved locally in protected LifeRoute app data on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Clients")
    }
}

struct ClientEditorView: View {
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
            Section("ABA client code") {
                TextField("First 2 initials", text: $first2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Last 2 initials", text: $last2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Preview: \(codePreview)")
                    .foregroundStyle(.secondary)
            }

            Section("Service location") {
                TextField("Client address / service location", text: $address)
                    .textContentType(.fullStreetAddress)
            }

            Section("Session supports") {
                Text("Preferred activities / reinforcers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $preferredActivities)
                    .frame(minHeight: 80)

                Text("Current targets / programs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $currentTargets)
                    .frame(minHeight: 80)

                Text("Behaviors of concern")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $behaviorsOfConcern)
                    .frame(minHeight: 80)
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
                Button(profileID == nil ? "Save client" : "Save changes") {
                    save()
                }
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
