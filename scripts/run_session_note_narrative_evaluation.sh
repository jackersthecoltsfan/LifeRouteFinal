#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
INSTRUCTION_SEAM="$(mktemp "${TMPDIR:-/tmp}/session-note-narrative-instructions.XXXXXX.swift")"
INSTRUCTION_MANIFEST="$(mktemp "${TMPDIR:-/tmp}/session-note-narrative-instructions.XXXXXX.json")"
EVALUATION_BINARY="$(mktemp "${TMPDIR:-/tmp}/session-note-narrative-evaluation.XXXXXX")"
trap 'rm -f "$INSTRUCTION_SEAM" "$INSTRUCTION_MANIFEST" "$EVALUATION_BINARY"' EXIT

python3 "$SCRIPT_DIRECTORY/source_extract.py" \
  --source "$REPOSITORY_ROOT/LifeRoute/LifeRouteIntelligenceCore.swift" \
  --logical-source-path "LifeRoute/LifeRouteIntelligenceCore.swift" \
  --label "session-note-production-instructions" \
  --mode marker_block \
  --start "// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS" \
  --end "// END SESSION NOTE PRODUCTION INSTRUCTIONS" \
  --output "$INSTRUCTION_SEAM" \
  --manifest "$INSTRUCTION_MANIFEST"

xcrun swiftc \
  -parse-as-library \
  -o "$EVALUATION_BINARY" \
  "$REPOSITORY_ROOT/LifeRoute/SessionNoteContracts.swift" \
  "$INSTRUCTION_SEAM" \
  "$SCRIPT_DIRECTORY/session_note_narrative_evaluation.swift"

"$EVALUATION_BINARY" "$@"
