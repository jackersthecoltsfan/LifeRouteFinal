// Browser routing bridge for the LifeRoute web preview.
// It emulates the small subset of the native bridge needed by gap routing:
// browser location, route-time estimates, and nearby preferred-store discovery.
// Native iPhone builds never load this file and continue to use Apple MapKit.
(() => {
  if (window.__lifeRouteWebRoutingBridgeLoaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebRoutingBridgeLoaded = true;

  const CONSENT_KEY = "liferoute_web_routing_consent_v1";
  const GEOCODE_KEY = "liferoute_web_geocode_cache_v1";
  const MAX_GEOCODE_CACHE = 120;
  const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
  const OSRM_URL = "https://router.project-osrm.org";
  const OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter"
  ];

  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const clean = value => String(value || "").trim();
  const normalize = value => clean(value).toLowerCase().replace(/[^a-z0-9]+/g, "");
  const numberOrNull = value => Number.isFinite(Number(value)) ? Number(value) : null;
  const emit = evt => setTimeout(() => {
    try { window.lifeRouteNativeEvent?.(evt); } catch (error) { console.warn("LifeRoute web bridge event failed", error); }
  }, 0);

  const fetchJSON = async (url, options = {}, timeoutMs = 16000) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { ...options, signal: controller.signal });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  };

  const routingConsent = () => {
    try {
      if (localStorage.getItem(CONSENT_KEY) === "yes") return true;
    } catch (_) {}
    const accepted = window.confirm(
      "Enable web route calculations?\n\nTo calculate drive times and nearby stores in the browser, LifeRoute will send the route addresses to OpenStreetMap-based geocoding/routing services. The iPhone build uses Apple MapKit instead."
    );
    if (accepted) {
      try { localStorage.setItem(CONSENT_KEY, "yes"); } catch (_) {}
    }
    return accepted;
  };

  const readGeocodeCache = () => {
    try {
      const value = JSON.parse(localStorage.getItem(GEOCODE_KEY) || "{}");
      return value && typeof value === "object" ? value : {};
    } catch (_) { return {}; }
  };
  let geocodeCache = readGeocodeCache();
  const persistGeocodeCache = () => {
    try {
      const entries = Object.entries(geocodeCache)
        .sort((a, b) => Number(b[1]?.cachedAt || 0) - Number(a[1]?.cachedAt || 0))
        .slice(0, MAX_GEOCODE_CACHE);
      geocodeCache = Object.fromEntries(entries);
      localStorage.setItem(GEOCODE_KEY, JSON.stringify(geocodeCache));
    } catch (_) {}
  };

  let geocodeQueue = Promise.resolve();
  let lastGeocodeAt = 0;
  const queuedGeocode = task => {
    geocodeQueue = geocodeQueue.catch(() => {}).then(async () => {
      const elapsed = Date.now() - lastGeocodeAt;
      if (elapsed < 1050) await wait(1050 - elapsed);
      try { return await task(); }
      finally { lastGeocodeAt = Date.now(); }
    });
    return geocodeQueue;
  };

  const geocode = async address => {
    const raw = clean(address);
    if (!raw || /^current location$/i.test(raw)) return null;
    const key = raw.toLowerCase().replace(/\s+/g, " ");
    const cached = geocodeCache[key];
    if (cached?.latitude != null && cached?.longitude != null) return cached;

    return queuedGeocode(async () => {
      const params = new URLSearchParams({
        format: "jsonv2",
        limit: "1",
        countrycodes: "us",
        addressdetails: "1",
        q: raw
      });
      const data = await fetchJSON(`${NOMINATIM_URL}?${params.toString()}`, {
        headers: { "Accept": "application/json", "Accept-Language": "en-US,en;q=0.8" }
      }, 14000);
      const first = Array.isArray(data) ? data[0] : null;
      if (!first) return null;
      const result = {
        latitude: Number(first.lat),
        longitude: Number(first.lon),
        displayName: clean(first.display_name) || raw,
        cachedAt: Date.now()
      };
      if (!Number.isFinite(result.latitude) || !Number.isFinite(result.longitude)) return null;
      geocodeCache[key] = result;
      persistGeocodeCache();
      return result;
    });
  };

  const pointFor = async (label, latitude, longitude) => {
    const lat = numberOrNull(latitude);
    const lon = numberOrNull(longitude);
    if (lat != null && lon != null) return { latitude: lat, longitude: lon, label: clean(label) || "Location" };
    const result = await geocode(label);
    return result ? { ...result, label: clean(label) || result.displayName || "Location" } : null;
  };

  const coordinateKey = point => `${point.longitude.toFixed(6)},${point.latitude.toFixed(6)}`;
  const routeOne = async (origin, destination) => {
    const path = `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
    const data = await fetchJSON(`${OSRM_URL}/route/v1/driving/${path}?overview=false&steps=false`, {}, 14000);
    const route = Array.isArray(data?.routes) ? data.routes[0] : null;
    if (!route || !Number.isFinite(Number(route.duration))) throw new Error("Route unavailable");
    return {
      minutes: Math.max(1, Math.ceil(Number(route.duration) / 60)),
      distanceMeters: Math.max(0, Math.round(Number(route.distance || 0)))
    };
  };

  const routeSegments = async payload => {
    const segments = Array.isArray(payload?.segments) ? payload.segments.slice(0, 45) : [];
    if (!segments.length) {
      emit({ type: "routeTimes", requestNumber: payload?.requestNumber, results: [] });
      return;
    }

    const resolved = await Promise.all(segments.map(async segment => {
      try {
        const [origin, destination] = await Promise.all([
          pointFor(segment.origin, segment.originLatitude, segment.originLongitude),
          pointFor(segment.destination, segment.destinationLatitude, segment.destinationLongitude)
        ]);
        if (!origin || !destination) throw new Error("Could not locate route address");
        return { segment, origin, destination };
      } catch (error) {
        return { segment, error: error?.message || "Could not locate route address" };
      }
    }));

    const valid = resolved.filter(item => item.origin && item.destination);
    const pointMap = new Map();
    valid.forEach(item => {
      pointMap.set(coordinateKey(item.origin), item.origin);
      pointMap.set(coordinateKey(item.destination), item.destination);
    });
    const points = Array.from(pointMap.values());
    const pointIndex = new Map(points.map((point, index) => [coordinateKey(point), index]));
    const results = [];

    let table = null;
    if (points.length >= 2 && points.length <= 48) {
      try {
        const coordinates = points.map(point => `${point.longitude},${point.latitude}`).join(";");
        const data = await fetchJSON(`${OSRM_URL}/table/v1/driving/${coordinates}?annotations=duration,distance`, {}, 18000);
        if (data?.code === "Ok" && Array.isArray(data.durations)) table = data;
      } catch (_) { table = null; }
    }

    for (const item of resolved) {
      const id = clean(item.segment?.id);
      if (!item.origin || !item.destination) {
        results.push({ id, error: item.error || "Route unavailable", source: "web" });
        continue;
      }
      try {
        let minutes = 0;
        let distanceMeters = 0;
        if (table) {
          const a = pointIndex.get(coordinateKey(item.origin));
          const b = pointIndex.get(coordinateKey(item.destination));
          const seconds = Number(table.durations?.[a]?.[b]);
          const meters = Number(table.distances?.[a]?.[b]);
          if (!Number.isFinite(seconds)) throw new Error("Matrix route unavailable");
          minutes = Math.max(1, Math.ceil(seconds / 60));
          distanceMeters = Number.isFinite(meters) ? Math.max(0, Math.round(meters)) : 0;
        } else {
          const route = await routeOne(item.origin, item.destination);
          minutes = route.minutes;
          distanceMeters = route.distanceMeters;
        }
        results.push({ id, minutes, distanceMeters, source: "web-osrm" });
      } catch (error) {
        results.push({ id, error: error?.message || "Route unavailable", source: "web" });
      }
    }

    emit({ type: "routeTimes", requestNumber: payload?.requestNumber, results });
  };

  const radians = degrees => Number(degrees) * Math.PI / 180;
  const crowDistanceMeters = (a, b) => {
    const earth = 6371000;
    const dLat = radians(b.latitude - a.latitude);
    const dLon = radians(b.longitude - a.longitude);
    const lat1 = radians(a.latitude);
    const lat2 = radians(b.latitude);
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
    return 2 * earth * Math.asin(Math.min(1, Math.sqrt(h)));
  };

  const aliasesFor = preference => {
    const raw = clean(preference);
    const key = normalize(raw);
    if (key.includes("walmart")) return ["Walmart"];
    if (key === "giant" || key.includes("giantfoodstores")) return ["GIANT", "Giant Food Stores", "Giant Food"];
    if (key.includes("bjswholesale") || key === "bjs") return ["BJ's Wholesale Club", "BJ's"];
    if (key.includes("wholefoods")) return ["Whole Foods Market", "Whole Foods"];
    if (key.includes("traderjoes")) return ["Trader Joe's", "Trader Joes"];
    return [raw];
  };

  const overpassEscape = value => clean(value).replace(/[\\.^$|?*+()[\]{}]/g, "\\$&").replace(/"/g, '\\"');
  const elementText = tags => [tags?.name, tags?.brand, tags?.operator, tags?.short_name].map(clean).filter(Boolean).join(" ");
  const preferenceForElement = (tags, preferences) => {
    const text = normalize(elementText(tags));
    if (!text) return "";
    for (const preference of preferences) {
      const aliases = aliasesFor(preference);
      for (const alias of aliases) {
        const candidate = normalize(alias);
        if (!candidate) continue;
        if (candidate === "giant") {
          if (text === "giant" || text.startsWith("giantfood")) return preference;
          continue;
        }
        if (text.includes(candidate)) return preference;
      }
    }
    return "";
  };

  const formattedStoreAddress = (tags, latitude, longitude) => {
    const street = [clean(tags?.["addr:housenumber"]), clean(tags?.["addr:street"])].filter(Boolean).join(" ");
    const city = clean(tags?.["addr:city"] || tags?.["addr:town"] || tags?.["addr:village"]);
    const state = clean(tags?.["addr:state"]);
    const postcode = clean(tags?.["addr:postcode"]);
    const line2 = [city, state, postcode].filter(Boolean).join(", ");
    if (street || line2) return [street, line2].filter(Boolean).join(", ");
    const name = clean(tags?.name || tags?.brand) || "Store";
    return `${name} · ${Number(latitude).toFixed(5)}, ${Number(longitude).toFixed(5)}`;
  };

  const fetchOverpass = async query => {
    let lastError = null;
    for (const endpoint of OVERPASS_URLS) {
      try {
        const body = new URLSearchParams({ data: query });
        return await fetchJSON(endpoint, { method: "POST", body }, 24000);
      } catch (error) { lastError = error; }
    }
    throw lastError || new Error("Nearby store search unavailable");
  };

  const currentPosition = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("Browser location unavailable"));
    navigator.geolocation.getCurrentPosition(
      position => resolve({
        latitude: Number(position.coords.latitude),
        longitude: Number(position.coords.longitude),
        accuracyMeters: Number(position.coords.accuracy || 0),
        timestamp: new Date(position.timestamp || Date.now()).toISOString()
      }),
      error => reject(new Error(error?.message || "Location permission was not granted")),
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 120000 }
    );
  });

  const searchStores = async payload => {
    const preferences = Array.from(new Set((payload?.queries || []).map(clean).filter(Boolean)));
    if (!preferences.length) {
      emit({ type: "storeLocations", requestID: payload?.requestID, locations: [] });
      return;
    }

    const anchors = [];
    for (const address of (payload?.nearAddresses || []).slice(0, 3)) {
      try {
        const point = await geocode(address);
        if (point) anchors.push(point);
      } catch (_) {}
    }
    if (!anchors.length) {
      try { anchors.push(await currentPosition()); } catch (_) {}
    }
    if (!anchors.length) throw new Error("Could not locate this part of your route");

    const center = {
      latitude: anchors.reduce((sum, point) => sum + Number(point.latitude), 0) / anchors.length,
      longitude: anchors.reduce((sum, point) => sum + Number(point.longitude), 0) / anchors.length
    };
    const span = anchors.length > 1 ? crowDistanceMeters(anchors[0], anchors[anchors.length - 1]) : 0;
    const radius = Math.round(clamp(17000 + span * 0.65, 18000, 45000));
    const regex = preferences.flatMap(aliasesFor).map(overpassEscape).filter(Boolean).join("|");
    const query = `[out:json][timeout:20];(nwr(around:${radius},${center.latitude},${center.longitude})["name"~"${regex}",i];nwr(around:${radius},${center.latitude},${center.longitude})["brand"~"${regex}",i];);out center tags 80;`;
    const data = await fetchOverpass(query);
    const elements = Array.isArray(data?.elements) ? data.elements : [];
    const deduped = new Map();

    elements.forEach(element => {
      const latitude = numberOrNull(element?.lat ?? element?.center?.lat);
      const longitude = numberOrNull(element?.lon ?? element?.center?.lon);
      if (latitude == null || longitude == null) return;
      const tags = element.tags || {};
      const brand = preferenceForElement(tags, preferences);
      if (!brand) return;
      const name = clean(tags.name || tags.brand) || brand;
      const key = `${normalize(name)}|${latitude.toFixed(4)}|${longitude.toFixed(4)}`;
      const distanceFromCenter = crowDistanceMeters(center, { latitude, longitude });
      const candidate = {
        brand,
        name,
        address: formattedStoreAddress(tags, latitude, longitude),
        latitude,
        longitude,
        distanceFromCenter
      };
      if (!deduped.has(key) || deduped.get(key).distanceFromCenter > distanceFromCenter) deduped.set(key, candidate);
    });

    const perBrandLimit = clamp(Number(payload?.limitPerQuery || 4), 1, 6);
    const counts = new Map();
    const locations = Array.from(deduped.values())
      .sort((a, b) => a.distanceFromCenter - b.distanceFromCenter)
      .filter(item => {
        const count = counts.get(item.brand) || 0;
        if (count >= perBrandLimit) return false;
        counts.set(item.brand, count + 1);
        return true;
      })
      .slice(0, 18)
      .map(({ distanceFromCenter, ...item }) => item);

    emit({ type: "storeLocations", requestID: payload?.requestID, locations });
  };

  const requestBrowserLocation = async () => {
    emit({ type: "currentLocationStatus", status: "requesting" });
    try {
      const location = await currentPosition();
      emit({ type: "currentLocation", ...location });
    } catch (error) {
      emit({ type: "currentLocationStatus", status: "denied", message: error?.message || "Location unavailable" });
    }
  };

  const browserPostNative = payload => {
    const action = clean(payload?.action);
    if (action === "requestCurrentLocation") {
      requestBrowserLocation();
      return true;
    }
    if (action === "requestRouteTimes") {
      if (!routingConsent()) return false;
      routeSegments(payload).catch(error => {
        const results = (payload?.segments || []).map(segment => ({ id: clean(segment?.id), error: error?.message || "Web route unavailable", source: "web" }));
        emit({ type: "routeTimes", requestNumber: payload?.requestNumber, results });
      });
      return true;
    }
    if (action === "searchStoreLocations") {
      if (!routingConsent()) return false;
      searchStores(payload).catch(error => {
        emit({ type: "storeLocations", requestID: payload?.requestID, locations: [], error: error?.message || "Web store search unavailable" });
      });
      return true;
    }
    // Returning false intentionally activates the app's existing browser fallback
    // for things such as opening Apple/Google Maps URLs and native-only features.
    return false;
  };

  window.postNative = browserPostNative;
  try { postNative = browserPostNative; } catch (_) {}

  const installAttribution = () => {
    const sourceLine = document.getElementById("activeSources");
    if (!sourceLine || document.getElementById("webRoutingAttribution")) return false;
    const link = document.createElement("a");
    link.id = "webRoutingAttribution";
    link.className = "chip on";
    link.href = "https://www.openstreetmap.org/copyright";
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = "Web routing · © OpenStreetMap contributors · OSRM";
    link.style.textDecoration = "none";
    link.style.color = "var(--muted)";
    sourceLine.appendChild(link);
    return true;
  };

  const polishWebRouteCopy = () => {
    document.querySelectorAll(".gapSuggest .tiny,.storeChooser .tiny,#setup .tiny,#locationContextStatus .contextPill").forEach(node => {
      const text = String(node.textContent || "");
      if (text.includes("Route estimates use Apple MapKit")) node.textContent = text.replace("Route estimates use Apple MapKit even if Google Maps is your navigation preference.", "Web preview uses browser road-route estimates; iPhone uses Apple MapKit.");
      if (text === "MapKit route intelligence") node.textContent = "Web + MapKit route intelligence";
      if (text.includes("Store search needs the iPhone build")) node.textContent = "Web store search is available — tap Compare stores again.";
    });
  };

  installAttribution();
  const observer = new MutationObserver(() => {
    installAttribution();
    polishWebRouteCopy();
  });
  observer.observe(document.body, { childList: true, subtree: true });
  polishWebRouteCopy();
  window.LifeRouteWebRouting = { routeSegments, searchStores, geocode };
})();