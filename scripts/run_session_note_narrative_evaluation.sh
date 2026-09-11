#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
INSTRUCTION_SEAM="$(mktemp "${TMPDIR:-/tmp}/session-note-narrative-instructions.XXXXXX.swift")"
EVALUATION_BINARY="$(mktemp "${TMPDIR:-/tmp}/session-note-narrative-evaluation.XXXXXX")"
trap 'rm -f "$INSTRUCTION_SEAM" "$EVALUATION_BINARY"' EXIT

python3 - "$REPOSITORY_ROOT/LifeRoute/LifeRouteIntelligenceCore.swift" "$INSTRUCTION_SEAM" <<'PYSEAM'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = "// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS"
end = "// END SESSION NOTE PRODUCTION INSTRUCTIONS"
assert source.count(start) == source.count(end) == 1
Path(sys.argv[2]).write_text(source.split(start, 1)[1].split(end, 1)[0])
PYSEAM

xcrun swiftc \
  -parse-as-library \
  -o "$EVALUATION_BINARY" \
  "$REPOSITORY_ROOT/LifeRoute/SessionNoteContracts.swift" \
  "$INSTRUCTION_SEAM" \
  "$SCRIPT_DIRECTORY/session_note_narrative_evaluation.swift"

"$EVALUATION_BINARY" "$@"
