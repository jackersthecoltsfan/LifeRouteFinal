#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Theme Phase 2 compile hotfix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.0 Theme Phase 2 compile compatibility"
    if marker in text:
        return
    if "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog" not in text:
        raise SystemExit("v0.7.0 Theme Phase 2 compile hotfix failed: Phase 2 marker missing")

    text = replace_once(
        text,
        "private struct LifeRouteDynamicMotionSignature {",
        "// v0.7.0 Theme Phase 2 compile compatibility\nfileprivate struct LifeRouteDynamicMotionSignature {",
        "motion signature visibility",
    )

    replacements = [
        (
            "x: 0.72 + 0.14 * cos(phase * 0.41),\n                        y: 0.18 + 0.09 * sin(phase * 0.33)",
            "x: CGFloat(0.72 + 0.14 * cos(phase * 0.41)),\n                        y: CGFloat(0.18 + 0.09 * sin(phase * 0.33))",
            "primary moving highlight UnitPoint",
        ),
        (
            "x: 0.22 + 0.12 * sin(phase * 0.29),\n                        y: 0.76 + 0.08 * cos(phase * 0.37)",
            "x: CGFloat(0.22 + 0.12 * sin(phase * 0.29)),\n                        y: CGFloat(0.76 + 0.08 * cos(phase * 0.37))",
            "secondary moving highlight UnitPoint",
        ),
        (
            "startPoint: UnitPoint(x: 0.16 + 0.05 * sin(phase * 0.22), y: 0),\n                    endPoint: UnitPoint(x: 0.84 + 0.05 * cos(phase * 0.22), y: 1)",
            "startPoint: UnitPoint(x: CGFloat(0.16 + 0.05 * sin(phase * 0.22)), y: 0),\n                    endPoint: UnitPoint(x: CGFloat(0.84 + 0.05 * cos(phase * 0.22)), y: 1)",
            "moving sheen UnitPoints",
        ),
    ]
    for old, new, label in replacements:
        text = replace_once(text, old, new, label)

    APP.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Theme Phase 2 compile compatibility applied: motion signature visibility and animated UnitPoint scalar types are Swift-safe on the iOS 16 baseline.")


if __name__ == "__main__":
    main()
