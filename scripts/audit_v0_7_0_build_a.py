#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Build A audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    design = read("LifeRoute/LifeRouteApp.swift")
    shell = read("LifeRoute/V054ContentView.swift")
    navigation = read("LifeRoute/AppNavigation.swift")
    cinematic = read("LifeRoute/CinematicThemeViews.swift")
    prepare = read("scripts/prepare_build.sh")
    contract = read("LIFEROUTE_V0_7_0_VISUAL_CONTRACT.md")

    require_all(
        design,
        [
            "v0.7.0 Build A design system",
            "static let pageHorizontal: CGFloat = 16",
            "static let cardGap: CGFloat = 12",
            "static let minimumTouchTarget: CGFloat = 44",
            "static let card: CGFloat = 18",
            "struct LifeRoutePageBackground: View",
            "struct LifeRouteSectionLabel: View",
            "struct LifeRouteIconBadge: View",
            "struct LifeRoutePill: View",
            "struct LifeRouteScreenHeader: View",
            "struct LifeRouteModalChromeModifier: ViewModifier",
            "func lifeRouteModalChrome() -> some View",
            "LifeRouteDesign.Layout.primaryControlHeight",
            "LifeRouteDesign.Layout.secondaryControlHeight",
        ],
        "shared Build A design system",
    )

    require_all(
        shell,
        [
            "v0.7.0 Build A shell",
            "LifeRouteCinematicBackdrop(",
            ".background(Color.clear) // v0.6.3 keep cinematic scenery visible",
            "TabView(selection: $router.selectedSection)",
            "UITabBarItemAppearance()",
            "tabItems.normal.iconColor = secondary",
            "tabItems.selected.iconColor = accent",
            "tabAppearance.stackedLayoutAppearance = tabItems",
            "bar.itemPositioning = .fill",
            "bar.prefersLargeTitles = false",
            ".tag(AppSection.today)",
            ".tag(AppSection.schedule)",
            ".tag(AppSection.tools)",
            ".tag(AppSection.resources)",
            ".tag(AppSection.setup)",
        ],
        "premium native shell",
    )

    require_all(
        navigation,
        [
            "case today",
            "case schedule",
            "case tools",
            "case resources",
            "case setup",
            "final class AppRouter: ObservableObject",
        ],
        "protected router",
    )
    require("LifeRouteWebView" not in shell, "legacy WebView must remain outside the active native shell")

    core_block = cinematic.split("        case .core:", 1)[1].split("        case .scenery:", 1)[0]
    require("LifeRouteThemeArtwork" not in core_block, "Core themes must remain color schemes without artwork")
    require("ForEach(" not in core_block, "Core themes must remain free of decorative band imprints")

    require("True app-wide Scenery architecture is reserved for **Build F**" in contract, "Scenery work must remain deferred to Build F")
    require("python3 scripts/patch_v0_7_0_build_a.py" in prepare, "canonical preparation must materialize Build A")
    require("python3 scripts/audit_v0_7_0_checkpoint_0.py" in prepare, "Checkpoint 0 audit must remain accumulated")
    require("python3 scripts/audit_v0_7_0_build_a.py" in prepare, "canonical preparation must run Build A audit")

    print(
        "LifeRoute v0.7.0 Build A audit passed: shared premium tokens/components materialized, native navigation/tab chrome restyled, five-tab AppRouter behavior preserved, Core themes remain clean, and Scenery stays deferred to Build F."
    )


if __name__ == "__main__":
    main()
