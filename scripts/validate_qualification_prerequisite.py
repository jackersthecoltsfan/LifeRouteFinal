#!/usr/bin/env python3
"""Verify an explicit same-source qualification prerequisite.

This is an identity guard for controlled CI reuse, not a receipt or a general
validation framework. Callers must still name the prerequisite gate explicitly.
"""

from __future__ import annotations

import argparse
import subprocess
import sys


def git_value(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gate", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--tree", required=True)
    args = parser.parse_args()

    actual_sha = git_value("rev-parse", "HEAD")
    actual_tree = git_value("rev-parse", "HEAD^{tree}")
    if actual_sha != args.sha or actual_tree != args.tree:
        print(
            "qualification prerequisite identity mismatch: "
            f"gate={args.gate} expected_sha={args.sha} actual_sha={actual_sha} "
            f"expected_tree={args.tree} actual_tree={actual_tree}",
            file=sys.stderr,
        )
        return 1

    print(f"qualification prerequisite identity verified: gate={args.gate} sha={actual_sha} tree={actual_tree}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
