#!/usr/bin/env python3
"""Run foreground Living/Timer integration on an explicitly named Simulator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

os.environ.pop('SDKROOT', None)
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--simulator', required=True)
p.add_argument('--app', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--checkpoint', type=Path, required=True)
a = p.parse_args()
subprocess.run(['python3', str(ROOT/'scripts/check_living_family_contracts.py'), '--checkpoint', str(a.checkpoint)], check=True)
devices = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))['devices']
assert any(d['udid']==a.simulator and d['state']=='Booted' for group in devices.values() for d in group)
out = a.output.resolve()
assert ROOT not in out.parents and out != ROOT
out.mkdir(parents=True, exist_ok=False)
shutil.copytree(ROOT/'scripts/fixtures/living-theme-ui/NativeUI.xcodeproj', out/'NativeUI.xcodeproj')
shutil.copy2(ROOT/'scripts/living_theme_ui_tests.swift', out/'NativeUI.swift')
(out/'manifest.json').write_text(json.dumps({'testSHA256':hashlib.sha256((out/'NativeUI.swift').read_bytes()).hexdigest(),
    'metallibSHA256':hashlib.sha256((a.app/'default.metallib').read_bytes()).hexdigest(), 'simulator':a.simulator}, indent=2)+'\n')
subprocess.run(['xcrun','simctl','install',a.simulator,str(a.app)], check=True)
command = ['xcodebuild','test','-project',str(out/'NativeUI.xcodeproj'),'-scheme','NativeUI',
    '-destination','platform=iOS Simulator,id='+a.simulator,'-derivedDataPath',str(out/'derived-data'),
    '-resultBundlePath',str(out/'integration.xcresult'),'-parallel-testing-enabled','NO','CODE_SIGNING_ALLOWED=NO']
with (out/'xcodebuild.log').open('w') as log:
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
text = (out/'xcodebuild.log').read_text()
assert '** TEST SUCCEEDED **' in text and 'NATIVE_UI_COMPLETE_PASS' in text
print('PASS: native toolbar, twelve selections, background/foreground and Timer fullscreen/resume')
