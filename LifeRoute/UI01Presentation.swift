import SwiftUI
import CoreText

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
    static let crystalBoxOpacity: Double = 0.25
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldShade],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// A cached Didot glyph path keeps the fine outline aligned with the gold fill.
/// It avoids offset text copies, masks and glyph shadows.
private enum UI01WordmarkGeometry {
    static let nominalSize: CGFloat = 32
    static let path: Path = {
        let font = CTFontCreateWithName("Didot" as CFString, nominalSize, nil)
        let text = NSAttributedString(string: "LifeRoute", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ])
        let line = CTLineCreateWithAttributedString(text)
        let outline = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                if let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil) {
                    outline.addPath(glyph, transform: CGAffineTransform(
                        translationX: positions[index].x, y: positions[index].y
                    ))
                }
            }
        }
        let bounds = outline.boundingBoxOfPath
        return Path(outline).applying(CGAffineTransform(
            a: 1, b: 0, c: 0, d: -1, tx: -bounds.minX, ty: bounds.maxY
        ))
    }()
}

private struct UI01WordmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bounds = UI01WordmarkGeometry.path.boundingRect
        return UI01WordmarkGeometry.path.applying(CGAffineTransform(
            a: rect.width / bounds.width, b: 0, c: 0, d: rect.height / bounds.height,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

struct UI01BrandWordmark: View {
    var showsLogo = false
    @ScaledMetric(relativeTo: .title2) private var pointSize: CGFloat = 32

    private var wordmarkFill: AnyShapeStyle {
        guard showsLogo else { return AnyShapeStyle(UI01Material.goldGradient) }
        return AnyShapeStyle(LinearGradient(
            stops: [
                .init(color: UI01Material.goldLight.opacity(0.80), location: 0),
                .init(color: UI01Material.gold.opacity(1), location: 0.34),
                .init(color: UI01Material.goldLight.opacity(1), location: 0.44),
                .init(color: UI01Material.goldLight.opacity(1), location: 0.56),
                .init(color: UI01Material.gold.opacity(1), location: 0.66),
                .init(color: UI01Material.goldShade.opacity(0.70), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    private var wordmarkOutline: AnyShapeStyle {
        guard showsLogo else { return AnyShapeStyle(Color.white.opacity(0.98)) }
        return AnyShapeStyle(LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.80), location: 0),
                .init(color: Color.white.opacity(1), location: 0.40),
                .init(color: Color.white.opacity(1), location: 0.60),
                .init(color: Color.white.opacity(0.70), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    private func wordmarkGlyph(width: CGFloat, height: CGFloat) -> some View {
        UI01WordmarkShape()
            .fill(wordmarkFill)
            // A near-opaque Today fill lets the dimensional mark read as one
            // unified brand lockup while keeping the lettering dominant.
            .overlay {
                UI01WordmarkShape().stroke(wordmarkOutline, lineWidth: 0.58)
            }
            .frame(width: width, height: height)
    }

    @ViewBuilder
    var body: some View {
        let scale = pointSize / UI01WordmarkGeometry.nominalSize
        let bounds = UI01WordmarkGeometry.path.boundingRect
        let wordmarkWidth = bounds.width * scale
        let wordmarkHeight = bounds.height * scale

        Group {
            if showsLogo {
                // Today owns a vertical brand lockup: the logo clears the
                // lettering, both share the same leading edge, and the existing
                // filament below the wordmark can separate the brand from Today.
                VStack(alignment: .leading, spacing: 4) {
                    UI01TodayLogoBackdrop(side: pointSize * 1.9)
                        .frame(width: wordmarkWidth, alignment: .leading)
                    wordmarkGlyph(width: wordmarkWidth, height: wordmarkHeight)
                }
                .frame(width: wordmarkWidth, alignment: .leading)
            } else {
                wordmarkGlyph(width: wordmarkWidth, height: wordmarkHeight)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute")
        .accessibilityAddTraits(.isStaticText)
    }
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

/// The Today header's dimensional brand mark stays behind the wordmark while
/// keeping its scenery-facing surface clear and visually restrained.
private struct UI01TodayLogoBackdrop: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            LifeRouteBrandMark(variant: .micro)

            // A low offset shade and a light-to-gold highlight read as a
            // shallow bevel without adding a glow or changing the logo art.
            RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                .stroke(Color.black.opacity(0.48), lineWidth: 0.9)
                .offset(y: 1.1)

            RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.88),
                            Color.white.opacity(0.20),
                            UI01Material.goldLight.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .padding(0.8)
        }
        .frame(width: side, height: side)
        .shadow(color: Color.black.opacity(0.42), radius: 2.1, x: 0, y: 1.6)
        .opacity(0.96)
        .accessibilityHidden(true)
    }
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

/// Small open-scene captions use a restrained dark-blue box so the scenery can
/// remain visible through the surface. Background-only insets preserve layout.
struct UI01CaptionReadingSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(UI01Material.secondary)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(UI01Material.navy.opacity(
                        reduceTransparency || contrast == .increased ? 1 : UI01Material.crystalBoxOpacity
                    ))
                    .padding(.horizontal, -4)
                    .padding(.vertical, -2)
                    .allowsHitTesting(false)
            }
    }
}

/// Shared rounded input boxes use the same clear 25% dark-blue treatment as
/// the Today date control, with the accepted opaque accessibility fallback.
struct UI01FieldSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(minHeight: 44)
            .background(
                UI01Material.navy.opacity(
                    reduceTransparency || contrast == .increased ? 1 : UI01Material.crystalBoxOpacity
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(alignment: .bottom) {
                UI01Hairline().padding(.horizontal, 8)
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
        HStack(alignment: .top, spacing: 8) {
            Color.clear.frame(width: 34)
            content
                .modifier(UI01ReadingZone())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, spacious ? 18 : 10)
        }
        .overlay(alignment: .leading) {
            GeometryReader { geometry in
                let mid = geometry.size.height / 2
                let railX: CGFloat = 17
                let route = Path { path in
                    path.move(to: CGPoint(x: railX, y: 0))
                    path.addCurve(to: CGPoint(x: railX, y: geometry.size.height),
                                  control1: CGPoint(x: railX + 16, y: mid * 0.6),
                                  control2: CGPoint(x: railX - 16, y: mid * 1.4))
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
                .position(x: railX, y: mid)
            }
            .frame(width: 34)
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
                .overlay(alignment: .topLeading) {
                    UI01ChromeShine(size: 34)
                        .offset(x: 10, y: -4)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomTrailing) {
                    UI01ChromeShine(size: 30)
                        .offset(x: -10, y: 4)
                        .allowsHitTesting(false)
                }
        }
    }
}

/// The selected root receives a clear crystal inset rather than a filled chip.
/// The offset rims and edge glint add dimensionality without refracting scenery.
struct UI01DockSelectionSurface: ViewModifier {
    let selected: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                if selected {
                    if reduceTransparency || contrast == .increased {
                        Capsule()
                            .fill(UI01Material.royal)
                            .overlay(Capsule().strokeBorder(UI01Material.goldLight.opacity(0.85), lineWidth: 1))
                    } else {
                        Capsule()
                            .fill(theme.palette.backgroundTop.opacity(0.03))
                            .overlay {
                                Capsule().strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            UI01Material.silver.opacity(0.60),
                                            UI01Material.goldLight.opacity(0.72),
                                            UI01Material.gold.opacity(0.24)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.85
                                )
                            }
                            .overlay {
                                Capsule()
                                    .stroke(UI01Material.silver.opacity(0.20), lineWidth: 0.5)
                                    .offset(y: -1)
                            }
                            .overlay(alignment: .topLeading) {
                                UI01ChromeShine(size: 26)
                                    .offset(x: 7, y: 1)
                                    .allowsHitTesting(false)
                            }
                    }
                }
            }
    }
}

/// Fine separators echo the reference instrument panel without splitting the
/// dock into independent surfaces.
struct UI01DockDivider: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    UI01Material.silver.opacity(0.04),
                    UI01Material.silver.opacity(0.34),
                    UI01Material.goldLight.opacity(0.20),
                    UI01Material.silver.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 0.6, height: 46)
            .accessibilityHidden(true)
    }
}

