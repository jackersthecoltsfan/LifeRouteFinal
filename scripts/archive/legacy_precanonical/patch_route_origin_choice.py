from pathlib import Path

# Let a selected gap route start either from live current location (default) or
# from the previous client's/event's address for ahead-of-time planning.

path = Path("LifeRoute/Web/index.html")
html = path.read_text()

old = '''function routeGapStop(encodedStop,encodedFinal){let stop=decodeURIComponent(encodedStop||"").trim(),final=decodeURIComponent(encodedFinal||"").trim();if(!stop)return;if(!final){routeTo(encodedStop);return}let p=selectedMapProvider(),mode=prefs.transportMode||"driving";if(postNative({action:"openRoute",provider:p,destination:final,waypoints:[stop]}))return;let u;if(p==="google"){let q=new URLSearchParams({api:"1",destination:final,travelmode:mode,waypoints:stop});u=`https://www.google.com/maps/dir/?${q.toString()}`}else{let q=new URLSearchParams({destination:final,mode});q.append("waypoint",stop);u=`https://maps.apple.com/directions?${q.toString()}`}location.href=u}
'''
new = '''function routeGapStop(encodedStop,encodedFinal,encodedOrigin=""){let stop=decodeURIComponent(encodedStop||"").trim(),final=decodeURIComponent(encodedFinal||"").trim(),origin=decodeURIComponent(encodedOrigin||"").trim();if(!stop)return;if(!final){if(origin){let p=selectedMapProvider(),mode=prefs.transportMode||"driving";if(postNative({action:"openRoute",provider:p,origin,destination:stop}))return;let q=new URLSearchParams({api:"1",origin,destination:stop,travelmode:mode});location.href=p==="google"?`https://www.google.com/maps/dir/?${q.toString()}`:`https://maps.apple.com/directions?source=${encodeURIComponent(origin)}&destination=${encodeURIComponent(stop)}&mode=${encodeURIComponent(mode)}`;return}routeTo(encodedStop);return}let p=selectedMapProvider(),mode=prefs.transportMode||"driving";if(postNative({action:"openRoute",provider:p,origin:origin||undefined,destination:final,waypoints:[stop]}))return;let u;if(p==="google"){let args={api:"1",destination:final,travelmode:mode,waypoints:stop};if(origin)args.origin=origin;let q=new URLSearchParams(args);u=`https://www.google.com/maps/dir/?${q.toString()}`}else{let q=new URLSearchParams({destination:final,mode});if(origin)q.append("source",origin);q.append("waypoint",stop);u=`https://maps.apple.com/directions?${q.toString()}`}location.href=u}
'''

if new not in html:
    if old not in html:
        raise SystemExit("Could not patch gap route origin choice: routeGapStop marker not found")
    html = html.replace(old, new, 1)
    path.write_text(html)

print("Gap routes can now start from current location or the previous client/event.")
