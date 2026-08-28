#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup hotfix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    shell = SHELL.read_text(encoding="utf-8")
    setup = SETUP.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")

    if "v0.7.1 toolbar accessibility hardening" not in shell:
        shell = replace_once(
            shell,
            '''                .accessibilityLabel(section.lifeRouteToolbarTitle)\n                .accessibilityAddTraits(selected ? .isSelected : [])''',
            '''                .accessibilityLabel(section.lifeRouteToolbarTitle)\n                // v0.7.1 toolbar accessibility hardening: explicit value avoids conditional OptionSet inference.\n                .accessibilityValue(selected ? "Selected" : "")''',
            "toolbar selected accessibility value",
        )
        SHELL.write_text(shell, encoding="utf-8")

    if "@Environment(\\\\.lifeRoutePalette)" in setup:
        setup = setup.replace("@Environment(\\\\.lifeRoutePalette)", "@Environment(\\.lifeRoutePalette)", 1)
    if "v0.7.1 Setup disclosure groups" not in setup or "@Environment(\\.lifeRoutePalette) private var palette" not in setup:
        raise SystemExit("v0.7.1 reduced catalog/toolbar/setup hotfix failed: Setup disclosure helper/key path missing")
    SETUP.write_text(setup, encoding="utf-8")

    if "8 live full-frame Liquid Glass environments" not in themes:
        themes = replace_once(
            themes,
            'return "12 slow, full-frame liquid-glass environments. Reduce Motion retains a still equivalent."',
            'return "8 live full-frame Liquid Glass environments with distinct color, flow, and motion. Reduce Motion retains a still equivalent."',
            "Dynamic Theme Center count copy",
        )
        themes = replace_once(
            themes,
            'return "20 cinematic environments across 10 families, with Day and Night selected independently. Reduce Motion keeps the chosen scene and freezes ambient motion."',
            'return "12 cinematic Day/Night environments across 6 landscape families, with Day and Night selected independently. Reduce Motion keeps the chosen scene and freezes ambient motion."',
            "Scenery Theme Center count copy",
        )
        themes = replace_once(
            themes,
            "// All 20 Scenery thumbnails are deterministic still frames; only the selected root scene can animate.",
            "// All 12 retained Scenery thumbnails are deterministic still frames; only the selected root scene can animate.",
            "Scenery preview count copy",
        )
        THEMES.write_text(themes, encoding="utf-8")

    print(
        "LifeRoute v0.7.1 toolbar/Setup generation hotfix applied: the custom toolbar uses an explicit "
        "accessibility selected value, Setup emits the correct environment key path, and Theme Center copy "
        "truthfully describes the reduced 8-Dynamic / 12-Scenery production library."
    )


if __name__ == "__main__":
    main()
