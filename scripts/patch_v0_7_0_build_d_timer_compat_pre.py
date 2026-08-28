#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 Build D timer compatibility pre-pass" in text:
        return
    if "struct VisualTimerView: View" not in text:
        raise SystemExit("Build D timer compatibility pre-pass failed: VisualTimerView missing")

    start = text.index("struct VisualTimerView: View {")
    end = text.index("struct QuickSessionNotesView: View {", start)
    section = text[start:end]
    old = "TimelineView(.periodic(from: .now, by: 0.10))"
    if old not in section:
        raise SystemExit("Build D timer compatibility pre-pass failed: validated v0.6.2 0.10-second TimelineView missing")
    section = section.replace(old, "TimelineView(.periodic(from: .now, by: 1))", 1)
    section = section.replace(
        "struct VisualTimerView: View {",
        "struct VisualTimerView: View {\n    // v0.7.0 Build D timer compatibility pre-pass; final cadence is restored after visual patching.",
        1,
    )
    PATH.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print("LifeRoute v0.7.0 Build D timer compatibility pre-pass applied.")


if __name__ == "__main__":
    main()
