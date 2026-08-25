from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))


def insert_before(path: Path, marker: str, block: str, label: str):
    text = path.read_text()
    if block in text:
        return
    if marker not in text:
        raise SystemExit(f"Could not harden {label}: marker not found")
    path.write_text(text.replace(marker, block + marker, 1))


# -----------------------------------------------------------------------------
# Live-location freshness + route refresh pressure.
# -----------------------------------------------------------------------------
smart = Path("LifeRoute/Web/smart-context.js")
insert_before(
    smart,
    "    const applyClientLocations = () => {\n",
    '''    const LIVE_LOCATION_MAX_AGE_MS = 120000;\n    let liveRouteRefreshTimer = 0;\n    let lastRoutedLocation = null;\n\n    const locationStampMs = live => {\n      const explicit = Date.parse(String(live?.timestamp || ""));\n      if (Number.isFinite(explicit)) return explicit;\n      const fallback = Number(nativeState.locationUpdatedAt || 0);\n      return Number.isFinite(fallback) ? fallback : 0;\n    };\n    const freshLiveLocation = () => {\n      const live = nativeState.currentLocation;\n      if (!live || !Number.isFinite(Number(live.latitude)) || !Number.isFinite(Number(live.longitude))) return null;\n      const stamp = locationStampMs(live);\n      if (!stamp || Date.now() - stamp > LIVE_LOCATION_MAX_AGE_MS) return null;\n      return live;\n    };\n    const locationDistanceMeters = (a, b) => {\n      if (!a || !b) return Infinity;\n      const toRad = degrees => Number(degrees) * Math.PI / 180;\n      const earth = 6371000;\n      const lat1 = toRad(a.latitude);\n      const lat2 = toRad(b.latitude);\n      const dLat = lat2 - lat1;\n      const dLon = toRad(Number(b.longitude) - Number(a.longitude));\n      const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;\n      return 2 * earth * Math.asin(Math.min(1, Math.sqrt(h)));\n    };\n    const scheduleLiveRouteRefresh = live => {\n      if (!live) return;\n      const now = Date.now();\n      const moved = !lastRoutedLocation || locationDistanceMeters(lastRoutedLocation, live) >= 35;\n      const aged = !lastRoutedLocation || now - Number(lastRoutedLocation.routedAt || 0) >= 30000;\n      if (!moved && !aged) return;\n      lastRoutedLocation = { latitude:Number(live.latitude), longitude:Number(live.longitude), routedAt:now };\n      clearTimeout(liveRouteRefreshTimer);\n      liveRouteRefreshTimer = setTimeout(() => window.refreshRouteTimes?.(), 550);\n    };\n\n''',
    "live-location freshness helpers",
)
replace_once(
    smart,
    '      const live = nativeState.currentLocation;\n      const home = homeFallback();\n',
    '      const live = freshLiveLocation();\n      const home = homeFallback();\n',
    "location status freshness",
)
replace_once(
    smart,
    '      const matched = events.filter(event => event.addressSource === "client" && String(event.address || "").trim()).length;\n      strip.innerHTML = `<span class="contextPill ${nativeState.currentLocation ? "live" : ""}">${nativeState.currentLocation ? "● Live commute start" : "○ Location fallback"}</span>',
    '      const matched = events.filter(event => event.addressSource === "client" && String(event.address || "").trim()).length;\n      const live = freshLiveLocation();\n      strip.innerHTML = `<span class="contextPill ${live ? "live" : ""}">${live ? "● Live commute start" : "○ Location fallback"}</span>',
    "smart strip freshness",
)
replace_once(
    smart,
    '      const today = localDateKey(new Date());\n      const live = nativeState.currentLocation;\n      const home = homeFallback();\n',
    '      const today = localDateKey(new Date());\n      const live = freshLiveLocation();\n      const home = homeFallback();\n',
    "route origin freshness",
)
replace_once(
    smart,
    '        renderLocationStatus();\n        renderSmartStrip();\n        setTimeout(() => window.refreshRouteTimes?.(), 80);\n',
    '        renderLocationStatus();\n        renderSmartStrip();\n        scheduleLiveRouteRefresh(nativeState.currentLocation);\n',
    "live route refresh debounce",
)
replace_once(
    smart,
    '    const observer = new MutationObserver(improveStoreMessage);\n    observer.observe(document.body, { childList: true, subtree: true });\n',
    '    const observer = new MutationObserver(improveStoreMessage);\n    const todayRoot = document.getElementById("today");\n    if (todayRoot) observer.observe(todayRoot, { childList: true, subtree: true });\n',
    "smart-context observer scope",
)
replace_once(
    smart,
    '      if (!nativeState.currentLocation && nativeState.locationStatus !== "denied") {\n',
    '      if (!freshLiveLocation() && nativeState.locationStatus !== "denied") {\n',
    "initial location freshness",
)

# -----------------------------------------------------------------------------
# Browser Google Calendar network deadlines.
# -----------------------------------------------------------------------------
google_web = Path("LifeRoute/Web/google-calendar-web.js")
insert_before(
    google_web,
    "  const api = async path => {\n",
    '''  const fetchWithTimeout = async (url, options = {}, timeoutMs = 20000) => {\n    const controller = new AbortController();\n    const timer = setTimeout(() => controller.abort(), timeoutMs);\n    try {\n      return await fetch(url, { ...options, signal: controller.signal });\n    } finally {\n      clearTimeout(timer);\n    }\n  };\n\n''',
    "Google web timeout helper",
)
text = google_web.read_text()
text = text.replace("const response = await fetch(`https://www.googleapis.com/calendar/v3${path}`, {", "const response = await fetchWithTimeout(`https://www.googleapis.com/calendar/v3${path}`, {")
text = text.replace('const response = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {', 'const response = await fetchWithTimeout("https://www.googleapis.com/oauth2/v3/userinfo", {')
google_web.write_text(text)

# -----------------------------------------------------------------------------
# Wikimedia media lookup deadline for Living Creatures.
# -----------------------------------------------------------------------------
animals = Path("LifeRoute/Web/dynamic-animals-v1.js")
insert_before(
    animals,
    "  const resolveMedia = async theme => {\n",
    '''  const fetchWithTimeout = async (url, options = {}, timeoutMs = 14000) => {\n    const controller = new AbortController();\n    const timer = setTimeout(() => controller.abort(), timeoutMs);\n    try { return await fetch(url, { ...options, signal: controller.signal }); }\n    finally { clearTimeout(timer); }\n  };\n\n''',
    "Wikimedia timeout helper",
)
animals.write_text(animals.read_text().replace("const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params}`, {", "const response = await fetchWithTimeout(`https://commons.wikimedia.org/w/api.php?${params}`, {", 1))

# -----------------------------------------------------------------------------
# Native Google Calendar requests should not inherit an unbounded/default wait.
# -----------------------------------------------------------------------------
native = Path("LifeRoute/LifeRouteWebView.swift")
replace_once(
    native,
    '            var request = URLRequest(url: googleTokenEndpoint)\n            request.httpMethod = "POST"\n',
    '            var request = URLRequest(url: googleTokenEndpoint)\n            request.timeoutInterval = 20\n            request.httpMethod = "POST"\n',
    "native Google token timeout",
)
replace_once(
    native,
    '            var request = URLRequest(url: url)\n            request.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")\n',
    '            var request = URLRequest(url: url)\n            request.timeoutInterval = 20\n            request.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")\n',
    "native Google API timeout",
)

print("Live location + external service hardening applied: freshness, debounced routes, scoped observer, and network deadlines.")
