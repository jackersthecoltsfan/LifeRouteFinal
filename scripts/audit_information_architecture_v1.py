from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
web = root / "LifeRoute" / "Web"
js_path = web / "information-architecture-v1.js"
js = js_path.read_text()
stability = (web / "stability-runtime.js").read_text()
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

if 'information-architecture-v1.js' not in stability:
    raise SystemExit('Final information architecture layer is not loaded by stability-runtime.js')

if '__lifeRouteInformationArchitectureLoaderInstalled' not in stability:
    raise SystemExit('Information architecture loader guard is missing')

if 'Lightweight cosmetic preview' not in playbook:
    raise SystemExit('Cosmetic preview workflow rule missing from canonical playbook')

subprocess.run(['node', '--check', str(js_path)], check=True)
print('LifeRoute information architecture + cosmetic preview workflow audit passed.')
