#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
# Compile the actual production stage declaration without Vision/model dependencies.
# The extraction is exact source, not a separately maintained prompt fixture.
INSTRUCTION_SEAM="$(mktemp "${TMPDIR:-/tmp}/session-note-production-instructions.XXXXXX.swift")"
trap 'rm -f "$INSTRUCTION_SEAM"' EXIT
python3 - "$SCRIPT_DIRECTORY/../LifeRoute/LifeRouteIntelligenceCore.swift" "$INSTRUCTION_SEAM" <<'PYSEAM'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
start = "// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS"
end = "// END SESSION NOTE PRODUCTION INSTRUCTIONS"
assert source.count(start) == source.count(end) == 1
seam = source.split(start, 1)[1].split(end, 1)[0]
assert "enum SessionNoteStageInstructions" in seam
Path(sys.argv[2]).write_text(seam)

# Production declarations/call sites, complementary to executable body/runtime tests.
root = Path(sys.argv[1]).parent
views = (root / "AIClinicalToolsViews.swift").read_text()
ui = views.split("struct AISessionNoteGeneratorView: View {", 1)[1].split("struct SessionNoteReadabilityFixtureView:", 1)[0]
note = source.split("    static func generateABASessionNote(", 1)[1].split("    static func generateVisualScheduleDraft(", 1)[0]
checks = [
    all(token not in ui for token in ["PhotosPicker", "selectedPhotoItems", "screenshotAttachments", "loadSelectedScreenshots", "Attach data screenshots", "Add Photo", "extractionSummary", "attachmentCount"]),
    "screenshotDataItems" not in views and "screenshotDataItems" not in source,
    "recognizeText" not in note and "structuredMeasurements:" not in note and ".extracted(" not in note,
    "guard !cleanNarrative.isEmpty" in note,
    "SessionNoteGenerationPipeline.generateNote(" in note and "writerRole: writerRole" in note,
    "SessionNoteWriterRole.resolve(profileCredential: writerCredential)" in views,
    "@AppStorage(SessionNoteWriterRole.profileCredentialKey)" in ui and "writerCredential: writerCredential" in ui,
    '"liferoute.rbtProfile.credential"' in (root / "V054SetupView.swift").read_text(),
    "PhotosPicker(selection: $selectedPhotoItem, matching: .images)" in (root / "SessionToolsViews.swift").read_text(),
    "VNRecognizeTextRequest()" in source and "VNImageRequestHandler(data: imageData" in source,
    sum(p.read_text().count("generateABASessionNote(") for p in root.glob("*.swift")) == 2,
    views.count("LifeRouteIntelligenceCore.generateABASessionNote(") == 1,
]
assert all(checks), [i + 1 for i, ok in enumerate(checks) if not ok]
print(f"Session Note production photo-removal / role call-path assertions passed ({len(checks)} assertions).")
PYSEAM

bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Session Note" \
  "session-note-contract-tests" \
  LifeRoute/SessionNoteContracts.swift \
  "$INSTRUCTION_SEAM" \
  scripts/session_note_contract_tests.swift
