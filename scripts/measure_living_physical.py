#!/usr/bin/env python3
"""GPU measurement of source-extracted river phase / actual snowfall function.

Never supplies a hand-entered motion multiplier. The measured expression is
extracted verbatim from the selected source and preserved with its source hash.
Snow density is particle-field occupancy, not whole-scene pixel delta. River
phase is the actual advancing phase used by the visible riffle field, not optical
flow or a claimed physical velocity. Native clips establish appearance separately.
"""
import argparse, hashlib, json, os, pathlib, re, subprocess, sys

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=pathlib.Path,required=True)
p.add_argument('--kind',choices=['river','snow'],required=True)
p.add_argument('--out',type=pathlib.Path,required=True)
p.add_argument('--compare',type=pathlib.Path)
a=p.parse_args(); a.source=a.source.resolve(); a.out=a.out.resolve()
os.environ.pop('SDKROOT',None); a.out.mkdir(parents=True,exist_ok=False)
shader=a.source/'LifeRoute/LivingRainforest.metal'; text=shader.read_text()
if a.kind=='river':
    section=text.split('fragment float4 livingCanyonFragment',1)[1].split('fragment float4 livingDesertFragment',1)[0]
    # Night branch comes first. Keep exact time declaration and phase expression.
    time=re.search(r'float waterTime = [^;]+;',section)
    phase=re.search(r'float phase = [^;]+;',section).group()
    expression=(time.group()+'\n' if time else '')+phase+'\n result[id] = phase;'
else:
    section=text.split('fragment float4 livingArcticDayFragment',1)[1].split('struct LivingAuroraSample',1)[0]
    call=re.search(r'livingSnowfallWithGust\(uv,t,c.light.y\)|livingPrecipitation\(uv,t,c.light.y,true,[0-9.]+\)',section).group()
    scene=(a.source/'LifeRoute/LivingThemeScene.swift').read_text()
    descriptor=re.search(r'static let arcticDay = Self\(skyA:.*?light: SIMD4\(([^)]+)\)',scene,re.S).group(1)
    expression='LivingAtmosphereConfiguration c; c.light = float4('+descriptor+');\n result[id] = '+call+';'
generated='#include "'+str(shader)+'"\nkernel void physicalProbe(device const float4 *requests [[buffer(0)]], device float *result [[buffer(1)]], uint id [[thread_position_in_grid]]) { float2 uv=requests[id].xy; float t=requests[id].z; '+expression+' }\n'
(a.out/'probe.metal').write_text(generated)
runner=pathlib.Path(__file__).with_name('living_physical_probe.swift')
commands=[['xcrun','-sdk','macosx','metal','-c',str(a.out/'probe.metal'),'-o',str(a.out/'probe.air')],
 ['xcrun','-sdk','macosx','metallib',str(a.out/'probe.air'),'-o',str(a.out/'probe.metallib')],
 ['xcrun','-sdk','macosx','swiftc','-parse-as-library',str(runner),'-o',str(a.out/'probe')],
 [str(a.out/'probe'),str(a.out/'probe.metallib'),a.kind,str(a.out/'raw.json')]]
for cmd in commands: subprocess.run(cmd,check=True,capture_output=True)
result=json.loads((a.out/'raw.json').read_text())
result.update(version='living-production-field-v1',expression=expression,commands=commands,
 invocation=[sys.executable,*sys.argv],source=str(a.source),
 inputs={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in [shader,runner,pathlib.Path(__file__),*sorted((a.source/'LifeRoute').glob('Living*Motion.h'))]},
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=a.source,text=True).strip(),
 dirty=subprocess.check_output(['git','status','--porcelain'],cwd=a.source,text=True))
if a.compare:
    parent=json.loads(a.compare.read_text()); assert parent['kind']==result['kind']
    keys=['meanPhaseRate'] if a.kind=='river' else ['visibleParticleFraction','meanParticleIntensity']
    result['comparison']={'parent':str(a.compare),'ratios':{k:result[k]/parent[k] for k in keys}}
(a.out/'measurement.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in result.items() if k in ['kind','meanPhaseRate','visibleParticleFraction','meanParticleIntensity','comparison']}))
