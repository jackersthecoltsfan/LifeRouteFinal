#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 scripts/validate_current.py fast

if command -v plutil >/dev/null 2>&1; then
  plutil -lint LifeRoute/Info.plist LifeRouteLiveActivityWidget/Info.plist
fi

echo "LifeRoute fast validation complete."
