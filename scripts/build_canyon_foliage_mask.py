#!/usr/bin/env python3
"""Build an inward-feathered data mask from photographed foliage polygons.
Requires Pillow. Existing artwork is read-only. The main-crown qualification
outline is independently wider than the deformation support; old broad
rectangles remain in historical metrics and are not used to manufacture spread.
"""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFilter
R=Path(__file__).resolve().parents[1]
imageSet=R/'LifeRoute/Assets.xcassets/SceneryCanyonDay.imageset'
art=imageSet/next(x['filename'] for x in json.loads((imageSet/'Contents.json').read_text())['images'] if 'filename' in x)
cores=[[[.11136,.65391],[.13029,.65448],[.15479,.66248],[.17483,.67047],[.18486,.67733],[.19933,.68418],[.21269,.69674],[.22160,.70531],[.21381,.71331],[.19933,.71559],[.17817,.72359],[.16481,.71902],[.15256,.71102],[.13029,.70531],[.12584,.69617],[.10802,.69103],[.08909,.68075],[.08018,.66933],[.09243,.65962]],[[.01670,.93147],[.04788,.92519],[.08129,.92918],[.11247,.92290],[.13474,.93090],[.14365,.94517],[.12027,.95717],[.09911,.96802],[.06904,.97544],[.03007,.97373],[.00557,.96288],[.00557,.94346]],[[.50111,.89834],[.51782,.89720],[.53452,.90463],[.54566,.91262],[.56904,.91548],[.58686,.92461],[.58352,.93090],[.56793,.93204],[.54788,.92576],[.53229,.91947],[.51559,.91719],[.50000,.90862]]]
reference=[[.06793,.67504],[.07684,.66362],[.09800,.65848],[.11247,.65049],[.13252,.65277],[.14588,.65905],[.15479,.66019],[.16481,.66819],[.18151,.67333],[.18931,.68075],[.20379,.68818],[.20824,.69503],[.22606,.70074],[.22717,.70988],[.21604,.71673],[.20713,.72187],[.18597,.72587],[.17038,.72930],[.15033,.71959],[.13029,.71045],[.10245,.70188],[.08463,.69903],[.06013,.69446],[.04788,.68818],[.05011,.68190]]
w,h=Image.open(art).size
mask=Image.new('L',(w,h));draw=ImageDraw.Draw(mask)
for poly in cores:draw.polygon([(x*w,y*h) for x,y in poly],fill=255)
# Maximum5artworkpixel sampling travel; retain a6pixel support margin.
# Three inward erosions feather only within that safe interior.
eroded=mask.filter(ImageFilter.MinFilter(13));inner=eroded.filter(ImageFilter.MinFilter(7));soft=inner.filter(ImageFilter.GaussianBlur(2))
from PIL import ImageChops
soft=ImageChops.multiply(soft,eroded)
output=R/'LifeRoute/Assets.xcassets/LivingCanyonDayFoliageMask.imageset';output.mkdir(exist_ok=True)
Image.merge('RGBA',(soft,Image.new('L',(w,h)),Image.new('L',(w,h)),Image.new('L',(w,h),255))).save(output/'mask.png')
(output/'Contents.json').write_text(json.dumps({'images':[{'filename':'mask.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
record={'version':'canyon-object-mask-v1','artworkSHA256':hashlib.sha256(art.read_bytes()).hexdigest(),'size':[w,h],'cores':cores,'broader_main_crown_reference':reference,'safeSamplingMarginPixels':6,'maximumSamplingTravelPixels':5,'nonzeroMaskPixels':sum(x>0 for x in soft.getdata()),'maskSHA256':hashlib.sha256((output/'mask.png').read_bytes()).hexdigest()}
(R/'scripts/canyon_foliage_object_contract.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
