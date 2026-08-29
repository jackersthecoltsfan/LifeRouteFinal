from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "LifeRoute.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, bool(condition)))


check("marketing version bumped to 0.8.1", "MARKETING_VERSION = 0.8.1;" in PROJECT)
check("build number remains workflow-owned", "CURRENT_PROJECT_VERSION = 2;" in PROJECT)
check("icon validation uses Python fallback on non-Swift hosts", "command -v swift" in PREPARE and "python3 -" in PREPARE)
check("plist lint uses Python fallback", "plistlib" in PREPARE and "Info.plist" in PREPARE)
check("v0.8.1 audits are wired into prepare", "audit_v0_8_1_session_note_and_visual_prompt.py" in PREPARE and "audit_v0_8_1_navigation_toolbar_schedule.py" in PREPARE)

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {label}")

print(f"LifeRoute v0.8.1 release-prep audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
