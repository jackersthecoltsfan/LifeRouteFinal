from pathlib import Path

root = Path(__file__).resolve().parents[1]
js = (root / "LifeRoute/Web/information-architecture-v1.js").read_text()
prepare = (root / "scripts/prepare_build.sh").read_text()
playbook = (root / "APP_CREATION_PLAYBOOK.md").read_text()

required_js = [
    'Schedule',
    'Session Tools',
    'Resources',
    'Setup',
    'Visual Timer',
    'Visuals Generator',
    'Documentation Tools',
    'Saved Places',
    'Clients',
    'Personal Tasks',
    'Connections',
    'Home',
    'Relaxation',
    'Errand',
    'Other',
    'data-lr-primary-nav',
    'data-lr-place-category',
    'lifeRouteInformationArchitectureV1Styles',
    'LifeRouteInformationArchitectureV1',
]
for marker in required_js:
    if marker not in js:
        raise SystemExit(f"Information architecture marker missing: {marker}")

if prepare.count('information-architecture-v1.js') < 2:
    raise SystemExit('information-architecture-v1.js must be included in both prepared script lists')

if 'audit_information_architecture_v1.py' not in prepare:
    raise SystemExit('Information architecture audit is not wired into prepare_build.sh')

if 'Lightweight cosmetic preview' not in playbook:
    raise SystemExit('Cosmetic preview workflow rule missing from canonical playbook')

print('LifeRoute information architecture + cosmetic preview workflow audit passed.')
