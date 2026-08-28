#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"


def require_once(text: str, token: str, label: str) -> None:
    count = text.count(token)
    if count != 1:
        raise SystemExit(f"v0.7.0 Theme Phase 2 background-motion fix failed: {label} expected once, found {count}")


def main() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.0 Theme Phase 2 full-frame background-motion QA fix"
    if marker in text:
        return

    start_token = "struct LifeRouteDynamicGlassFrame: View {"
    end_token = "struct LifeRouteDynamicGlassEnvironment: View {"
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit("v0.7.0 Theme Phase 2 background-motion fix failed: Dynamic frame boundaries missing") from exc

    region = text[start:end]
    require_once(region, "                palette.backgroundGradient\n", "static Dynamic base gradient")
    require_once(
        region,
        "                    colors: [palette.accent.opacity(0.30), palette.accent.opacity(0.06), .clear],",
        "primary broad highlight",
    )
    require_once(
        region,
        "                    colors: [palette.accentSecondary.opacity(0.20), .clear],",
        "secondary broad highlight",
    )

    live_background = '''                // v0.7.0 Theme Phase 2 full-frame background-motion QA fix:\n                // the entire backdrop now drifts and refracts instead of leaving a static black field behind foreground ribbons.\n                LinearGradient(\n                    colors: [\n                        palette.backgroundTop,\n                        palette.panelElevated.opacity(0.94),\n                        palette.backgroundBottom,\n                        palette.accent.opacity(0.28),\n                        palette.backgroundTop,\n                    ],\n                    startPoint: UnitPoint(\n                        x: CGFloat(0.02 + 0.16 * (0.5 + 0.5 * sin(phase * 0.17))),\n                        y: CGFloat(0.02 + 0.14 * (0.5 + 0.5 * cos(phase * 0.13)))\n                    ),\n                    endPoint: UnitPoint(\n                        x: CGFloat(0.98 - 0.14 * (0.5 + 0.5 * cos(phase * 0.15))),\n                        y: CGFloat(0.98 - 0.16 * (0.5 + 0.5 * sin(phase * 0.11)))\n                    )\n                )\n\n                AngularGradient(\n                    gradient: Gradient(colors: [\n                        palette.backgroundTop,\n                        palette.accent.opacity(0.34),\n                        palette.panel.opacity(0.64),\n                        palette.accentSecondary.opacity(0.28),\n                        palette.backgroundBottom,\n                        palette.backgroundTop,\n                    ]),\n                    center: UnitPoint(\n                        x: CGFloat(0.50 + 0.06 * sin(phase * 0.19)),\n                        y: CGFloat(0.48 + 0.05 * cos(phase * 0.16))\n                    ),\n                    angle: .degrees(phase * 11.0)\n                )\n                .scaleEffect(1.55)\n                .blur(radius: 24)\n                .opacity(0.88)\n\n                LinearGradient(\n                    colors: [\n                        palette.accentSecondary.opacity(0.12),\n                        .clear,\n                        palette.accent.opacity(0.10),\n                        .clear,\n                    ],\n                    startPoint: UnitPoint(\n                        x: CGFloat(0.08 + 0.12 * sin(phase * 0.21)),\n                        y: 0\n                    ),\n                    endPoint: UnitPoint(\n                        x: CGFloat(0.90 + 0.08 * cos(phase * 0.18)),\n                        y: 1\n                    )\n                )\n                .blendMode(.screen)\n'''

    region = region.replace("                palette.backgroundGradient\n", live_background, 1)
    region = region.replace(
        "                    colors: [palette.accent.opacity(0.30), palette.accent.opacity(0.06), .clear],",
        "                    colors: [palette.accent.opacity(0.48), palette.accent.opacity(0.13), .clear],",
        1,
    )
    region = region.replace(
        "                    endRadius: longSide * 0.68",
        "                    endRadius: longSide * 0.84",
        1,
    )
    region = region.replace(
        "                    colors: [palette.accentSecondary.opacity(0.20), .clear],",
        "                    colors: [palette.accentSecondary.opacity(0.38), palette.accentSecondary.opacity(0.08), .clear],",
        1,
    )
    region = region.replace(
        "                    endRadius: longSide * 0.58",
        "                    endRadius: longSide * 0.78",
        1,
    )
    region = region.replace(
        "                        Color.white.opacity(0.055),",
        "                        Color.white.opacity(0.085),",
        1,
    )

    text = text[:start] + region + text[end:]
    APP.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 Theme Phase 2 background-motion QA fix applied: Dynamic Liquid Glass now uses a moving full-frame gradient and angular refraction field beneath the existing ribbons, with broader moving color illumination while retaining one root timeline, Reduce Motion stills, lifecycle pausing, static Core Glass, and pre-Phase-3 Scenery isolation."
    )


if __name__ == "__main__":
    main()
