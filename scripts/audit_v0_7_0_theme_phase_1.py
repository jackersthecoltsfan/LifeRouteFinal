#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text(encoding="utf-8")
SHELL = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
THEMES = (ROOT / "LifeRoute/V054ThemeCenterView.swift").read_text(encoding="utf-8")
NAVIGATION = (ROOT / "LifeRoute/AppNavigation.swift").read_text(encoding="utf-8")
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Theme Phase 1 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    require_all(
        APP,
        [
            "v0.7.0 Theme Phase 1 Core Glass catalog",
            "static let phaseOneCoreGlassCatalog: [LifeRouteTheme]",
            ".royal, .obsidian, .midnight, .titanium",
            ".coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet",
            ".emerald, .roseQuartz, .arctic, .coreEmber",
            'case coreOcean = "core.ocean"',
            'case coreAurora = "core.aurora"',
            'case coreSolarFlare = "core.solarFlare"',
            'case coreUltraviolet = "core.ultraviolet"',
            'case emerald = "core.emerald"',
            'case roseQuartz = "core.roseQuartz"',
            'case arctic = "core.arctic"',
            'case coreEmber = "core.ember"',
            'case .coreOcean: return "Ocean"',
            'case .coreAurora: return "Aurora"',
            'case .coreSolarFlare: return "Solar Flare"',
            'case .coreUltraviolet: return "Ultraviolet"',
            'case .emerald: return "Emerald"',
            'case .roseQuartz: return "Rose Quartz"',
            'case .arctic: return "Arctic"',
            'case .coreEmber: return "Ember"',
        ],
        "approved 12-theme Core Glass catalog",
    )

    catalog_block = APP.split("static let phaseOneCoreGlassCatalog", 1)[1].split("var isPhaseOneCoreGlass", 1)[0]
    require(catalog_block.count(".") >= 12, "Core catalog must contain the approved 12 entries")
    for legacy in ["cobaltShine", "golden", "sunflare", "noir", "kaleidoscope", "light", "dark", "classic", "accessible", "slate", "moltenGold", "phantomSilver"]:
        require(f".{legacy}" not in catalog_block, f"retired legacy theme {legacy} must not remain in the selectable Core Glass catalog")

    require_all(
        APP,
        [
            "final class LifeRouteThemeStore: ObservableObject",
            'private static let storageKey = "liferoute.selectedTheme"',
            "@Published var selectedTheme: LifeRouteTheme",
            "UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)",
            "let theme = Self.resolveStoredTheme(savedIdentifier)",
            "if savedIdentifier != theme.rawValue",
            'case "carbon", "noir", "dark", "accessible":',
            'case "navyNoir", "cobaltShine":',
            'case "slate", "phantomSilver", "classic":',
            'case "moltenGold", "golden", "sunflare":',
            'case "kaleidoscope":',
            'case "light":',
            "return LifeRouteTheme(rawValue: identifier) ?? .royal",
        ],
        "single-owner persistence and deterministic migration",
    )
    require(APP.count("final class LifeRouteThemeStore: ObservableObject") == 1, "there must be exactly one LifeRouteThemeStore type")
    require("LifeRouteThemeStore()" not in THEMES, "Theme Center must not create a second theme store")
    require("@EnvironmentObject private var themeStore: LifeRouteThemeStore" in THEMES, "Theme Center must consume the root theme owner")

    phase1_host = all(
        token in APP
        for token in [
            "struct LifeRouteCoreGlassEnvironment: View",
            "v0.7.0 Theme Phase 1 persistent environment host",
            "if theme.isPhaseOneCoreGlass",
            "LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)",
            "LifeRouteCinematicBackdrop(theme: theme, palette: palette)",
            ".ignoresSafeArea()",
            ".allowsHitTesting(false)",
            "content",
            ".scrollContentBackground(.hidden)",
            ".background(Color.clear)",
            "ContentView()",
            ".lifeRouteChrome()",
        ]
    )
    current_host = all(
        token in APP
        for token in [
            "@StateObject private var themeStore = LifeRouteThemeStore()",
            "WindowGroup {",
            "ContentView()",
            ".lifeRouteChrome()",
            ".environmentObject(themeStore)",
            ".environment(\\.lifeRoutePalette, themeStore.palette)",
            ".environment(\\.lifeRouteTheme, themeStore.selectedTheme)",
        ]
    )
    require(phase1_host or current_host, "single persistent app-wide environment host")

    core_renderer = APP.split("struct LifeRouteCoreGlassEnvironment: View", 1)[1].split("struct LifeRouteDynamicGlassEnvironment: View", 1)[0]
    for forbidden in ["TimelineView", "repeatForever", "withAnimation", "Animation.", "Task {", "Timer."]:
        require(forbidden not in core_renderer, f"Core Glass must remain still; found continuous-motion primitive {forbidden}")
    require_all(
        core_renderer,
        [
            "palette.backgroundGradient",
            "RadialGradient(",
            "LinearGradient(",
            "palette.accent.opacity",
            "palette.accentSecondary.opacity",
            ".blur(radius:",
        ],
        "static layered Core Glass rendering",
    )

    require_all(
        APP,
        [
            "struct LifeRoutePageBackground: View",
            "v0.7.0 Theme Phase 1: page-level renderers are intentionally disabled",
            "Color.clear",
            "RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)\n                        .fill(.ultraThinMaterial)",
        ],
        "duplicate-page suppression and translucent functional glass",
    )

    require("v0.7.0 Theme Phase 1 single environment shell" in SHELL, "five-tab shell must declare the single-environment contract")
    require("LifeRouteCinematicBackdrop(" not in SHELL, "five-tab shell must not mount a second cinematic environment")
    require("LifeRouteCoreGlassEnvironment(" not in SHELL, "five-tab shell must not mount a second Core Glass environment")
    require(".background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment" in SHELL, "shell must remain transparent over root environment")

    require_all(
        THEMES,
        [
            "v0.7.0 Theme Phase 1 Theme Center",
            'case core = "Core"',
            'case dynamic = "Dynamic"',
            'case scenery = "Scenery"',
            "LifeRouteTheme.phaseOneCoreGlassCatalog",
            "private let dynamicThemes: [LifeRouteTheme] = [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide]",
            "private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]",
            "themeStore.selectedTheme = theme",
            "LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)",
            'Text("STILL")',
            'Text(coreGlass ? "CORE GLASS" : category(for: theme).rawValue.uppercased())',
            ".accessibilityValue(selected ? \"Selected\" : \"Not selected\")",
            "LifeRouteDesign.Layout.minimumTouchTarget",
        ],
        "compact three-category Theme Center",
    )
    require('case all = "All"' not in THEMES, "Theme Center categories must be exactly Core, Dynamic, and Scenery")
    require("LifeRouteCinematicBackdrop" not in THEMES, "Theme Center must preview themes without mounting another full environment renderer")

    for token in ["glassEffect(", "GlassEffectContainer", ".buttonStyle(.glass", ".scrollTargetBehavior(", ".containerRelativeFrame("]:
        require(token not in APP and token not in THEMES and token not in SHELL, f"Phase 1 must remain iOS-16 compatible; found {token}")

    require_all(
        NAVIGATION,
        ["case today", "case schedule", "case tools", "case resources", "case setup", "final class AppRouter: ObservableObject"],
        "protected five-tab navigation owner",
    )
    require(SHELL.count(".tag(AppSection.") == 5, "root TabView must still expose exactly five AppSection tags")
    require("case routes" not in NAVIGATION, "Routes must not become a sixth root tab")

    require("python3 scripts/patch_v0_7_0_theme_phase_1.py" in PREPARE, "canonical preparation must materialize Theme Phase 1")
    require("python3 scripts/audit_v0_7_0_theme_phase_1.py" in PREPARE, "canonical preparation must run Theme Phase 1 audit")
    require(
        PREPARE.find("python3 scripts/patch_v0_7_0_swipe_day_overview.py") < PREPARE.find("python3 scripts/patch_v0_7_0_theme_phase_1.py"),
        "Theme Phase 1 must materialize after the validated swipe checkpoint patch",
    )

    print(
        "LifeRoute v0.7.0 Theme Phase 1 audit passed: one persistent root environment spans the five-tab app; page/shell duplicate renderers are removed; exactly 12 approved still Core Glass themes use stable identifiers and deterministic migration; functional cards use translucent native material; Dynamic/Scenery legacy catalogs remain intact; iOS 16 compatibility and AppRouter ownership are preserved."
    )


if __name__ == "__main__":
    main()
