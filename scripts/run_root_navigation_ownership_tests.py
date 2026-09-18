#!/usr/bin/env python3
"""Compile exact production declarations into an external UIKit test app.

Only unrelated theme types and root content are fixtures. No fake pager, path
model, appearance controller, or deep-token implementation replaces production.
This is container evidence; actual feature behavior requires app qualification.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

from liferoute_storage import scratch_path
from simulator_console_capture import CAPTURE_INCOMPLETE, FAIL, PASS, capture_simctl_launch

ROOT = Path(__file__).resolve().parents[1]
ENV = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'),
           GIT_OPTIONAL_LOCKS='0', PYTHONDONTWRITEBYTECODE='1')
ENV.pop('SDKROOT', None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    assert out != ROOT and ROOT not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    calls = []

    def run(command):
        result = subprocess.run(command, env=ENV, cwd=ROOT, capture_output=True, text=True)
        calls.append(dict(command=command, exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
        (out/'commands.json').write_text(json.dumps(calls, indent=2)+'\n')
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    content = (ROOT/'LifeRoute/V054ContentView.swift').read_text()
    navigation = (ROOT/'LifeRoute/AppNavigation.swift').read_text()
    coordinator = (ROOT/'LifeRoute/LifeRouteVisualActivityCoordinator.swift').read_text()
    tests = (ROOT/'scripts/root_navigation_ownership_tests.swift').read_text()
    pieces = {
        'pager': content.split('// BEGIN PERMANENT ROOT PAGER\n',1)[1].split('// END PERMANENT ROOT PAGER',1)[0],
        'stack': content[content.index('private struct LifeRouteRootNavigationStack<'):content.index('extension LifeRouteAppearance {')],
        'navigation': navigation[:navigation.index('// Checkpoint 06:')],
        'ambient': coordinator[:coordinator.index('#if DEBUG')],
    }
    manifest = {
        'production_extractions': {key:dict(sha256=hashlib.sha256(value.encode()).hexdigest(),bytes=len(value.encode())) for key,value in pieces.items()},
        'source_files': {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in [
            'LifeRoute/V054ContentView.swift','LifeRoute/AppNavigation.swift',
            'LifeRoute/LifeRouteVisualActivityCoordinator.swift','scripts/root_navigation_ownership_tests.swift',
            'scripts/run_root_navigation_ownership_tests.py']},
        'limitations': 'Synthetic root content/theme dependencies. Actual production controller/relay/stack/router/token/coordinator. Manual delegate transport is not a HID gesture or actual feature lifecycle proof.',
    }
    (out/'extraction.json').write_text(json.dumps(manifest,indent=2)+'\n')
    # File-private declarations stay in one translation unit with the tests.
    source = out/'main.swift'
    source.write_text('import SwiftUI\nimport UIKit\nimport Combine\n'+ '\n'.join(pieces.values())+'\n'+tests)
    sdk = run(['xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip()
    app = out/'RootOwnershipTests.app'
    app.mkdir()
    (app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.liferoute.RootOwnershipTests',
        CFBundleExecutable='RootOwnershipTests',CFBundleName='Root Ownership Tests',CFBundlePackageType='APPL',
        CFBundleVersion='1',CFBundleShortVersionString='1.0',MinimumOSVersion='16.0',
        LSRequiresIPhoneOS=True,UIDeviceFamily=[1],UILaunchScreen={},
        UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False},
        UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'])))
    module_cache = scratch_path('contract-fixtures/root-navigation/module-cache')
    module_cache.mkdir(parents=True, exist_ok=True)
    run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios16.0-simulator','-swift-version','5','-D','DEBUG',
         '-module-cache-path',str(module_cache),str(source),'-o',str(app/'RootOwnershipTests')])
    run(['codesign','--force','--sign','-',str(app)])
    run(['xcrun','simctl','install',args.simulator,str(app)])
    capture = capture_simctl_launch(
        simulator=args.simulator,
        bundle_id='local.liferoute.RootOwnershipTests',
        arguments=['-LifeRouteRootOwnershipTrace'],
        stdout_path=out/'stdout.log',
        stderr_path=out/'stderr.log',
        timeout_seconds=55,
        pass_markers=('ROOT_OWNERSHIP_TEST_PASS',),
        fail_markers=('ROOT_OWNERSHIP_TEST_FAIL',),
        env=ENV,
        cwd=ROOT,
    )
    calls.extend(capture.commands)
    (out/'commands.json').write_text(json.dumps(calls, indent=2)+'\n')
    if capture.state == PASS:
        print(capture.marker)
        return
    if capture.state == FAIL:
        raise AssertionError(capture.marker)
    assert capture.state == CAPTURE_INCOMPLETE
    raise AssertionError(f'{CAPTURE_INCOMPLETE}: {capture.reason}')


if __name__ == '__main__':
    main()
