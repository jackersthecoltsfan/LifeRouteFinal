#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Theme Phase 1 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.0 Theme Phase 1 patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def patch_theme_model() -> None:
    text = APP.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 1 Core Glass catalog" in text:
        return

    required = [
        "final class LifeRouteThemeStore: ObservableObject",
        "private struct LifeRouteChromeModifier: ViewModifier",
        "struct LifeRouteCardModifier: ViewModifier",
        "struct LifeRoutePageBackground: View",
        "case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible",
        "case .accessible: return \"Accessible\"",
        "case .accessible: return (\"accessibility\", \"circle.fill\")",
        "case .accessible: return makeThemePalette(0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff, textPrimary: .white, textSecondary: .white)",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 1 patch failed: materialized theme baseline missing {missing}")

    text = replace_once(
        text,
        "    case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible\n",
        "    case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible\n"
        "    // v0.7.0 Theme Phase 1 Core Glass catalog uses stable identifiers that cannot collide\n"
        "    // with the retained legacy Dynamic/Scenery identifiers.\n"
        "    case coreOcean = \"core.ocean\"\n"
        "    case coreAurora = \"core.aurora\"\n"
        "    case coreSolarFlare = \"core.solarFlare\"\n"
        "    case coreUltraviolet = \"core.ultraviolet\"\n"
        "    case emerald = \"core.emerald\"\n"
        "    case roseQuartz = \"core.roseQuartz\"\n"
        "    case arctic = \"core.arctic\"\n"
        "    case coreEmber = \"core.ember\"\n",
        "new stable Core identifiers",
    )

    text = replace_once(
        text,
        "    case coreEmber = \"core.ember\"\n\n    var id: String { rawValue }\n",
        "    case coreEmber = \"core.ember\"\n\n"
        "    var id: String { rawValue }\n\n"
        "    // v0.7.0 Theme Phase 1 Core Glass catalog: exactly the 12 approved still environments.\n"
        "    static let phaseOneCoreGlassCatalog: [LifeRouteTheme] = [\n"
        "        .royal, .obsidian, .midnight, .titanium,\n"
        "        .coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet,\n"
        "        .emerald, .roseQuartz, .arctic, .coreEmber,\n"
        "    ]\n\n"
        "    var isPhaseOneCoreGlass: Bool {\n"
        "        Self.phaseOneCoreGlassCatalog.contains(self)\n"
        "    }\n",
        "approved Core catalog",
    )

    text = replace_once(
        text,
        '''        case .accessible: return "Accessible"
        }''',
        '''        case .accessible: return "Accessible"
        case .coreOcean: return "Ocean"
        case .coreAurora: return "Aurora"
        case .coreSolarFlare: return "Solar Flare"
        case .coreUltraviolet: return "Ultraviolet"
        case .emerald: return "Emerald"
        case .roseQuartz: return "Rose Quartz"
        case .arctic: return "Arctic"
        case .coreEmber: return "Ember"
        }''',
        "Core theme names",
    )

    old_core_category = "        case .royal, .obsidian, .carbon, .midnight, .navyNoir, .sunflare, .noir, .golden, .cobaltShine, .light, .dark, .kaleidoscope, .classic, .accessible: return .core"
    new_core_category = "        case .royal, .obsidian, .carbon, .midnight, .navyNoir, .sunflare, .noir, .golden, .cobaltShine, .light, .dark, .kaleidoscope, .classic, .accessible, .coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet, .emerald, .roseQuartz, .arctic, .coreEmber: return .core"
    text = replace_once(text, old_core_category, new_core_category, "new Core categories")

    text = replace_once(
        text,
        '''        case .accessible: return ("accessibility", "circle.fill")
        }''',
        '''        case .accessible: return ("accessibility", "circle.fill")
        case .coreOcean: return ("water.waves", "drop.fill")
        case .coreAurora: return ("wand.and.stars", "sparkles")
        case .coreSolarFlare: return ("sun.max.fill", "flame.fill")
        case .coreUltraviolet: return ("circle.hexagongrid.fill", "sparkles")
        case .emerald: return ("leaf.fill", "diamond.fill")
        case .roseQuartz: return ("diamond.fill", "sparkles")
        case .arctic: return ("snowflake", "circle.fill")
        case .coreEmber: return ("flame.fill", "circle.fill")
        }''',
        "Core artwork exhaustiveness",
    )

    text = replace_once(
        text,
        "        case .midnight: return makeThemePalette(0x080924, 0x24113f, 0x171333, 0x32265c, 0x7b68ff, 0xb8a5ff)",
        "        case .midnight: return makeThemePalette(0x050817, 0x071f46, 0x0d1730, 0x153964, 0x4e9eff, 0x99c8ff)",
        "Midnight luminous-blue palette",
    )

    text = replace_once(
        text,
        '''        case .accessible: return makeThemePalette(0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff, textPrimary: .white, textSecondary: .white)
        }''',
        '''        case .accessible: return makeThemePalette(0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff, textPrimary: .white, textSecondary: .white)
        case .coreOcean: return makeThemePalette(0x031923, 0x063e4e, 0x0a2b35, 0x115060, 0x34d1dc, 0x88f4e6)
        case .coreAurora: return makeThemePalette(0x120824, 0x35105b, 0x24103d, 0x4f1d75, 0xae5cff, 0xff78d1)
        case .coreSolarFlare: return makeThemePalette(0x2a0b05, 0x64170a, 0x3a120a, 0x78260d, 0xff7a2f, 0xffd060)
        case .coreUltraviolet: return makeThemePalette(0x0e0727, 0x271056, 0x1b103e, 0x3b1b70, 0x8d5bff, 0x4cc8ff)
        case .emerald: return makeThemePalette(0x041a15, 0x0c3b31, 0x082a22, 0x135246, 0x2ed3a6, 0x7cf4d2)
        case .roseQuartz: return makeThemePalette(0x251016, 0x4a1f31, 0x351824, 0x66314a, 0xe88aa6, 0xffc5d2)
        case .arctic: return makeThemePalette(0x071923, 0x173847, 0x102934, 0x245263, 0x8ee8ff, 0xe2f8ff)
        case .coreEmber: return makeThemePalette(0x240807, 0x57120d, 0x35100d, 0x6e1c13, 0xff4d32, 0xffa05d)
        }''',
        "new Core palettes",
    )

    store = r'''final class LifeRouteThemeStore: ObservableObject {
    // v0.7.0 Theme Phase 1 persistence: one owner, stable identifiers, deterministic legacy migration.
    private static let storageKey = "liferoute.selectedTheme"

    @Published var selectedTheme: LifeRouteTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
            LifeRouteAppearance.configure(theme: selectedTheme)
        }
    }

    init() {
        let savedIdentifier = UserDefaults.standard.string(forKey: Self.storageKey)
        let theme = Self.resolveStoredTheme(savedIdentifier)
        selectedTheme = theme
        if savedIdentifier != theme.rawValue {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        }
        LifeRouteAppearance.configure(theme: theme)
    }

    var palette: LifeRouteThemePalette { selectedTheme.palette }

    private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme {
        guard let identifier else { return .royal }

        // Retired Core/Metallic choices migrate to the closest approved Phase 1 still identity.
        // Existing Dynamic/Scenery identifiers remain valid and unchanged until their own phases.
        switch identifier {
        case "carbon", "noir", "dark", "accessible":
            return .obsidian
        case "navyNoir", "cobaltShine":
            return .midnight
        case "slate", "phantomSilver", "classic":
            return .titanium
        case "moltenGold", "golden", "sunflare":
            return .coreSolarFlare
        case "kaleidoscope":
            return .coreAurora
        case "light":
            return .arctic
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal
        }
    }
}

'''
    text = replace_region(
        text,
        "final class LifeRouteThemeStore: ObservableObject {",
        "private struct LifeRouteThemePaletteKey",
        store,
        "single theme owner and migration",
    )

    # Any historical per-page helper becomes transparent. The persistent environment is mounted once
    # by LifeRouteChromeModifier above ContentView, preventing tab/navigation scene duplication.
    page_background = r'''struct LifeRoutePageBackground: View {
    // v0.7.0 Theme Phase 1: page-level renderers are intentionally disabled.
    // The single persistent environment is owned above the five-tab shell.
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

'''
    text = replace_region(
        text,
        "struct LifeRoutePageBackground: View {",
        "struct LifeRouteSectionLabel: View {",
        page_background,
        "page background deduplication",
    )

    card = r'''struct LifeRouteCardModifier: ViewModifier {
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
                                    palette.panelElevated.opacity(0.44),
                                    palette.panel.opacity(0.26),
                                    palette.accent.opacity(0.035),
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

'''
    text = replace_region(
        text,
        "struct LifeRouteCardModifier: ViewModifier {",
        "struct LifeRoutePrimaryButtonStyle: ButtonStyle {",
        card,
        "app-wide glass card material",
    )

    environment = r'''struct LifeRouteCoreGlassEnvironment: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                palette.backgroundGradient

                RadialGradient(
                    colors: [palette.accent.opacity(0.22), palette.accent.opacity(0.05), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.72
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.13), .clear],
                    center: .bottomLeading,
                    startRadius: 8,
                    endRadius: max(size.width, size.height) * 0.62
                )

                Ellipse()
                    .fill(palette.accentSecondary.opacity(0.09))
                    .frame(width: size.width * 1.05, height: size.width * 0.46)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(glassAngle))
                    .offset(x: size.width * 0.34, y: -size.height * 0.22)

                RoundedRectangle(cornerRadius: max(36, size.width * 0.12), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.11),
                                palette.accentSecondary.opacity(0.055),
                                Color.white.opacity(0.015),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.width * 1.25, height: max(90, size.height * 0.18))
                    .blur(radius: 12)
                    .rotationEffect(.degrees(glassAngle - 9))
                    .offset(x: -size.width * 0.18, y: size.height * 0.18)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        .clear,
                        palette.accent.opacity(0.035),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var glassAngle: Double {
        switch theme {
        case .royal, .midnight, .coreOcean, .arctic:
            return -24
        case .obsidian, .titanium, .coreUltraviolet, .emerald:
            return 18
        case .coreAurora, .roseQuartz:
            return -12
        case .coreSolarFlare, .coreEmber:
            return 26
        default:
            return -18
        }
    }
}

private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        // v0.7.0 Theme Phase 1 persistent environment host: mounted once above ContentView.
        ZStack {
            if theme.isPhaseOneCoreGlass {
                LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                // Retain the already-validated Dynamic/Scenery rendering until Phases 2 and 3.
                LifeRouteCinematicBackdrop(theme: theme, palette: palette)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            content
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: theme)
        .environment(\.defaultMinListRowHeight, 52)
        .tint(palette.accent)
        .preferredColorScheme(theme == .light ? .light : .dark)
    }
}

'''
    text = replace_region(
        text,
        "private struct LifeRouteChromeModifier: ViewModifier {",
        "private struct LifeRouteThemeBackdrop: View {",
        environment,
        "persistent root environment",
    )

    APP.write_text(text, encoding="utf-8")


def patch_shell() -> None:
    text = SHELL.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 1 single environment shell" in text:
        return

    required = [
        "v0.7.0 Build A shell",
        "LifeRouteCinematicBackdrop(",
        "TabView(selection: $router.selectedSection)",
        ".background(Color.clear) // v0.6.3 keep cinematic scenery visible",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 1 patch failed: materialized shell baseline missing {missing}")

    text = replace_once(
        text,
        '''        ZStack {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.palette
            )
            .ignoresSafeArea()

            TabView(selection: $router.selectedSection) {''',
        '''        // v0.7.0 Theme Phase 1 single environment shell: background is mounted once by LifeRouteApp chrome.
        TabView(selection: $router.selectedSection) {''',
        "duplicate shell backdrop removal",
    )

    text = replace_once(
        text,
        '''            .tint(themeStore.palette.accent)
            .background(Color.clear) // v0.6.3 keep cinematic scenery visible
        }
        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)''',
        '''        .tint(themeStore.palette.accent)
        .background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment
        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)''',
        "single shell container",
    )

    SHELL.write_text(text, encoding="utf-8")


def patch_theme_center() -> None:
    text = THEMES.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 1 Theme Center" in text:
        return

    required = [
        "v0.7.0 Build E Theme Center",
        "v0.7.0 Build E validated theme catalog compatibility",
        "@EnvironmentObject private var themeStore: LifeRouteThemeStore",
        "themeStore.selectedTheme = theme",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 1 patch failed: Theme Center baseline missing {missing}")

    final = r'''import SwiftUI

struct V054ThemeCenterView: View {
    // v0.7.0 Theme Phase 1 Theme Center: approved Core Glass catalog over the single LifeRouteThemeStore.
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .core

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }
    }

    // Dynamic and Scenery remain the exact validated pre-Phase-1 catalogs until their dedicated phases.
    private let dynamicThemes: [LifeRouteTheme] = [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide]
    private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                selectedThemeHeader
                categoryStrip

                HStack {
                    LifeRouteSectionLabel(title: selectedCategory == .core ? "Core Glass" : selectedCategory.rawValue)
                    Spacer()
                    Text("\(filteredThemes.count)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredThemes) { theme in
                        themeCard(theme)
                    }
                }

                Label(
                    selectedCategory == .core
                        ? "Core Glass includes 12 still, app-wide environments with no continuous ambient motion."
                        : "This catalog is retained unchanged until its dedicated visual phase.",
                    systemImage: selectedCategory == .core ? "sparkles" : "clock.arrow.circlepath"
                )
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCategory = category(for: themeStore.selectedTheme)
        }
        .onChange(of: themeStore.selectedTheme) { theme in
            selectedCategory = category(for: theme)
        }
    }

    private var filteredThemes: [LifeRouteTheme] {
        switch selectedCategory {
        case .core:
            return LifeRouteTheme.phaseOneCoreGlassCatalog
        case .dynamic:
            return dynamicThemes
        case .scenery:
            return sceneryThemes
        }
    }

    private func category(for theme: LifeRouteTheme) -> ThemeFilter {
        if theme.isPhaseOneCoreGlass { return .core }
        if dynamicThemes.contains(theme) { return .dynamic }
        if sceneryThemes.contains(theme) { return .scenery }
        return .core
    }

    private var selectedThemeHeader: some View {
        HStack(spacing: 12) {
            themePreview(themeStore.selectedTheme)
                .frame(width: 82, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(themeStore.selectedTheme.palette.accent.opacity(0.42), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE THEME")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accentSecondary)
                Text(themeStore.selectedTheme.name)
                    .font(.title3.weight(.black))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(category(for: themeStore.selectedTheme).rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(palette.panel.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active theme, \(themeStore.selectedTheme.name), \(category(for: themeStore.selectedTheme).rawValue)")
    }

    private var categoryStrip: some View {
        HStack(spacing: 7) {
            ForEach(ThemeFilter.allCases) { filter in
                Button {
                    selectedCategory = filter
                    LifeRouteHaptics.selection()
                } label: {
                    LifeRoutePill(title: filter.rawValue, isSelected: selectedCategory == filter)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(minHeight: LifeRouteDesign.Layout.minimumTouchTarget)
                .accessibilityLabel("\(filter.rawValue) themes")
                .accessibilityValue(selectedCategory == filter ? "Selected" : "Not selected")
            }
        }
    }

    private func themeCard(_ theme: LifeRouteTheme) -> some View {
        let selected = themeStore.selectedTheme == theme
        let coreGlass = theme.isPhaseOneCoreGlass

        return Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    themePreview(theme)
                        .frame(height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if coreGlass {
                        Text("STILL")
                            .font(.system(size: 8, weight: .black))
                            .tracking(0.7)
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.horizontal, 6)
                            .frame(minHeight: 22)
                            .background(Color.black.opacity(0.30), in: Capsule())
                            .padding(7)
                    }

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(theme.palette.accentSecondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                Text(theme.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(coreGlass ? "CORE GLASS" : category(for: theme).rawValue.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
            }
            .padding(9)
            .background(selected ? palette.panelElevated.opacity(0.56) : palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.72) : Color.white.opacity(0.07), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 132)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private func themePreview(_ theme: LifeRouteTheme) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)
        } else {
            ZStack {
                theme.palette.backgroundGradient
                LifeRouteThemeArtwork(theme: theme, palette: theme.palette, compact: true)
            }
        }
    }
}
'''

    THEMES.write_text(final, encoding="utf-8")


def main() -> None:
    patch_theme_model()
    patch_shell()
    patch_theme_center()
    print(
        "LifeRoute v0.7.0 Theme Phase 1 applied: one persistent root environment now spans the five-tab native shell; duplicate shell/page renderers are removed; the 12 approved still Core Glass identities use stable persisted IDs with deterministic legacy migration; shared cards use translucent material treatment; and the validated Dynamic/Scenery catalogs remain available unchanged for later phases."
    )


if __name__ == "__main__":
    main()
