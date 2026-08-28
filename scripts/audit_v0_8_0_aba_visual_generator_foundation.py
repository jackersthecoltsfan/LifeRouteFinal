#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEWS = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
DOMAIN = (ROOT / "LifeRoute/SessionToolsDomain.swift").read_text(encoding="utf-8")
PREP = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
WRAPPER = (ROOT / "scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py").read_text(encoding="utf-8")
COMPILE_HOTFIX = (ROOT / "scripts/patch_v0_8_0_aba_visual_generator_compile_hotfix.py").read_text(encoding="utf-8")
SPEC = (ROOT / "LIFEROUTE_V0_8_0_ABA_VISUAL_SUPPORT_GENERATOR_SPEC.md").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []

def check(name: str, condition: bool) -> None:
    checks.append((name, bool(condition)))

# Canonical product contract.
check("approved spec recorded", "PHOTO / TEXT → VISUAL-SUPPORT ICON → PERSONAL ICON LIBRARY" in SPEC)
check("master illustration style recorded", all(token in SPEC for token in [
    "realistically illustrated cartoon",
    "clean bold outlines",
    "soft natural shading",
    "bright but natural colors",
    "strong contrast",
    "clean white background",
    "square 1:1",
]))
check("photo-specific recognition recorded", "actual cup, stroller, home, playground, tablet, store" in SPEC)
check("exact-label ownership recorded", "LifeRoute renders the exact user label as native text beneath the artwork" in SPEC)
check("batch and PDF remain phased", "### Batch checkpoint" in SPEC and "### Print/PDF checkpoint" in SPEC)
check("default print layout recorded", "2 columns × 4 rows" in SPEC and "up to 8 standard icons per page" in SPEC)

# Existing visual-domain ownership and persistence must remain authoritative.
check("single visual-state owner retained", VIEWS.count("@StateObject private var visualState = ClientVisualSupportCore()") == 1)
check("single visual-support core type retained", DOMAIN.count("final class ClientVisualSupportCore: ObservableObject") == 1)
check("existing icon mutation remains authoritative", "visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)" in VIEWS)
check("General/client isolation remains", "ClientVisualSupportCore.generalClientCode" in VIEWS and "crossClientReference" in DOMAIN)
check("existing builders remain reachable", all(token in VIEWS for token in [
    "ClientChoiceBoardBuilderView",
    "ClientVisualScheduleBuilderView",
    "ClientFirstThenVisualView",
]))

# Image Playground integration must be availability-gated and use Apple's supported reviewed UI.
check("Image Playground import is guarded", "#if canImport(ImagePlayground)\nimport ImagePlayground\n#endif" in VIEWS)
check(
    "iOS 26.4 availability gate",
    "@available(iOS 26.4, *)" in VIEWS
    and "if #available(iOS 26.4, *)" in VIEWS
    and "v0.8.0 ABA visual-support Image Playground 26.4 gate" in VIEWS,
)
check("pre-26.4 generator type gate removed", "@available(iOS 26.0, *)\nprivate struct ABAVisualSupportImageGeneratorButton" not in VIEWS)
check("correct system availability environment", "@Environment(\\.supportsImagePlayground) private var supportsImagePlayground" in VIEWS)
check("obsolete environment key removed", "supportsImageGeneration" not in VIEWS)
check("system generation sheet used", ".imagePlaygroundSheet(" in VIEWS)
check("square generation requested", "options.sizeSpecification = .closest(to: CGSize(width: 1_024, height: 1_024))" in VIEWS)
check("person personalization disabled", "options.personalization = .disabled" in VIEWS)
check("illustration style locked", ".imagePlaygroundGenerationStyle(.illustration, in: [.illustration])" in VIEWS)
check("optional reference photo supplied", "sourceImage: sourceImage" in VIEWS and "sourceImage: referenceSourceImage" in VIEWS)
check("text-only generation supported", "hasReference: referencePhotoData != nil" in VIEWS and "cleanLabel" in VIEWS)
check("unsupported fallback retained", "supported iOS 26.4 Apple Intelligence device" in VIEWS and "Photo and text-only visual saving remain available" in VIEWS)

# Master ABA visual prompt behavior.
for token, label in [
    ("realistically illustrated cartoon", "realistic illustrated-cartoon prompt"),
    ("clean bold outlines", "bold-outline prompt"),
    ("soft natural shading", "natural-shading prompt"),
    ("bright but natural colors", "natural-color prompt"),
    ("strong visual contrast", "contrast prompt"),
    ("clean white background", "white-background prompt"),
    ("square 1:1 composition", "square-composition prompt"),
    ("occupy most", "subject-scale prompt"),
    ("Remove distracting or irrelevant background information", "background-cleanup prompt"),
    ("Preserve identifying characteristics needed for recognition", "recognition/generalization prompt"),
    ("Do not introduce unrelated objects or scenery", "no-unrelated-content prompt"),
    ("Do not include people unless a person is necessary", "people-only-when-needed prompt"),
    ("professionally designed ABA visual-support library", "set-consistency prompt"),
    ("Prioritize immediate functional recognition and visual clarity", "clinical functional-goal prompt"),
]:
    check(label, token in VIEWS)

