from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WF = ROOT / ".github" / "workflows"

files = {
    "ios": WF / "ios-ci.yml",
    "pages": WF / "pages.yml",
    "policy": WF / "policy-check.yml",
    "assistant": WF / "chatgpt-testflight-request.yml",
    "testflight": WF / "testflight.yml",
}

checks = []


def check(name, ok):
    checks.append((name, bool(ok)))


def read(name):
    path = files[name]
    return path.read_text() if path.exists() else ""


for name, path in files.items():
    check(f"{name} workflow exists", path.exists())

all_workflows = sorted(p.name for p in WF.glob("*.yml")) + sorted(p.name for p in WF.glob("*.yaml"))
check("workflow set is intentionally small", set(all_workflows) == {
    "ios-ci.yml",
    "pages.yml",
    "policy-check.yml",
    "chatgpt-testflight-request.yml",
    "testflight.yml",
})
check("obsolete auto-testflight placeholder removed", "auto-testflight.yml" not in all_workflows)
check("obsolete release placeholder removed", "release.yml" not in all_workflows)

ios = read("ios")
pages = read("pages")
policy = read("policy")
assistant = read("assistant")
testflight = read("testflight")

check("iOS CI does not trigger on every workflow edit", "'.github/workflows/**'" not in ios and '".github/workflows/**"' not in ios)
check("iOS CI self-change still triggers validation", ".github/workflows/ios-ci.yml" in ios)
check("iOS CI routes release-policy audit to lightweight workflow", "!scripts/audit_release_isolation.py" in ios)
check("iOS concurrency is workflow-scoped", "group: ${{ github.workflow }}-${{ github.ref }}" in ios)
check("iOS cancels superseded validation", "cancel-in-progress: true" in ios)

check("Pages routes release-policy audit to lightweight workflow", "!scripts/audit_release_isolation.py" in pages)
check("Pages concurrency is workflow-scoped", "group: ${{ github.workflow }}-${{ github.ref }}" in pages)
check("Pages cancels superseded previews", "cancel-in-progress: true" in pages)

# prepare_build.sh already owns these deep shared audits. Re-running them in the
# Pages workflow wastes macOS runner time and increases queue pressure.
for duplicate in [
    "audit_interaction_performance_v3.py",
    "audit_stability.py",
    "audit_runtime_release.py",
    "audit_state_invariants.py",
    "audit_user_journeys.py",
]:
    check(f"Pages does not duplicate {duplicate}", duplicate not in pages)

check("policy audit uses inexpensive Ubuntu runner", "runs-on: ubuntu-latest" in policy and "macos-" not in policy)
check("policy audit covers workflow edits", ".github/workflows/**" in policy)
check("policy audit covers release documentation", "TESTFLIGHT_SETUP.md" in policy and "APP_CREATION_PLAYBOOK.md" in policy)

# The assistant release bridge should validate completed runs and dispatch; it
# must not hold a runner for hours while polling other workflows.
timeout = re.search(r"timeout-minutes:\s*(\d+)", assistant)
check("assistant release bridge timeout is short", bool(timeout) and int(timeout.group(1)) <= 15)
check("assistant release bridge has no 30-second polling", "sleep 30" not in assistant)
check("assistant release bridge has no 180-iteration wait loops", "seq 1 180" not in assistant)
check("assistant bridge requires completed successful validation", 'status == "completed" and .conclusion == "success"' in assistant)

check("TestFlight remains workflow_dispatch only", "workflow_dispatch:" in testflight and not any(
    trigger in testflight for trigger in ["push:", "pull_request:", "issues:", "workflow_run:", "schedule:"]
))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute workflow efficiency audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Workflow efficiency audit failed: " + "; ".join(failed))
