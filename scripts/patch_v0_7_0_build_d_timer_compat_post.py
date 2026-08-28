#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 Build D timer cadence restored" in text:
        return
    if "v0.7.0 Build D timer presentation" not in text:
        raise SystemExit("Build D timer compatibility post-pass failed: Build D timer presentation missing")

    start = text.index("struct VisualTimerView: View {")
    end = text.index("struct QuickSessionNotesView: View {", start)
    section = text[start:end]
    old = "TimelineView(.periodic(from: .now, by: 1))"
    if old not in section:
        raise SystemExit("Build D timer compatibility post-pass failed: normalized TimelineView missing")
    section = section.replace(old, "TimelineView(.periodic(from: .now, by: 0.10))", 1)
    section = section.replace(
        "// v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.",
        "// v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.\n    // v0.7.0 Build D timer cadence restored: keep the validated 0.10-second visual pulse updates.",
        1,
    )
    PATH.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print("LifeRoute v0.7.0 Build D timer compatibility post-pass applied: validated 0.10-second visual cadence restored.")


if __name__ == "__main__":
    main()
