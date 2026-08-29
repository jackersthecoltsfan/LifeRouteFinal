from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VIEW = (ROOT / "LifeRoute/AIClinicalToolsViews.swift").read_text(encoding="utf-8")
CORE = (ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift").read_text(encoding="utf-8")
DOM = (ROOT / "LifeRoute/SessionToolsDomain.swift").read_text(encoding="utf-8")
SESSION_PATCH = (ROOT / "scripts/patch_v0_8_0_session_note_followup.py").read_text(encoding="utf-8")
VISUAL_FOUNDATION = (ROOT / "scripts/patch_v0_8_0_aba_visual_generator_foundation.py").read_text(encoding="utf-8")
VISUAL_FOLLOWUP = (ROOT / "scripts/patch_v0_8_0_visual_generator_followup.py").read_text(encoding="utf-8")
TOOLS = (ROOT / "LifeRoute/V054ToolsDashboard.swift").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, bool(condition)))


check("v0.8.1 session-note repair marker", "v0.8.1 session-note repair" in SESSION_PATCH)
check("sanitized repair result returned", "cleanedRepairedDraft" in SESSION_PATCH and "return cleanedRepairedDraft" in SESSION_PATCH)
check("sanitizer keeps line cleanup", "headingPrefixes" in SESSION_PATCH and "replacingOccurrences(of: \"\\n{3,}\"" in SESSION_PATCH)
check("multi-screenshot request remains bounded", "screenshotDataItems: [Data]" in SESSION_PATCH and "Array(imageDataItems.prefix(6))" in SESSION_PATCH)
check("typed narrative still primary", "cleanNarrative" in SESSION_PATCH and "recognizedScreenshots.contains(where: { !$0.isEmpty })" in SESSION_PATCH)
check("RBT identity remains normalized", 'replacingOccurrences(of: "Brandon Good", with: "the RBT"' in SESSION_PATCH)
check("mixed measurement contract preserved", "INDEPENDENT/PROMPTED" in SESSION_PATCH and "DURATION" in SESSION_PATCH and "LATENCY" in SESSION_PATCH)
check("session-note view keeps six-attachment state", "selectedPhotoItems: [PhotosPickerItem]" in VIEW and "screenshotAttachments: [SessionNoteScreenshotAttachment]" in VIEW and "maxSelectionCount: 6" in VIEW)
check("session-note view keeps explicit generation states", "generationPhase: SessionNoteGenerationPhase = .idle" in VIEW and "generationTask: Task<Void, Never>?" in VIEW and "activeGenerationID = UUID()" in VIEW)
check("session-note view keeps cancellation and stale-request protection", "cancelGeneration()" in VIEW and "guard generationTask == nil else { return }" in VIEW and "guard activeGenerationID == requestID else { return }" in VIEW)
check("session-note view preserves attachment result flow", "screenshotDataItems: screenshotAttachments.map(\\.data)" in VIEW and "SessionNoteScreenshotAttachment(id:" in VIEW)
check("session-note view exposes all terminal states", ".checkingAvailability" in VIEW and ".generating" in VIEW and ".repairing" in VIEW and ".success" in VIEW and ".unavailable" in VIEW and ".failed" in VIEW and ".timedOut" in VIEW and ".cancelled" in VIEW)
check("session-note view keeps generated result visible", "generatedNote = result" in VIEW and "if !generatedNote.isEmpty { resultCard }" in VIEW)
check("session-note deep tool screen hides the root toolbar", ".toolbar(.hidden, for: .tabBar)" in VIEW)
check("session-note core still materializes availability and repair", "sessionNoteNeedsMasterABARepair" in CORE and "sanitizedSessionNoteDraft" in CORE)

check("functional concept interpreter exists", "enum ABAVisualSupportConceptInterpreter" in DOM)
for token in ("water play", "outside", "break", "help", "more", "bathroom", "eat", "sleep"):
    check(f"concept mapping covers {token}", token in DOM.lower())

check("visual prompt uses interpreter", "ABAVisualSupportConceptInterpreter.describe" in VISUAL_FOUNDATION)
check("visual prompt preserves exact label", "exact user label" in VISUAL_FOUNDATION and "Functional concept:" in VISUAL_FOUNDATION)
check("no lettering in artwork", "Do not render letters, words, captions, labels" in VISUAL_FOUNDATION)
check("visual generator follow-up keeps reference/result clarity", "referenceSourceImage" in VISUAL_FOLLOWUP and "referencePreviewID" in VISUAL_FOLLOWUP and "Preparing approved visual…" in VISUAL_FOLLOWUP)
check("tools dashboard concept prompt is interpreter-backed", "resolvedIconPrompt" in TOOLS and "ABAVisualSupportConceptInterpreter.describe" in TOOLS)

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {label}")

print(f"LifeRoute v0.8.1 session-note and visual-prompt audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
