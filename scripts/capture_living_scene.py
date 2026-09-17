#!/usr/bin/env python3
"""Record a privacy-empty Simulator presentation of the production Living surface."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import time

from liferoute_storage import scratch_path, validate_scratch_path

os.environ.pop('SDKROOT', None)
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--simulator', required=True)
p.add_argument('--app', type=Path, required=True)
p.add_argument('--build', type=Path, required=True)
p.add_argument('--evidence', type=Path, required=True)
p.add_argument('--scene', required=True)
p.add_argument('--checkpoint', type=Path, required=True)
p.add_argument('--seconds', type=int, default=20)
a = p.parse_args()
subprocess.run(['python3', str(ROOT/'scripts/check_living_family_contracts.py'), '--checkpoint', str(a.checkpoint)], check=True)
assert a.scene in ['scenery.'+f+'.'+v for f in ['rainforest','ocean','arctic','mountains','canyon','desert'] for v in ['day','night']]
assert 12 <= a.seconds <= 35
a.build = validate_scratch_path(a.build)
a.build.mkdir(parents=True, exist_ok=True)
a.evidence.mkdir(parents=True, exist_ok=False)
commands = []
def run(cmd):
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    commands.append({'command':cmd, 'exit':result.returncode, 'stdout':result.stdout, 'stderr':result.stderr})
    (a.evidence/'commands.json').write_text(json.dumps(commands, indent=2)+'\n')
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout

devices = json.loads(run(['xcrun','simctl','list','devices','-j']))['devices']
assert any(d['udid']==a.simulator and d['state']=='Booted' for group in devices.values() for d in group)
source_paths = ['LifeRoute/LivingThemeScene.swift','LifeRoute/LivingThemeEnvironment.swift','scripts/living_scene_capture.swift']
manifest = {s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in source_paths}
for name in ['Assets.car','default.metallib']:
    manifest[name] = hashlib.sha256((a.app/name).read_bytes()).hexdigest()
app = a.build/'LivingCapture.app'
saved = a.build/'manifest.json'
if not saved.exists() or json.loads(saved.read_text()) != manifest:
    app.mkdir(exist_ok=True)
    (a.build/'main.swift').write_text((ROOT/source_paths[-1]).read_text())
    sdk = run(['xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip()
    module_cache = scratch_path('living-scene/module-cache')
    module_cache.mkdir(parents=True, exist_ok=True)
    run(['xcrun','swiftc','-swift-version','5','-D','DEBUG','-sdk',sdk,'-target','arm64-apple-ios16.0-simulator',
         '-module-cache-path',str(module_cache),*[str(ROOT/s) for s in source_paths[:2]],
         str(a.build/'main.swift'),'-o',str(app/'LivingCapture')])
    for name in ['Assets.car','default.metallib']: shutil.copy2(a.app/name,app/name)
    (app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.liferoute.LivingCapture',
        CFBundleExecutable='LivingCapture',CFBundleName='Living Capture',CFBundlePackageType='APPL',
        CFBundleVersion='1',CFBundleShortVersionString='1.0',MinimumOSVersion='16.0',LSRequiresIPhoneOS=True,
        UIDeviceFamily=[1],UILaunchScreen={},UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False})))
    run(['codesign','--force','--sign','-',str(app)])
    run(['xcrun','simctl','install',a.simulator,str(app)])
    saved.write_text(json.dumps(manifest,indent=2)+'\n')
stdout = a.evidence/'surface.log'
run(['xcrun','simctl','launch','--terminate-running-process','--stdout='+str(stdout),'--stderr='+str(a.evidence/'surface-errors.log'),
     a.simulator,'local.liferoute.LivingCapture','-LifeRouteLivingDiagnostics',a.scene])
deadline=time.monotonic()+12
while time.monotonic()<deadline:
    lines=stdout.read_text().splitlines() if stdout.exists() else []
    terminal=[s for s in lines if s.startswith(('CAPTURE_READY','CAPTURE_FAIL'))]
    if terminal:
        assert terminal[-1].startswith('CAPTURE_READY'), terminal[-1]
        break
    time.sleep(.1)
else: raise AssertionError('No completed production surface presentation')
video=a.evidence/'motion.mp4'
cmd=['xcrun','simctl','io',a.simulator,'recordVideo','--codec=h264',str(video)]
with (a.evidence/'recording.log').open('w') as log:
    recorder=subprocess.Popen(cmd,stdout=log,stderr=log)
    time.sleep(a.seconds)
    recorder.send_signal(signal.SIGINT)
    assert recorder.wait(timeout=15)==0
assert video.stat().st_size>10000
raw_dir=a.checkpoint/'raw-simulator-motion'
raw_dir.mkdir(exist_ok=True)
raw=raw_dir/(a.scene.replace('scenery.','').replace('.','-')+'.mp4')
assert not raw.exists()
video.rename(raw)
video_validation=run([str(a.checkpoint/'compress-video'),str(raw),str(video)]).strip()
run(['xcrun','simctl','io',a.simulator,'screenshot',str(a.evidence/'scene.png')])
run(['xcrun','simctl','terminate',a.simulator,'local.liferoute.LivingCapture'])
# Close the process before sealing its log; later Simulator work must not append
# lifecycle output to a scene evidence file after that scene has been committed.
payload={'scene':a.scene,'source_manifest':manifest,'duration_requested_seconds':a.seconds,
         'readiness':terminal[-1],'video_sha256':hashlib.sha256(video.read_bytes()).hexdigest(),
         'raw_video_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'video_validation':video_validation,
         'boundary':'Simulator engineering evidence. Empty production surface harness, no user data. Physical acceptance unverified.'}
(a.evidence/'capture.json').write_text(json.dumps(payload,indent=2)+'\n')
print('CAPTURE_PASS '+a.scene,flush=True)
