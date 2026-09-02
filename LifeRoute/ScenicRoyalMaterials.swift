import SwiftUI

/// The executable Foundation contract is also the production role vocabulary,
/// so tests and SwiftUI rendering cannot drift into parallel definitions.
typealias ScenicRoyalSurfaceRole = LifeRouteSurfaceRoleContract

extension LifeRouteSurfaceRoleContract {
    // Compatibility aliases let existing feature screens migrate without a
    // second styling system. They resolve to the semantic roles above.
    static let ambient = Self.passiveRow
    static let card = Self.majorGroup
    static let readability = Self.majorGroup
    static let toolbar = Self.majorGroup
    static let legibilityControl = Self.control

    var fallbackUnderlayOpacity: Double {
        switch self {
        case .majorGroup: return 0.055
        case .passiveRow: return 0
        case .control: return 0.045
        case .selectedControl: return 0.06
        case .focalControl: return 0.07
        }
    }

    var tintMultiplier: Double {
        switch self {
        case .majorGroup: return 0.72
        case .passiveRow: return 0
        case .control: return 0.78
        case .selectedControl: return 0.92
        case .focalControl: return 1.0
        }
    }

    var drawsSurfaceShadow: Bool {
        drawsIndependentShadow
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
        if role == .passiveRow {
            // Passive rows are content inside their owning group. A faint
            // outline preserves grouping without another slab, blur, or shadow.
            content
                .overlay {
                    surfaceShape.stroke(
                        Color.white.opacity(contrast == .increased ? 0.16 : 0.045),
                        lineWidth: ScenicRoyalDesignSystem.Stroke.subtle
                    )
                }
        } else if reduceTransparency || contrast == .increased {
            decorated(
                content.background {
                    surfaceShape.fill(style.readabilityBase.opacity(accessibleSurfaceOpacity))
                },
                opaque: true
            )
        } else if role.usesNativeGlass, #available(iOS 26.0, *) {
            decorated(
                content
                    .background {
                        if role == .majorGroup {
                            surfaceShape.fill(style.readabilityBase.opacity(fallbackUnderlayOpacity))
                        }
                    }
                    .glassEffect(emphasizedNativeGlass, in: .rect(cornerRadius: cornerRadius)),
                opaque: false
            )
        } else {
            decorated(
                content.background {
                    ZStack {
                        surfaceShape.fill(.ultraThinMaterial)
                        surfaceShape.fill(style.readabilityBase.opacity(fallbackUnderlayOpacity))
                        surfaceShape.fill(style.glassTint.opacity(glassTintOpacity * 0.30))
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
        guard role.fallbackUnderlayOpacity > 0 else { return 0 }
        return role.fallbackUnderlayOpacity + (style.isBrightEnvironment ? 0.02 : 0)
    }

    private var glassTintOpacity: Double {
        style.glassTintOpacity * role.tintMultiplier
    }

    @available(iOS 26.0, *)
    private var emphasizedNativeGlass: Glass {
        let base: Glass = role == .majorGroup ? .clear : .regular
        let styled = base.tint(style.glassTint.opacity(glassTintOpacity))
        return interactive ? styled.interactive() : styled
    }

    private func decorated<Surface: View>(_ surface: Surface, opaque: Bool) -> some View {
        surface
            .overlay {
                surfaceShape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(opaque ? 0.18 : (contrast == .increased ? 0.32 : 0.11)),
                            style.accentReflection.opacity(opaque ? (contrast == .increased ? 0.30 : 0.18) : 0.08),
                            ScenicRoyalDesignSystem.ColorToken.brandGold.opacity(
                                opaque ? (role == .focalControl ? 0.34 : 0.12) : (role == .focalControl ? 0.10 : 0.05)
                            ),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased ? 1.2 : ScenicRoyalDesignSystem.Stroke.subtle
                )
            }
            .shadow(
                color: role.drawsSurfaceShadow ? Color.black.opacity(opaque ? 0.16 : 0.045) : .clear,
                radius: role == .focalControl ? ScenicRoyalDesignSystem.Shadow.toolbarRadius : ScenicRoyalDesignSystem.Shadow.cardRadius,
                y: role == .focalControl ? ScenicRoyalDesignSystem.Shadow.toolbarY : ScenicRoyalDesignSystem.Shadow.cardY
            )
    }
}

extension View {
    func scenicRoyalSurface(
        role: ScenicRoyalSurfaceRole = .majorGroup,
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
