#!/usr/bin/env bash
set -euo pipefail

# Non-production reusable hook. Keep it deterministic, idempotent, and
# validation-oriented. The checked-in project should remain the source owner.

# Examples:
# python3 scripts/validate_current.py fast
# node --check App/Web/app.js
# plutil -lint App/Info.plist

echo "App preparation/preflight complete."
