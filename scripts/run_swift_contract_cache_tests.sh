#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
RUNNER="$ROOT/scripts/run_swift_contract_test.sh"
TEMPORARY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-swift-cache-v2.XXXXXX")"
trap 'rm -rf "$TEMPORARY_ROOT"' EXIT

CACHE_DIRECTORY="$TEMPORARY_ROOT/cache"
FAKE_BIN="$TEMPORARY_ROOT/bin"
mkdir -p "$CACHE_DIRECTORY" "$FAKE_BIN"

COMPILE_COUNT="$TEMPORARY_ROOT/compile-count"
EXECUTION_LOG="$TEMPORARY_ROOT/execution-log"
FAKE_VERSION_FILE="$TEMPORARY_ROOT/compiler-version"
FAKE_FAIL_FILE="$TEMPORARY_ROOT/compiler-fail"
FAKE_UNAME_S_FILE="$TEMPORARY_ROOT/uname-s"
FAKE_UNAME_M_FILE="$TEMPORARY_ROOT/uname-m"
printf 'fake swiftc v1\n' > "$FAKE_VERSION_FILE"
printf '0\n' > "$COMPILE_COUNT"
printf 'Darwin\n' > "$FAKE_UNAME_S_FILE"
printf 'arm64\n' > "$FAKE_UNAME_M_FILE"

cat > "$FAKE_BIN/swiftc" <<'FAKE_SWIFTC'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  cat "$FAKE_VERSION_FILE"
  exit 0
fi
count="$(cat "$COMPILE_COUNT")"
printf '%s\n' "$((count + 1))" > "$COMPILE_COUNT"
if [[ -f "$FAKE_FAIL_FILE" ]]; then
  exit 42
fi
output=''
previous=''
for argument in "$@"; do
  if [[ "$previous" == '-o' ]]; then
    output="$argument"
    break
  fi
  previous="$argument"
done
test -n "$output"
cat > "$output" <<'FAKE_EXECUTABLE'
#!/usr/bin/env bash
set -euo pipefail
printf 'executed\n' >> "$EXECUTION_LOG"
FAKE_EXECUTABLE
chmod 700 "$output"
FAKE_SWIFTC
chmod 700 "$FAKE_BIN/swiftc"

cat > "$FAKE_BIN/uname" <<'FAKE_UNAME'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  -s) cat "$FAKE_UNAME_S_FILE" ;;
  -m) cat "$FAKE_UNAME_M_FILE" ;;
  *) /usr/bin/uname "$@" ;;
esac
FAKE_UNAME
chmod 700 "$FAKE_BIN/uname"

export PATH="$FAKE_BIN:$PATH"
export LIFEROUTE_CONTRACT_CACHE_DIRECTORY="$CACHE_DIRECTORY"
export FAKE_VERSION_FILE FAKE_FAIL_FILE FAKE_UNAME_S_FILE FAKE_UNAME_M_FILE
export COMPILE_COUNT EXECUTION_LOG

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

