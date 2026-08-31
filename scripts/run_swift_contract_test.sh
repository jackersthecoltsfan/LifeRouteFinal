#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 )); then
  echo "usage: run_swift_contract_test.sh SUITE_LABEL EXECUTABLE_NAME SOURCE..." >&2
  exit 2
fi

SUITE_LABEL="$1"
EXECUTABLE_NAME="$2"
shift 2

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler unavailable; $SUITE_LABEL executable contract fixtures skipped on this host."
  exit 0
fi

for source in "$@"; do
  test -f "$source"
done

umask 077
CACHE_DIRECTORY="${LIFEROUTE_CONTRACT_CACHE_DIRECTORY:-${TMPDIR:-/tmp}/liferoute-contract-cache-v1}"
mkdir -p "$CACHE_DIRECTORY"
CACHE_KEY="$({
  printf '%s\n' "LifeRoute Swift contract cache v1"
  swiftc --version 2>&1
  shasum -a 256 "$0" "$@"
} | shasum -a 256 | awk '{print $1}')"
CACHED_EXECUTABLE="$CACHE_DIRECTORY/$EXECUTABLE_NAME-$CACHE_KEY"

if [[ ! -x "$CACHED_EXECUTABLE" ]]; then
  TEMPORARY_EXECUTABLE="$(mktemp "$CACHE_DIRECTORY/$EXECUTABLE_NAME.XXXXXX")"
  trap 'rm -f "$TEMPORARY_EXECUTABLE"' EXIT
  swiftc "$@" -o "$TEMPORARY_EXECUTABLE"
  mv -f "$TEMPORARY_EXECUTABLE" "$CACHED_EXECUTABLE"
  trap - EXIT
fi

"$CACHED_EXECUTABLE"
