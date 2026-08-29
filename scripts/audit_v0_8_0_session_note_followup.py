from pathlib import Path


VIEW = Path("LifeRoute/AIClinicalToolsViews.swift").read_text(encoding="utf-8")
CORE = Path("LifeRoute/LifeRouteIntelligenceCore.swift").read_text(encoding="utf-8")
PREPARE = Path("scripts/prepare_build.sh").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, condition))


check("follow-up marker materialized in view", "v0.8.0 follow-up session-note refinement" in VIEW)
check("follow-up marker materialized in core", "v0.8.0 follow-up session-note refinement" in CORE)
check("RBT-only clinician contract", 'Refer to the clinician only as "the RBT" or "RBT."' in CORE)
check("personal name excluded from generation instructions", "Never use Brandon Good" not in CORE)
check("personal clinician name scrubbed from input", 'of: "Brandon Good"' in CORE and 'with: "RBT"' in CORE)
check("personal clinician name scrubbed from output", "sanitizedSessionNoteDraft" in CORE and 'with: "the RBT"' in CORE)
check("personal clinician name triggers repair", 'lower.contains("brandon good")' in CORE)
check("clinical shorthand synthesis required", "Convert rough shorthand into connected chronological prose" in CORE)
check("intervention-response linking required", "link each supplied intervention to the corresponding client response" in CORE)

check("stable attachment model", "struct SessionNoteScreenshotAttachment: Identifiable" in VIEW)
check("multi-selection picker", "selection: $selectedPhotoItems" in VIEW and "maxSelectionCount: 6" in VIEW)
check("no single screenshot state", "@State private var screenshotData: Data?" not in VIEW)
check("attachment removal available", "removeScreenshot(attachment)" in VIEW)
check("stable attachment identity retained", "?.id ?? UUID()" in VIEW)
check("attachment rows use random-access data", "ForEach(Array(screenshotAttachments.enumerated()), id: \\.element.id)" in VIEW)
check("local loading feedback", "isLoadingScreenshots" in VIEW and "ProgressView()" in VIEW)
check("multi-screenshot runtime protocol", VIEW.count("screenshotDataItems: [Data]") == 4)
check("attachment data snapshotted into request", "screenshotAttachments.map(\\.data)" in VIEW)
check("typed narrative remains valid alone", "|| !screenshotAttachments.isEmpty" in VIEW)
check("editing remains", 'Text("Editable draft")' in VIEW and "TextEditor(text: $runtime.generatedNote)" in VIEW)
check("copy remains", "UIPasteboard.general.string = runtime.generatedNote" in VIEW)
check("regeneration remains", 'Label("Regenerate from current facts"' in VIEW)
check("cancellation and timeout remain", "SessionNoteRequestRace" in VIEW and "timeoutSeconds: UInt64 = 75" in VIEW)
check("background cancellation remains", ".onChange(of: scenePhase)" in VIEW and "runtime.cancel()" in VIEW)

check("core accepts screenshot array", "screenshotDataItems: [Data]" in CORE)
check("OCR input capped", "Array(imageDataItems.prefix(6))" in CORE)
check("OCR runs concurrently", "withTaskGroup" in CORE)
check("OCR order restored", ".sorted { $0.0 < $1.0 }" in CORE)
check("evidence grouped by screenshot", 'return "SCREENSHOT \\(screenshotIndex + 1):' in CORE)
check("combined OCR bounded", ".prefix(2_800)" in CORE)
check("narrative remains primary evidence", "SESSION FACTS — primary evidence" in CORE)
check("screenshots remain supporting evidence", "SCREENSHOT OCR / DATA — supporting evidence only" in CORE)

for source_label, source_token in (
    ("percentage", "PERCENTAGE"),
    ("frequency/count", "FREQUENCY/COUNT"),
    ("duration", "DURATION"),
    ("latency", "LATENCY"),
    ("rate", "RATE"),
    ("trial-based", "TRIAL-BASED"),
    ("independent/prompted", "INDEPENDENT/PROMPTED"),
    ("ambiguous OCR", "AMBIGUOUS OCR"),
):
    check(f"{source_label} evidence classification", source_token in CORE)

check("mixed data types cannot be flattened", "never flatten unlike data into generic percentages" in CORE)
check("frequency wording constrained", "number of instances or events" in CORE)
check("duration wording constrained", "Duration describes how long" in CORE)
check("latency wording constrained", "Latency describes the supplied time before" in CORE)
check("rate wording constrained", "events-per-unit" in CORE)
check("trial wording constrained", "correct/total or trial-based form" in CORE)
check("independent and prompted remain distinct", "Independent and prompted responding remain distinct" in CORE)
check("prompt fidelity remains", "Preserve every explicitly supplied prompting level exactly" in CORE)
check("behaviors-of-concern terminology remains", 'Say "behaviors of concern," never "maladaptive behaviors."' in CORE)
check("no-fabrication boundary remains", "Do not fabricate targets, behaviors, antecedents" in CORE)
check("treatment-plan close remains", "continue implementing the established treatment plan" in CORE)

check("follow-up patch is prepared", "patch_v0_8_0_session_note_followup.py" in PREPARE)
check("follow-up audit is prepared", "audit_v0_8_0_session_note_followup.py" in PREPARE)

failed = [label for label, condition in checks if not condition]
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(f"LifeRoute v0.8.0 session-note follow-up audit failed: {len(failed)} checks")

print(f"LifeRoute v0.8.0 session-note follow-up audit passed: {len(checks)}/{len(checks)} checks")
