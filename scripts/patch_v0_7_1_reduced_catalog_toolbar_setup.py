#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def patch_catalog() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.1 reduced production theme catalog"
    if marker in text:
        return

    required = [
        "v0.7.1 physical-device motion visibility repair",
        "static let phaseOneCoreGlassCatalog: [LifeRouteTheme]",
        "static let phaseTwoDynamicCatalog: [LifeRouteTheme]",
        "static let phaseThreeSceneryCatalog: [LifeRouteTheme]",
        "private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 reduced catalog patch failed: Build #98 runtime baseline missing {missing}")

    text = replace_once(
        text,
        '''    // v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog: exactly 12 approved live environments.
    static let phaseTwoDynamicCatalog: [LifeRouteTheme] = [
        .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse,
        .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber,
        .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow,
    ]''',
        '''    // v0.7.1 reduced production theme catalog: eight distinct live Dynamic identities.
    static let phaseTwoDynamicCatalog: [LifeRouteTheme] = [
        .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse,
        .emeraldFlow, .oceanGlass, .obsidianSpectra, .plasmaOrchid,
    ]''',
        "reduced Dynamic catalog",
    )

    text = replace_once(
        text,
        '''    // v0.7.0 Theme Phase 3 Scenery catalog: exactly 10 families × explicit Day/Night variants.
    static let phaseThreeSceneryCatalog: [LifeRouteTheme] = [
        .sceneryMountainsDay, .sceneryMountainsNight,
        .sceneryOceanDay, .sceneryOceanNight,
        .sceneryDesertDay, .sceneryDesertNight,
        .sceneryAlpineDay, .sceneryAlpineNight,
        .sceneryRainforestDay, .sceneryRainforestNight,
        .sceneryGrasslandDay, .sceneryGrasslandNight,
        .sceneryVolcanicDay, .sceneryVolcanicNight,
        .sceneryCanyonDay, .sceneryCanyonNight,
        .sceneryArcticDay, .sceneryArcticNight,
        .sceneryCoastalCliffsDay, .sceneryCoastalCliffsNight,
    ]''',
        '''    // v0.7.1 reduced production theme catalog: six scenery families × explicit Day/Night variants.
    static let phaseThreeSceneryCatalog: [LifeRouteTheme] = [
        .sceneryMountainsDay, .sceneryMountainsNight,
        .sceneryOceanDay, .sceneryOceanNight,
        .sceneryDesertDay, .sceneryDesertNight,
        .sceneryRainforestDay, .sceneryRainforestNight,
        .sceneryCanyonDay, .sceneryCanyonNight,
        .sceneryArcticDay, .sceneryArcticNight,
    ]''',
        "reduced Scenery catalog",
    )

    text = replace_once(
        text,
        '''        case "ember":
            return .sceneryVolcanicNight
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        '''        case "ember":
            return .sceneryVolcanicNight
        // v0.7.1 reduced production theme catalog: retired choices migrate to the nearest retained identity.
        case "dynamic.arcticHalo":
            return .oceanGlass
        case "dynamic.roseEmber":
            return .solarPulse
        case "dynamic.verdantMist":
            return .emeraldFlow
        case "dynamic.titaniumGlow":
            return .obsidianSpectra
        case "scenery.alpine.day":
            return .sceneryMountainsDay
        case "scenery.alpine.night":
            return .sceneryMountainsNight
        case "scenery.grassland.day":
            return .sceneryRainforestDay
        case "scenery.grassland.night":
            return .sceneryRainforestNight
        case "scenery.volcanic.day":
            return .sceneryDesertDay
        case "scenery.volcanic.night":
            return .sceneryDesertNight
        case "scenery.coastalCliffs.day":
            return .sceneryOceanDay
        case "scenery.coastalCliffs.night":
            return .sceneryOceanNight
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        "retired-theme migration",
    )

    APP.write_text(text, encoding="utf-8")


