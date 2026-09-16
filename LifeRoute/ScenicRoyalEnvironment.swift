import SwiftUI

/// A single root-level host keeps the selected LifeRoute environment mounted while the
/// five independent NavigationStacks swipe and navigate above it.
struct ScenicRoyalEnvironmentHost<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var visualActivityCoordinator: LifeRouteVisualActivityCoordinator

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

        // Foreground content owns the root proposal and system safe area.
        // A backdrop (including an aspect-fill image) must never enlarge that
        // proposal or change the toolbar's shared safe-area reservation.
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .background {
                // Scenery stays direct. Readability belongs to local controls
                // and reading planes, never a full-screen presentation veil.
                environmentBackdrop(reduceMotion: motionIsReduced)
            }
#if DEBUG
            .overlay(alignment: .topLeading) {
                if ProcessInfo.processInfo.arguments.contains("-LifeRouteLivingDiagnostics") {
                    LivingThemeContinuityProbe()
                        .environmentObject(visualActivityCoordinator)
                }
            }
#endif
        .environment(\.scenicRoyalThemeStyle, style)
        .environment(\.defaultMinListRowHeight, 52)
        .tint(style.nativeControlTint)
        .preferredColorScheme(style.nativeColorScheme)
    }

    @ViewBuilder
    private func environmentBackdrop(reduceMotion: Bool) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        } else if theme.isPhaseThreeScenery {
            LifeRouteLiveThemeEnvironment(
                theme: theme,
                palette: palette,
                reduceMotion: reduceMotion,
                isActive: scenePhase == .active,
                renderMode: effectiveRenderMode
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        } else {
            LifeRouteCinematicBackdrop(theme: theme, palette: palette)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var effectiveRenderMode: LifeRouteAmbientRenderMode {
        guard visualActivityCoordinator.livingEnvironmentRenderingIsActive else {
            return .frozen
        }

#if DEBUG
        return LifeRouteDebugVisualActivityMode.current.ambientRenderMode
#else
        return .full
#endif
    }
}
