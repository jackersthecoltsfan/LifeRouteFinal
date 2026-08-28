#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEWS = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
DOMAIN = (ROOT / "LifeRoute/SessionToolsDomain.swift").read_text(encoding="utf-8")
PREP = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
WRAPPER = (ROOT / "scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py").read_text(encoding="utf-8")
COMPILE = (ROOT / "scripts/patch_v0_8_0_aba_visual_generator_compile_hotfix.py").read_text(encoding="utf-8")
SPEC = (ROOT / "LIFEROUTE_V0_8_0_ABA_VISUAL_SUPPORT_GENERATOR_SPEC.md").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []

def check(name: str, condition: bool) -> None:
    checks.append((name, bool(condition)))

# Approved product contract and phased scope.
check("approved workflow recorded", "PHOTO / TEXT → VISUAL-SUPPORT ICON → PERSONAL ICON LIBRARY" in SPEC)
check("photo-specific recognition recorded", "actual cup, stroller, home, playground, tablet, store" in SPEC)
check("exact native label ownership recorded", "LifeRoute renders the exact user label as native text beneath the artwork" in SPEC)
check("batch remains later", "### Batch checkpoint" in SPEC)
check("PDF remains later", "### Print/PDF checkpoint" in SPEC)
check("default printable layout recorded", "2 columns × 4 rows" in SPEC and "up to 8 standard icons per page" in SPEC)
check("provider dimensions documented honestly", "source dimensions as provider-controlled" in SPEC)
check("local square normalization documented", "1,024 × 1,024 square white canvas" in SPEC)

# Existing state, library, and persistence ownership.
check("single visual state owner retained", VIEWS.count("@StateObject private var visualState = ClientVisualSupportCore()") == 1)
check("single visual-support core retained", DOMAIN.count("final class ClientVisualSupportCore: ObservableObject") == 1)
check("existing icon mutation remains authoritative", "visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)" in VIEWS)
check("General/client isolation remains", "ClientVisualSupportCore.generalClientCode" in VIEWS and "crossClientReference" in DOMAIN)
check("Choice Board remains", "ClientChoiceBoardBuilderView" in VIEWS)
check("Visual Schedule remains", "ClientVisualScheduleBuilderView" in VIEWS)
check("First Then remains", "ClientFirstThenVisualView" in VIEWS)

# Supported Image Playground integration.
check("Image Playground import guarded", "#if canImport(ImagePlayground)\nimport ImagePlayground\n#endif" in VIEWS)
check("iOS 26.4 gate", "@available(iOS 26.4, *)" in VIEWS and "if #available(iOS 26.4, *)" in VIEWS)
check("correct availability environment", "@Environment(\\.supportsImagePlayground) private var supportsImagePlayground" in VIEWS)
check("obsolete availability key removed", "supportsImageGeneration" not in VIEWS)
check("system generation sheet used", ".imagePlaygroundSheet(" in VIEWS)
check("Illustration style locked", ".imagePlaygroundGenerationStyle(.illustration, in: [.illustration])" in VIEWS)
check("person personalization disabled", "options.personalization = .disabled" in VIEWS)
check("optional reference image supplied", "sourceImage: sourceImage" in VIEWS and "sourceImage: referenceSourceImage" in VIEWS)
check("text-only generation supported", "hasReference: referencePhotoData != nil" in VIEWS and "cleanLabel" in VIEWS)
check("unsupported-device fallback retained", "supported iOS 26.4 Apple Intelligence device" in VIEWS)
check("unsupported size API removed", "sizeSpecification" not in VIEWS)

# Canonical Master Image Prompt.
prompt_tokens = [
    "realistically illustrated cartoon",
    "clean bold outlines",
    "soft natural shading",
    "bright but natural colors",
    "strong visual contrast",
    "clean white background",
    "square 1:1 composition",
    "occupy most",
    "Remove distracting or irrelevant background information",
    "Preserve identifying characteristics needed for recognition",
    "Do not introduce unrelated objects or scenery",
    "Do not include people unless a person is necessary",
    "professionally designed ABA visual-support library",
    "Prioritize immediate functional recognition and visual clarity",
]
for token in prompt_tokens:
    check(f"master prompt token: {token}", token in VIEWS)

# Exact labels and deterministic saved output.
check("embedded model text forbidden", "Do not render letters, words, captions, labels, logos, borders, or watermarks" in VIEWS)
check("exact label field", 'TextField("Exact icon label", text: $label)' in VIEWS)
check("native label shown below artwork", "Text(displayLabel)" in VIEWS and "Visual support preview" in VIEWS)
check("approved result normalized locally", "normalizedSquarePNG" in VIEWS)
check("saved canvas exactly 1024 square", "CGSize(width: 1_024, height: 1_024)" in VIEWS)
check("saved canvas is opaque white", "context.cgContext.setFillColor(UIColor.white.cgColor)" in VIEWS)
check("temporary result decoded through ImageIO", "CGImageSourceCreateWithURL" in VIEWS and "CGImageSourceCreateThumbnailAtIndex" in VIEWS)
check("approved temporary URL not persisted", "normalizedSquarePNG(from: url)" in VIEWS)
check("generated draft reviewed before save", "Review the artwork and exact label before saving" in VIEWS)
check("original photo restore remains", "Use original photo instead" in VIEWS)

# Performance, lifecycle, and privacy.
check("no synchronous UIImage data decode", "UIImage(data:" not in VIEWS)
check("reference decode uses actor cache", "await ClientVisualThumbnailCache.shared.thumbnail" in VIEWS)
check("generated decode detached", "await Task.detached(priority: .userInitiated)" in VIEWS)
check("reference source cleared", VIEWS.count("referenceSourceImage = nil") == 2)
check("photo picker retained", "PhotosPicker(selection: $selectedPhotoItem, matching: .images)" in VIEWS)
check("text/photo fallback retained", "imageData: photoData" in VIEWS)
check("existing protected library save retained", "Icon saved to \\(libraryName)’s visual library on this iPhone." in VIEWS)
check("system privacy boundary disclosed", "Apple’s system Image Playground handles the prompt and optional reference" in VIEWS)
check("later phases disclosed in UI", "Batch generation and printable PDF sheets remain later checkpoints." in VIEWS)

# Deterministic materialization and retained regressions.
check("foundation patch wired", "python3 scripts/patch_v0_8_0_aba_visual_generator_foundation.py" in PREP)
check("performance wrapper wired", "python3 scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py" in PREP)
check("compile hotfix invoked by wrapper", "runpy.run_path" in WRAPPER and "patch_v0_8_0_aba_visual_generator_compile_hotfix.py" in WRAPPER)
check("compile hotfix removes unsupported size API", "unsupported_size_option" in COMPILE and "text.replace(unsupported_size_option, \"\", 1)" in COMPILE)
check("visual audit wired", "python3 scripts/audit_v0_8_0_aba_visual_generator_foundation.py" in PREP)
check("note audit remains before visual pass", PREP.find("audit_v0_8_0_master_aba_note.py") < PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("visual persistence reruns afterward", PREP.rfind("audit_v0_5_0_client_visual_persistence.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("performance reruns afterward", PREP.rfind("audit_v0_5_0_performance_architecture.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("stability reruns afterward", PREP.rfind("audit_v0_5_0_stability_architecture.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("protected v0.7.1 audit reruns afterward", PREP.rfind("audit_v0_7_1_protected_regressions.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.8.0 ABA visual generator foundation audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
