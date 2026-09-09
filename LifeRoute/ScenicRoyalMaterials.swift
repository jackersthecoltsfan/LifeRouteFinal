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

/// The single selected-state surface language. It keeps functional selection
/// separate from a scenery's decorative accent while allowing every selected
/// control shape to clip the same day/night treatment.
struct ScenicRoyalSelectedControlMaterial<Form: Shape>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let shape: Form

    var body: some View {
        ZStack {
            shape.fill(style.selectedControlFill)

            if style.isBrightEnvironment {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color.white.opacity(0.86),
                            style.selectedControlDayEdge.opacity(0.20),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(
                    LinearGradient(
                        colors: [
                            ScenicRoyalDesignSystem.ColorToken.selectedControlNightEdge,
                            ScenicRoyalDesignSystem.ColorToken.selectedControlNightInnerGlow.opacity(0.72),
                            ScenicRoyalDesignSystem.ColorToken.selectedControlNightFill,
                            ScenicRoyalDesignSystem.ColorToken.selectedControlNightEdge,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                shape.fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.035),
                            .clear,
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
            }

            // Theme reflection coordinates emphasis without replacing the
            // legible base or changing the selected foreground contract.
            shape.fill(
                RadialGradient(
                    colors: [style.accent.opacity(0.14), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 110
                )
            )

            if style.isBrightEnvironment {
                shape.stroke(
                    style.selectedControlIndicator.opacity(0.34),
                    lineWidth: ScenicRoyalDesignSystem.Stroke.selected
                )
            } else {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.36),
                            ScenicRoyalDesignSystem.ColorToken.selectedControlNightInnerGlow.opacity(0.56),
                            Color.black.opacity(0.46),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: ScenicRoyalDesignSystem.Stroke.selected
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension ScenicRoyalThemeStyle {
    var selectedControlDayEdge: Color {
        ScenicRoyalDesignSystem.ColorToken.brandNavy
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
                    surfaceShape.fill(style.accessibleSurfaceFill.opacity(accessibleSurfaceOpacity))
                },
                opaque: true
            )
        } else if role == .majorGroup, #available(iOS 26.0, *) {
            // The physical OFF/OFF verdict selected raw Clear glass for
            // ordinary groups in both scenery states. Keep exactly one
            // neutral legibility underlay and no theme decoration or shadow;
            // bright/day scenery receives the bounded readability floor.
            content
                .background {
                    surfaceShape.fill(Color.black.opacity(majorGroupUnderlayOpacity))
                }
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else if role.usesNativeGlass, #available(iOS 26.0, *) {
            decorated(
                content
                    .background {
                        if role == .majorGroup || role == .control {
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

    private var majorGroupUnderlayOpacity: Double {
        style.isBrightEnvironment
            ? ScenicRoyalDesignSystem.Opacity.brightMajorGroupUnderlay
            : ScenicRoyalDesignSystem.Opacity.standardMajorGroupUnderlay
    }

    private var glassTintOpacity: Double {
        style.glassTintOpacity * role.tintMultiplier
    }

    @available(iOS 26.0, *)
    private var emphasizedNativeGlass: Glass {
        let base: Glass
        switch role {
        case .selectedControl, .focalControl:
            base = .regular
        case .majorGroup, .control, .passiveRow:
            base = .clear
        }
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

#if DEBUG
/// A deliberately isolated, non-persistent legibility comparison surface.
/// It is reachable only from `-LifeRouteGlassLab` and never participates in
/// the production surface-role migration. The physically selected material
/// policy is fixed while V2 varies only a neutral dimming underlay.
enum LifeRouteGlassLabCandidate: String, CaseIterable, Identifiable {
    case l0
    case l1
    case l2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .l0: return "L0 — No underlay"
        case .l1: return "L1 — Extremely light"
        case .l2: return "L2 — Slightly stronger"
        }
    }

    var summary: String {
        switch self {
        case .l0: return "0% neutral dimming"
        case .l1: return "3.5% neutral dimming"
        case .l2: return "7% neutral dimming"
        }
    }

    var dimmingOpacity: Double {
        switch self {
        case .l0: return 0
        case .l1: return ScenicRoyalDesignSystem.Opacity.standardMajorGroupUnderlay
        case .l2: return 0.07
        }
    }
}

enum LifeRouteGlassLabScene: String, CaseIterable, Identifiable {
    case bright = "bright"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bright: return "Bright · Canyon Day"
        case .dark: return "Dark · Canyon Night"
        }
    }

    var pickerTitle: String {
        switch self {
        case .bright: return "Bright"
        case .dark: return "Dark"
        }
    }

    var assetName: String {
        switch self {
        case .bright: return "SceneryCanyonDay"
        case .dark: return "SceneryCanyonNight"
        }
    }

    var theme: LifeRouteTheme {
        switch self {
        case .bright: return .sceneryCanyonDay
        case .dark: return .sceneryCanyonNight
        }
    }

    var selectedMaterialTitle: String {
        "A — Glass.clear"
    }
}

enum LifeRouteGlassLabLaunch {
    struct Selection {
        let scene: LifeRouteGlassLabScene
    }

    static var current: Selection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-LifeRouteGlassLab") else { return nil }

        return Selection(
            scene: value(after: "-LifeRouteGlassLabScene", in: arguments)
                .flatMap(LifeRouteGlassLabScene.init(rawValue:)) ?? .bright
        )
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}

struct LifeRouteGlassLabView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var scene: LifeRouteGlassLabScene

    init(initialScene: LifeRouteGlassLabScene = .bright) {
        _scene = State(initialValue: initialScene)
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image(scene.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    accessibilityStatus
                    sceneControl
                    primaryComparison
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .accessibilityIdentifier("lifeRoute.glassLab")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Glass Lab V2 · Legibility")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text("LOCKED MATERIAL · \(scene.selectedMaterialTitle)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .accessibilityElement(children: .combine)
    }

    private var accessibilityStatus: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("System adaptation")
            Text(
                "Reduce Transparency: \(reduceTransparency ? "ON" : "OFF") · "
                    + "Increase Contrast: \(contrast == .increased ? "ON" : "OFF")"
            )
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("lifeRoute.glassLab.accessibilityStatus")
    }

    private var sceneControl: some View {
        Picker("Scenery", selection: $scene) {
            ForEach(LifeRouteGlassLabScene.allCases) { option in
                Text(option.pickerTitle).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("lifeRoute.glassLab.scenePicker")
    }

    private var primaryComparison: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(LifeRouteGlassLabCandidate.allCases) { candidate in
                candidateSample(candidate)
            }
        }
        .accessibilityIdentifier("lifeRoute.glassLab.primaryComparison")
    }

    private func candidateSample(_ candidate: LifeRouteGlassLabCandidate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            VStack(alignment: .leading, spacing: 0) {
                Text(candidate.title)
                    .font(.caption.weight(.heavy))
                Text(candidate.summary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.80))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)

            candidateSurface(candidate) {
                identicalContent
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeRoute.glassLab.candidate.\(candidate.rawValue)")
    }

    private var identicalContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Major group")
                    .font(.subheadline.weight(.bold))
                Text("Passive row · identical content")
                    .font(.caption)
                Text("Passive row · no nested material")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {} label: {
                    Label("Focal", systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .labGlassControl(selected: false)

                Button {} label: {
                    Label("Selected", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .labGlassControl(selected: true)
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func candidateSurface<Content: View>(
        _ candidate: LifeRouteGlassLabCandidate,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        if #available(iOS 26.0, *) {
            legibilityUnderlay(candidate, shape: shape, content: content)
                .glassEffect(.clear, in: .rect(cornerRadius: 22))
        } else {
            legibilityUnderlay(candidate, shape: shape, content: content)
                .overlay(shape.stroke(Color.white.opacity(0.34), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    private func legibilityUnderlay<Content: View>(
        _ candidate: LifeRouteGlassLabCandidate,
        shape: RoundedRectangle,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if candidate.dimmingOpacity == 0 {
            content()
        } else {
            content()
                .background(Color.black.opacity(candidate.dimmingOpacity), in: shape)
        }
    }
}

private extension View {
    @ViewBuilder
    func labGlassControl(selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                .overlay {
                    if selected {
                        shape.stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                    }
                }
        } else {
            self
                .foregroundStyle(.white)
                .overlay {
                    shape.stroke(Color.white.opacity(selected ? 0.28 : 0.18), lineWidth: 0.8)
                }
        }
    }
}
#endif
