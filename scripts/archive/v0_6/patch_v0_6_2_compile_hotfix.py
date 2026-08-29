#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_if_present(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"v0.6.2 compile hotfix failed: missing expected token in {path.name}: {old}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_if_present(
    ROOT / "LifeRoute" / "SessionToolsViews.swift",
    ".scaleEffect(0.92 + 0.12 * pulsePhase)",
    ".scaleEffect(CGFloat(0.92 + 0.12 * pulsePhase))",
)

print("LifeRoute v0.6.2 Swift compile hotfix applied.")
