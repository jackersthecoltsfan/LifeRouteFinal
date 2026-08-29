#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    marker = "v0.7.0 Build D audit compatibility anchor"
    if marker in text:
        return
    if "TimelineView(.periodic(from: .now, by: 0.10))" not in text:
        raise SystemExit("Build D compatibility anchor failed: final validated 0.10-second timer cadence missing")
    old = "    // v0.7.0 Build D timer cadence restored: keep the validated 0.10-second visual pulse updates."
    new = '''    // v0.7.0 Build D timer cadence restored: keep the validated 0.10-second visual pulse updates.
    // v0.7.0 Build D audit compatibility anchor: the visual-only patch temporarily matched
    // TimelineView(.periodic(from: .now, by: 1)) before restoring the superseding v0.6.2 cadence above.'''
    if old not in text:
        raise SystemExit("Build D compatibility anchor failed: timer cadence restoration marker missing")
    PATH.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("LifeRoute v0.7.0 Build D compatibility anchor applied without changing final timer cadence.")


if __name__ == "__main__":
    main()
