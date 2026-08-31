import SwiftUI
import UIKit

enum LifeRouteDesign {
    // v0.7.0 Build A design system: compact premium geometry shared by every later screen family.
    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 18
        static let hero: CGFloat = 26
        static let iconContainer: CGFloat = 12
    }

    enum Layout {
        static let pageHorizontal: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let minimumTouchTarget: CGFloat = 44
        static let primaryControlHeight: CGFloat = 50
        static let secondaryControlHeight: CGFloat = 46
    }

    enum Stroke {
        static let subtle: CGFloat = 1
    }

    enum Elevation {
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
    }
}
@MainActor
enum LifeRouteHaptics {
    private final class GeneratorPool {
        weak var hostView: UIView?
        var primaryAction: UIImpactFeedbackGenerator?
        var selection: UISelectionFeedbackGenerator?
        var success: UINotificationFeedbackGenerator?
    }

    private static let generators = GeneratorPool()

    static func primaryAction() {
        prepareGenerators()
        guard let generator = generators.primaryAction else { return }
        generator.prepare()
        generator.impactOccurred(intensity: 0.78)
        generator.prepare()
    }

    static func selection() {
        prepareGenerators()
        guard let generator = generators.selection else { return }
        generator.prepare()
        generator.selectionChanged()
        generator.prepare()
    }

    static func success() {
        prepareGenerators()
        guard let generator = generators.success else { return }
        generator.prepare()
        generator.notificationOccurred(.success)
        generator.prepare()
    }

    private static func prepareGenerators() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if #available(iOS 17.5, *),
           LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(version),
           let hostView = foregroundHostView() {
            guard generators.hostView !== hostView
                    || generators.primaryAction == nil
                    || generators.selection == nil
                    || generators.success == nil else { return }

            generators.hostView = hostView
            generators.primaryAction = UIImpactFeedbackGenerator(style: .light, view: hostView)
            generators.selection = UISelectionFeedbackGenerator(view: hostView)
            generators.success = UINotificationFeedbackGenerator(view: hostView)
            return
        }

        guard generators.hostView != nil
                || generators.primaryAction == nil
                || generators.selection == nil
                || generators.success == nil else { return }

        generators.hostView = nil
        generators.primaryAction = UIImpactFeedbackGenerator(style: .light)
        generators.selection = UISelectionFeedbackGenerator()
        generators.success = UINotificationFeedbackGenerator()
    }

    private static func foregroundHostView() -> UIView? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        for scene in scenes {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            if let visibleWindow = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 }) {
                return visibleWindow
            }
        }
        return nil
    }
}

struct LifeRouteCardModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(LifeRouteDesign.Spacing.comfortable)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.panelElevated.opacity(0.30),
                                    palette.panel.opacity(0.16),
                                    palette.accent.opacity(0.025),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                palette.accentSecondary.opacity(0.14),
                                palette.accent.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: LifeRouteDesign.Stroke.subtle
                    )
            }
            .shadow(color: Color.black.opacity(0.20), radius: LifeRouteDesign.Elevation.cardRadius, y: LifeRouteDesign.Elevation.cardY)
    }
}

struct LifeRouteReadableTextSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeRoutePalette) private var palette

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let elevatedOpacity: Double = reduceTransparency ? 0.98 : (colorSchemeContrast == .increased ? 0.92 : 0.82)
        let panelOpacity: Double = reduceTransparency ? 0.96 : (colorSchemeContrast == .increased ? 0.84 : 0.70)

        content
            .scrollContentBackground(.hidden)
            .padding(8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(reduceTransparency ? AnyShapeStyle(palette.panelElevated) : AnyShapeStyle(.regularMaterial))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.panelElevated.opacity(elevatedOpacity),
                                    palette.panel.opacity(panelOpacity),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(colorSchemeContrast == .increased ? 0.24 : 0.14), lineWidth: 0.8)
            }
    }
}

struct LifeRoutePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.78))
            .frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.primaryControlHeight)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.accentGradient))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(Color.white.opacity(0.23), lineWidth: 0.8) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 7 : 11, y: configuration.isPressed ? 2 : 4)
            .opacity(configuration.isPressed ? 0.86 : (isEnabled ? 1 : 0.48))
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct LifeRouteSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.secondaryControlHeight)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.panelElevated.opacity(configuration.isPressed ? 0.94 : 0.68)))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(palette.accent.opacity(configuration.isPressed ? 0.46 : 0.28), lineWidth: 1) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.03 : 0.07), radius: 7, y: 3)
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - v0.7.0 Build A reusable visual primitives

enum LifeRouteBrandMarkVariant {
    case master
    case standard
    case small
    case micro
}

struct LifeRouteBrandMark: View {
    let variant: LifeRouteBrandMarkVariant

