#!/usr/bin/env python3
"""Run exact BoardArtifact.swift export fixtures in a separate Simulator app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--simulator', required=True, help='Explicit Simulator UUID; never selects a booted device implicitly')
parser.add_argument('--developer-dir', type=Path)
parser.add_argument('--boot', action='store_true', help='Explicitly authorize booting the selected existing Simulator')
parser.add_argument('--timeout', type=int, default=240)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
assert output != root and root not in output.parents, 'Evidence must be outside the checkout'
assert args.timeout > 0
bundle_id = 'local.liferoute.BoardArtifactTests'
run_id = uuid.uuid4().hex
run = output / run_id
run.mkdir(parents=True)
environment = dict(os.environ)
if args.developer_dir:
    environment['DEVELOPER_DIR'] = str(args.developer_dir.resolve())
environment.pop('SDKROOT', None)
log = run / 'commands.log'


def command(*argv, extra_env=None):
    env = dict(environment)
    if extra_env:
        env.update(extra_env)
    result = subprocess.run(list(map(str, argv)), capture_output=True, text=True, env=env)
    with log.open('a') as stream:
        stream.write(json.dumps(list(map(str, argv))) + '\n')
        stream.write(result.stdout + result.stderr + f'\nEXIT={result.returncode}\n')
    result.check_returncode()
    return result.stdout.strip()


devices = json.loads(command('xcrun', 'simctl', 'list', 'devices', '--json'))
matches = [(runtime, item) for runtime, entries in devices['devices'].items()
           for item in entries if item['udid'] == args.simulator]
assert len(matches) == 1 and matches[0][1].get('isAvailable', False), 'Selected Simulator must exist and be available'
runtime, device = matches[0]
if device['state'] != 'Booted':
    assert args.boot, 'Selected Simulator is shut down; boot it explicitly or pass --boot'
    command('xcrun', 'simctl', 'boot', args.simulator)
command('xcrun', 'simctl', 'bootstatus', args.simulator, '-b')
sdk = command('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
app = run / 'BoardArtifactTests.app'
source = run / 'source'
app.mkdir()
source.mkdir()
shutil.copy2(root / 'LifeRoute/BoardArtifact.swift', source / 'BoardArtifact.swift')
shutil.copy2(root / 'scripts/fixtures/BoardArtifactRenderHarness.swift', source / 'BoardArtifactRenderHarness.swift')
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob('*.swift')}
manifest.update({'simulator': args.simulator, 'runtime': runtime, 'test_bundle': bundle_id,
                 'sdk': sdk, 'run_id': run_id})
(run / 'SOURCE_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
info = {'CFBundleIdentifier': bundle_id, 'CFBundleName': 'BoardArtifactTests',
        'CFBundleExecutable': 'BoardArtifactTests', 'CFBundleVersion': '1',
        'CFBundleShortVersionString': '1.0', 'CFBundlePackageType': 'APPL',
        'MinimumOSVersion': '26.0', 'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1, 2],
        'UILaunchScreen': {}}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
command('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-target', 'arm64-apple-ios26.0-simulator',
        '-sdk', sdk, '-parse-as-library', '-module-cache-path', run / 'module-cache',
        source / 'BoardArtifact.swift', source / 'BoardArtifactRenderHarness.swift',
        '-o', app / 'BoardArtifactTests')
command('codesign', '--force', '--sign', '-', app)
command('xcrun', 'simctl', 'install', args.simulator, app)
command('xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator, bundle_id,
        extra_env={'SIMCTL_CHILD_BOARD_REVIEW_RUN_ID': run_id})
container = Path(command('xcrun', 'simctl', 'get_app_container', args.simulator, bundle_id, 'data'))
results = container / 'Documents' / ('BoardReview-' + run_id)
report_path = results / 'REPORT.json'
deadline = time.monotonic() + args.timeout
report = None
while time.monotonic() < deadline:
    if report_path.exists():
        report = json.loads(report_path.read_text())
        if report['status'] in ('COMPLETE', 'ERROR'):
            break
    time.sleep(1)
if results.exists():
    shutil.copytree(results, run / 'results')
assert report is not None and report['status'] == 'COMPLETE', f'Review incomplete; retained evidence: {run}'
assert not report['failed_checks'], f'Review failures retained: {run / "results/REPORT.json"}'
print(f'PASS: {len(report["checks"])} native export checks. Evidence: {run}')
