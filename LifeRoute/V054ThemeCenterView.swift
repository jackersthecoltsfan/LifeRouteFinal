import SwiftUI

struct V054ThemeCenterView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ScenicRoyalThemeCategory = .core
    /// Sol/Terra can observe Theme Center visibility without a second global
    /// coordinator. `true` is emitted when the catalog becomes visible and
    /// `false` when navigation removes it, including back-navigation.
    private let onVisibilityChanged: ((Bool) -> Void)?

    init(onVisibilityChanged: ((Bool) -> Void)? = nil) {
        self.onVisibilityChanged = onVisibilityChanged
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ScenicRoyalSelectedThemeHeader(
                    theme: themeStore.selectedTheme,
                    category: category(for: themeStore.selectedTheme)
                )

                ScenicRoyalThemeCategoryPicker(
                    selection: $selectedCategory,
                    onSelection: LifeRouteHaptics.selection
                )

                ScenicRoyalThemeSectionHeading(
                    category: selectedCategory,
                    count: filteredThemes.count
                )

                LazyVGrid(columns: gridColumns, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    ForEach(filteredThemes) { theme in
                        ScenicRoyalThemeCard(
                            theme: theme,
                            category: selectedCategory,
                            isSelected: themeStore.selectedTheme == theme,
                            action: {
                                select(theme)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCategory = category(for: themeStore.selectedTheme)
            onVisibilityChanged?(true)
        }
        .onDisappear {
            onVisibilityChanged?(false)
        }
        // Keep the iOS 16 deployment path; this single-value overload is
        // availability-safe until the app's minimum OS moves to iOS 17.
        .onChange(of: themeStore.selectedTheme) { theme in
            selectedCategory = category(for: theme)
        }
    }

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
        ]
    }

    private var filteredThemes: [LifeRouteTheme] {
        switch selectedCategory {
        case .core:
            return LifeRouteTheme.phaseOneCoreGlassCatalog
        case .dynamic:
            return LifeRouteTheme.v071RetainedDynamicCatalog
        case .scenery:
            return LifeRouteTheme.v071RetainedSceneryCatalog
        }
    }

    private func category(for theme: LifeRouteTheme) -> ScenicRoyalThemeCategory {
        if theme.isPhaseOneCoreGlass { return .core }
        if theme.isPhaseTwoDynamic { return .dynamic }
        if theme.isPhaseThreeScenery { return .scenery }
        return .core
    }

    private func select(_ theme: LifeRouteTheme) {
        themeStore.selectedTheme = theme
        LifeRouteHaptics.success()
    }
}
