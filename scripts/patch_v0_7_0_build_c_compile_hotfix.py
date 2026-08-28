#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054ScheduleView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build C compile hotfix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    marker = "// v0.7.0 Build C compile hotfix: explicit shape fills avoid SwiftUI background overload ambiguity."
    if marker in text:
        return
    if "v0.7.0 Build C Schedule" not in text:
        raise SystemExit("v0.7.0 Build C compile hotfix failed: Build C Schedule is not materialized")

    old_chip = '''            .background(
                selected ? AnyShapeStyle(gold) : AnyShapeStyle(palette.panelElevated.opacity(today ? 0.56 : 0.34)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )'''
    new_chip = '''            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? gold : palette.panelElevated.opacity(today ? 0.56 : 0.34))
            }'''
    text = replace_once(text, old_chip, new_chip, "compact date-chip background")

    old_month = '''            .background(
                selected ? AnyShapeStyle(gold) : AnyShapeStyle(today ? gold.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )'''
    new_month = '''            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? gold : (today ? gold.opacity(0.12) : Color.clear))
            }'''
    text = replace_once(text, old_month, new_month, "month-day background")

    text = text.replace(
        "// v0.7.0 Build C Schedule: premium agenda/calendar surface; provider, manual-event,\n",
        "// v0.7.0 Build C Schedule: premium agenda/calendar surface; provider, manual-event,\n"
        "// v0.7.0 Build C compile hotfix: explicit shape fills avoid SwiftUI background overload ambiguity.\n",
        1,
    )

    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Build C compile hotfix applied: conditional AnyShapeStyle backgrounds replaced with explicit RoundedRectangle fills.")


if __name__ == "__main__":
    main()
