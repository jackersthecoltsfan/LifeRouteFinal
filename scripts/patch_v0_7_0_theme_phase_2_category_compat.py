#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"

EXPECTED = "        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse: return .dynamic"
REQUIRED_CASES = [".solarFlare", ".electricStorm", ".ultraviolet", ".arcticPulse"]


def main() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.0 Theme Phase 2 category compatibility"
    if marker in text:
        return

    candidates = []
    for index, line in enumerate(text.splitlines()):
        if "return .dynamic" in line and all(token in line for token in REQUIRED_CASES):
            candidates.append((index, line))

    if len(candidates) != 1:
        raise SystemExit(
            f"v0.7.0 Theme Phase 2 category compatibility failed: expected one legacy Dynamic category line, found {len(candidates)}"
        )

    _, original = candidates[0]
    stripped = original.strip()
    prefix = stripped.split(": return .dynamic", 1)[0]
    cases_text = prefix.removeprefix("case ")
    cases = [item.strip() for item in cases_text.split(",") if item.strip()]
    extras = [item for item in cases if item not in REQUIRED_CASES]

    replacement_lines = [
        "        // v0.7.0 Theme Phase 2 category compatibility",
        EXPECTED,
    ]
    if extras:
        replacement_lines.append(f"        case {', '.join(extras)}: return .dynamic")

    replacement = "\n".join(replacement_lines)
    if text.count(original) != 1:
        raise SystemExit("v0.7.0 Theme Phase 2 category compatibility failed: legacy line was not unique")
    text = text.replace(original, replacement, 1)
    APP.write_text(text, encoding="utf-8")

    print(
        "LifeRoute v0.7.0 Theme Phase 2 category compatibility applied: the four historical Dynamic anchors are normalized for deterministic Phase 2 materialization and any additional legacy Dynamic cases retain their original category."
    )


if __name__ == "__main__":
    main()
