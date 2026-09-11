import SwiftUI

/// A single root-level host keeps the selected LifeRoute environment mounted while the
/// five independent NavigationStacks swipe and navigate above it.
struct ScenicRoyalEnvironmentHost<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
                ZStack {
                    environmentBackdrop(reduceMotion: motionIsReduced)

                    ScenicRoyalEnvironmentReadabilityVeil(
                        style: style,
                        reduceTransparency: reduceTransparency
                    )
                }
            }
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
        guard visualActivityCoordinator.ambientRenderingIsActive else {
            return .frozen
        }

#if DEBUG
        return LifeRouteDebugVisualActivityMode.current.ambientRenderMode
#else
        return .full
#endif
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
                    style.glassTint.opacity(reduceTransparency ? 0 : 0.018),
                    Color.clear,
                    style.accentReflection.opacity(reduceTransparency ? 0 : 0.008),
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
        if reduceTransparency {
            return min(0.28, style.environmentScrimOpacity + 0.06)
        }
        return min(0.10, style.environmentScrimOpacity * 0.34)
    }

    private var bottomOpacity: Double {
        if reduceTransparency {
            return min(0.34, style.environmentScrimOpacity + 0.13)
        }
        return min(0.14, (style.environmentScrimOpacity + 0.07) * 0.34)
    }
}
