#!/usr/bin/env python3
"""Enforce LifeRoute's native compiler-warning budget."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


KNOWN_TOOLCHAIN_NOTICE = (
    "warning: Metadata extraction skipped. No AppIntents.framework dependency found."
)


def warning_lines(paths: list[Path]) -> list[str]:
    lines: list[str] = []
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(f"Missing xcodebuild log: {path}")
        lines.extend(
            line.rstrip()
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
            if "warning:" in line
        )
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", nargs="+", type=Path)
    args = parser.parse_args()

    try:
        warnings = warning_lines(args.logs)
    except OSError as error:
        print(error, file=sys.stderr)
        return 2

    known = [line for line in warnings if KNOWN_TOOLCHAIN_NOTICE in line]
    unexpected = [line for line in warnings if KNOWN_TOOLCHAIN_NOTICE not in line]

    print(f"Known Xcode no-AppIntents notice lines: {len(known)}")
    print(f"Unexpected compiler warning lines: {len(unexpected)}")

    if unexpected:
        print("\n".join(unexpected), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
