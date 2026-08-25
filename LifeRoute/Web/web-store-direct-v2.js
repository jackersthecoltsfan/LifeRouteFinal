// Direct browser preferred-store search for GitHub Pages.
// Uses Photon (OpenStreetMap) first because it supports browser CORS and
// location-biased name search. Falls back to the older web store chain only
// when Photon cannot return usable branches. Native iPhone builds never load it.
(() => {
  if (window.__lifeRouteWebStoreDirectV2Loaded) return;
  if (window.webkit?.messageHandlers?.lifeRoute) return;
  window.__lifeRouteWebStoreDirectV2Loaded = true;

  const PHOTON_URL = "https://photon.komoot.io/api/";
  const previousPostNative = window.postNative;
  const clean = value => String(value || "").trim();
  const normalize = value => clean(value).toLowerCase().replace(/[^a-z0-9]+/g, "");
  const clamp = (value, min, max) => Math.max(min, Math.min(max, Number(value) || 0));

  const emit = evt => setTimeout(() => {
    try { window.lifeRouteNativeEvent?.(evt); } catch (error) {
      console.warn("LifeRoute direct web store event failed", error);
    }
  }, 0);

  const currentPosition = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("Browser location unavailable"));
    navigator.geolocation.getCurrentPosition(
      position => resolve({
        latitude: Number(position.coords.latitude),
        longitude: Number(position.coords.longitude)
      }),
      error => reject(new Error(error?.message || "Location permission was not granted")),
      { enableHighAccuracy: true, timeout: 9000, maximumAge: 120000 }
    );
  });

  const fetchJSON = async (url, timeoutMs = 9000) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json", "Accept-Language": "en-US,en;q=0.8" },
        cache: "no-store",
        signal: controller.signal
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  };

  const photon = async (query, bias = null, limit = 6) => {
    const params = new URLSearchParams({
      q: clean(query),
      limit: String(clamp(limit, 1, 12) || 6),
      lang: "en"
    });
    if (bias?.latitude != null && bias?.longitude != null) {
      params.set("lat", String(Number(bias.latitude)));
      params.set("lon", String(Number(bias.longitude)));
    }
    return fetchJSON(`${PHOTON_URL}?${params.toString()}`);
  };

  const featurePoint = feature => {
    const coordinates = feature?.geometry?.coordinates;
    const longitude = Number(Array.isArray(coordinates) ? coordinates[0] : NaN);
    const latitude = Number(Array.isArray(coordinates) ? coordinates[1] : NaN);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    return { latitude, longitude };
  };

  const addressFor = properties => {
    const street = [clean(properties?.housenumber), clean(properties?.street)].filter(Boolean).join(" ");
    const city = clean(properties?.city || properties?.town || properties?.village || properties?.district || properties?.county);
    const state = clean(properties?.state || properties?.statecode);
    const postcode = clean(properties?.postcode);
    const line2 = [city, state, postcode].filter(Boolean).join(", ");
    return [street, line2].filter(Boolean).join(", ");
  };

  const radians = degrees => Number(degrees) * Math.PI / 180;
  const distanceMeters = (a, b) => {
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
    if (key === "giant" || key.includes("giantfoodstores")) return ["GIANT Food Stores", "Giant Food", "GIANT"];
    if (key === "bjs" || key.includes("bjswholesale")) return ["BJ's Wholesale Club", "BJ's"];
    if (key.includes("wholefoods")) return ["Whole Foods Market", "Whole Foods"];
    if (key.includes("traderjoes")) return ["Trader Joe's", "Trader Joes"];
    if (key.includes("costco")) return ["Costco Wholesale", "Costco"];
    if (key.includes("wegmans")) return ["Wegmans"];
    if (key.includes("shoprite")) return ["ShopRite"];
    if (key.includes("aldi")) return ["ALDI"];
    if (key.includes("target")) return ["Target"];
    return [raw];
  };

  const brandMatch = (properties, preference) => {
    const text = normalize([
      properties?.name,
      properties?.brand,
      properties?.operator,
      properties?.osm_value
    ].map(clean).filter(Boolean).join(" "));
    if (!text) return false;
    return aliasesFor(preference).some(alias => {
      const candidate = normalize(alias);
      if (!candidate) return false;
      if (candidate === "giant") return text === "giant" || text.includes("giantfood");
      return text.includes(candidate);
    });
  };

  const resolveAnchor = async address => {
    const raw = clean(address);
    if (!raw) return null;

    // Reuse an already warm web geocoder when possible.
    try {
      const existing = await window.LifeRouteWebRouting?.geocode?.(raw);
      if (existing?.latitude != null && existing?.longitude != null) {
        return { latitude: Number(existing.latitude), longitude: Number(existing.longitude) };
      }
    } catch (_) {}

    // Photon is also the independent fallback for route-area geocoding.
    try {
      const data = await photon(raw, null, 2);
      const first = Array.isArray(data?.features) ? data.features.find(featurePoint) : null;
      return first ? featurePoint(first) : null;
    } catch (_) {
      return null;
    }
  };

  const centerFor = async payload => {
    const addresses = (payload?.nearAddresses || []).map(clean).filter(Boolean).slice(0, 3);
    const resolved = await Promise.all(addresses.map(resolveAnchor));
    const points = resolved.filter(Boolean);
    if (!points.length) {
      try { points.push(await currentPosition()); } catch (_) {}
    }
    if (!points.length) throw new Error("Could not locate this part of your route");
    return {
      latitude: points.reduce((sum, point) => sum + point.latitude, 0) / points.length,
      longitude: points.reduce((sum, point) => sum + point.longitude, 0) / points.length
    };
  };

  const searchOneBrand = async (preference, center, limit) => {
    const aliases = aliasesFor(preference);
    const all = [];

    for (const alias of aliases.slice(0, 2)) {
      let data = null;
      try { data = await photon(alias, center, Math.max(6, Number(limit || 5) * 2)); }
      catch (_) { continue; }

      for (const feature of Array.isArray(data?.features) ? data.features : []) {
        const point = featurePoint(feature);
        if (!point) continue;
        const properties = feature.properties || {};
        if (!brandMatch(properties, preference)) continue;
        const distanceFromCenter = distanceMeters(center, point);
        if (distanceFromCenter > 80000) continue;

        const name = clean(properties.name || properties.brand || properties.operator) || preference;
        const address = addressFor(properties) || [name, clean(properties.city), clean(properties.state)].filter(Boolean).join(", ");
        all.push({
          brand: preference,
          name,
          address: address || name,
          latitude: point.latitude,
          longitude: point.longitude,
          distanceFromCenter
        });
      }
      if (all.length >= Number(limit || 5)) break;
    }

    const seen = new Set();
    return all
      .sort((a, b) => a.distanceFromCenter - b.distanceFromCenter)
      .filter(item => {
        const key = `${normalize(item.name)}|${item.latitude.toFixed(4)}|${item.longitude.toFixed(4)}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .slice(0, clamp(limit || 5, 1, 6));
  };

  const directSearch = async payload => {
    const queries = Array.from(new Set((payload?.queries || []).map(clean).filter(Boolean))).slice(0, 5);
    if (!queries.length) return [];
    const center = await centerFor(payload);
    const groups = await Promise.all(queries.map(query => searchOneBrand(query, center, payload?.limitPerQuery || 5)));
    const locations = groups.flat();
    const seen = new Set();
    return locations.filter(item => {
      const key = `${normalize(item.name)}|${item.latitude.toFixed(4)}|${item.longitude.toFixed(4)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 18);
  };

  window.postNative = function lifeRouteWebDirectStorePostNative(payload) {
    if (clean(payload?.action) !== "searchStoreLocations") {
      return typeof previousPostNative === "function" ? previousPostNative(payload) : false;
    }

    const requestID = clean(payload?.requestID);
    if (!requestID) return typeof previousPostNative === "function" ? previousPostNative(payload) : false;

    try { window.setStatus?.("Searching nearby stores…"); } catch (_) {}

    directSearch(payload).then(locations => {
      if (locations.length) {
        try { window.setStatus?.(`Found ${locations.length} nearby store${locations.length === 1 ? "" : "s"}`); } catch (_) {}
        emit({ type: "storeLocations", requestID, locations, source: "web-photon-direct" });
        return;
      }

      const handled = typeof previousPostNative === "function" ? previousPostNative(payload) : false;
      if (!handled) {
        emit({ type: "storeLocations", requestID, locations: [], source: "web-photon-direct", error: "No nearby branches found" });
      }
    }).catch(error => {
      console.warn("LifeRoute direct web store search failed; using legacy fallback", error);
      const handled = typeof previousPostNative === "function" ? previousPostNative(payload) : false;
      if (!handled) {
        emit({ type: "storeLocations", requestID, locations: [], source: "web-photon-direct", error: error?.message || "Store search unavailable" });
      }
    });

    return true;
  };

  try { postNative = window.postNative; } catch (_) {}
  window.LifeRouteWebStoreDirectV2 = { search: directSearch, ready: true };
})();
