#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def main() -> None:
    text = TODAY.read_text(encoding="utf-8")
    marker = "v0.7.0 official branding Today hero"
    if marker in text:
        return

    old = '''                HStack(alignment: .center, spacing: 0) {
                    Text("Life")
                        .foregroundStyle(.white)
                    Text("Route")
                        .foregroundStyle(brandGold)
                    Spacer(minLength: 12)
'''
    new = '''                // v0.7.0 official branding Today hero: official mark + stable LifeRoute wordmark.
                HStack(alignment: .center, spacing: 10) {
                    LifeRouteBrandMark(variant: .small)
                        .frame(width: 46, height: 46)
                        .accessibilityHidden(true)

                    Text("LifeRoute")
                        .foregroundStyle(.white)

                    Spacer(minLength: 12)
'''

    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 official branding Today compatibility failed: current B.1/B.2/B.3 hero prefix expected once, found {count}")

    text = text.replace(old, new, 1)
    TODAY.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 official branding Today compatibility applied: old split Life/Route wordmark replaced by the official mark while the validated hero day-picker button remains untouched.")


if __name__ == "__main__":
    main()
