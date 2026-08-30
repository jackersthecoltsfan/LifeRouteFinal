import SwiftUI

enum ScenicRoyalSurfaceRole {
    case ambient
    case card
    case readability
    case toolbar
    case selectedControl

    var underlayOpacity: Double {
        switch self {
        case .ambient: return 0.20
        case .card: return 0.34
        case .readability: return 0.78
        case .toolbar: return 0.66
        case .selectedControl: return 0.52
        }
    }

    var tintMultiplier: Double {
        switch self {
        case .ambient: return 0.55
        case .card: return 0.78
        case .readability: return 0.52
        case .toolbar: return 0.72
        case .selectedControl: return 0.88
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
        if reduceTransparency {
            decorated(
                content.background {
                    surfaceShape.fill(style.readabilityBase.opacity(0.98))
                },
                opaque: true
            )
        } else if #available(iOS 26.0, *) {
            decorated(
                content
                    .background {
                        surfaceShape.fill(
                            style.readabilityBase.opacity(adjustedUnderlayOpacity)
                        )
                    }
                    .glassEffect(
                        interactive
                            ? .regular.tint(style.glassTint.opacity(glassTintOpacity)).interactive()
                            : .regular.tint(style.glassTint.opacity(glassTintOpacity)),
                        in: .rect(cornerRadius: cornerRadius)
                    ),
                opaque: false
            )
        } else {
            decorated(
                content.background {
                    ZStack {
                        surfaceShape.fill(.ultraThinMaterial)
                        surfaceShape.fill(style.readabilityBase.opacity(adjustedUnderlayOpacity))
                        surfaceShape.fill(style.glassTint.opacity(glassTintOpacity * 0.72))
                    }
                },
                opaque: false
            )
        }
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var adjustedUnderlayOpacity: Double {
        min(0.94, role.underlayOpacity + (contrast == .increased ? 0.16 : 0))
    }

    private var glassTintOpacity: Double {
        style.glassTintOpacity * role.tintMultiplier
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
                color: Color.black.opacity(opaque ? 0.20 : 0.28),
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
