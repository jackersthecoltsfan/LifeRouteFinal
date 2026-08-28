#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 physical runtime fix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_motion() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.1 physical-device motion visibility repair"
    if marker in text:
        return

    required = [
        "v0.7.1 Royal Current exemplar",
        "struct LifeRouteLiveThemeEnvironment: View",
        "case .royalCurrent: return .init(speed: 0.12, amplitude: 32, ribbonAngle: -7, stillPhase: 0.7)",
        "case .sceneryCanyonDay",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 physical runtime fix failed: exemplar baseline missing {missing}")

    speed_replacements = {
        "case .royalCurrent: return .init(speed: 0.12, amplitude: 32, ribbonAngle: -7, stillPhase: 0.7)":
            "case .royalCurrent: return .init(speed: 0.90, amplitude: 32, ribbonAngle: -7, stillPhase: 0.7)",
        "case .midnightPrism: return .init(speed: 0.095, amplitude: 38, ribbonAngle: 9, stillPhase: 1.4)":
            "case .midnightPrism: return .init(speed: 0.78, amplitude: 38, ribbonAngle: 9, stillPhase: 1.4)",
        "case .auroraBloom: return .init(speed: 0.085, amplitude: 44, ribbonAngle: -11, stillPhase: 2.1)":
            "case .auroraBloom: return .init(speed: 0.68, amplitude: 44, ribbonAngle: -11, stillPhase: 2.1)",
        "case .solarPulse: return .init(speed: 0.14, amplitude: 34, ribbonAngle: 6, stillPhase: 0.2)":
            "case .solarPulse: return .init(speed: 1.00, amplitude: 34, ribbonAngle: 6, stillPhase: 0.2)",
        "case .emeraldFlow: return .init(speed: 0.10, amplitude: 40, ribbonAngle: -5, stillPhase: 1.8)":
            "case .emeraldFlow: return .init(speed: 0.82, amplitude: 40, ribbonAngle: -5, stillPhase: 1.8)",
        "case .arcticHalo: return .init(speed: 0.07, amplitude: 28, ribbonAngle: 12, stillPhase: 2.7)":
            "case .arcticHalo: return .init(speed: 0.62, amplitude: 28, ribbonAngle: 12, stillPhase: 2.7)",
        "case .oceanGlass: return .init(speed: 0.105, amplitude: 42, ribbonAngle: -3, stillPhase: 1.1)":
            "case .oceanGlass: return .init(speed: 0.86, amplitude: 42, ribbonAngle: -3, stillPhase: 1.1)",
        "case .roseEmber: return .init(speed: 0.115, amplitude: 35, ribbonAngle: 8, stillPhase: 2.4)":
            "case .roseEmber: return .init(speed: 0.92, amplitude: 35, ribbonAngle: 8, stillPhase: 2.4)",
        "case .obsidianSpectra: return .init(speed: 0.075, amplitude: 46, ribbonAngle: -9, stillPhase: 0.9)":
            "case .obsidianSpectra: return .init(speed: 0.66, amplitude: 46, ribbonAngle: -9, stillPhase: 0.9)",
        "case .plasmaOrchid: return .init(speed: 0.125, amplitude: 39, ribbonAngle: 7, stillPhase: 1.6)":
            "case .plasmaOrchid: return .init(speed: 0.96, amplitude: 39, ribbonAngle: 7, stillPhase: 1.6)",
        "case .verdantMist: return .init(speed: 0.065, amplitude: 30, ribbonAngle: -4, stillPhase: 2.9)":
            "case .verdantMist: return .init(speed: 0.58, amplitude: 30, ribbonAngle: -4, stillPhase: 2.9)",
        "case .titaniumGlow: return .init(speed: 0.08, amplitude: 26, ribbonAngle: 10, stillPhase: 0.4)":
            "case .titaniumGlow: return .init(speed: 0.70, amplitude: 26, ribbonAngle: 10, stillPhase: 0.4)",
    }
    for old, new in speed_replacements.items():
        text = replace_once(text, old, new, f"motion speed {old.split(':')[0]}")

    text = replace_once(
        text,
        "        case .canyon: return .init(speed: 0.014, drift: 0.028, stillPhase: 2.9)",
        "        case .canyon: return .init(speed: 0.120, drift: 0.028, stillPhase: 2.9)",
        "Canyon ambient speed",
    )

    text = replace_once(
        text,
        "private struct LifeRouteRoyalCurrentFrame: View {",
        "// v0.7.1 physical-device motion visibility repair: live movement must be perceptible within a few seconds.\nprivate struct LifeRouteRoyalCurrentFrame: View {",
        "motion visibility marker",
    )

    text = replace_once(
        text,
        ".scaleEffect(1.035 + pulse * 0.012)\n                    .offset(x: drift * 4.2, y: -drift * 2.4)",
        ".scaleEffect(1.040 + pulse * 0.022)\n                    .offset(x: drift * 9.0, y: -drift * 4.8)",
        "Royal Current asset motion amplitude",
    )

    APP.write_text(text, encoding="utf-8")


def patch_shell_transparency() -> None:
    text = SHELL.read_text(encoding="utf-8")
    marker = "v0.7.1 physical-device root environment reveal"
    if marker in text:
        return

    required = [
        "TabView(selection: $router.selectedSection)",
        ".background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment",
        "static func refreshVisibleChrome(theme: LifeRouteTheme)",
        "guard let viewController else { return }",
        ".onChange(of: router.selectedSection)",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 physical runtime fix failed: shell baseline missing {missing}")

    tab_item_token = "                .tabItem {"
    tab_count = text.count(tab_item_token)
    if tab_count != 5:
        raise SystemExit(f"v0.7.1 physical runtime fix failed: expected five tab roots, found {tab_count}")
    text = text.replace(
        tab_item_token,
        "                .background(Color.clear)\n" + tab_item_token,
    )

    text = replace_once(
        text,
        "        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)\n        .onChange(of: router.selectedSection)",
        "        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)\n        .onAppear {\n            // v0.7.1 physical-device root environment reveal: clear UIKit host surfaces on first presentation.\n            LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)\n        }\n        .onChange(of: router.selectedSection)",
        "initial chrome refresh",
    )

    text = replace_once(
        text,
        "        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {\n            for window in scene.windows where !window.isHidden {\n                refresh(",
        "        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {\n            for window in scene.windows where !window.isHidden {\n                window.backgroundColor = .clear\n                refresh(",
        "window transparency",
    )

    text = replace_once(
        text,
        "        guard let viewController else { return }\n\n        if let navigationController = viewController as? UINavigationController {",
        "        guard let viewController else { return }\n\n        // v0.7.1 physical-device root environment reveal: UIKit host/controller fills must not cover the shared SwiftUI environment.\n        viewController.view.backgroundColor = .clear\n\n        if let navigationController = viewController as? UINavigationController {",
        "controller transparency",
    )

    SHELL.write_text(text, encoding="utf-8")


def main() -> None:
    patch_motion()
    patch_shell_transparency()
    print(
        "LifeRoute v0.7.1 physical runtime repair applied: Dynamic motion is perceptible on-device, "
        "Canyon ambience no longer advances at a near-static rate, and UIKit tab/navigation host surfaces "
        "are explicitly transparent so the existing single persistent root environment can remain visible "
        "behind Today, Schedule, Tools, Resources, and Setup."
    )


if __name__ == "__main__":
    main()
