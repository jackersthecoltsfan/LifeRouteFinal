#!/usr/bin/env python3
"""Detect fixed photographed star cores and create a constant-cost data texture.
No artwork edits. Requires numpy/Pillow. RGB data encode per-component phase,
period and sqrt(linear high-frequency amplitude); alpha is exact core support.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageFilter
R=Path(__file__).resolve().parents[1]
folder=R/'LifeRoute/Assets.xcassets/SceneryArcticNight.imageset'
art=folder/next(x['filename'] for x in json.loads((folder/'Contents.json').read_text())['images'] if 'filename' in x)
assert hashlib.sha256(art.read_bytes()).hexdigest()=='46dc4e0e2b5827b12a959053e4490659035101697297c522c28d711f79896820'
im=Image.open(art).convert('RGB');a=np.array(im,dtype=float);bg=np.array(im.filter(ImageFilter.GaussianBlur(3)),dtype=float);h,w=a.shape[:2]
weights=np.array([.2126,.7152,.0722]);lum=a@weights;bglum=bg@weights;residual=(a-bg)@weights
allowed=np.zeros((h,w),bool);allowed[7:int(h*.295)+1,7:w-7]=True
allowed &= (bglum<80)&~(((bg[:,:,1]-bg[:,:,0])>28)&((bg[:,:,2]-bg[:,:,1])<24))
core=allowed&(residual>=14)&((a-bg).min(axis=2)>=5)
seen=np.zeros((h,w),bool);components=[]
for y,x in zip(*np.nonzero(core)):
 if seen[y,x]:continue
 pending=[(int(y),int(x))];seen[y,x]=True;pixels=[]
 while pending:
  cy,cx=pending.pop();pixels.append((cy,cx))
  for ny in range(cy-1,cy+2):
   for nx in range(cx-1,cx+2):
    if 0<=ny<h and 0<=nx<w and core[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;pending.append((ny,nx))
 pixels.sort();ys=[p[0] for p in pixels];xs=[p[1] for p in pixels]
 if not 1<=len(pixels)<=28 or max(xs)-min(xs)+1>9 or max(ys)-min(ys)+1>9:continue
 cy,cx=max(pixels,key=lambda p:residual[p[0],p[1]])
 ring=[lum[cy+dy,cx+dx] for dy in range(-7,8) for dx in range(-7,8) if 16<=dx*dx+dy*dy<=49]
 prominence=lum[cy,cx]-np.percentile(ring,75)
 if prominence<18:continue
 components.append({'center':[cx,cy],'pixels':[[x,y] for y,x in pixels],'peakResidual255':float(residual[cy,cx]),'prominence255':float(prominence)})
def linear(v):
 z=v/255;return np.where(z<=.04045,z/12.92,((z+.055)/1.055)**2.4)
frequency=np.maximum(0,(linear(a)-linear(bg)).min(axis=2))
mask=np.zeros((h,w,4),dtype=np.uint8)
for i,item in enumerate(components):
 seed=hashlib.sha256(('arctic-star-v1:'+','.join(map(str,item['center']))).encode()).digest();phase=seed[0]%255;period=seed[1]
 item.update(id=i+1,phaseByte=phase,periodByte=period,periodSeconds=1.5+period/255*2.5)
 for x,y in item['pixels']:mask[y,x]=[phase,period,round(np.sqrt(frequency[y,x])*255),255]
assert not mask[int(h*.295)+1:,:,3].any();assert np.all((mask[:,:,3]>0)<=allowed)
output=R/'LifeRoute/Assets.xcassets/LivingArcticNightStarMask.imageset';output.mkdir(exist_ok=True);Image.fromarray(mask).save(output/'mask.png')
(output/'Contents.json').write_text(json.dumps({'images':[{'filename':'mask.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
phases=np.array([c['phaseByte']/255 for c in components]);periods=np.array([c['periodSeconds'] for c in components]);fractions=[]
for t in np.arange(0,20,1/60):
 p=(t/periods+phases)%1;fractions.append(float((((p>0)&(p<.10))|((p>.20)&(p<.30))).mean()))
report={'version':'photographed-star-cores-v1','sourceSHA256':hashlib.sha256(art.read_bytes()).hexdigest(),'maskSHA256':hashlib.sha256((output/'mask.png').read_bytes()).hexdigest(),'dimensions':[w,h],'detectedAndSelectedObjects':len(components),'maskPixels':int((mask[:,:,3]>0).sum()),'selectedFractionOfDetectedCatalogue':1.0,'changingPhaseFractionMinimum':min(fractions),'changingPhaseFractionMaximum':max(fractions),'phaseSweepSeconds':20,'phaseSweepHz':60,'phaseFractionBoundary':'Production rise/fall phase duty, not physical apparent brightness acceptance','components':components}
assert .1<=min(fractions)<=max(fractions)<=.3
(R/'scripts/arctic_star_object_contract.json').write_text(json.dumps(report,separators=(',',':'))+'\n');print(json.dumps({k:v for k,v in report.items() if k!='components'},indent=2))
