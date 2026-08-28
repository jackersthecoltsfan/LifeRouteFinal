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

    # Apple exposes current-device generation availability through
    # EnvironmentValues.supportsImagePlayground. Keep this inside the same 26.4-gated
    # helper as ImagePlaygroundOptions so the iOS 16 deployment target remains clean.
    wrong_environment = (
        "@Environment(\\.supportsImageGeneration) private var supportsImageGeneration"
    )
    correct_environment = (
        "@Environment(\\.supportsImagePlayground) private var supportsImagePlayground"
    )
    if text.count(wrong_environment) != 1:
        raise SystemExit(
            "v0.8.0 visual compile hotfix failed: obsolete Image Playground environment anchor missing"
        )
    text = text.replace(wrong_environment, correct_environment, 1)
    text = text.replace("supportsImageGeneration", "supportsImagePlayground")

    # The current ImagePlaygroundOptions API does not expose a sizeSpecification member.
    # LifeRoute instead guarantees the product's square-card contract after approval by
    # normalizing the returned temporary image to a 1,024 × 1,024 white canvas.
    unsupported_size_option = (
        "        options.sizeSpecification = .closest(to: CGSize(width: 1_024, height: 1_024))\n"
    )
    if text.count(unsupported_size_option) != 1:
        raise SystemExit(
            "v0.8.0 visual compile hotfix failed: unsupported sizeSpecification anchor missing"
        )
    text = text.replace(unsupported_size_option, "", 1)

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
    "LifeRoute v0.8.0 ABA visual generator compile hotfix applied: supportsImagePlayground, "
    "ImagePlaygroundOptions, and the configured generation sheet are isolated behind their actual "
    "iOS 26.4 availability boundary; unsupported sizeSpecification usage is removed; and approved "
    "artwork is still normalized locally to the required square white icon canvas."
)
