#!/usr/bin/env python3
"""Exercise the actual DEBUG viewer through native UI on an explicit Simulator."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess
os.environ.pop('SDKROOT', None)
root = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--simulator', required=True)
p.add_argument('--gate', choices=['isolation', 'runtime', 'normal', 'release'], required=True)
p.add_argument('--app', type=pathlib.Path, required=True)
p.add_argument('--output', type=pathlib.Path, required=True)
a = p.parse_args()
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j']))['devices']
assert any(d['udid'] == a.simulator and d['state'] == 'Booted' for group in devices.values() for d in group)
out = a.output.resolve(); assert out != root and root not in out.parents
out.mkdir(parents=True, exist_ok=False)
shutil.copytree(root/'scripts/fixtures/living-theme-ui/NativeUI.xcodeproj', out/'NativeUI.xcodeproj')
shutil.copy2(root/'scripts/living_theme_qa_ui_tests.swift', out/'NativeUI.swift')
(out/'manifest.json').write_text(json.dumps({'test_sha256': hashlib.sha256((out/'NativeUI.swift').read_bytes()).hexdigest(),
    'app_binary_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in a.app.iterdir() if p.name == 'LifeRoute' or p.suffix == '.dylib'}, 'simulator': a.simulator, 'gate': a.gate}, indent=2)+'\n')
subprocess.run(['xcrun', 'simctl', 'install', a.simulator, str(a.app)], check=True)
command = ['xcodebuild', 'test', '-project', str(out/'NativeUI.xcodeproj'), '-scheme', 'NativeUI',
    '-destination', 'platform=iOS Simulator,id='+a.simulator, '-derivedDataPath', str(out/'derived-data'),
    '-resultBundlePath', str(out/'viewer.xcresult'),
    '-only-testing:NativeUI/NativeUI/testLivingQA'+a.gate.title(), '-parallel-testing-enabled', 'NO', 'CODE_SIGNING_ALLOWED=NO']
with (out/'xcodebuild.log').open('w') as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
(out/'exit.json').write_text(json.dumps({'command': command, 'exit': result.returncode})+'\n')
assert result.returncode == 0, 'Native QA viewer validation failed; inspect xcodebuild.log'
text = (out/'xcodebuild.log').read_text()
assert '** TEST SUCCEEDED **' in text and ('LIVING_QA_'+a.gate.upper()+'_PASS') in text
print('PASS: actual DEBUG QA viewer native '+a.gate)
