#!/usr/bin/env python3
"""Execute the production Metal surface on an explicitly named Simulator.

Uses shader and compiled asset catalog from the supplied built app. Does not
modify app source, global developer settings, or any physical device.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

from liferoute_storage import scratch_path
from simulator_console_capture import CAPTURE_INCOMPLETE, FAIL, PASS, capture_simctl_launch

os.environ.pop('SDKROOT', None)  # Explicit -sdk owns the native harness toolchain.
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--simulator', required=True)
p.add_argument('--app', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args()
out = a.output.resolve()
assert out != ROOT and ROOT not in out.parents
out.mkdir(parents=True, exist_ok=False)
app = out/'LivingSceneTests.app'
app.mkdir()
command_log = []
def run(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    command_log.append(dict(command=command, exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
    (out/'commands.json').write_text(json.dumps(command_log, indent=2)+'\n')
    if result.returncode: raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

# Refuse a physical or unknown destination.
devices = json.loads(run(['xcrun','simctl','list','devices','-j']))['devices']
assert any(d['udid'] == a.simulator and d['state'] == 'Booted' for group in devices.values() for d in group)
sdk = run(['xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip()
sources = ['LifeRoute/LivingThemeScene.swift','LifeRoute/LivingThemeEnvironment.swift','scripts/living_theme_native_tests.swift']
(out/'main.swift').write_text((ROOT/sources[-1]).read_text())
module_cache = scratch_path('contract-fixtures/living-theme-native/module-cache')
module_cache.mkdir(parents=True, exist_ok=True)
run(['xcrun','swiftc','-swift-version','5','-D','DEBUG','-sdk',sdk,'-target','arm64-apple-ios16.0-simulator',
     '-module-cache-path',str(module_cache),*[str(ROOT/s) for s in sources[:2]],str(out/'main.swift'),'-o',str(app/'LivingSceneTests')])
manifest = {'sources':{s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in sources}, 'assets':{}}
for name in ['Assets.car','default.metallib']:
    source = a.app/name
    shutil.copy2(source,app/name)
    manifest['assets'][name] = hashlib.sha256(source.read_bytes()).hexdigest()
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.liferoute.LivingSceneTests',
    CFBundleExecutable='LivingSceneTests',CFBundleName='Living Scene Tests',CFBundlePackageType='APPL',
    CFBundleVersion='1',CFBundleShortVersionString='1.0',MinimumOSVersion='16.0',LSRequiresIPhoneOS=True,
    UIDeviceFamily=[1],UILaunchScreen={},UIApplicationSceneManifest={"UIApplicationSupportsMultipleScenes":False})))
run(['codesign','--force','--sign','-',str(app)])
run(['xcrun','simctl','install',a.simulator,str(app)])
stdout=out/'stdout.log'
capture = capture_simctl_launch(
    simulator=a.simulator,
    bundle_id='local.liferoute.LivingSceneTests',
    arguments=['-LifeRouteLivingDiagnostics'],
    stdout_path=stdout,
    stderr_path=out/'stderr.log',
    timeout_seconds=180,
    pass_markers=('LIVING_NATIVE_PASS',),
    fail_markers=('LIVING_NATIVE_FAIL',),
    env=os.environ,
    cwd=ROOT,
)
if capture.state == PASS:
    print(capture.marker)
elif capture.state == FAIL:
    raise AssertionError(capture.marker)
else:
    assert capture.state == CAPTURE_INCOMPLETE
    raise AssertionError(f'{CAPTURE_INCOMPLETE}: {capture.reason}')
command_log.extend(capture.commands)
(out/'commands.json').write_text(json.dumps(command_log, indent=2)+'\n')
