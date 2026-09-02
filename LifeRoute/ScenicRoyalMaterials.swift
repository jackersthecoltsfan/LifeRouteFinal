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
/// A deliberately isolated, non-persistent Liquid Glass comparison surface.
/// It is reachable only from `-LifeRouteGlassLab` and never participates in
/// the production surface-role migration.
enum LifeRouteGlassLabCandidate: String, CaseIterable, Identifiable {
    case clear = "clear"
    case regular = "regular"
    case material = "material"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: return "A · Clear"
        case .regular: return "B · Regular"
        case .material: return "C · Material"
        }
    }

    var summary: String {
        switch self {
        case .clear: return "Glass.clear + one bounded legibility underlay"
        case .regular: return "Glass.regular + restrained theme tint"
        case .material: return "ultraThinMaterial fallback"
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

    var assetName: String {
        switch self {
        case .bright: return "SceneryCanyonDay"
        case .dark: return "SceneryCanyonNight"
        }
    }
}

enum LifeRouteGlassLabLaunch {
    struct Selection {
        let candidate: LifeRouteGlassLabCandidate
        let scene: LifeRouteGlassLabScene
    }

    static var current: Selection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-LifeRouteGlassLab") else { return nil }

        return Selection(
            candidate: value(after: "-LifeRouteGlassLabCandidate", in: arguments)
                .flatMap(LifeRouteGlassLabCandidate.init(rawValue:)) ?? .clear,
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

    @State private var candidate: LifeRouteGlassLabCandidate
    @State private var scene: LifeRouteGlassLabScene
    @State private var actionMessage = "No selection is persisted."

    init(
        initialCandidate: LifeRouteGlassLabCandidate = .clear,
        initialScene: LifeRouteGlassLabScene = .bright
    ) {
        _candidate = State(initialValue: initialCandidate)
        _scene = State(initialValue: initialScene)
    }

    var body: some View {
        ZStack {
            Image(scene.assetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    switchingControls
                    sample
                    Text(actionMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .accessibilityIdentifier("lifeRoute.glassLab")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Liquid Glass Lab")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("DEBUG ONLY · compare one material recipe over real scenery")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
        }
        .accessibilityElement(children: .combine)
    }

    private var switchingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Candidate", selection: $candidate) {
                ForEach(LifeRouteGlassLabCandidate.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lifeRoute.glassLab.candidatePicker")

            Picker("Scenery", selection: $scene) {
                ForEach(LifeRouteGlassLabScene.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lifeRoute.glassLab.scenePicker")

            Text(candidate.summary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private var sample: some View {
        VStack(alignment: .leading, spacing: 14) {
            majorGroup

            ScenicRoyalGlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    focalButton
                    selectedControl
                }
            }
        }
    }

    private var majorGroup: some View {
        majorGroupSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(labAccent)
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Major group")
                            .font(.headline.weight(.bold))
                        Text("Header · one bounded material owner")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(labSecondaryText)
                    }
                }

                Divider()
                    .overlay(labAccent.opacity(0.32))

                passiveRow(title: "Passive row", detail: "Transparent content inside the group")
                passiveRow(title: "Passive row", detail: "No independent glass, material, or shadow")
            }
            .foregroundStyle(labPrimaryText)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeRoute.glassLab.majorGroup")
    }

    private func passiveRow(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(labAccent.opacity(0.75))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(labSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lifeRoute.glassLab.passiveRow")
    }

    private var focalButton: some View {
        Button {
            actionMessage = "Focal action stays local to this DEBUG lab."
        } label: {
            Label("Focal action", systemImage: "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .controlSurface(
            candidate: candidate,
            accent: labAccent,
            selected: false,
            reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased
        )
        .accessibilityIdentifier("lifeRoute.glassLab.focalButton")
    }

    private var selectedControl: some View {
        Button {
            actionMessage = "Selected control treatment is intentionally stronger."
        } label: {
            Label("Selected", systemImage: "checkmark")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .controlSurface(
            candidate: candidate,
            accent: labAccent,
            selected: true,
            reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased
        )
        .accessibilityAddTraits(.isSelected)
        .accessibilityIdentifier("lifeRoute.glassLab.selectedControl")
    }

    private var labAccent: Color {
        scene == .bright ? Color(red: 0.06, green: 0.34, blue: 0.48) : Color(red: 0.42, green: 0.72, blue: 0.92)
    }

    private var labPrimaryText: Color { .white }
    private var labSecondaryText: Color { .white.opacity(0.78) }

    @ViewBuilder
    private func majorGroupSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if reduceTransparency || contrast == .increased {
            content()
                .padding(20)
                .background(Color.black.opacity(0.76), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.30), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            switch candidate {
            case .clear:
                content()
                    .padding(20)
                    .background {
                        shape.fill(Color.black.opacity(0.10))
                    }
                    .glassEffect(.clear, in: .rect(cornerRadius: 26))
            case .regular:
                content()
                    .padding(20)
                    .glassEffect(.regular.tint(labAccent.opacity(0.16)), in: .rect(cornerRadius: 26))
            case .material:
                content()
                    .padding(20)
                    .background(.ultraThinMaterial, in: shape)
            }
        } else {
            content()
                .padding(20)
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

private extension View {
    @ViewBuilder
    func controlSurface(
        candidate: LifeRouteGlassLabCandidate,
        accent: Color,
        selected: Bool,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if reduceTransparency || increasedContrast {
            self
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.76), in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.30), lineWidth: 1)
                }
        } else if #available(iOS 26.0, *) {
            switch candidate {
            case .clear:
                let base: Glass = selected ? .regular : .clear
                self
                    .foregroundStyle(.white)
                    .glassEffect(
                        base
                            .tint(accent.opacity(selected ? 0.18 : 0.02))
                            .interactive(),
                        in: .rect(cornerRadius: 18)
                    )
            case .regular:
                self
                    .foregroundStyle(.white)
                    .glassEffect(
                        .regular.tint(accent.opacity(selected ? 0.26 : 0.16)).interactive(),
                        in: .rect(cornerRadius: 18)
                    )
            case .material:
                self
                    .foregroundStyle(.white)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape.stroke(accent.opacity(selected ? 0.34 : 0.18), lineWidth: 1)
                    }
            }
        } else {
            self
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(accent.opacity(selected ? 0.34 : 0.18), lineWidth: 1)
                }
        }
    }
}
#endif
