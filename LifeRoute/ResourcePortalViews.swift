import SwiftUI

struct ResourcePortalHubView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var portalState = ResourcePortalCore()

    @State private var customTitle = ""
    @State private var customURL = ""
    @State private var customCategory: LifeRoutePortalCategory = .other
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                ScenicRoyalResourceHeader(
                    builtInCount: portalState.builtInPortals.count,
                    customCount: portalState.customPortals.count
                )

                ForEach(LifeRoutePortalCategory.allCases) { category in
                    ScenicRoyalResourceCategorySection(
                        category: category,
                        portals: portalState.portals(in: category),
                        onOpen: openPortal,
                        onDelete: removePortal
                    )
                }

                ScenicRoyalCustomPortalForm(
                    title: $customTitle,
                    urlString: $customURL,
                    category: $customCategory,
                    message: message,
                    onSave: saveCustomPortal
                )

                ScenicRoyalResourcePrivacyNote()
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openPortal(_ portal: LifeRoutePortalLink) {
        guard let url = portal.url else { return }
        LifeRouteHaptics.primaryAction()
        openURL(url)
    }

    private func removePortal(_ portal: LifeRoutePortalLink) {
        guard portal.isCustom else { return }
        LifeRouteHaptics.selection()
        portalState.removeCustomPortal(id: portal.id)
    }

    private func saveCustomPortal() {
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
}
