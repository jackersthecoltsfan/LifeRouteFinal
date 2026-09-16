import SwiftUI

/// R2 foreground roles. The existing environment remains the only scenery owner.
enum UI01Material {
    static let silver = Color(red: 250 / 255, green: 246 / 255, blue: 238 / 255)
    static let secondary = Color(red: 214 / 255, green: 224 / 255, blue: 232 / 255)
    static let navy = Color(red: 6 / 255, green: 26 / 255, blue: 59 / 255)
    static let royal = Color(red: 22 / 255, green: 49 / 255, blue: 95 / 255)
    static let royalLight = Color(red: 49 / 255, green: 94 / 255, blue: 141 / 255)
    static let gold = Color(red: 242 / 255, green: 186 / 255, blue: 66 / 255)
    static let goldLight = Color(red: 1, green: 240 / 255, blue: 168 / 255)
    static let goldShade = Color(red: 155 / 255, green: 91 / 255, blue: 11 / 255)
    static let destructive = Color(red: 1, green: 184 / 255, blue: 176 / 255)
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldShade],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct UI01MarbleText: View {
    let title: String
    var size: CGFloat = 26
    var relativeTo: Font.TextStyle = .title2
    // Only explicit wordmarks and the accepted Today hero use the branded serif.
    var branded = false
    var metallic = false

    var body: some View {
        Text(title)
            .font(branded ? .custom("Didot", size: size, relativeTo: relativeTo) : .system(relativeTo).weight(.semibold))
            .foregroundStyle(metallic ? AnyShapeStyle(UI01Material.goldGradient) : AnyShapeStyle(UI01Material.silver))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Stable foreground roles, never sampled from moving scenery. Today and the
/// material titles use silver; existing dark environmental copy uses the
/// theme role. A light composition can explicitly request dark lettering.
enum UI01TextRole {
    case silver, dark, environmental
}

struct UI01ReadingZone: ViewModifier {
    var role: UI01TextRole = .silver

    func body(content: Content) -> some View {
        // Compatibility for open-content call sites. Dense reading regions
        // own their local planes; scenic lettering has no veil or backplate.
        content
    }
}

struct UI01Hairline: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    UI01Material.gold.opacity(0),
                    UI01Material.goldLight.opacity(contrast == .increased ? 0.85 : 0.58),
                    UI01Material.gold.opacity(contrast == .increased ? 0.7 : 0.38),
                    UI01Material.gold.opacity(0)
                ],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: contrast == .increased ? 1 : 0.5)
            .accessibilityHidden(true)
    }
}

/// A hairline brand mark; its gold stays independent of the selected scenery.
struct UI01BrandFilament: View {
    var body: some View {
        Capsule()
            .fill(UI01Material.goldGradient)
            .frame(width: 56, height: 1)
            .accessibilityHidden(true)
    }
}

/// Foreground-only palette. The existing environment above the navigation
/// stacks continues to render the selected theme and owns all scene motion.
struct UI01ContentStyle: ViewModifier {
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        let source = theme.palette
        let palette = LifeRouteThemePalette(
            backgroundTop: source.backgroundTop, backgroundBottom: source.backgroundBottom,
            panel: UI01Material.navy, panelElevated: UI01Material.royal,
            accent: UI01Material.gold, accentSecondary: UI01Material.goldLight,
            textPrimary: UI01Material.silver, textSecondary: UI01Material.secondary
        )
        content
            .environment(\.lifeRoutePalette, palette)
            .environment(\.scenicRoyalThemeStyle, ScenicRoyalThemeStyle(
                family: theme.scenicRoyalStyle.family, palette: palette, isBrightEnvironment: false
            ))
            .environment(\.colorScheme, .dark)
            .foregroundStyle(UI01Material.silver)
            .font(.body)
            .tint(UI01Material.goldLight)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// A bounded, stable plane is reserved for actual input/long reading regions.
/// It never supplies the backdrop for a scenic title or directory row.
struct UI01ReadingPlane: ViewModifier {
    var padding: CGFloat = 16
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(UI01Material.navy.opacity(reduceTransparency || contrast == .increased ? 1 : 0.94),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [
                            UI01Material.goldLight.opacity(contrast == .increased ? 0.6 : 0.25),
                            UI01Material.silver.opacity(contrast == .increased ? 0.5 : 0.16)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
    }
}

/// A selected choice is an action material, while unselected choices stay open.
struct UI01SelectionSurface: ViewModifier {
    let selected: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(selected ? UI01Material.goldLight : UI01Material.silver)
            .background {
                if selected {
                    // Selection stays inside the group's single crystal surface.
                    if reduceTransparency || contrast == .increased {
                        Capsule().fill(UI01Material.royal)
                            .overlay(Capsule().strokeBorder(UI01Material.goldLight, lineWidth: 1))
                    } else {
                        Capsule().fill(theme.palette.backgroundTop.opacity(0.03))
                            .overlay(UI01CrystalRim(primary: true))
                    }
                }
            }
    }
}

struct UI01SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    // Legacy style adapters call makeBody directly. Read the environment in a
    // mounted View so disabled and motion settings still reach the material.
    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(configuration.role == .destructive ? UI01Material.destructive : UI01Material.silver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .modifier(UI01CompactControlSurface())
                .opacity(enabled ? 1 : 0.5)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
                .contentShape(Capsule())
        }
    }
}

