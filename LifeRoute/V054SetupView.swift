import SwiftUI

struct V054SetupView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var clientState: ClientProfileCore

    @State private var homeDraft = ""
    @State private var placeName = ""
    @State private var placeAddress = ""
    @State private var placeKind: LifeRoutePlaceKind = .other
    @State private var minimumVisitMinutes = 30
    @State private var gapSuggestion = true
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                themeCard
                clientCard
                homeCard
                savedPlacesCard
                addPlaceCard
                privacyCard
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if homeDraft.isEmpty { homeDraft = routingState.homeAddress }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.selectedTheme.palette
            )
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("SETUP")
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.70))
                Spacer(minLength: 92)
                Text("Make LifeRoute yours.")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Appearance, clients, home base, and the places that shape your workday.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(19)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.34), lineWidth: 1)
        }
    }

    private var themeCard: some View {
        NavigationLink {
            V054ThemeCenterView()
        } label: {
            HStack(spacing: 12) {
                LifeRouteCinematicThemeThumbnail(theme: themeStore.selectedTheme)
                    .frame(width: 102, height: 82)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Themes")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(themeStore.selectedTheme.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.accentSecondary)
                    Text("Cinematic scenery + premium materials")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .lifeRouteCard()
    }

    private var clientCard: some View {
        NavigationLink {
            V054ClientProfilesView(clientState: clientState)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accent.opacity(0.14))
                    Image(systemName: "person.2.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Clients")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(clientState.clients.isEmpty ? "No client profiles yet" : "\(clientState.clients.count) saved client profiles")
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
    }

    private var homeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Home base", systemImage: "house.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text("Home is the routing fallback when live current location is unavailable, and it powers Return Home planning.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            V054AddressField("Home address", text: $homeDraft)

            Button {
                do {
                    try routingState.setHomeAddress(homeDraft)
                    message = "Home address saved."
                    LifeRouteHaptics.success()
                } catch {
                    message = error.localizedDescription
                }
            } label: {
                Label("Save home address", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var savedPlacesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Saved places", systemImage: "bookmark.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(routingState.savedPlaces.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            if routingState.savedPlaces.isEmpty {
                Text("Save gyms, stores, parks, work locations, errands, and other useful stops below.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            } else {
                ForEach(routingState.savedPlaces) { place in
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.13))
                            Image(systemName: icon(for: place.kind))
                                .foregroundStyle(palette.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text(place.address)
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(2)
                            if place.useInGapSuggestions {
                                Label("Gap suggestion", systemImage: "sparkles")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(palette.accentSecondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            routingState.removeSavedPlace(id: place.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(place.name)")
                    }
                    .padding(10)
                    .background(palette.panelElevated.opacity(0.27), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .lifeRouteCard()
    }

    private var addPlaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add place", systemImage: "mappin.and.ellipse")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            TextField("Place name", text: $placeName)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            V054AddressField("Address or place", text: $placeAddress)

            Picker("Type", selection: $placeKind) {
                ForEach(LifeRoutePlaceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Stepper("Useful visit: \(minimumVisitMinutes) min", value: $minimumVisitMinutes, in: 5...240, step: 5)
                .font(.subheadline.weight(.semibold))

            Toggle("Use in gap suggestions", isOn: $gapSuggestion)
                .font(.subheadline.weight(.semibold))

            Button {
                addPlace()
            } label: {
                Label("Save place", systemImage: "plus.circle.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
        }
        .lifeRouteCard()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Local-first setup", systemImage: "lock.shield.fill")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("Home, saved places, client profiles, and visual supports are stored locally in protected LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private func addPlace() {
        do {
            try routingState.addSavedPlace(
                name: placeName,
                address: placeAddress,
                kind: placeKind,
                minimumVisitMinutes: minimumVisitMinutes,
                useInGapSuggestions: gapSuggestion
            )
            placeName = ""
            placeAddress = ""
            placeKind = .other
            minimumVisitMinutes = 30
            gapSuggestion = true
            message = "Saved place added."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func icon(for kind: LifeRoutePlaceKind) -> String {
        switch kind {
        case .gym: return "figure.strengthtraining.traditional"
        case .work: return "briefcase.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        case .park: return "leaf.fill"
        case .library: return "books.vertical.fill"
        case .errand: return "checklist"
        case .other: return "mappin.circle.fill"
        }
    }
}
