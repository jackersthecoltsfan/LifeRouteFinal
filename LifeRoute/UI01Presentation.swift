import SwiftUI

/// UI-01's small, static material vocabulary. The existing environment remains
/// the only scenery owner; these roles belong to foreground reading zones.
enum UI01Material {
    static let silver = Color(red: 0.95, green: 0.97, blue: 0.98)
    static let secondary = Color(red: 0.79, green: 0.84, blue: 0.88)
    static let navy = Color(red: 0.02, green: 0.055, blue: 0.085)
    static let gold = Color(red: 0.90, green: 0.71, blue: 0.30)
    static let goldLight = Color(red: 1, green: 0.85, blue: 0.47)
    static let goldShade = Color(red: 0.59, green: 0.36, blue: 0.10)
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldLight, Color(red: 0.78, green: 0.56, blue: 0.22), gold],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct UI01MarbleText: View {
    let title: String
    var size: CGFloat = 26
    var relativeTo: Font.TextStyle = .title2
    @Environment(\.scenicRoyalThemeStyle) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    private var lettering: Text {
        Text(title).font(.custom("Didot", size: size, relativeTo: relativeTo))
    }

    var body: some View {
        lettering
            .foregroundStyle(LinearGradient(
                colors: [UI01Material.silver, .white, UI01Material.secondary, .white],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay {
                if contrast != .increased && !typeSize.isAccessibilitySize {
                    Canvas { context, bounds in
                        // Sparse fixed veins, masked to semantic text, never animated.
                        for index in 0..<7 {
                            let x = bounds.width * CGFloat(index) / 6
                            var vein = Path()
                            vein.move(to: CGPoint(x: x - 10, y: 0))
                            vein.addLines([
                                CGPoint(x: x + 2, y: bounds.height * 0.32),
                                CGPoint(x: x - 3, y: bounds.height * 0.58),
                                CGPoint(x: x + 12, y: bounds.height)
                            ])
                            context.stroke(vein, with: .color(theme.glassTint.opacity(0.48)), lineWidth: 1.2)
                            if index.isMultiple(of: 3) {
                                context.stroke(vein, with: .color(UI01Material.gold.opacity(0.60)), lineWidth: 0.45)
                            }
                        }
                    }
                    .mask(lettering)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 2)
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
    @Environment(\.scenicRoyalThemeStyle) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    private var darkLettering: Bool {
        switch role {
        case .silver: return false
        case .dark: return true
        case .environmental: return theme.isBrightEnvironment
        }
    }

    func body(content: Content) -> some View {
        // Native alpha-following shadows form a sub-point glyph edge and a
        // short contact shadow. No background, mask, duplicate semantic text,
        // animated texture, offscreen rasterization or rectangular scrim.
        let edge = darkLettering ? UI01Material.silver : Color.black
        let strong = contrast == .increased || typeSize.isAccessibilitySize
        content
            .shadow(color: edge, radius: strong ? 0.8 : 0.55)
            .shadow(color: edge.opacity(strong ? 0.95 : 0.8), radius: 0.4, x: 0, y: 0.6)
            .shadow(color: edge.opacity(0.55), radius: 1, x: 0, y: 1)
    }
}

struct UI01Hairline: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Rectangle()
            .fill(UI01Material.silver.opacity(contrast == .increased ? 0.95 : 0.65))
            .frame(height: contrast == .increased ? 1 : 0.5)
            .accessibilityHidden(true)
    }
}

struct UI01GoldButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Baskerville", size: compact ? 16 : 25, relativeTo: compact ? .subheadline : .title2).weight(.semibold))
            .foregroundStyle(enabled ? UI01Material.navy : UI01Material.silver)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, compact ? 15 : 22)
            .padding(.vertical, compact ? 9 : 13)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 56)
            .background {
                Capsule().fill(enabled ? UI01Material.goldGradient : LinearGradient(
                    colors: [Color(red: 0.15, green: 0.22, blue: 0.28), UI01Material.navy],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay {
                    if enabled && contrast != .increased && !typeSize.isAccessibilitySize {
                        Canvas { context, bounds in
                            // Mirrored fine hammered facets. A calm central midtone
                            // keeps the dark letter interiors readable.
                            for index in 0..<90 {
                                let unit = CGFloat(index)
                                let x = abs(sin(unit * 127.1 + 3.7)) * bounds.width * 0.32
                                let y = abs(sin(unit * 311.7 + 9.2)) * bounds.height
                                for mirrored in [false, true] {
                                    let origin = mirrored ? bounds.width - x : x
                                    var facet = Path()
                                    facet.move(to: CGPoint(x: origin, y: y))
                                    facet.addLine(to: CGPoint(x: origin + (mirrored ? -2 : 2), y: y + 1))
                                    facet.addLine(to: CGPoint(x: origin + (mirrored ? -3 : 3), y: y - 2))
                                    context.stroke(facet, with: .color(index.isMultiple(of: 2) ? .white.opacity(0.17) : UI01Material.goldShade.opacity(0.19)), lineWidth: 0.4)
                                }
                            }
                        }
                        .clipShape(Capsule())
                    }
                }
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.9), UI01Material.goldLight.opacity(0.3), UI01Material.goldLight], startPoint: .top, endPoint: .bottom),
                    lineWidth: contrast == .increased ? 1.5 : 0.85
                ))
                .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: configuration.isPressed ? 1 : 3)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .contentShape(Capsule())
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
                Path { path in
                    path.move(to: CGPoint(x: 14, y: 0))
                    path.addCurve(to: CGPoint(x: 14, y: geometry.size.height),
                                  control1: CGPoint(x: 30, y: mid * 0.6),
                                  control2: CGPoint(x: -2, y: mid * 1.4))
                }
                .stroke(UI01Material.goldGradient, lineWidth: 1.15)
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