# Exact label and deterministic output treatment.
check("model text rendering forbidden", "Do not render letters, words, captions, labels, logos, borders, or watermarks" in VIEWS)
check("LifeRoute exact-label rule in prompt", "LifeRoute renders the exact user label beneath the artwork separately" in VIEWS)
check("exact editable label field", 'TextField("Exact icon label", text: $label)' in VIEWS)
check("native label preview below artwork", "Text(displayLabel)" in VIEWS and "Visual support preview" in VIEWS)
check("generated result normalized to square", "normalizedSquarePNG" in VIEWS and "CGSize(width: 1_024, height: 1_024)" in VIEWS)
check("white canvas is deterministic", "context.cgContext.setFillColor(UIColor.white.cgColor)" in VIEWS)
check("generated temporary URL decoded through ImageIO", "CGImageSourceCreateWithURL" in VIEWS and "rendered.pngData()" in VIEWS)
check("generated draft remains review-before-save", "Illustrated ABA visual ready. Review the artwork and exact label before saving." in VIEWS)
check("original photo can be restored", "Use original photo instead" in VIEWS)
check("library row covers photo/generated art", '"Image visual"' in VIEWS)

# Image performance and lifecycle contract.
check("async image-decode hotfix materialized", "v0.8.0 ABA visual-support async image decode" in VIEWS)
check("no synchronous UIImage data decode remains", "UIImage(data:" not in VIEWS)
check("reference image uses actor-owned thumbnail pipeline", "await ClientVisualThumbnailCache.shared.thumbnail" in VIEWS and "referenceSourceImage = decodedReference.map" in VIEWS)
check("generated result decoding is detached", "await Task.detached(priority: .userInitiated)" in VIEWS and "CGImageSourceCreateThumbnailAtIndex" in VIEWS)
check("reference source clears with selection and save", VIEWS.count("referenceSourceImage = nil") == 2)
check("generated URL is not retained", "normalizedSquarePNG(from: url)" in VIEWS and "LifeRoute stores only the image you approve" in VIEWS)

# Existing single-image and privacy workflow remains honest.
check("photo picker retained", "PhotosPicker(selection: $selectedPhotoItem, matching: .images)" in VIEWS)
check("text-only save retained", "imageData: photoData" in VIEWS)
check("generated result stored through existing protected library", "Icon saved to \\(libraryName)’s visual library on this iPhone." in VIEWS)
check("Image Playground privacy copy is truthful", "Apple’s system Image Playground handles the prompt and optional reference" in VIEWS)
check("later checkpoints are disclosed", "Batch generation and printable PDF sheets remain later checkpoints." in VIEWS)

# Deterministic materialization and post-change protection.
check("visual patch wired into preparation", "python3 scripts/patch_v0_8_0_aba_visual_generator_foundation.py" in PREP)
check("performance wrapper wired into preparation", "python3 scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py" in PREP)
check(
    "compile hotfix has correct availability key",
    "Image Playground 26.4 gate" in COMPILE_HOTFIX
    and "@available(iOS 26.4, *)" in COMPILE_HOTFIX
    and "supportsImagePlayground" in COMPILE_HOTFIX
    and "supportsImageGeneration" in COMPILE_HOTFIX,
)
check(
    "compile hotfix wired through canonical wrapper",
    "runpy.run_path" in WRAPPER
    and "patch_v0_8_0_aba_visual_generator_compile_hotfix.py" in WRAPPER,
)
check("visual audit wired into preparation", "python3 scripts/audit_v0_8_0_aba_visual_generator_foundation.py" in PREP)
check("performance wrapper precedes visual audit", PREP.find("patch_v0_8_0_aba_visual_generator_performance_hotfix.py") < PREP.find("audit_v0_8_0_aba_visual_generator_foundation.py"))
check("Master ABA note audit still runs first", PREP.find("audit_v0_8_0_master_aba_note.py") < PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("protected visual persistence reruns after patch", PREP.rfind("audit_v0_5_0_client_visual_persistence.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("protected performance audit reruns after patch", PREP.rfind("audit_v0_5_0_performance_architecture.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))
check("protected v0.7.1 regression reruns after patch", PREP.rfind("audit_v0_7_1_protected_regressions.py") > PREP.find("patch_v0_8_0_aba_visual_generator_foundation.py"))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.8.0 ABA visual generator foundation audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
