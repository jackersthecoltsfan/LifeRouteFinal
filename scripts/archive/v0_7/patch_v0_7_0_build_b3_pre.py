#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")

    anchor = "// v0.7.0 B.3 compatibility anchor: struct ClientVisualIconMakerView: View {\n"
    target = "private struct VisualWorkspaceCard: View {"
    if anchor not in text:
        if target not in text:
            raise SystemExit("v0.7.0 Build B.3 prepatch failed: VisualWorkspaceCard boundary missing")
        text = text.replace(target, anchor + target, 1)

    # B.2 places the full-screen board/schedule preview structs after the Schedule builder.
    # B.3 intentionally patches only the Schedule builder's palette environment line; make the
    # later preview copies textually distinct while preserving identical valid Swift semantics.
    schedule_start = text.index("struct ClientVisualScheduleBuilderView: View {")
    schedule_end = text.index("private struct VisualBuilderHero: View {", schedule_start)
    section = text[schedule_start:schedule_end]
    needle = "    @Environment(\\.lifeRoutePalette) private var palette\n"
    occurrences = section.count(needle)
    if occurrences < 1:
        raise SystemExit("v0.7.0 Build B.3 prepatch failed: Schedule palette owner missing")
    if occurrences > 1:
        first = section.index(needle) + len(needle)
        tail = section[first:].replace(
            needle,
            "    @Environment(\\.lifeRoutePalette)  private var palette\n",
        )
        section = section[:first] + tail
        text = text[:schedule_start] + section + text[schedule_end:]

    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Build B.3 visual compatibility anchors applied: library boundary restored and Schedule builder patch ownership narrowed.")


if __name__ == "__main__":
    main()
