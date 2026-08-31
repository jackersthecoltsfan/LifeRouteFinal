#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 scripts/validate_current.py full
bash scripts/run_contract_tests.sh

echo "LifeRoute full validation complete."