compile_count() { cat "$COMPILE_COUNT"; }
execution_count() { [[ -f "$EXECUTION_LOG" ]] && wc -l < "$EXECUTION_LOG" | tr -d ' ' || printf '0\n'; }
assert_equal() {
  [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"
}
run_contract() {
  bash "$@"
}

printf 'same bytes\n' > "$TEMPORARY_ROOT/source-a.swift"
mkdir -p "$TEMPORARY_ROOT/other-location"
cp "$TEMPORARY_ROOT/source-a.swift" "$TEMPORARY_ROOT/other-location/source-b.swift"
run_contract "$RUNNER" "Path-independent" "path-independent" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "1" "first identical-source invocation compiles"
run_contract "$RUNNER" "Path-independent" "path-independent" "$TEMPORARY_ROOT/other-location/source-b.swift"
assert_equal "$(compile_count)" "1" "identical bytes at another path hit the cache"
assert_equal "$(execution_count)" "2" "cache hit still executes the fixture"

run_contract "$ROOT/scripts/run_swift_contract_test.sh" "Runner spelling" "runner-spelling" "$TEMPORARY_ROOT/source-a.swift"
run_contract "$ROOT/scripts/../scripts/run_swift_contract_test.sh" "Runner spelling" "runner-spelling" "$TEMPORARY_ROOT/other-location/source-b.swift"
assert_equal "$(compile_count)" "2" "different runner path spelling preserves the semantic key"

printf 'changed bytes\n' > "$TEMPORARY_ROOT/source-a.swift"
run_contract "$RUNNER" "Changed source" "changed-source" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "3" "changed source bytes miss the cache"

printf 'first\n' > "$TEMPORARY_ROOT/first.swift"
printf 'second\n' > "$TEMPORARY_ROOT/second.swift"
run_contract "$RUNNER" "Source order" "source-order" "$TEMPORARY_ROOT/first.swift" "$TEMPORARY_ROOT/second.swift"
run_contract "$RUNNER" "Source order" "source-order" "$TEMPORARY_ROOT/second.swift" "$TEMPORARY_ROOT/first.swift"
assert_equal "$(compile_count)" "5" "changed source order misses the cache"

TEMPORARY_RUNNER_ROOT="$TEMPORARY_ROOT/runner-copy"
mkdir -p "$TEMPORARY_RUNNER_ROOT/scripts"
cp "$RUNNER" "$TEMPORARY_RUNNER_ROOT/scripts/run_swift_contract_test.sh"
cp "$ROOT/scripts/liferoute_storage.py" "$TEMPORARY_RUNNER_ROOT/scripts/liferoute_storage.py"
printf '# changed runner bytes\n' >> "$TEMPORARY_RUNNER_ROOT/scripts/run_swift_contract_test.sh"
chmod 700 "$TEMPORARY_RUNNER_ROOT/scripts/run_swift_contract_test.sh"
run_contract "$TEMPORARY_RUNNER_ROOT/scripts/run_swift_contract_test.sh" "Changed runner" "changed-runner" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "6" "changed runner bytes miss the cache"

printf 'fake swiftc v2\n' > "$FAKE_VERSION_FILE"
run_contract "$RUNNER" "Changed compiler" "changed-compiler" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "7" "changed compiler identity misses the cache"

printf 'Linux\n' > "$FAKE_UNAME_S_FILE"
printf 'x86_64\n' > "$FAKE_UNAME_M_FILE"
run_contract "$RUNNER" "Changed host" "changed-host" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "8" "changed host identity misses the cache"

run_contract "$RUNNER" "Namespace A" "namespace-a" "$TEMPORARY_ROOT/source-a.swift"
run_contract "$RUNNER" "Namespace B" "namespace-b" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "10" "different executable namespaces do not collide"
namespace_files=("$CACHE_DIRECTORY/namespace-a-"* "$CACHE_DIRECTORY/namespace-b-"*)
[[ ${#namespace_files[@]} -eq 2 ]] || fail "expected separate namespace cache entries"

touch "$FAKE_FAIL_FILE"
if run_contract "$RUNNER" "Compiler failure" "compiler-failure" "$TEMPORARY_ROOT/source-a.swift"; then
  fail "compiler failure unexpectedly succeeded"
fi
rm "$FAKE_FAIL_FILE"
if compgen -G "$CACHE_DIRECTORY/compiler-failure-*" > /dev/null; then
  fail "compiler failure published a cache entry"
fi

run_contract "$RUNNER" "Corrupt cache" "corrupt-cache" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "12" "initial corrupt-cache fixture compiles"
corrupt_entry=("$CACHE_DIRECTORY/corrupt-cache-"*)
printf 'not an executable\n' > "${corrupt_entry[0]}"
chmod 600 "${corrupt_entry[0]}"
run_contract "$RUNNER" "Corrupt cache" "corrupt-cache" "$TEMPORARY_ROOT/source-a.swift"
assert_equal "$(compile_count)" "13" "non-executable cache entry rebuilds"

if rg -n '#file(Path|ID)?\b' "$ROOT/LifeRoute" "$ROOT/scripts" --glob '*.swift' > "$TEMPORARY_ROOT/path-sensitive-matches"; then
  cat "$TEMPORARY_ROOT/path-sensitive-matches" >&2
  fail "contract source contains path-sensitive #file usage"
fi

printf 'PASS Swift contract cache v2: compile invocations=%s fixture executions=%s\n' "$(compile_count)" "$(execution_count)"