def patch_toolbar() -> None:
    text = SHELL.read_text(encoding="utf-8")
    marker = "v0.7.1 custom LifeRoute bottom toolbar"
    if marker in text:
        return

    required = [
        "v0.7.1 physical-device root environment reveal",
        "TabView(selection: $router.selectedSection)",
        ".tint(themeStore.palette.accent)",
        "extension LifeRouteAppearance {",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 custom toolbar patch failed: physical runtime shell missing {missing}")

    text = replace_once(
        text,
        "            .tint(themeStore.palette.accent)\n",
        '''            .tint(themeStore.palette.accent)
            // v0.8.1 paged root navigation: keep TabView/router ownership, replace only presentation.
            .tabViewStyle(.page(indexDisplayMode: .never))
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if router.shouldShowBottomToolbar {
                    LifeRouteBottomToolbar(
                        selection: $router.selectedSection,
                        palette: themeStore.palette
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
''',
        "custom toolbar host",
    )

    toolbar = r'''// v0.7.1 custom LifeRoute bottom toolbar: approved five-destination gold/navy direction.
private extension AppSection {
    var lifeRouteToolbarTitle: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Calendar"
        case .tools: return "Tools"
        case .resources: return "Resources"
        case .setup: return "Setup"
        }
    }
}

private struct LifeRouteBottomToolbar: View {
    @Binding var selection: AppSection
    let palette: LifeRouteThemePalette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppSection.allCases) { section in
                let selected = selection == section

                Button {
                    selection = section
                } label: {
                    VStack(spacing: 4) {
                        LifeRouteTabGlyph(
                            section: section,
                            color: selected ? palette.accentSecondary : palette.accent.opacity(0.78)
                        )
                        .frame(width: 30, height: 28)

                        Text(section.lifeRouteToolbarTitle)
                            .font(.system(size: 10.5, weight: selected ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 2)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            palette.accent.opacity(0.24),
                                            palette.accentSecondary.opacity(0.10),
                                            Color.white.opacity(0.035),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [palette.accentSecondary.opacity(0.88), palette.accent.opacity(0.45)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.25
                                        )
                                }
                                .shadow(color: palette.accent.opacity(0.34), radius: 10, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.lifeRouteToolbarTitle)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(palette.backgroundTop.opacity(0.38))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [palette.accentSecondary.opacity(0.62), Color.white.opacity(0.14), palette.accent.opacity(0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: palette.accent.opacity(0.16), radius: 16, y: 5)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }
}

private struct LifeRouteTabGlyph: View {
    let section: AppSection
    let color: Color

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 32
            let sy = size.height / 30
            let stroke = StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            func strokePath(_ path: Path) {
                context.stroke(path, with: .color(color), style: stroke)
            }

            switch section {
            case .today:
                var mountains = Path()
                mountains.move(to: point(2, 20))
                mountains.addLine(to: point(9, 11))
                mountains.addLine(to: point(15, 18))
                mountains.addLine(to: point(21, 10))
                mountains.addLine(to: point(30, 20))
                strokePath(mountains)

                var route = Path()
                route.move(to: point(5, 26))
                route.addCurve(to: point(17, 21), control1: point(9, 22), control2: point(12, 27))
                route.addCurve(to: point(23, 18), control1: point(19, 20), control2: point(21, 19))
                strokePath(route)

                var star = Path()
                star.move(to: point(18, 3))
                star.addLine(to: point(18, 8))
                star.move(to: point(15.5, 5.5))
                star.addLine(to: point(20.5, 5.5))
                strokePath(star)

            case .schedule:
                let rect = CGRect(x: 5 * sx, y: 5 * sy, width: 22 * sx, height: 20 * sy)
                strokePath(Path(roundedRect: rect, cornerRadius: 3.5 * sx))

                var header = Path()
                header.move(to: point(5, 10))
                header.addLine(to: point(27, 10))
                header.move(to: point(10, 3.5))
                header.addLine(to: point(10, 7))
                header.move(to: point(22, 3.5))
                header.addLine(to: point(22, 7))
                strokePath(header)

                for row in 0..<2 {
                    for column in 0..<3 {
                        let cx = CGFloat(10 + column * 6)
                        let cy = CGFloat(15 + row * 5)
                        let dot = CGRect(x: (cx - 0.9) * sx, y: (cy - 0.9) * sy, width: 1.8 * sx, height: 1.8 * sy)
                        context.fill(Path(ellipseIn: dot), with: .color(color))
                    }
                }

            case .tools:
                var tools = Path()
                tools.move(to: point(6, 24))
                tools.addLine(to: point(24, 6))
                tools.move(to: point(9, 5))
                tools.addLine(to: point(27, 23))
                tools.move(to: point(21.5, 5.5))
                tools.addLine(to: point(26, 4))
                tools.addLine(to: point(28, 6))
                tools.addLine(to: point(25, 9))
                tools.move(to: point(5, 7))
                tools.addLine(to: point(9, 4))
                tools.addLine(to: point(12, 7))
                strokePath(tools)

            case .resources:
                var book = Path()
                book.move(to: point(3, 7))
                book.addCurve(to: point(15.5, 9), control1: point(8, 5), control2: point(12, 6))
                book.addLine(to: point(15.5, 25))
                book.addCurve(to: point(3, 22), control1: point(11, 22), control2: point(7, 21))
                book.closeSubpath()
                book.move(to: point(29, 7))
                book.addCurve(to: point(16.5, 9), control1: point(24, 5), control2: point(20, 6))
                book.addLine(to: point(16.5, 25))
                book.addCurve(to: point(29, 22), control1: point(21, 22), control2: point(25, 21))
                book.closeSubpath()
                strokePath(book)

                var tree = Path()
                tree.move(to: point(23, 11))
                tree.addLine(to: point(20.5, 15))
                tree.addLine(to: point(22.2, 15))
                tree.addLine(to: point(20, 18.5))
                tree.addLine(to: point(26, 18.5))
                tree.addLine(to: point(23.8, 15))
                tree.addLine(to: point(25.5, 15))
                tree.closeSubpath()
                tree.move(to: point(23, 18.5))
                tree.addLine(to: point(23, 21))
                strokePath(tree)

            case .setup:
                let outer = CGRect(x: 5 * sx, y: 4 * sy, width: 22 * sx, height: 22 * sy)
                let inner = CGRect(x: 9 * sx, y: 8 * sy, width: 14 * sx, height: 14 * sy)
                strokePath(Path(ellipseIn: outer))
                strokePath(Path(ellipseIn: inner))

                var spokes = Path()
                for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                    let radians = angle * .pi / 180
                    let x1 = 16 + CGFloat(cos(radians)) * 11
                    let y1 = 15 + CGFloat(sin(radians)) * 11
                    let x2 = 16 + CGFloat(cos(radians)) * 13
                    let y2 = 15 + CGFloat(sin(radians)) * 13
                    spokes.move(to: point(x1, y1))
                    spokes.addLine(to: point(x2, y2))
                }
                strokePath(spokes)

                var needle = Path()
                needle.move(to: point(18.5, 10.5))
                needle.addLine(to: point(14.5, 17.5))
                needle.addLine(to: point(13.5, 19.5))
                needle.addLine(to: point(17.5, 12.5))
                needle.closeSubpath()
                strokePath(needle)
            }
        }
        .accessibilityHidden(true)
    }
}

'''

    text = replace_once(
        text,
        "extension LifeRouteAppearance {",
        toolbar + "extension LifeRouteAppearance {",
        "custom toolbar component",
    )

    SHELL.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    marker = "v0.7.1 Setup disclosure groups"
    if marker in text:
        return

    required = [
        "v0.7.0 Build E Setup Control Center",
        "private var weeklyTodosCard: some View",
        "private var addTodoCard: some View",
        "routingState.addTodo(",
        "routingState.addSavedPlace(",
        "routingState.removeSavedPlace(id: place.id)",
        "V054ClientProfilesView(clientState: clientState)",
        "V054ThemeCenterView()",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 Setup declutter patch failed: Build E Setup baseline missing {missing}")

    disclosure = r'''// v0.7.1 Setup disclosure groups: keep every existing control, reduce simultaneous visual load.
private struct LifeRouteSetupDisclosureGroup<Content: View>: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
                LifeRouteHaptics.selection()
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.accent.opacity(isExpanded ? 0.18 : 0.10))
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isExpanded ? palette.accentSecondary : palette.accent)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(isExpanded ? "expanded" : "collapsed")")

            if isExpanded {
                VStack(spacing: 10) {
                    content
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(palette.panel.opacity(0.54), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(isExpanded ? 0.20 : 0.10), lineWidth: 1)
        }
    }
}

'''

    text = replace_once(
        text,
        "struct V054SetupView: View {",
        disclosure + "struct V054SetupView: View {",
        "Setup disclosure component",
    )

    text = replace_once(
        text,
        "    @State private var message: String?\n",
        '''    @State private var message: String?

    // v0.7.1 Setup disclosure groups: Appearance is immediately useful; heavier sections start collapsed.
    @State private var appearanceExpanded = true
    @State private var profileExpanded = false
    @State private var navigationExpanded = false
    @State private var todosExpanded = false
    @State private var clinicalExpanded = false
    @State private var privacyExpanded = false
''',
        "Setup disclosure state",
    )

    body = r'''    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                hero

                LifeRouteSetupDisclosureGroup(
                    title: "Appearance",
                    subtitle: themeStore.selectedTheme.name,
                    systemImage: "sparkles",
                    isExpanded: $appearanceExpanded
                ) {
                    themeCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Profile & Work",
                    subtitle: rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "RBT identity and organization" : rbtName,
                    systemImage: "person.crop.circle.badge.checkmark",
                    isExpanded: $profileExpanded
                ) {
                    rbtProfileCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Navigation & Places",
                    subtitle: "\(preferredNavigationApp.title) · \(routingState.savedPlaces.count) saved places",
                    systemImage: "location.north.line.fill",
                    isExpanded: $navigationExpanded
                ) {
                    navigationAppCard
                    homeCard
                    savedPlacesCard
                    addPlaceCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Weekly To-Dos",
                    subtitle: "Recurring planning and destinations",
                    systemImage: "checklist",
                    isExpanded: $todosExpanded
                ) {
                    weeklyTodosCard
                    addTodoCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Clinical",
                    subtitle: clientState.clients.isEmpty ? "Client profiles" : "\(clientState.clients.count) saved client profiles",
                    systemImage: "person.2.fill",
                    isExpanded: $clinicalExpanded
                ) {
                    clientCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Privacy",
                    subtitle: "Local-first storage details",
                    systemImage: "lock.shield.fill",
                    isExpanded: $privacyExpanded
                ) {
                    privacyCard
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if homeDraft.isEmpty { homeDraft = routingState.homeAddress }
        }
    }

'''

    text = replace_region(
        text,
        "    var body: some View {",
        "    private var hero: some View {",
        body,
        "decluttered Setup body",
    )

    SETUP.write_text(text, encoding="utf-8")


def main() -> None:
    patch_catalog()
    patch_toolbar()
    patch_setup()
    print(
        "LifeRoute v0.7.1 reduced-catalog/toolbar/Setup patch applied: the visible theme library is now "
        "12 Core + 8 Dynamic + 12 Scenery, retired selections migrate safely, the existing five-tab router "
        "uses the approved custom LifeRoute gold/navy toolbar with hand-drawn SwiftUI glyphs, and Setup keeps "
        "all existing actions inside independently expandable disclosure groups with Appearance open by default."
    )


if __name__ == "__main__":
    main()
