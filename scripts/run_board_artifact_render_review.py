#!/usr/bin/env python3
"""Run exact BoardArtifact.swift export fixtures in a separate Simulator app."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time
import uuid

from liferoute_storage import scratch_path

SCHEMA = 'com.brandongood.liferoute.native-qualification'
SCHEMA_VERSION = 1
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
started_at = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
environment = dict(os.environ)
if args.developer_dir:
    environment['DEVELOPER_DIR'] = str(args.developer_dir.resolve())
environment.pop('SDKROOT', None)
log = run / 'commands.log'
terminal = {'status': 'NOT_RUN', 'marker': 'BOARD_ARTIFACT_RENDER_REVIEW_NOT_RUN', 'checks': []}
runtime_identity = {'class': 'simulator', 'simulator': {'uuid': args.simulator}}
source_files = {'production': root / 'LifeRoute/BoardArtifact.swift', 'fixture': root / 'scripts/fixtures/BoardArtifactRenderHarness.swift', 'harness': Path(__file__).resolve()}

def now():
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()

def inventory(path):
    return [{'path': item.relative_to(path).as_posix(), 'sha256': sha256(item), 'bytes': item.stat().st_size}
            for item in sorted(p for p in path.rglob('*') if p.is_file())]

def inventory_hash(rows):
    payload = ''.join(f"{row['path']}\t{row['sha256']}\t{row['bytes']}\n" for row in rows)
    return hashlib.sha256(payload.encode()).hexdigest()

def git(*argv, default='unavailable'):
    try:
        return subprocess.check_output(['git', *argv], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return default

def version(argv):
    try:
        return subprocess.check_output(argv, env=environment, text=True, stderr=subprocess.STDOUT).strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unavailable'

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

def write_manifest(finished_at, result_status, artifact=None, evidence=None):
    source_hashes = {}
    for key, path in source_files.items():
        source_hashes[key] = {'path': str(path), 'state': 'present', 'sha256': sha256(path), 'bytes': path.stat().st_size} if path.exists() else {'path': str(path), 'state': 'unavailable'}
    status_text = git('status', '--porcelain')
    clean = status_text == '' if status_text != 'unavailable' else 'unavailable'
    manifest = {
        'manifest': {'schema': SCHEMA, 'schemaVersion': SCHEMA_VERSION, 'manifestPath': 'NATIVE_QUALIFICATION_MANIFEST.json'},
        'run': {'gateID': 'Q-VISUAL-SUPPORTS-BOARD-ARTIFACT-RENDER', 'harnessPath': str(Path(__file__).resolve()),
                'harnessSHA256': source_hashes['harness'].get('sha256', 'unavailable'), 'argv': [str(item) for item in sys.argv],
                'environment': {key: environment[key] for key in ('DEVELOPER_DIR', 'PATH') if key in environment},
                'startedAt': started_at, 'finishedAt': finished_at, 'exitCode': 0 if result_status == 'PASS' else 1, 'terminal': terminal},
        'source': {'repository': str(root), 'branch': git('branch', '--show-current'),
                   'state': 'detached' if git('symbolic-ref', '--quiet', '--short', 'HEAD', default='') == '' else 'branch',
                   'commitSHA': git('rev-parse', 'HEAD'), 'treeSHA': git('rev-parse', 'HEAD^{tree}'), 'clean': clean, 'status': status_text,
                   'worktreeCount': len([line for line in git('worktree', 'list', '--porcelain').splitlines() if line.startswith('worktree ')]), 'inputs': source_hashes},
        'artifact': artifact or {'kind': 'generated-simulator-test-product', 'configuration': 'Debug-fixture', 'platform': 'iphonesimulator',
                                 'bundleIDs': [bundle_id], 'productHashStatus': 'not_recorded', 'productManifest': {'status': 'not_recorded'},
                                 'archive': {'status': 'not_applicable'}, 'export': {'status': 'not_applicable'}},
        'toolchain': {'DEVELOPER_DIR': environment.get('DEVELOPER_DIR', 'default'),
                      'xcode': version([str(Path(environment.get('DEVELOPER_DIR', '/Applications/Xcode.app')) / 'usr/bin/xcodebuild'), '-version']),
                      'swift': version(['swiftc', '--version']),
                      'sdk': {'name': 'iphonesimulator', 'path': runtime_identity.get('sdkPath', 'unavailable'), 'version': runtime_identity.get('sdkVersion', 'unavailable')},
                      'macOS': version(['sw_vers', '-productVersion']), 'hostArchitecture': version(['uname', '-m'])},
        'runtime': runtime_identity,
        'evidence': {'root': str(run), 'files': evidence or [], 'retention': 'external evidence; caller-defined retention'},
        'result': {'status': result_status, 'checks': terminal.get('checks', []),
                   'limitations': ['Simulator/synthetic-fixture evidence only', 'physical-device identity and acceptance were not evaluated',
                                   'owner acceptance is not evaluated', 'archive/export identity is not applicable to this harness'],
                   'nonClaims': ['Simulator PASS != physical QA PASS', 'native runtime PASS != owner acceptance', 'artifact existence != artifact identity',
                                 'TestFlight upload != release approval', 'Debug source marker != Release provenance'], 'ownerAcceptance': 'NOT_EVALUATED'},
    }
    (run / 'NATIVE_QUALIFICATION_MANIFEST.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')

artifact = None
evidence = []
result_status = 'NOT_RUN'
try:
    devices = json.loads(command('xcrun', 'simctl', 'list', 'devices', '--json'))
    matches = [(runtime, item) for runtime, entries in devices['devices'].items() for item in entries if item['udid'] == args.simulator]
    assert len(matches) == 1 and matches[0][1].get('isAvailable', False), 'Selected Simulator must exist and be available'
    runtime, device = matches[0]
    runtime_identity.update({'runtimeIdentifier': runtime, 'simulator': {'uuid': args.simulator, 'name': device.get('name', 'unavailable'),
                            'model': device.get('deviceTypeIdentifier', 'unavailable'), 'productType': device.get('deviceTypeIdentifier', 'unavailable'),
                            'state': device.get('state', 'unavailable')}})
    if device['state'] != 'Booted':
        assert args.boot, 'Selected Simulator is shut down; boot it explicitly or pass --boot'
        command('xcrun', 'simctl', 'boot', args.simulator)
    command('xcrun', 'simctl', 'bootstatus', args.simulator, '-b')
    sdk = command('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
    runtime_identity['sdkPath'] = sdk
    runtime_identity['sdkVersion'] = command('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version')
    app = run / 'BoardArtifactTests.app'; source = run / 'source'; app.mkdir(); source.mkdir()
    shutil.copy2(source_files['production'], source / 'BoardArtifact.swift')
    shutil.copy2(source_files['fixture'], source / 'BoardArtifactRenderHarness.swift')
    source_manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob('*.swift')}
    source_manifest.update({'simulator': args.simulator, 'runtime': runtime, 'test_bundle': bundle_id, 'sdk': sdk, 'run_id': run_id})
    (run / 'SOURCE_MANIFEST.json').write_text(json.dumps(source_manifest, indent=2) + '\n')
    info = {'CFBundleIdentifier': bundle_id, 'CFBundleName': 'BoardArtifactTests', 'CFBundleExecutable': 'BoardArtifactTests', 'CFBundleVersion': '1',
            'CFBundleShortVersionString': '1.0', 'CFBundlePackageType': 'APPL', 'MinimumOSVersion': '26.0', 'LSRequiresIPhoneOS': True,
            'UIDeviceFamily': [1, 2], 'UILaunchScreen': {}}
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    module_cache = scratch_path('contract-fixtures/board-artifact/module-cache'); module_cache.mkdir(parents=True, exist_ok=True)
    command('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-target', 'arm64-apple-ios26.0-simulator', '-sdk', sdk, '-parse-as-library',
            '-module-cache-path', module_cache, source / 'BoardArtifact.swift', source / 'BoardArtifactRenderHarness.swift', '-o', app / 'BoardArtifactTests')
    command('codesign', '--force', '--sign', '-', app)
    product_rows = inventory(app)
    (run / 'PRODUCT_FILE_MANIFEST.json').write_text(json.dumps(product_rows, indent=2, sort_keys=True) + '\n')
    artifact = {'kind': 'generated-simulator-test-product', 'configuration': 'Debug-fixture', 'platform': 'iphonesimulator', 'bundleIDs': [bundle_id],
                'productHashStatus': 'present', 'productManifest': {'path': 'PRODUCT_FILE_MANIFEST.json', 'sha256': inventory_hash(product_rows), 'fileCount': len(product_rows)},
                'productPath': str(app), 'archive': {'status': 'not_applicable'}, 'export': {'status': 'not_applicable'}}
    command('xcrun', 'simctl', 'install', args.simulator, app)
    command('xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator, bundle_id, extra_env={'SIMCTL_CHILD_BOARD_REVIEW_RUN_ID': run_id})
    container = Path(command('xcrun', 'simctl', 'get_app_container', args.simulator, bundle_id, 'data'))
    results = container / 'Documents' / ('BoardReview-' + run_id); report_path = results / 'REPORT.json'; deadline = time.monotonic() + args.timeout; report = None
    while time.monotonic() < deadline:
        if report_path.exists():
            report = json.loads(report_path.read_text())
            if report['status'] in ('COMPLETE', 'ERROR'): break
        time.sleep(1)
    if results.exists(): shutil.copytree(results, run / 'results')
    assert report is not None and report['status'] == 'COMPLETE', f'Review incomplete; retained evidence: {run}'
    assert not report['failed_checks'], f'Review failures retained: {run / "results/REPORT.json"}'
    terminal = {'status': 'PASS', 'marker': 'BOARD_ARTIFACT_RENDER_REVIEW_PASS', 'checks': report['checks']}; result_status = 'PASS'
except Exception:
    result_status = 'FAIL'; terminal = {'status': 'FAIL', 'marker': 'BOARD_ARTIFACT_RENDER_REVIEW_FAIL', 'checks': []}
    raise
finally:
    finished_at = now()
    if run.exists():
        evidence = [{'path': candidate.relative_to(run).as_posix(), 'sha256': sha256(candidate), 'bytes': candidate.stat().st_size}
                    for candidate in sorted(p for p in run.rglob('*') if p.is_file() and p.name != 'NATIVE_QUALIFICATION_MANIFEST.json')]
        write_manifest(finished_at, result_status, artifact, evidence)

if result_status == 'PASS': print(f'PASS: {len(terminal["checks"])} native export checks. Evidence: {run}')
