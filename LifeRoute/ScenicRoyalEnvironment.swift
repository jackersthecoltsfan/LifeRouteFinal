import SwiftUI

/// A single root-level host keeps the selected LifeRoute environment mounted while the
/// five independent NavigationStacks swipe and navigate above it.
struct ScenicRoyalEnvironmentHost<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let reduceMotionOverride: Bool
    private let content: Content

    init(
        theme: LifeRouteTheme,
        palette: LifeRouteThemePalette,
        reduceMotionOverride: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.palette = palette
        self.reduceMotionOverride = reduceMotionOverride
        self.content = content()
    }

    var body: some View {
        let style = theme.scenicRoyalStyle
        let motionIsReduced = reduceMotion || reduceMotionOverride

        ZStack {
            environmentBackdrop(reduceMotion: motionIsReduced)

            ScenicRoyalEnvironmentReadabilityVeil(
                style: style,
                reduceTransparency: reduceTransparency
            )

            content
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .environment(\.scenicRoyalThemeStyle, style)
        .animation(
            motionIsReduced ? nil : ScenicRoyalDesignSystem.Motion.environmentChange,
            value: theme
        )
        .environment(\.defaultMinListRowHeight, 52)
        .tint(palette.accent)
        .preferredColorScheme(theme == .light ? .light : .dark)
    }

    @ViewBuilder
    private func environmentBackdrop(reduceMotion: Bool) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        } else if theme.isPhaseTwoDynamic || theme.isPhaseThreeScenery {
            LifeRouteLiveThemeEnvironment(
                theme: theme,
                palette: palette,
                reduceMotion: reduceMotion,
                isActive: scenePhase == .active
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        } else {
            LifeRouteCinematicBackdrop(theme: theme, palette: palette)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct ScenicRoyalEnvironmentReadabilityVeil: View {
    let style: ScenicRoyalThemeStyle
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(topOpacity),
                    Color.clear,
                    Color.black.opacity(bottomOpacity),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    style.glassTint.opacity(reduceTransparency ? 0 : 0.055),
                    Color.clear,
                    style.accentReflection.opacity(reduceTransparency ? 0 : 0.025),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topOpacity: Double {
        min(0.28, style.environmentScrimOpacity + (reduceTransparency ? 0.06 : 0))
    }

    private var bottomOpacity: Double {
        min(0.34, style.environmentScrimOpacity + 0.07 + (reduceTransparency ? 0.06 : 0))
    }
}
