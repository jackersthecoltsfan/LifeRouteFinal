import SwiftUI

struct ResourcePortalHubView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.openURL) private var openURL
    @StateObject private var portalState = ResourcePortalCore()

    @State private var customTitle = ""
    @State private var customURL = ""
    @State private var customCategory: LifeRoutePortalCategory = .other
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero

                ForEach(LifeRoutePortalCategory.allCases) { category in
                    portalSection(category)
                }

                customPortalCard

                Text("LifeRoute only launches these portals. Sign-in, data entry, and account information stay with the destination service.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(palette.panelGradient)

            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 180, height: 180)
                .offset(x: 190, y: -70)

            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.accent.opacity(0.15))
                    Image(systemName: "rectangle.connected.to.line.below")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 50, height: 50)

                Text("Work portals")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("One clean launchpad for ABA systems, payroll and HR, training, credentials, and company-specific portals.")
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

    private func portalSection(_ category: LifeRoutePortalCategory) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(category.rawValue, systemImage: category.systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(portalState.portals(in: category).count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.12), in: Capsule())
            }

            ForEach(portalState.portals(in: category)) { portal in
                portalRow(portal)
            }
        }
        .lifeRouteCard()
    }

    private func portalRow(_ portal: LifeRoutePortalLink) -> some View {
        Button {
            guard let url = portal.url else { return }
            LifeRouteHaptics.primaryAction()
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.accent.opacity(0.13))
                    Image(systemName: portal.systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(portal.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(portal.subtitle)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                if portal.isCustom {
                    Button(role: .destructive) {
                        LifeRouteHaptics.selection()
                        portalState.removeCustomPortal(id: portal.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(portal.title)")
                } else {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(11)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var customPortalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add company portal", systemImage: "plus.app.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            TextField("Portal name", text: $customTitle)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("Website address", text: $customURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Picker("Category", selection: $customCategory) {
                ForEach(LifeRoutePortalCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.menu)

            Button("Save portal") {
                do {
                    try portalState.addCustomPortal(
                        title: customTitle,
                        urlString: customURL,
                        category: customCategory
                    )
                    customTitle = ""
                    customURL = ""
                    message = "Custom portal saved."
                    LifeRouteHaptics.success()
                } catch {
                    message = error.localizedDescription
                }
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
}