/// One compact crystal owner for controls and grouped navigation. A rim and
/// tiny wash preserve the scenery's geometry; dense input uses UI01ReadingPlane.
struct UI01CompactControlSurface: ViewModifier {
    var primary = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        let shade = theme.palette.backgroundTop
        if reduceTransparency || contrast == .increased {
            content.background(UI01Material.royal, in: Capsule())
                .overlay(Capsule().strokeBorder(UI01Material.secondary.opacity(0.5), lineWidth: 1).allowsHitTesting(false))
        } else {
            content.background(shade.opacity(primary ? 0.03 : 0.02), in: Capsule())
                .overlay(UI01CrystalRim(primary: primary).allowsHitTesting(false))
        }
    }
}

/// A shared rim, without its own fill or glass compositor.
private struct UI01CrystalRim: View {
    var primary = false
    @Environment(\.lifeRouteTheme) private var theme

    var body: some View {
        Capsule().strokeBorder(LinearGradient(
            colors: [
                Color.white.opacity(0.40),
                theme.palette.backgroundTop.opacity(0.22),
                UI01Material.goldLight.opacity(primary ? 0.35 : 0.28)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ), lineWidth: primary ? 0.45 : 0.4)
    }
}

extension View {
    func ui01ScenicText() -> some View { modifier(UI01ReadingZone()) }
    func ui01ContentStyle() -> some View { modifier(UI01ContentStyle()) }
    func ui01OpenSection() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .ui01ScenicText()
    }
    func ui01ReadingPlane(padding: CGFloat = 16) -> some View {
        modifier(UI01ReadingPlane(padding: padding))
    }
}

struct UI01GoldButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, compact: compact)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        let compact: Bool
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(enabled ? UI01Material.silver : UI01Material.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, compact ? 14 : 20)
                .padding(.vertical, compact ? 8 : 10)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 48)
                // Dim only the label, keeping the accessibility backing opaque.
                .opacity(enabled ? 1 : 0.75)
                .modifier(UI01CompactControlSurface(primary: true))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
                .contentShape(Capsule())
        }
    }
}

/// Each self-sizing row owns one connected segment. Its path ends on the same
/// axis it starts on, so long text and arbitrary event counts cannot break it.
struct UI01TrailRow<Content: View>: View {
    var active = false
    var symbol: String? = nil
    var spacious = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Color.clear.frame(width: 28)
            content
                .modifier(UI01ReadingZone())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, spacious ? 18 : 10)
        }
        .overlay(alignment: .leading) {
            GeometryReader { geometry in
                let mid = geometry.size.height / 2
                let route = Path { path in
                    path.move(to: CGPoint(x: 14, y: 0))
                    path.addCurve(to: CGPoint(x: 14, y: geometry.size.height),
                                  control1: CGPoint(x: 30, y: mid * 0.6),
                                  control2: CGPoint(x: -2, y: mid * 1.4))
                }
                route.stroke(UI01Material.gold.opacity(0.10), lineWidth: 3)
                route.stroke(UI01Material.goldGradient, lineWidth: 1.15)
                Group {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .regular))
                            .foregroundStyle(UI01Material.goldGradient)
                            .padding(4)
                            .background(UI01Material.navy.opacity(0.92), in: Circle())
                    } else {
                        Circle().fill(active ? UI01Material.gold : UI01Material.navy)
                            .frame(width: active ? 13 : 10, height: active ? 13 : 10)
                            .overlay(Circle().stroke(UI01Material.goldLight, lineWidth: 1))
                            .padding(active ? 4 : 0)
                            .overlay(Circle().stroke(active ? UI01Material.gold : .clear, lineWidth: 1))
                    }
                }
                .position(x: 14, y: mid)
            }
            .frame(width: 28)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The dock keeps its single surface owner without refracting the living scene.
struct UI01DockSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(UI01Material.royal, in: Capsule())
                .overlay(Capsule().strokeBorder(UI01Material.secondary.opacity(0.5), lineWidth: 1).allowsHitTesting(false))
        } else {
            content.background(theme.palette.backgroundTop.opacity(0.02), in: Capsule())
                .overlay(UI01CrystalRim().allowsHitTesting(false))
        }
    }
}

/// Fixed vector silhouettes share one stroke and route-node vocabulary.
struct UI01DockInstrument: View {
    let section: AppSection

    var body: some View {
        LifeRouteDockGlyph(section: section)
            .stroke(style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }
}

struct UI01DockLabel: View {
    let section: AppSection
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            UI01DockInstrument(section: section)
                .foregroundStyle(selected ? UI01Material.goldLight : UI01Material.secondary)
            Text(section.title)
                .font(.caption2.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? UI01Material.silver : UI01Material.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Capsule().fill(UI01Material.goldGradient)
                .frame(width: 12, height: 1)
                .opacity(selected ? 1 : 0)
                .frame(height: 5)
                .accessibilityHidden(true)
        }
        // Navigation remains simultaneously available at accessibility sizes;
        // the full unabridged name is always exposed to VoiceOver.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
