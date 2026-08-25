from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
web = ROOT / "LifeRoute" / "Web"
script = (web / "toolbar-cleanup-v1.js").read_text()
config = (web / "config.js").read_text()
index = (web / "index.html").read_text()

checks = {
    "shared cleanup file exists": bool(script.strip()),
    "exports toolbar cleanup": "LifeRouteToolbarCleanupV1" in script,
    "targets main tabs only": "document.querySelector('.tabs')" in script,
    "removes month data-view": "child.dataset?.view === 'month'" in script,
    "does not delete month view section": "getElementById('month')" not in script and 'getElementById("month")' not in script,
    "retains real month calendar builder": 'monthSection.id = "month"' in config,
    "retains month renderer": "renderMonth" in config,
    "dynamic toolbar column count": "grid-template-columns" in script and "repeat(${count}" in script,
    "late tab reconciliation": "MutationObserver" in script,
    "observer limited to child list": "{ childList: true }" in script,
    "no subtree-wide toolbar observer": "subtree: true" not in script,
    "prepared index loads shared cleanup": '<script src="toolbar-cleanup-v1.js"></script>' in index,
}

failed = [name for name, ok in checks.items() if not ok]
print(f"LifeRoute toolbar cleanup audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)

# The final information-architecture layer owns the user-facing navigation after
# the core runtime settles. Run its independent contract audit from this gate so
# every prepared CI/TestFlight build validates both layers without duplicating
# release-workflow wiring.
subprocess.run(["python3", str(ROOT / "scripts" / "audit_information_architecture_v1.py")], check=True)
print("LifeRoute toolbar cleanup + final information architecture audits passed.")
