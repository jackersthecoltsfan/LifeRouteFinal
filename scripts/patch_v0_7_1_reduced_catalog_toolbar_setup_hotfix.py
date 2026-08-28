#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup hotfix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    shell = SHELL.read_text(encoding="utf-8")
    setup = SETUP.read_text(encoding="utf-8")

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

    print(
        "LifeRoute v0.7.1 toolbar/Setup generation hotfix applied: the custom toolbar uses an explicit "
        "accessibility selected value, and the Setup disclosure helper emits the correct Swift environment key path."
    )


if __name__ == "__main__":
    main()
