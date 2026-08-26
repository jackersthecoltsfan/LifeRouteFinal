from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
PAGES = WORKFLOWS / "pages.yml"
TESTFLIGHT = WORKFLOWS / "testflight.yml"
ASSISTANT_RELEASE = WORKFLOWS / "chatgpt-testflight-request.yml"
SETUP = ROOT / "TESTFLIGHT_SETUP.md"
PLAYBOOK = ROOT / "APP_CREATION_PLAYBOOK.md"

checks = []


def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))


def text(path: Path) -> str:
    return path.read_text() if path.exists() else ""


def executable_yaml(src: str) -> str:
    return "\n".join(
        line for line in src.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )


pages = text(PAGES)
testflight = text(TESTFLIGHT)
assistant_release = text(ASSISTANT_RELEASE)
setup = text(SETUP)
playbook = text(PLAYBOOK)
workflow_files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))

automatic_release_triggers = [
    "workflow_run:",
    "repository_dispatch:",
    "schedule:",
    "push:",
    "pull_request:",
    "issues:",
]
apple_secrets = [
    "APPLE_TEAM_ID",
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_PRIVATE_KEY",
]
upload_markers = [
    "Upload to TestFlight",
    "--upload-app",
    "iTMSTransporter",
    "xcrun altool",
]

# There is exactly one real upload workflow, and it is manual-only.
check("dedicated TestFlight workflow exists", TESTFLIGHT.exists())
check("TestFlight requires workflow_dispatch", bool(re.search(r"(?m)^\s*workflow_dispatch\s*:\s*$", testflight)))
for forbidden in automatic_release_triggers:
    check(f"TestFlight has no automatic trigger {forbidden[:-1]}", forbidden not in testflight)
check("TestFlight has no Actions write permission", "actions: write" not in testflight)
check("TestFlight contains the upload step", "Upload to TestFlight" in testflight and "--upload-app" in testflight)
check("TestFlight accepts assistant authorized_sha input", "authorized_sha:" in testflight)
check("TestFlight validates dispatched SHA against authorized SHA", 'test "$GITHUB_SHA" = "$AUTHORIZED_SHA"' in testflight)

release_capable = []
for path in workflow_files:
    src = text(path)
    if any(marker in src for marker in upload_markers):
        release_capable.append(path.name)
check("only testflight.yml contains upload machinery", release_capable == ["testflight.yml"])

# The assistant bridge may dispatch the manual workflow, but it may not sign,
# archive, or upload an app itself.
check("assistant release bridge exists", ASSISTANT_RELEASE.exists())
check("assistant bridge is issue-gated", bool(re.search(r"(?m)^\s*issues\s*:\s*$", assistant_release)))
check("assistant bridge has no push trigger", not bool(re.search(r"(?m)^\s*push\s*:\s*$", assistant_release)))
check("assistant bridge has Actions write permission", "actions: write" in assistant_release)
check("assistant bridge requires exact authorization marker", "AUTHORIZED_TESTFLIGHT_RELEASE=YES" in assistant_release)
check("assistant bridge dispatches only testflight.yml", "actions/workflows/testflight.yml/dispatches" in assistant_release)
check("assistant bridge passes exact authorized SHA", "authorized_sha" in assistant_release and "$RELEASE_SHA" in assistant_release)
check("assistant bridge has no Apple credential references", not any(token in assistant_release for token in apple_secrets))
check("assistant bridge has no upload machinery", not any(marker in assistant_release for marker in upload_markers))
check("assistant bridge has no archive/export machinery", not re.search(r"(?i)xcodebuild|\.ipa|exportArchive|archivePath", assistant_release))

# Every other workflow is validation/publishing/policy only. None may gain Apple
# secrets, Actions-write dispatch capability, or TestFlight upload machinery.
for path in workflow_files:
    if path.name in {"testflight.yml", "chatgpt-testflight-request.yml"}:
        continue
    src = executable_yaml(text(path))
    check(f"{path.name} has no Apple credential references", not any(token in src for token in apple_secrets))
    check(f"{path.name} cannot dispatch TestFlight", "actions/workflows/testflight.yml/dispatches" not in src)
    check(f"{path.name} has no Actions write permission", "actions: write" not in src)
    check(f"{path.name} has no TestFlight upload machinery", not any(marker in src for marker in upload_markers))

# Pages is explicitly release-isolated.
check("Pages workflow exists", PAGES.exists())
check("Pages does not invoke TestFlight workflow", "testflight.yml" not in executable_yaml(pages).lower())
check("Pages has no Apple credential references", not any(token in executable_yaml(pages) for token in apple_secrets))

# Documentation keeps the human authorization boundary explicit and consistent.
policy_docs = setup + "\n" + playbook
manual_policy_documented = (
    "manual-only TestFlight" in policy_docs
    or "explicit-confirmation-only TestFlight release" in policy_docs
)
check("manual-only release policy documented", manual_policy_documented)
check("explicit confirmation documented", "explicit" in policy_docs.lower() and "confirmation" in policy_docs.lower())
check("launch does not imply TestFlight documented", "launch" in policy_docs.lower() and "does not" in policy_docs.lower())
check("exact-SHA assistant dispatch documented", "exact-SHA" in policy_docs or "exact main SHA" in policy_docs)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute release isolation audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Release isolation audit failed: " + "; ".join(failed))
