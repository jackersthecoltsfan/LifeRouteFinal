from pathlib import Path


DASHBOARD = Path("LifeRoute/V054ToolsDashboard.swift").read_text(encoding="utf-8")
VISUALS = Path("LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
DOMAIN = Path("LifeRoute/SessionToolsDomain.swift").read_text(encoding="utf-8")
PREPARE = Path("scripts/prepare_build.sh").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, condition))


check("visible-generator marker in primary screen", "v0.8.0 follow-up visible ABA visual generator" in DASHBOARD)
check("visible-generator marker in generator screen", "v0.8.0 follow-up visible ABA visual generator" in VISUALS)
check("primary card has visibly new identity", 'Text("Illustrated Icon Generator")' in DASHBOARD)
check("primary card reaches real generator", "ClientVisualIconLibraryView(" in DASHBOARD and "clientCode: selectedClientCode" in DASHBOARD)
check("text-only mode visible", 'visualGeneratorModeBadge("TEXT ONLY"' in DASHBOARD)
check("photo mode visible", 'visualGeneratorModeBadge("PHOTO"' in DASHBOARD)
check("regeneration mode visible", 'visualGeneratorModeBadge("REGENERATE"' in DASHBOARD)
check("reference-to-result journey visible", 'Text("REFERENCE")' in DASHBOARD and 'Text("ILLUSTRATED ICON")' in DASHBOARD)
check("selected protected library retained", "libraryDisplayName" in DASHBOARD and "selectedClientCode" in DASHBOARD)

check("exact editable label remains", 'TextField("Exact icon label"' in VISUALS)
check("text-only saving remains", "addIcon(clientCode: clientCode, label: label, imageData: photoData)" in VISUALS)
check("reference photo picker remains", "PhotosPicker(selection: $selectedPhotoItem" in VISUALS)
check("reference source reaches Image Playground", "sourceImage: referenceSourceImage" in VISUALS and "sourceImage: sourceImage" in VISUALS)
check("reference and result comparison", 'title: "REFERENCE PHOTO"' in VISUALS and 'title: "GENERATED ICON"' in VISUALS)
check("comparison adapts to width", "ViewThatFits(in: .horizontal)" in VISUALS)
check("stable reference preview identity", "referencePreviewID" in VISUALS)
check("regeneration control remains", '"Regenerate illustrated icon"' in VISUALS)
check("result preparation feedback", "isPreparingResult" in VISUALS and 'Text("Preparing approved visual…")' in VISUALS)
check("generation failure remains visible", "LifeRoute could not import that generated image" in VISUALS)

check("Master ABA visual prompt remains", "ABAVisualSupportPrompt.make" in VISUALS)
check("consistent illustration style", "one coordinated professionally designed ABA visual-support library" in VISUALS)
check("neutral view and pure white requested", "neutral front or three-quarter viewing angle" in VISUALS and "pure-white background" in VISUALS)
check("no generated lettering requested", "Do not render letters, words, captions, labels" in VISUALS)
check("LifeRoute renders exact label", "LifeRoute renders the exact user label beneath the artwork separately" in VISUALS)
check("square white normalization remains", "normalizedSquarePNG" in VISUALS and "CGSize(width: 1_024, height: 1_024)" in VISUALS)
check("ImageIO decode remains off render path", "CGImageSourceCreateThumbnailAtIndex" in VISUALS and "Task.detached(priority: .userInitiated)" in VISUALS)
check("local persistence owner unchanged", "final class ClientVisualSupportCore" in DOMAIN)
check("library save remains", 'message = "Icon saved to \\(libraryName)’s visual library on this iPhone."' in VISUALS)
check("original photo restore remains", 'Label("Use original photo instead"' in VISUALS)

check("follow-up patch prepared", "patch_v0_8_0_visual_generator_followup.py" in PREPARE)
check("follow-up audit prepared", "audit_v0_8_0_visual_generator_followup.py" in PREPARE)

failed = [label for label, condition in checks if not condition]
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(f"LifeRoute v0.8.0 visual-generator follow-up audit failed: {len(failed)} checks")

print(f"LifeRoute v0.8.0 visual-generator follow-up audit passed: {len(checks)}/{len(checks)} checks")
