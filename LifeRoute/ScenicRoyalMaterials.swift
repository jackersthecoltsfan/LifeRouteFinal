import SwiftUI

enum ScenicRoyalSurfaceRole {
    case ambient
    case card
    case readability
    case toolbar
    case selectedControl
    case legibilityControl

    var fallbackUnderlayOpacity: Double {
        switch self {
        case .ambient: return 0.03
        case .card: return 0.05
        case .readability: return 0.10
        case .toolbar: return 0.07
        case .selectedControl: return 0.06
        case .legibilityControl: return 0.08
        }
    }

    var tintMultiplier: Double {
        switch self {
        case .ambient: return 0.62
        case .card: return 0.86
        case .readability: return 0.68
        case .toolbar: return 0.78
        case .selectedControl: return 0.92
        case .legibilityControl: return 0.76
        }
    }
}

struct ScenicRoyalGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = ScenicRoyalDesignSystem.Spacing.compact, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private struct ScenicRoyalGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenicRoyalThemeStyle) private var style

    let role: ScenicRoyalSurfaceRole
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            decorated(
                content.background {
                    surfaceShape.fill(style.readabilityBase.opacity(accessibleSurfaceOpacity))
                },
                opaque: true
            )
        } else if #available(iOS 26.0, *) {
            decorated(
                content
                    .glassEffect(
                        nativeGlass,
                        in: .rect(cornerRadius: cornerRadius)
                    ),
                opaque: false
            )
        } else {
            decorated(
                content.background {
                    ZStack {
                        surfaceShape.fill(.ultraThinMaterial)
                        surfaceShape.fill(style.readabilityBase.opacity(fallbackUnderlayOpacity))
                        surfaceShape.fill(style.glassTint.opacity(glassTintOpacity * 0.42))
                    }
                },
                opaque: false
            )
        }
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var accessibleSurfaceOpacity: Double {
        reduceTransparency ? 0.98 : 0.90
    }

    private var fallbackUnderlayOpacity: Double {
        guard style.isBrightEnvironment else { return role.fallbackUnderlayOpacity }

        switch role {
        case .ambient: return role.fallbackUnderlayOpacity + 0.01
        case .card, .toolbar, .selectedControl, .legibilityControl:
            return role.fallbackUnderlayOpacity + 0.02
        case .readability: return role.fallbackUnderlayOpacity + 0.04
        }
    }

    private var glassTintOpacity: Double {
        style.glassTintOpacity * role.tintMultiplier
    }

    @available(iOS 26.0, *)
    private var nativeGlass: Glass {
        let base: Glass
        switch role {
        case .legibilityControl:
            base = .regular
        case .ambient, .card, .readability, .toolbar, .selectedControl:
            base = .clear
        }

        let tinted = base.tint(style.glassTint.opacity(glassTintOpacity))
        return interactive ? tinted.interactive() : tinted
    }

    private func decorated<Surface: View>(_ surface: Surface, opaque: Bool) -> some View {
        surface
            .overlay {
                surfaceShape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(opaque ? 0.18 : (contrast == .increased ? 0.32 : 0.20)),
                            style.accentReflection.opacity(contrast == .increased ? 0.30 : 0.18),
                            ScenicRoyalDesignSystem.ColorToken.brandGold.opacity(role == .toolbar ? 0.34 : 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased ? 1.2 : ScenicRoyalDesignSystem.Stroke.subtle
                )
            }
            .shadow(
                color: Color.black.opacity(opaque ? 0.20 : 0.16),
                radius: role == .toolbar ? ScenicRoyalDesignSystem.Shadow.toolbarRadius : ScenicRoyalDesignSystem.Shadow.cardRadius,
                y: role == .toolbar ? ScenicRoyalDesignSystem.Shadow.toolbarY : ScenicRoyalDesignSystem.Shadow.cardY
            )
    }
}

extension View {
    func scenicRoyalSurface(
        role: ScenicRoyalSurfaceRole = .card,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.card
    ) -> some View {
        modifier(
            ScenicRoyalGlassSurfaceModifier(
                role: role,
                cornerRadius: cornerRadius,
                interactive: false
            )
        )
    }

    func scenicRoyalInteractiveSurface(
        role: ScenicRoyalSurfaceRole = .selectedControl,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.control
    ) -> some View {
        modifier(
            ScenicRoyalGlassSurfaceModifier(
                role: role,
                cornerRadius: cornerRadius,
                interactive: true
            )
        )
    }
}
