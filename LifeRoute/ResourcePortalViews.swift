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
            LazyVStack(spacing: 12) {
                hero

                ForEach(LifeRoutePortalCategory.allCases) { category in
                    portalSection(category)
                }

                customPortalCard

                Label(
                    "LifeRoute launches third-party portals only. Credentials, sign-in, and data entered there remain with the destination service.",
                    systemImage: "lock.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        // v0.7.0 Build E Resources: compact premium launchpad; ResourcePortalCore remains the owner.
        HStack(spacing: 12) {
            LifeRouteIconBadge(systemImage: "rectangle.connected.to.line.below", prominent: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Resources")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Clinical, work, training, and company portals.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(portalState.builtInPortals.count)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                Text(portalState.customPortals.isEmpty ? "BUILT-IN" : "+ \(portalState.customPortals.count) CUSTOM")
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(13)
        .background(palette.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func portalSection(_ category: LifeRoutePortalCategory) -> some View {
        let portals = portalState.portals(in: category)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)
                Text(category.rawValue.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text("\(portals.count)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(palette.accentSecondary)
            }
            .frame(minHeight: 30)

            VStack(spacing: 6) {
                ForEach(portals) { portal in
                    portalRow(portal)
                }
            }
        }
    }

    private func portalRow(_ portal: LifeRoutePortalLink) -> some View {
        HStack(spacing: 8) {
            Button {
                guard let url = portal.url else { return }
                LifeRouteHaptics.primaryAction()
                openURL(url)
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(palette.accent.opacity(0.12))
                        Image(systemName: portal.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(portal.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                            if portal.isCustom {
                                Text("CUSTOM")
                                    .font(.system(size: 8, weight: .black))
                                    .tracking(0.5)
                                    .foregroundStyle(palette.accentSecondary)
                            }
                        }
                        Text(portal.subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 52)

            if portal.isCustom {
                Button(role: .destructive) {
                    LifeRouteHaptics.selection()
                    portalState.removeCustomPortal(id: portal.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(portal.title)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var customPortalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add Company Portal", systemImage: "plus.app.fill")
                .font(.headline.weight(.bold))
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
