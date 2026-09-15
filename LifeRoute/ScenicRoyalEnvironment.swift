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

private struct ScenicRoyalEnvironmentReadabilityVeil: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let style: ScenicRoyalThemeStyle
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            // A single atmospheric royal grade spans the scene. Its smooth
            // vertical stops support open content without text-local boxes.
            LinearGradient(
                stops: [
                    .init(color: UI01Material.navy.opacity(density * 0.45), location: 0),
                    .init(color: UI01Material.navy.opacity(density), location: 0.22),
                    .init(color: UI01Material.royal.opacity(density * 0.9), location: 0.64),
                    .init(color: UI01Material.navy.opacity(density * 0.6), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    UI01Material.royal.opacity(0.12),
                    Color.clear,
                    UI01Material.royal.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var density: Double {
        let base = style.isBrightEnvironment ? 0.58 : 0.28
        return min(0.78, base + (contrast == .increased ? 0.16 : 0) + (reduceTransparency ? 0.04 : 0))
    }
}
