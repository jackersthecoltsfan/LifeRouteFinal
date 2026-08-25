// Web-preview resilience layer for routing + preferred-store search.
// Loaded after web-routing-bridge.js and web-store-search-fallback.js.
(() => {
  if (window.__lifeRouteWebRoutingResilienceLoaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebRoutingResilienceLoaded = true;

  const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
  const clean = value => String(value || "").trim();
  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  const number = value => Number.isFinite(Number(value)) ? Number(value) : null;
  const routePending = new Map();
  const storePending = new Map();
  const completedRouteIDs = new Map();
  let locationCache = null;
  let lastNominatimAt = 0;

  const emit = evt => setTimeout(() => {
    try { window.lifeRouteNativeEvent?.(evt); } catch (_) {}
  }, 0);

  const currentPosition = () => new Promise((resolve, reject) => {
    if (locationCache && Date.now() - locationCache.cachedAt < 180000) return resolve(locationCache);
    if (!navigator.geolocation) return reject(new Error("Browser location unavailable"));
    navigator.geolocation.getCurrentPosition(position => {
      locationCache = {
        latitude:Number(position.coords.latitude),
        longitude:Number(position.coords.longitude),
        cachedAt:Date.now()
      };
      resolve(locationCache);
    }, reject, { enableHighAccuracy:true, timeout:9000, maximumAge:120000 });
  });

  const nominatim = async (query, bias = null, limit = 1) => {
    const elapsed = Date.now() - lastNominatimAt;
    if (elapsed < 1050) await wait(1050 - elapsed);
    const params = new URLSearchParams({
      format:"jsonv2",
      q:query,
      limit:String(limit),
      countrycodes:"us",
      addressdetails:"1"
    });
    if (bias?.latitude != null && bias?.longitude != null) {
      const lat = Number(bias.latitude), lon = Number(bias.longitude);
      params.set("viewbox", `${lon-.75},${lat+.6},${lon+.75},${lat-.6}`);
      params.set("bounded", "0");
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(),9000);
    try {
      const response = await fetch(`${NOMINATIM_URL}?${params}`, {
        headers:{"Accept":"application/json","Accept-Language":"en-US,en;q=.8"},
        cache:"no-store",
        signal:controller.signal
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } finally {
      clearTimeout(timer);
      lastNominatimAt = Date.now();
    }
  };

  const stripUnit = value => clean(value).replace(/,?\s+(?:apt|apartment|unit|suite|ste|#)\s*[a-z0-9-]+.*$/i, "").trim();

  const resolvePoint = async (label, latitude, longitude) => {
    const lat = number(latitude), lon = number(longitude);
    if (lat != null && lon != null) return { latitude:lat, longitude:lon };
    const raw = clean(label);
    if (!raw) return null;
    if (/^current location$/i.test(raw)) return currentPosition();

    try {
      const primary = await window.LifeRouteWebRouting?.geocode?.(raw);
      if (primary?.latitude != null && primary?.longitude != null) return primary;
    } catch (_) {}

    const simplified = stripUnit(raw) || raw;
    let data = [];
    try { data = await nominatim(simplified); } catch (_) {}
    if (!data?.length && !/\b[A-Z]{2}\b|\b\d{5}\b/i.test(simplified)) {
      let bias = locationCache;
      if (!bias) { try { bias = await currentPosition(); } catch (_) {} }
      if (bias) { try { data = await nominatim(simplified,bias); } catch (_) {} }
    }
    const first = Array.isArray(data) ? data[0] : null;
    const out = first ? { latitude:Number(first.lat), longitude:Number(first.lon) } : null;
    return out && Number.isFinite(out.latitude) && Number.isFinite(out.longitude) ? out : null;
  };

  const radians = d => Number(d) * Math.PI / 180;
  const distanceMeters = (a,b) => {
    const R=6371000, dLat=radians(b.latitude-a.latitude), dLon=radians(b.longitude-a.longitude);
    const p1=radians(a.latitude), p2=radians(b.latitude);
    const h=Math.sin(dLat/2)**2 + Math.cos(p1)*Math.cos(p2)*Math.sin(dLon/2)**2;
    return 2*R*Math.asin(Math.min(1,Math.sqrt(h)));
  };

  const estimateRoute = async segment => {
    const [origin,destination] = await Promise.all([
      resolvePoint(segment.origin,segment.originLatitude,segment.originLongitude),
      resolvePoint(segment.destination,segment.destinationLatitude,segment.destinationLongitude)
    ]);
    if (!origin || !destination) return { id:clean(segment.id), error:"Could not locate route address", source:"web" };
    const straight=Math.max(0,distanceMeters(origin,destination));
    const roadFactor=straight<5000?1.34:straight<25000?1.25:1.18;
    const meters=Math.max(1,Math.round(straight*roadFactor));
    const miles=meters/1609.344;
    const mph=miles<5?24:miles<20?33:46;
    const minutes=Math.max(2,Math.ceil((miles/mph)*60+(miles<8?3:2)));
    return { id:clean(segment.id), minutes, distanceMeters:meters, source:"web-distance-estimate", approximate:true };
  };

  const routeKey = payload => payload?.requestNumber != null
    ? `n:${payload.requestNumber}`
    : `i:${(payload?.segments||[]).map(x=>clean(x.id)).join("|")}`;

  const findRouteState = evt => {
    if (evt?.requestNumber != null && routePending.has(`n:${evt.requestNumber}`)) return routePending.get(`n:${evt.requestNumber}`);
    const ids = new Set((evt?.results||[]).map(x=>clean(x.id)).filter(Boolean));
    return Array.from(routePending.values()).find(state => state.segments.some(seg=>ids.has(clean(seg.id))));
  };

  const synthesizeRoutes = async state => {
    if (!state || state.finished) return;
    state.finished=true;
    clearTimeout(state.timer);
    routePending.delete(state.key);
    const results=[];
    for (const segment of state.segments) results.push(await estimateRoute(segment));
    results.forEach(result => { if (!result.error) completedRouteIDs.set(result.id,Date.now()); });
    try { window.setStatus?.("Web routes ready · approximate fallback"); } catch (_) {}
    emit({ type:"routeTimes", requestNumber:state.requestNumber, engine:"web-distance-estimate", results });
  };

  const aliasesFor = brand => {
    const raw=clean(brand), key=raw.toLowerCase().replace(/[^a-z0-9]+/g,"");
    if(key.includes("walmart")) return ["Walmart"];
    if(key==="giant"||key.includes("giantfoodstores")) return ["GIANT Food Stores","GIANT"];
    if(key==="bjs"||key.includes("bjswholesale")) return ["BJ's Wholesale Club","BJ's"];
    return [raw];
  };

  const searchBrand = async (brand,center,limit) => {
    const aliases=aliasesFor(brand);
    for(const alias of aliases){
      const paramsBias={latitude:center.latitude,longitude:center.longitude};
      let data=[];
      try { data=await nominatim(alias,paramsBias,Math.max(2,Math.min(5,limit||4))); } catch (_) {}
      const locations=(Array.isArray(data)?data:[]).map(item=>({
        brand,
        name:clean(item.name)||clean(item.display_name).split(",")[0]||brand,
        address:clean(item.display_name)||brand,
        latitude:Number(item.lat),longitude:Number(item.lon)
      })).filter(item=>Number.isFinite(item.latitude)&&Number.isFinite(item.longitude));
      if(locations.length) return locations;
    }
    return [];
  };

  const fallbackStores = async state => {
    if(!state||state.finished||state.fallbackRunning) return;
    state.fallbackRunning=true;
    clearTimeout(state.timer);
    const points=[];
    for(const address of (state.payload.nearAddresses||[]).slice(0,3)){
      try { const p=await resolvePoint(address); if(p) points.push(p); } catch (_) {}
    }
    if(!points.length){ try{points.push(await currentPosition());}catch(_){} }
    if(!points.length){
      state.finished=true; storePending.delete(state.id);
      emit({type:"storeLocations",requestID:state.id,locations:[],source:"web-resilience",error:"Could not locate this route area"});
      return;
    }
    const center={
      latitude:points.reduce((s,p)=>s+p.latitude,0)/points.length,
      longitude:points.reduce((s,p)=>s+p.longitude,0)/points.length
    };
    const all=[];
    for(const brand of Array.from(new Set((state.payload.queries||[]).map(clean).filter(Boolean))).slice(0,5)){
      all.push(...await searchBrand(brand,center,state.payload.limitPerQuery||4));
    }
    if(state.finished||storePending.get(state.id)!==state) return;
    const seen=new Set();
    const locations=all.filter(item=>{
      const key=`${item.brand}|${item.latitude.toFixed(4)}|${item.longitude.toFixed(4)}`;
      if(seen.has(key)) return false; seen.add(key); return true;
    }).slice(0,18);
    state.finished=true; storePending.delete(state.id);
    emit({type:"storeLocations",requestID:state.id,locations,source:"web-resilience",error:locations.length?"":"No nearby branches found"});
  };

  const previousPostNative = window.postNative;
  window.postNative = function lifeRouteWebResilientPostNative(payload){
    const action=clean(payload?.action);
    const handled=typeof previousPostNative==="function"?previousPostNative(payload):false;
    if(!handled) return false;

    if(action==="requestRouteTimes"){
      const key=routeKey(payload);
      const prior=routePending.get(key); if(prior) clearTimeout(prior.timer);
      const state={key,requestNumber:payload?.requestNumber,segments:(payload?.segments||[]).slice(),finished:false,timer:null};
      state.timer=setTimeout(()=>synthesizeRoutes(state),5200);
      routePending.set(key,state);
    }
    if(action==="searchStoreLocations"){
      const id=clean(payload?.requestID);
      if(id){
        const prior=storePending.get(id); if(prior) clearTimeout(prior.timer);
        const state={id,payload,finished:false,fallbackRunning:false,timer:null};
        state.timer=setTimeout(()=>fallbackStores(state),2600);
        storePending.set(id,state);
      }
    }
    return true;
  };
  try { postNative=window.postNative; } catch (_) {}

  const previousNativeEvent=window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent=function lifeRouteNativeEventWithWebResilience(evt){
    if(evt?.type==="routeTimes"){
      const state=findRouteState(evt);
      if(state&&!state.finished){
        const results=Array.isArray(evt.results)?evt.results:[];
        const failed=results.filter(result=>result.error||!Number(result.minutes||0));
        if(failed.length){
          state.finished=true; clearTimeout(state.timer); routePending.delete(state.key);
          (async()=>{
            const repaired=[];
            for(const result of results){
              if(!result.error&&Number(result.minutes||0)){ repaired.push(result); continue; }
              const segment=state.segments.find(seg=>clean(seg.id)===clean(result.id));
              repaired.push(segment?await estimateRoute(segment):result);
            }
            repaired.forEach(result=>{if(!result.error) completedRouteIDs.set(clean(result.id),Date.now());});
            try { window.setStatus?.("Web routes ready"+(repaired.some(x=>x.approximate)?" · approximate fallback":"")); } catch (_) {}
            if(typeof previousNativeEvent==="function") previousNativeEvent({...evt,engine:"web",results:repaired});
          })();
          return;
        }
        state.finished=true; clearTimeout(state.timer); routePending.delete(state.key);
      } else if(resultsOnlyErrorsFromCompleted(evt,completedRouteIDs)) {
        return;
      }
    }

    if(evt?.type==="storeLocations"){
      const id=clean(evt.requestID), state=storePending.get(id);
      if(state&&!state.finished){
        const locations=Array.isArray(evt.locations)?evt.locations:[];
        if(!locations.length||evt.error){ fallbackStores(state); return; }
        state.finished=true; clearTimeout(state.timer); storePending.delete(id);
      }
    }
    if(typeof previousNativeEvent==="function") previousNativeEvent(evt);
  };

  function resultsOnlyErrorsFromCompleted(evt,map){
    const results=Array.isArray(evt?.results)?evt.results:[];
    return results.length>0&&results.every(result=>{
      const id=clean(result.id), when=map.get(id);
      return !!when&&Date.now()-when<30000&&(result.error||!Number(result.minutes||0));
    });
  }

  window.LifeRouteWebResilience={ready:true};
  [80,900,2200].forEach(delay=>setTimeout(()=>{try{window.refreshRouteTimes?.();}catch(_){}},delay));
})();
