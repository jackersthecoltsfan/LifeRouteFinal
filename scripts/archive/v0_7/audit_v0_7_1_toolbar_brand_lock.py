#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "LifeRoute/V054ContentView.swift"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.1 toolbar brand-lock audit failed: missing {label}: {token}")


def main() -> None:
    shell = SHELL.read_text(encoding="utf-8")
    start_token = "// v0.7.1 final toolbar brand lock"
    end_token = "private struct LifeRouteTabGlyph: View {"
    require(shell, start_token, "brand-lock marker")
    require(shell, end_token, "custom glyph boundary")

    start = shell.index(start_token)
    end = shell.index(end_token, start)
    toolbar = shell[start:end]

    for token, label in [
        ("private let brandNavy = Color(red: 0.025, green: 0.070, blue: 0.145)", "stable LifeRoute navy"),
        ("private let brandNavyDeep = Color(red: 0.008, green: 0.026, blue: 0.065)", "deep navy rail base"),
        ("private let brandGold = Color(red: 0.93, green: 0.70, blue: 0.31)", "stable LifeRoute gold"),
        ("private let brandGoldBright = Color(red: 1.00, green: 0.83, blue: 0.49)", "bright selected gold"),
        ("color: selected ? brandGoldBright : brandGold.opacity(0.78)", "brand-owned icon color"),
        (".font(.system(size: 10.0, weight: selected ? .bold : .medium, design: .rounded))", "refined label typography"),
        (".fill(brandNavy.opacity(0.96))", "opaque selected navy capsule"),
        ("colors: [brandGoldBright.opacity(0.95), brandGold.opacity(0.64)]", "selected gold edge"),
        (".shadow(color: brandGold.opacity(0.23), radius: 8, y: 1)", "selected restrained gold glow"),
        (".fill(brandNavyDeep.opacity(0.92))", "deep navy rail"),
        (".fill(brandNavy.opacity(0.30))", "navy glass depth"),
        (".fill(palette.accent.opacity(0.035))", "minimal theme reflection"),
        ("colors: [brandGoldBright.opacity(0.72), Color.white.opacity(0.10), brandGold.opacity(0.48)]", "gold perimeter"),
    ]:
        require(toolbar, token, label)

    if "palette.backgroundTop" in toolbar:
        raise SystemExit("v0.7.1 toolbar brand-lock audit failed: selected theme still owns toolbar rail color")
    if "palette.accentSecondary" in toolbar:
        raise SystemExit("v0.7.1 toolbar brand-lock audit failed: selected theme still owns toolbar selected/icon chrome")
    if "palette.textSecondary" in toolbar:
        raise SystemExit("v0.7.1 toolbar brand-lock audit failed: selected theme still owns toolbar label color")

    require(
        shell,
        "let stroke = StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)",
        "refined custom glyph line weight",
    )
    require(shell, "v0.7.1 single-toolbar physical fix", "single-toolbar physical fix retained")
    require(shell, "bar.isHidden = true", "UIKit stock tab bar remains hidden")
    if shell.count("LifeRouteBottomToolbar(") != 1:
        raise SystemExit("v0.7.1 toolbar brand-lock audit failed: exactly one custom toolbar host is required")
    if shell.count(".tabItem {") != 5:
        raise SystemExit("v0.7.1 toolbar brand-lock audit failed: five-tab navigation ownership changed")

    print(
        "LifeRoute v0.7.1 toolbar brand-lock audit passed: the one custom toolbar keeps the five-tab router intact, "
        "uses fixed LifeRoute navy/gold chrome across themes, allows only a 3.5% theme reflection, retains explicit "
        "UIKit stock-bar suppression, and uses the refined 1.45-point custom glyph line weight."
    )


if __name__ == "__main__":
    main()