/// One optical family rendered as small native metal instruments. These are
/// decorative labels inside the existing dock buttons, never another owner.
struct UI01DockInstrument: View {
    let section: AppSection
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 32
            context.scaleBy(x: scale, y: scale)
            var metal = Path()
            var detail = Path()
            switch section {
            case .today:
                metal.addEllipse(in: CGRect(x: 2, y: 14, width: 28, height: 13))
                for ray in 0..<8 {
                    let angle = Double(ray) * .pi / 4
                    metal.move(to: CGPoint(x: 15 + cos(angle) * 11, y: 13 + sin(angle) * 11))
                    metal.addLine(to: CGPoint(x: 15 + cos(angle) * 14, y: 13 + sin(angle) * 14))
                }
                detail.addEllipse(in: CGRect(x: 8, y: 6, width: 14, height: 14))
                detail.addEllipse(in: CGRect(x: 27, y: 19, width: 3, height: 3))
            case .schedule:
                metal.addRoundedRect(in: CGRect(x: 3, y: 7, width: 26, height: 23), cornerSize: CGSize(width: 1, height: 1))
                metal.move(to: CGPoint(x: 4, y: 12)); metal.addLine(to: CGPoint(x: 28, y: 12))
                for x: CGFloat in [9, 23] {
                    metal.move(to: CGPoint(x: x, y: 2)); metal.addLine(to: CGPoint(x: x, y: 10))
                }
                detail.move(to: CGPoint(x: 7, y: 23)); detail.addLines([CGPoint(x: 16, y: 20), CGPoint(x: 25, y: 22)])
                for x: CGFloat in [7, 16, 25] { detail.addEllipse(in: CGRect(x: x - 1.5, y: x == 16 ? 18.5 : 21, width: 3, height: 3)) }
            case .tools:
                metal.move(to: CGPoint(x: 5, y: 29))
                metal.addLines([CGPoint(x: 2, y: 26), CGPoint(x: 18, y: 11), CGPoint(x: 19, y: 5), CGPoint(x: 25, y: 2), CGPoint(x: 23, y: 8), CGPoint(x: 28, y: 9), CGPoint(x: 30, y: 4), CGPoint(x: 30, y: 11), CGPoint(x: 24, y: 15), CGPoint(x: 5, y: 29)])
                detail.move(to: CGPoint(x: 28, y: 28)); detail.addLines([CGPoint(x: 25, y: 30), CGPoint(x: 13, y: 18), CGPoint(x: 15, y: 15), CGPoint(x: 28, y: 28)])
                metal.move(to: CGPoint(x: 14, y: 16)); metal.addLines([CGPoint(x: 5, y: 7), CGPoint(x: 3, y: 2), CGPoint(x: 8, y: 5), CGPoint(x: 16, y: 14)])
            case .resources:
                metal.move(to: CGPoint(x: 16, y: 29))
                metal.addCurve(to: CGPoint(x: 2, y: 26), control1: CGPoint(x: 11, y: 24), control2: CGPoint(x: 6, y: 24))
                metal.addLine(to: CGPoint(x: 4, y: 5))
                metal.addQuadCurve(to: CGPoint(x: 16, y: 8), control: CGPoint(x: 12, y: 3))
                metal.addQuadCurve(to: CGPoint(x: 28, y: 5), control: CGPoint(x: 22, y: 3))
                metal.addLine(to: CGPoint(x: 30, y: 26))
                metal.addQuadCurve(to: CGPoint(x: 16, y: 29), control: CGPoint(x: 22, y: 24))
                metal.move(to: CGPoint(x: 16, y: 8)); metal.addLine(to: CGPoint(x: 16, y: 29))
                detail.move(to: CGPoint(x: 12, y: 24)); detail.addCurve(to: CGPoint(x: 24, y: 12), control1: CGPoint(x: 23, y: 25), control2: CGPoint(x: 16, y: 12))
                detail.addEllipse(in: CGRect(x: 22, y: 10, width: 3, height: 3))
            case .setup:
                for point in 0..<40 {
                    let angle = Double(point) * .pi / 20
                    let radius: Double = point % 4 < 2 ? 15 : 12
                    let vertex = CGPoint(x: 16 + cos(angle) * radius, y: 16 + sin(angle) * radius)
                    if point == 0 { metal.move(to: vertex) } else { metal.addLine(to: vertex) }
                }
                metal.closeSubpath()
                metal.addEllipse(in: CGRect(x: 7, y: 7, width: 18, height: 18))
                detail.addEllipse(in: CGRect(x: 5, y: 12, width: 22, height: 9))
                detail.addEllipse(in: CGRect(x: 13, y: 13, width: 6, height: 6))
            }
            context.stroke(metal, with: .linearGradient(
                Gradient(colors: [.white, UI01Material.secondary, .white, Color.gray]),
                startPoint: .zero, endPoint: CGPoint(x: 24, y: 32)
            ), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            context.stroke(detail, with: .color(selected ? UI01Material.goldLight : UI01Material.gold.opacity(0.85)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            if section == .today {
                context.fill(Path(ellipseIn: CGRect(x: 9, y: 7, width: 12, height: 12)), with: .color(selected ? UI01Material.gold : UI01Material.secondary))
            }
        }
        .frame(width: 28, height: 28)
        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}

struct UI01DockLabel: View {
    let section: AppSection
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            UI01DockInstrument(section: section, selected: selected)
            Text(section.title)
                .font(.custom("Baskerville", size: 12, relativeTo: .caption2))
                .foregroundStyle(selected ? UI01Material.goldLight : UI01Material.silver)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Circle().fill(selected ? UI01Material.goldGradient : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 5, height: 5)
                .accessibilityHidden(true)
        }
        // Navigation remains simultaneously available at accessibility sizes;
        // the full unabridged name is always exposed to VoiceOver.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .frame(maxWidth: .infinity, minHeight: 54)
        .contentShape(Rectangle())
    }
}
