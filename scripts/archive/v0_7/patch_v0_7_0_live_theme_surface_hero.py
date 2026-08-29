#!/usr/bin/env python3
from pathlib import Path
import patch_v0_7_0_today_overview_agenda as today_overview_agenda

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 live-theme surface repair failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_app() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.0 live theme surface visibility repair"
    if marker in text:
        return

    required = [
        "v0.7.0 Theme Phase 2 full-frame background-motion QA fix",
        "struct LifeRouteDynamicGlassFrame: View",
        "struct LifeRouteDynamicGlassEnvironment: View",
        "struct LifeRouteCardModifier: ViewModifier",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 live-theme surface repair failed: validated Phase 2 baseline missing {missing}")

    start = text.index("struct LifeRouteDynamicGlassFrame: View {")
    end = text.index("struct LifeRouteDynamicGlassEnvironment: View {", start)
    region = text[start:end]

    region = replace_once(
        region,
        "                        palette.accent.opacity(0.28),\n",
        "                        palette.accent.opacity(0.50),\n",
        "moving full-frame accent strength",
    )
    region = replace_once(
        region,
        "                        palette.accent.opacity(0.34),\n",
        "                        palette.accent.opacity(0.58),\n",
        "angular refraction primary accent",
    )
    region = replace_once(
        region,
        "                        palette.accentSecondary.opacity(0.28),\n",
        "                        palette.accentSecondary.opacity(0.50),\n",
        "angular refraction secondary accent",
    )
    region = replace_once(
        region,
        "                .blur(radius: 24)\n                .opacity(0.88)\n",
        '''                .blur(radius: 16)
                .opacity(1.0)

                // v0.7.0 live theme surface visibility repair: broad luminous fields keep the
                // active Dynamic identity visible across the entire interface instead of reading
                // as a black canvas with isolated moving foreground ribbons.
                RadialGradient(
                    colors: [
                        palette.accentSecondary.opacity(0.34),
                        palette.accent.opacity(0.13),
                        .clear,
                    ],
                    center: UnitPoint(
                        x: CGFloat(0.18 + 0.18 * (0.5 + 0.5 * sin(phase * 0.23))),
                        y: CGFloat(0.24 + 0.14 * (0.5 + 0.5 * cos(phase * 0.17)))
                    ),
                    startRadius: 4,
                    endRadius: longSide * 0.86
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [
                        palette.accent.opacity(0.30),
                        palette.accentSecondary.opacity(0.10),
                        .clear,
                    ],
                    center: UnitPoint(
                        x: CGFloat(0.80 - 0.15 * (0.5 + 0.5 * cos(phase * 0.19))),
                        y: CGFloat(0.76 - 0.13 * (0.5 + 0.5 * sin(phase * 0.21)))
                    ),
                    startRadius: 6,
                    endRadius: longSide * 0.78
                )
                .blendMode(.screen)
''',
        "full-frame luminous fields",
    )

    text = text[:start] + region + text[end:]

    # Let the app-wide environment show through cards and system chrome while keeping native material
    # and contrast. These are presentation-only opacity changes; no navigation/domain state changes.
    text = replace_once(
        text,
        "                                    palette.panelElevated.opacity(0.44),\n                                    palette.panel.opacity(0.26),\n                                    palette.accent.opacity(0.035),\n",
        "                                    palette.panelElevated.opacity(0.30),\n                                    palette.panel.opacity(0.16),\n                                    palette.accent.opacity(0.025),\n",
        "glass card translucency",
    )
    text = replace_once(
        text,
        "        nav.backgroundColor = background.withAlphaComponent(0.78)\n",
        "        nav.backgroundColor = background.withAlphaComponent(0.54)\n",
        "navigation chrome translucency",
    )
    text = replace_once(
        text,
        "        tab.backgroundColor = background.withAlphaComponent(0.88)\n",
        "        tab.backgroundColor = background.withAlphaComponent(0.66)\n",
        "tab chrome translucency",
    )
    text = replace_once(
        text,
        "        cell.backgroundColor = panel.withAlphaComponent(0.42)\n",
        "        cell.backgroundColor = panel.withAlphaComponent(0.28)\n",
        "list cell translucency",
    )

    APP.write_text(text, encoding="utf-8")


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    marker = "v0.7.0 Today hero preview-parity repair"
    if marker in text:
        return

    required = [
        "v0.7.0 official branding Today hero",
        "LifeRouteBrandMark(variant: .small)",
        'Text("LifeRoute")',
        "showingDayPicker = true",
        "LifeRouteTodayHeroScene()",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 live-theme surface repair failed: branded Today baseline missing {missing}")

    old = '''                // v0.7.0 official branding Today hero: official mark + stable LifeRoute wordmark.
                HStack(alignment: .center, spacing: 10) {
                    LifeRouteBrandMark(variant: .small)
                        .frame(width: 46, height: 46)
                        .accessibilityHidden(true)

                    Text("LifeRoute")
                        .foregroundStyle(.white)

                    Spacer(minLength: 12)
'''
    new = '''                // v0.7.0 official branding Today hero — the official LR mark remains the
                // production app identity, while Today returns to the approved preview composition.
                // v0.7.0 Today hero preview-parity repair.
                HStack(alignment: .center, spacing: 0) {
                    Text("Life")
                        .foregroundStyle(.white)
                    Text("Route")
                        .foregroundStyle(brandGold)
                    Spacer(minLength: 12)
'''
    text = replace_once(text, old, new, "Today approved split wordmark restoration")
    TODAY.write_text(text, encoding="utf-8")


def main() -> None:
    patch_app()
    patch_today()
    today_overview_agenda.main()
    print(
        "LifeRoute v0.7.0 live-theme surface repair applied: Dynamic Liquid Glass uses stronger full-frame moving illumination, cards/navigation/tab chrome expose more of the persistent root environment, Today restores the approved split Life/Route hero composition, and its overview lists every selected-day appointment while the official LR identity remains on the AppIcon and supporting brand surfaces."
    )


if __name__ == "__main__":
    main()