private struct UI01ChromeShine: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        UI01Material.goldLight.opacity(0.62),
                        UI01Material.gold.opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                ))
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 2.4, height: 2.4)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Fixed vector silhouettes share one stroke and route-node vocabulary.
struct UI01DockInstrument: View {
    let section: AppSection

    var body: some View {
        LifeRouteDockGlyph(section: section)
            .stroke(style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
    }
}

struct UI01DockLabel: View {
    let section: AppSection
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            UI01DockInstrument(section: section)
                .foregroundStyle(selected ? UI01Material.goldLight : UI01Material.silver)
            Text(section.title)
                .font(.caption2.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? UI01Material.silver : UI01Material.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Circle()
                .fill(UI01Material.goldGradient)
                .frame(width: selected ? 4.5 : 3.5, height: selected ? 4.5 : 3.5)
                .opacity(selected ? 1 : 0.62)
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

struct UI01ToolbarActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.headline.weight(.semibold))
                .foregroundStyle(enabled ? UI01Material.silver : UI01Material.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .modifier(UI01CompactControlSurface(primary: true))
                .opacity(enabled ? 1 : 0.75)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
                .contentShape(Capsule())
        }
    }
}

/// Route actions use one compact instrument treatment so planning controls do
/// not read as oversized novelty buttons. The existing rim-only surface keeps
/// the scenery sharp; the small edge glints supply just enough depth to make
/// the control feel machined rather than flat.
struct UI01RouteButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        Content(
            configuration: configuration,
            compact: compact
        )
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
                .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(enabled ? UI01Material.silver : UI01Material.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, compact ? 15 : 18)
                .frame(
                    maxWidth: compact ? nil : .infinity,
                    minHeight: compact ? 44 : 48,
                    alignment: .center
                )
                .modifier(UI01CompactControlSurface(primary: true))
                .overlay {
                    if enabled && !reduceTransparency && contrast != .increased {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.16),
                                        UI01Material.goldLight.opacity(0.22),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.35
                            )
                            .overlay(alignment: .topLeading) {
                                UI01ChromeShine(size: 18)
                                    .offset(x: 8, y: 2)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Capsule()
                                    .fill(UI01Material.goldLight.opacity(0.54))
                                    .frame(width: compact ? 18 : 24, height: 1)
                                    .offset(x: compact ? -10 : -14, y: -5)
                            }
                            .allowsHitTesting(false)
                    }
                }
                .opacity(enabled ? 1 : 0.62)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
                .contentShape(Capsule())
        }
    }
}
