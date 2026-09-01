#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 )); then
  echo "usage: run_swift_contract_test.sh SUITE_LABEL EXECUTABLE_NAME SOURCE..." >&2
  exit 2
fi

SUITE_LABEL="$1"
EXECUTABLE_NAME="$2"
shift 2

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SWIFT_COMPILER="$(command -v swiftc || true)"
if [[ -z "$SWIFT_COMPILER" ]]; then
  echo "Swift compiler unavailable; $SUITE_LABEL executable contract fixtures skipped on this host."
  exit 0
fi

for source_path in "$@"; do
  test -f "$source_path"
done

umask 077
CACHE_DIRECTORY="${LIFEROUTE_CONTRACT_CACHE_DIRECTORY:-${TMPDIR:-/tmp}/liferoute-contract-cache-v1}"
mkdir -p "$CACHE_DIRECTORY"
CACHE_KEY="$({
  printf '%s\n' "LifeRoute Swift contract cache v1"
  printf '%s\n' "$SWIFT_COMPILER"
  "$SWIFT_COMPILER" --version 2>&1
  uname -s
  uname -m
  shasum -a 256 "$0" "$@"
} | shasum -a 256 | awk '{print $1}')"
CACHED_EXECUTABLE="$CACHE_DIRECTORY/$EXECUTABLE_NAME-$CACHE_KEY"

if [[ ! -x "$CACHED_EXECUTABLE" ]]; then
  TEMPORARY_EXECUTABLE="$(mktemp "$CACHE_DIRECTORY/$EXECUTABLE_NAME.XXXXXX")"
  trap 'rm -f "$TEMPORARY_EXECUTABLE"' EXIT
  "$SWIFT_COMPILER" "$@" -o "$TEMPORARY_EXECUTABLE"
  chmod 700 "$TEMPORARY_EXECUTABLE"
  mv -f "$TEMPORARY_EXECUTABLE" "$CACHED_EXECUTABLE"
  trap - EXIT
fi

"$CACHED_EXECUTABLE"
