from pathlib import Path

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
    "top nav includes Schedule": "label: 'Schedule'" in script,
    "top nav includes Session Tools": "label: 'Session Tools'" in script,
    "top nav includes Resources": "label: 'Resources'" in script,
    "top nav includes Setup": "label: 'Setup'" in script,
    "session tools uses refined vector icon": "icon('briefcase', '◈', 19)" in script and "🧩" not in script,
    "session tools includes Visual Timer": "label: 'Visual Timer'" in script,
    "session tools includes Visuals Generator": "label: 'Visuals Generator'" in script,
    "session tools includes Documentation Tools": "label: 'Documentation Tools'" in script,
    "setup includes Saved Places": "Saved Places" in script and 'data-lr-setup-pane="places"' in script,
    "setup includes Clients": 'data-lr-setup-pane="clients"' in script,
    "setup includes Personal Tasks": "Personal Tasks" in script and 'data-lr-setup-pane="tasks"' in script,
    "setup includes Connections": "Connections" in script and 'data-lr-setup-pane="connections"' in script,
    "connections own calendars and navigation": "Calendar inputs|Use these sources|Navigation" in script,
    "saved places include Home": "Home: ['⌂'" in script,
    "saved places include Relaxation": "Relaxation: ['♧'" in script,
    "saved places include Errand": "Errand: ['🛒'" in script,
    "saved places include Other": "Other: ['＋'" in script,
    "gear receives planning preferences": "lifeRoutePlanningSettingsV2" in script and "Ideal maximum open gap" in script,
}

failed = [name for name, ok in checks.items() if not ok]
print(f"LifeRoute navigation architecture audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)
print("LifeRoute top navigation, refined vector iconography, Session Tools, Setup hierarchy, and Saved Places categories passed.")