    private let navyDeep = Color(red: 0.008, green: 0.027, blue: 0.075)
    private let navyMid = Color(red: 0.025, green: 0.105, blue: 0.22)
    private let navyLift = Color(red: 0.06, green: 0.22, blue: 0.37)
    private let gold = Color(red: 0.88, green: 0.65, blue: 0.23)
    private let goldBright = Color(red: 1.00, green: 0.86, blue: 0.45)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [navyDeep, navyMid, navyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if variant != .micro {
                    brandTopo(size: proxy.size)
                        .stroke(navyLift.opacity(variant == .master ? 0.34 : 0.20), lineWidth: max(0.7, side * 0.012))
                    brandMountains(size: proxy.size)
                        .fill(navyLift.opacity(variant == .small ? 0.34 : 0.48))
                }

                brandRoute(size: proxy.size)
                    .stroke(gold.opacity(0.24), style: StrokeStyle(lineWidth: max(3, side * 0.12), lineCap: .round, lineJoin: .round))
                    .blur(radius: variant == .micro ? 0.5 : side * 0.035)

                brandRoute(size: proxy.size)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: max(1.5, side * 0.047), lineCap: .round, lineJoin: .round)
                    )

                Text("LR")
                    .font(.system(size: side * (variant == .micro ? 0.48 : 0.52), weight: .black, design: .serif))
                    .tracking(-side * 0.045)
                    .foregroundStyle(
                        LinearGradient(colors: [goldBright, gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.56), radius: max(1, side * 0.025), y: side * 0.018)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.47)

                Image(systemName: "mappin")
                    .font(.system(size: side * (variant == .micro ? 0.18 : 0.20), weight: .black))
                    .foregroundStyle(goldBright)
                    .shadow(color: .black.opacity(0.46), radius: max(1, side * 0.018), y: 1)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.34)

                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold, goldBright], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(1, side * 0.025)
                    )
                    .padding(max(1.5, side * 0.045))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute logo")
    }

    private func brandMountains(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.73))
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.31, y: size.height * 0.66))
            path.addLine(to: CGPoint(x: size.width * 0.47, y: size.height * 0.49))
            path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width * 0.79, y: size.height * 0.52))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.69))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func brandTopo(size: CGSize) -> Path {
        Path { path in
            for index in 0..<4 {
                let y = size.height * (0.18 + CGFloat(index) * 0.12)
                path.move(to: CGPoint(x: -size.width * 0.08, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width * 1.08, y: y + size.height * 0.035),
                    control1: CGPoint(x: size.width * 0.26, y: y + size.height * 0.07),
                    control2: CGPoint(x: size.width * 0.72, y: y - size.height * 0.06)
                )
            }
        }
    }

    private func brandRoute(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.92))
            path.addCurve(
                to: CGPoint(x: size.width * 0.40, y: size.height * 0.69),
                control1: CGPoint(x: size.width * 0.29, y: size.height * 0.84),
                control2: CGPoint(x: size.width * 0.37, y: size.height * 0.77)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.60, y: size.height * 0.55),
                control1: CGPoint(x: size.width * 0.45, y: size.height * 0.60),
                control2: CGPoint(x: size.width * 0.58, y: size.height * 0.62)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.50, y: size.height * 0.40),
                control1: CGPoint(x: size.width * 0.64, y: size.height * 0.49),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.44)
            )
        }
    }
}

struct LifeRouteIconBadge: View {
    @Environment(\.lifeRoutePalette) private var palette
    let systemImage: String
    var prominent = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(prominent ? palette.accent : palette.textPrimary)
            .frame(width: LifeRouteDesign.Layout.minimumTouchTarget, height: LifeRouteDesign.Layout.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .fill(prominent ? palette.accent.opacity(0.14) : palette.panelElevated.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .stroke(prominent ? palette.accent.opacity(0.28) : Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
            }
    }
}

struct LifeRouteScreenHeader: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                LifeRouteIconBadge(systemImage: systemImage, prominent: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LifeRouteModalChromeModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.backgroundGradient.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .tint(palette.accent)
    }
}

extension View {
    func lifeRouteModalChrome() -> some View {
        modifier(LifeRouteModalChromeModifier())
    }
}

struct LifeRouteThemeArtwork: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            let symbols = theme.artworkSymbols
            ZStack {
                Image(systemName: symbols.primary)
                    .font(.system(size: compact ? max(38, proxy.size.height * 0.56) : max(110, proxy.size.width * 0.38), weight: .black))
                    .foregroundStyle(palette.accent.opacity(compact ? 0.32 : 0.075))
                    .rotationEffect(.degrees(primaryRotation))
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * (compact ? 0.52 : 0.30))

                Image(systemName: symbols.secondary)
                    .font(.system(size: compact ? max(25, proxy.size.height * 0.34) : max(82, proxy.size.width * 0.27), weight: .bold))
                    .foregroundStyle(palette.accentSecondary.opacity(compact ? 0.22 : 0.055))
                    .rotationEffect(.degrees(secondaryRotation))
                    .position(x: proxy.size.width * 0.24, y: proxy.size.height * (compact ? 0.64 : 0.72))

                Circle()
                    .fill(palette.accentSecondary.opacity(compact ? 0.12 : 0.055))
                    .frame(width: compact ? 34 : 120, height: compact ? 34 : 120)
                    .blur(radius: compact ? 8 : 28)
                    .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.16)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var primaryRotation: Double {
        switch theme {
        case .carbon, .slate: return -12
        case .aurora, .sapphireTide: return 8
        case .electricStorm, .solarFlare: return -8
        default: return 0
        }
    }

    private var secondaryRotation: Double {
        switch theme {
        case .obsidian, .titanium, .phantomSilver: return 18
        case .forest, .plum: return -10
        default: return 0
        }
    }
}
