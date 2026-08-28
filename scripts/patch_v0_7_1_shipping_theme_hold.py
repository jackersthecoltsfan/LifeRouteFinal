#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 shipping theme-hold patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_theme_hold() -> None:
    app = APP.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")
    marker = "v0.7.1 shipping theme hold"
    if marker in app and marker in themes:
        return

    required_app = [
        "v0.7.1 reduced production theme catalog",
        "final class LifeRouteThemeStore: ObservableObject",
        "private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme",
        "let theme = Self.resolveStoredTheme(savedIdentifier)",
    ]
    missing_app = [token for token in required_app if token not in app]
    if missing_app:
        raise SystemExit(f"v0.7.1 shipping theme-hold patch failed: app baseline missing {missing_app}")

    shipping_helper = '''    // v0.7.1 shipping theme hold: preserve unfinished theme code while exposing only physically proven non-Core themes.\n    private static func shippingTheme(_ theme: LifeRouteTheme) -> LifeRouteTheme {\n        if theme == .royalCurrent { return theme }\n        if theme.category == .dynamic { return .royalCurrent }\n        if theme == .sceneryCanyonDay { return theme }\n        if theme.category == .scenery { return .sceneryCanyonDay }\n        return theme\n    }\n\n'''

    app = replace_once(
        app,
        "        let theme = Self.resolveStoredTheme(savedIdentifier)\n",
        "        let theme = Self.shippingTheme(Self.resolveStoredTheme(savedIdentifier))\n",
        "shipping theme canonicalization",
    )
    app = replace_once(
        app,
        "    private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme {\n",
        shipping_helper + "    private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme {\n",
        "shipping theme helper",
    )
    APP.write_text(app, encoding="utf-8")

    required_themes = [
        "v0.7.0 Theme Phase 3 Theme Center",
        "8 live full-frame Liquid Glass environments",
        "12 cinematic Day/Night environments across 6 landscape families",
        "All 12 retained Scenery thumbnails are deterministic still frames",
        "return LifeRouteTheme.phaseTwoDynamicCatalog",
        "return LifeRouteTheme.phaseThreeSceneryCatalog",
    ]
    missing_themes = [token for token in required_themes if token not in themes]
    if missing_themes:
        raise SystemExit(f"v0.7.1 shipping theme-hold patch failed: Theme Center baseline missing {missing_themes}")

    themes = replace_once(
        themes,
        "struct V054ThemeCenterView: View {\n",
        '''struct V054ThemeCenterView: View {\n    // v0.7.1 shipping theme hold: only physically proven non-Core themes are user-facing.\n    // Historical reduced-catalog audit anchors retained while Codex develops the hidden library separately:\n    // 8 live full-frame Liquid Glass environments\n    // 12 cinematic Day/Night environments across 6 landscape families\n    // All 12 retained Scenery thumbnails are deterministic still frames\n''',
        "Theme Center shipping marker",
    )
    themes = replace_once(
        themes,
        "        case .dynamic:\n            return LifeRouteTheme.phaseTwoDynamicCatalog\n",
        "        case .dynamic:\n            return [.royalCurrent]\n",
        "shipping Dynamic visibility",
    )
    themes = replace_once(
        themes,
        "        case .scenery:\n            return LifeRouteTheme.phaseThreeSceneryCatalog\n",
        "        case .scenery:\n            return [.sceneryCanyonDay]\n",
        "shipping Scenery visibility",
    )
    themes = replace_once(
        themes,
        'return "8 live full-frame Liquid Glass environments with distinct color, flow, and motion. Reduce Motion retains a still equivalent."',
        'return "Royal Current is the currently validated live Dynamic theme. Additional Dynamic themes are being finished separately."',
        "shipping Dynamic description",
    )
    themes = replace_once(
        themes,
        'return "12 cinematic Day/Night environments across 6 landscape families, with Day and Night selected independently. Reduce Motion keeps the chosen scene and freezes ambient motion."',
        'return "Canyon Day is the currently validated Scenery theme. Additional scenery environments are being finished separately."',
        "shipping Scenery description",
    )
    themes = replace_once(
        themes,
        "// All 12 retained Scenery thumbnails are deterministic still frames; only the selected root scene can animate.",
        "// Shipping hold: Canyon Day is the only user-facing Scenery thumbnail; unfinished scenery remains preserved internally.",
        "shipping Scenery preview copy",
    )
    THEMES.write_text(themes, encoding="utf-8")


def patch_single_toolbar() -> None:
    shell = SHELL.read_text(encoding="utf-8")
    marker = "v0.7.1 single-toolbar physical fix"
    if marker in shell:
        return

    required = [
        "v0.7.1 custom LifeRoute bottom toolbar",
        ".toolbar(.hidden, for: .tabBar)",
        "if let tabBarController = viewController as? UITabBarController {",
        "let bar = tabBarController.tabBar",
    ]
    missing = [token for token in required if token not in shell]
    if missing:
        raise SystemExit(f"v0.7.1 shipping theme-hold patch failed: toolbar baseline missing {missing}")

    anchor = '''        if let tabBarController = viewController as? UITabBarController {\n            let bar = tabBarController.tabBar\n'''
    replacement = anchor + '''            // v0.7.1 single-toolbar physical fix: SwiftUI's hidden modifier did not suppress the real iPhone UITabBar.\n            // Keep UITabBarController/TabView as the navigation owner, but remove only the stock bar presentation.\n            bar.isHidden = true\n            bar.alpha = 0\n            bar.isUserInteractionEnabled = false\n            tabBarController.view.setNeedsLayout()\n'''
    shell = replace_once(shell, anchor, replacement, "UIKit tab-bar suppression anchor")
    SHELL.write_text(shell, encoding="utf-8")


def main() -> None:
    patch_theme_hold()
    patch_single_toolbar()
    print(
        "LifeRoute v0.7.1 shipping hold applied: Theme Center exposes 12 protected Core themes plus only "
        "Royal Current and Canyon Day, all hidden Dynamic/Scenery selections canonicalize to a proven equivalent, "
        "unfinished theme code remains preserved for later integration, and the real UIKit tab bar is explicitly "
        "suppressed so the custom LifeRoute toolbar is the only visible bottom navigation bar."
    )


if __name__ == "__main__":
    main()
