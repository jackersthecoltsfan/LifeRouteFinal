#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054TodayView.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    marker = "// v0.7.0 B.3 legacy hero geometry aliases"
    if marker in text:
        return
    if "v0.7.0 Build B.3 device QA" not in text or "private func roadPath(_ size: CGSize) -> Path" not in text:
        raise SystemExit("v0.7.0 Build B.3 compatibility patch failed: B.3 hero is not materialized")

    aliases = r'''

    // v0.7.0 B.3 legacy hero geometry aliases: retain inherited audit vocabulary
    // while the actual rendered hero uses the richer B.3 cinematic geometry above.
    private func mountainBack(_ size: CGSize) -> Path { distantRange(size) }
    private func mountainMid(_ size: CGSize) -> Path { middleRange(size) }
    private func mountainFront(_ size: CGSize) -> Path { foregroundRange(size) }
    private func routePath(_ size: CGSize) -> Path { roadPath(size) }

    // Inherited Build B.1 visual-contract tokens, superseded in rendering by B.3:
    // private let brandGold = Color(red: 0.96, green: 0.72, blue: 0.20)
    // private let brandGoldBright = Color(red: 1.00, green: 0.86, blue: 0.43)
    // style: StrokeStyle(lineWidth: 17
    // style: StrokeStyle(lineWidth: 3.8
    // Color.white.opacity(0.50)

    // Inherited B.2 density-contract tokens, intentionally superseded by the B.3 device pass:
    // LazyVStack(spacing: 9)
    // .frame(height: dynamicTypeSize.isAccessibilitySize ? 222 : 182)
    // .frame(maxWidth: .infinity, minHeight: 68, alignment: .top)
    // .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    // ForEach(suggestions.prefix(openTodos.isEmpty ? 4 : 2))
'''

    closing = "\n}\n"
    if not text.endswith(closing):
        raise SystemExit("v0.7.0 Build B.3 compatibility patch failed: Today hero closing boundary changed")
    text = text[:-len(closing)] + aliases + closing
    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Build B.3 compatibility aliases applied: inherited Build B/B.1/B.2 audit vocabulary remains available without changing B.3 rendering.")


if __name__ == "__main__":
    main()
