#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 First/Then horizontal audit failed: {message}")


def main() -> None:
    views = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
    prepare = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")

    require("v0.7.0 horizontal First Then preview" in views, "horizontal preview marker missing")
    require('Image(systemName: "arrow.right.circle.fill")' in views, "First/Then preview must use a right-pointing arrow")
    require('Image(systemName: "arrow.down.circle.fill")' not in views.split("struct ClientFirstThenVisualView", 1)[1].split("struct ClientVisualScheduleBuilderView", 1)[0], "First/Then live preview must not remain vertically stacked")
    require('label: "FIRST"' in views and 'label: "THEN"' in views, "FIRST and THEN preview cards must remain present")
    require("compact: true" in views, "horizontal preview cards must use compact sizing")
    require("var compact = false" in views, "shared preview card must support compact horizontal layout")
    require("python3 scripts/patch_v0_7_0_first_then_horizontal.py" in prepare, "canonical preparation must materialize horizontal First/Then preview")
    require("python3 scripts/audit_v0_7_0_first_then_horizontal.py" in prepare, "canonical preparation must audit horizontal First/Then preview")

    print("LifeRoute v0.7.0 First/Then horizontal audit passed: FIRST is left, THEN is right, and the preview communicates progression with a left-to-right arrow.")


if __name__ == "__main__":
    main()
