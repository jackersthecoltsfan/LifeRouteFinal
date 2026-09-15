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
    static let moltenGold = LinearGradient(
        colors: [
            Color(red: 1, green: 246 / 255, blue: 210 / 255),
            goldLight,
            gold,
            goldShade
        ],
        startPoint: .top,
        endPoint: .bottom
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
        // Compatibility for existing open-content call sites. Reading support
        // belongs to the full-width environment veil, never individual glyphs.
        content
    }
}

struct UI01Hairline: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        UI01Material.gold.opacity(0),
                        UI01Material.goldLight.opacity(contrast == .increased ? 0.95 : 0.78),
                        UI01Material.gold.opacity(contrast == .increased ? 0.88 : 0.58),
                        UI01Material.gold.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: contrast == .increased ? 1.25 : 0.75)
            .accessibilityHidden(true)
    }
}

/// Ceremonial brand mark used under the LifeRoute wordmark. Independent of
/// living-theme scenery — gold is chrome, never sampled from the environment.
struct UI01BrandFilament: View {
    var body: some View {
        Capsule()
            .fill(UI01Material.goldGradient)
            .frame(width: 56, height: 2)
            .shadow(color: UI01Material.gold.opacity(0.45), radius: 6, y: 0)
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
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                UI01Material.goldLight.opacity(contrast == .increased ? 0.72 : 0.38),
                                UI01Material.silver.opacity(contrast == .increased ? 0.5 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                    .allowsHitTesting(false)
            }
    }
}

/// A selected choice is an action material, while unselected choices stay open.
struct UI01SelectionSurface: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
            .foregroundStyle(UI01Material.silver)
            .background {
                if selected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    UI01Material.gold.opacity(0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), UI01Material.goldLight.opacity(0.42)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                        )
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

/// One compact material owner for controls and grouped navigation. Dense input
/// surfaces use UI01ReadingPlane and never nest Liquid Glass.
struct UI01CompactControlSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        let shade = theme.palette.backgroundTop
        if reduceTransparency || contrast == .increased {
            content.background(UI01Material.royal, in: Capsule())
                .overlay(Capsule().strokeBorder(UI01Material.secondary.opacity(0.5), lineWidth: 1).allowsHitTesting(false))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.clear.tint(shade.opacity(0.02)), in: .capsule)
                .overlay(jewelRim.allowsHitTesting(false))
        } else {
            content.background(shade.opacity(0.03), in: Capsule())
                .overlay(jewelRim.allowsHitTesting(false))
        }
    }

    private var jewelRim: some View {
        Capsule().strokeBorder(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    theme.palette.backgroundTop.opacity(0.22),
                    UI01Material.goldLight.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.4
        )
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
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Environment(\.colorSchemeContrast) private var contrast
        var body: some View {
            configuration.label
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(enabled ? UI01Material.silver : UI01Material.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, compact ? 14 : 20)
                .padding(.vertical, compact ? 8 : 10)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 48)
                .modifier(LiquidPrimaryGlass(reduceTransparency: reduceTransparency, contrast: contrast, enabled: enabled))
                .opacity(enabled ? 1 : 0.55)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .contentShape(Capsule())
        }
    }
}

private struct LiquidPrimaryGlass: ViewModifier {
    let reduceTransparency: Bool
    let contrast: ColorSchemeContrast
    let enabled: Bool
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        let shade = theme.palette.backgroundTop
        if reduceTransparency || contrast == .increased {
            content.background(UI01Material.royal, in: Capsule())
                .overlay(Capsule().strokeBorder(UI01Material.goldLight.opacity(enabled ? 0.7 : 0.3), lineWidth: 1).allowsHitTesting(false))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.clear.tint(shade.opacity(enabled ? 0.03 : 0.015)), in: .capsule)
                .overlay(primaryRim.allowsHitTesting(false))
        } else {
            content
                .background(shade.opacity(enabled ? 0.03 : 0.015), in: Capsule())
                .overlay(primaryRim.allowsHitTesting(false))
        }
    }

    private var primaryRim: some View {
        Capsule().strokeBorder(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.4),
                    theme.palette.backgroundTop.opacity(0.22),
                    UI01Material.goldLight.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.45
        )
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
                route.stroke(UI01Material.gold.opacity(0.22), lineWidth: 4.5)
                route.stroke(UI01Material.goldGradient, lineWidth: 1.35)
                Group {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .regular))
                            .foregroundStyle(UI01Material.goldGradient)
                            .padding(4)
                            .background(UI01Material.navy.opacity(0.92), in: Circle())
                            .overlay(Circle().strokeBorder(UI01Material.gold.opacity(0.45), lineWidth: 0.7))
                    } else {
                        Circle().fill(active ? UI01Material.gold : UI01Material.navy)
                            .frame(width: active ? 13 : 10, height: active ? 13 : 10)
                            .overlay(Circle().stroke(UI01Material.goldLight, lineWidth: 1))
                            .padding(active ? 4 : 0)
                            .overlay(Circle().stroke(active ? UI01Material.gold : .clear, lineWidth: 1))
                            .shadow(color: active ? UI01Material.gold.opacity(0.55) : .clear, radius: 6, y: 0)
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

/// Native symbols share one optical treatment inside the existing dock buttons.
struct UI01DockInstrument: View {
    let section: AppSection
    let selected: Bool

    static func symbolName(for section: AppSection) -> String {
        switch section {
        case .today: return "sun.max.fill"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver.fill"
        case .resources: return "book.fill"
        case .setup: return "gearshape.fill"
        }
    }

    var body: some View {
        Image(systemName: Self.symbolName(for: section))
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: selected ? 24 : 22, weight: .semibold))
            .foregroundStyle(selected ? UI01Material.goldLight : UI01Material.secondary)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }
}

struct UI01DockLabel: View {
    let section: AppSection
    let selected: Bool

    var body: some View {
        VStack(spacing: 3) {
            UI01DockInstrument(section: section, selected: selected)
            Text(section.title)
                .font(.caption2.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? UI01Material.silver : UI01Material.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Navigation remains simultaneously available at accessibility sizes;
        // the full unabridged name is always exposed to VoiceOver.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, 4)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.5)
                    }
            }
        }
        .contentShape(Rectangle())
    }
}
