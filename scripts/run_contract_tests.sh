#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler is required for canonical LifeRoute full validation." >&2
  exit 1
fi

CONTRACT_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-contract-suite.XXXXXX")"
trap 'rm -rf "$CONTRACT_DIRECTORY"' EXIT

labels=(
  "Day Route"
  "Session Note"
  "Visual Timer feedback"
  "Runtime feedback"
)
runners=(
  "scripts/run_day_route_contract_tests.sh"
  "scripts/run_session_note_contract_tests.sh"
  "scripts/run_visual_timer_feedback_contract_tests.sh"
  "scripts/run_runtime_feedback_contract_tests.sh"
)
pids=()
logs=()

for index in "${!runners[@]}"; do
  log="$CONTRACT_DIRECTORY/contract-$index.log"
  logs+=("$log")
  bash "${runners[$index]}" >"$log" 2>&1 &
  pids+=("$!")
done

failed=0
for index in "${!pids[@]}"; do
  if ! wait "${pids[$index]}"; then
    failed=1
  fi
  echo "${labels[$index]} contracts:"
  sed 's/^/  /' "${logs[$index]}"
done

if (( failed != 0 )); then
  echo "One or more LifeRoute executable contract suites failed." >&2
  exit 1
fi

echo "LifeRoute executable contract suites passed."
