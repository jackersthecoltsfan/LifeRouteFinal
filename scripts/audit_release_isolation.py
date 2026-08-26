from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
PAGES = WORKFLOWS / "pages.yml"
TESTFLIGHT = WORKFLOWS / "testflight.yml"
AUTO_POLICY = WORKFLOWS / "auto-testflight.yml"
RELEASE_PLACEHOLDER = WORKFLOWS / "release.yml"
SETUP = ROOT / "TESTFLIGHT_SETUP.md"

checks = []

def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

pages = PAGES.read_text() if PAGES.exists() else ""
testflight = TESTFLIGHT.read_text() if TESTFLIGHT.exists() else ""
auto = AUTO_POLICY.read_text() if AUTO_POLICY.exists() else ""
release = RELEASE_PLACEHOLDER.read_text() if RELEASE_PLACEHOLDER.exists() else ""
setup = SETUP.read_text() if SETUP.exists() else ""
automatic_triggers = ["workflow_run:", "repository_dispatch:", "schedule:", "push:", "pull_request:"]

# Dedicated TestFlight workflow must remain explicit/manual only.
check("dedicated TestFlight workflow exists", TESTFLIGHT.exists())
check("TestFlight requires workflow_dispatch", bool(re.search(r"(?m)^\s*workflow_dispatch\s*:\s*$", testflight)))
for forbidden in automatic_triggers:
    check(f"TestFlight has no automatic trigger {forbidden[:-1]}", forbidden not in testflight)

# The former auto-promoter is now a harmless manual policy card only.
check("auto-TestFlight file exists as policy guard", AUTO_POLICY.exists())
check("auto policy is manual-only", bool(re.search(r"(?m)^\s*workflow_dispatch\s*:\s*$", auto)))
for forbidden in automatic_triggers:
    check(f"auto policy has no trigger {forbidden[:-1]}", forbidden not in auto)
check("auto policy cannot invoke gh workflow", "gh workflow" not in auto.lower())
check("auto policy cannot call dispatch API", "/dispatches" not in auto.lower() and "createworkflowdispatch" not in auto.lower())
check("auto policy has no Actions write permission", "actions: write" not in auto)

# A historical release.yml placeholder must also remain inert so there is no
# second release-shaped path hiding outside testflight.yml.
check("release placeholder exists", RELEASE_PLACEHOLDER.exists())
check("release placeholder is manual-only", bool(re.search(r"(?m)^\s*workflow_dispatch\s*:\s*$", release)))
for forbidden in automatic_triggers:
    check(f"release placeholder has no trigger {forbidden[:-1]}", forbidden not in release)
check("release placeholder has read-only contents permission", "contents: read" in release and "contents: write" not in release)
check("release placeholder has no Actions write permission", "actions: write" not in release)
check("release placeholder has no Apple credentials", not any(token in release for token in [
    "APPLE_TEAM_ID", "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_PRIVATE_KEY"
]))
check("release placeholder has no archive/upload machinery", not re.search(r"(?i)xcodebuild|\.ipa|upload.*testflight|iTMSTransporter|notarytool|altool|gh workflow|/dispatches", release))

# Web publishing must be release-isolated. Comments may mention TestFlight, but
# executable workflow lines must never call or dispatch it.
executable_pages = "\n".join(
    line for line in pages.splitlines()
    if line.strip() and not line.lstrip().startswith("#")
)
check("Pages workflow exists", PAGES.exists())
check("Pages does not invoke TestFlight workflow", "testflight.yml" not in executable_pages.lower())
check("Pages does not use GitHub CLI workflow dispatch", "gh workflow" not in executable_pages.lower())
check("Pages does not call workflow dispatch REST", "/dispatches" not in executable_pages.lower())
check("Pages has no Apple credential references", not any(token in executable_pages for token in [
    "APPLE_TEAM_ID", "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_PRIVATE_KEY"
]))
check("Pages has no IPA upload command", not re.search(r"(?i)upload.*testflight|iTMSTransporter|notarytool|altool", executable_pages))

# Documentation keeps the human authorization boundary explicit. Accept both
# the older manual-only wording and the newer, stricter explicit-confirmation wording.
manual_policy_documented = (
    "manual-only TestFlight" in setup
    or "explicit-confirmation-only TestFlight release" in setup
)
check("manual-only release policy documented", manual_policy_documented)
check("explicit confirmation documented", "explicit" in setup.lower() and "confirmation" in setup.lower())
check("launch does not imply TestFlight documented", "request to “launch,”" in setup or 'request to "launch,"' in setup)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute release isolation audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Release isolation audit failed: " + "; ".join(failed))
