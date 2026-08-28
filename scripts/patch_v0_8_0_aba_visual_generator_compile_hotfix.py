#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"
text = PATH.read_text(encoding="utf-8")

MARKER = "v0.8.0 ABA visual-support Image Playground 26.4 gate"

if MARKER not in text:
    call_gate = "if #available(iOS 26.0, *) {"
    if text.count(call_gate) != 1:
        raise SystemExit(
            "v0.8.0 visual compile hotfix failed: expected one iOS 26 Image Playground call-site gate"
        )
    text = text.replace(
        call_gate,
        "if #available(iOS 26.4, *) { // v0.8.0 ABA visual-support Image Playground 26.4 gate",
        1,
    )

    type_gate = "@available(iOS 26.0, *)\nprivate struct ABAVisualSupportImageGeneratorButton"
    if text.count(type_gate) != 1:
        raise SystemExit(
            "v0.8.0 visual compile hotfix failed: Image Playground generator availability anchor missing"
        )
    text = text.replace(
        type_gate,
        "@available(iOS 26.4, *)\nprivate struct ABAVisualSupportImageGeneratorButton",
        1,
    )

    fallback_copy = (
        "Illustrated generation requires a supported iOS 26 Apple Intelligence device. "
        "Photo and text-only visual saving remain available."
    )
    replacement_copy = (
        "Illustrated generation requires a supported iOS 26.4 Apple Intelligence device. "
        "Photo and text-only visual saving remain available."
    )
    if text.count(fallback_copy) != 1:
        raise SystemExit(
            "v0.8.0 visual compile hotfix failed: unsupported-device copy anchor missing"
        )
    text = text.replace(fallback_copy, replacement_copy, 1)

    PATH.write_text(text, encoding="utf-8")

print(
    "LifeRoute v0.8.0 ABA visual generator compile hotfix applied: ImagePlaygroundOptions, "
    "supportsImageGeneration, and the configured generation sheet are isolated behind their "
    "actual iOS 26.4 availability boundary while earlier systems retain photo/text fallback."
)
