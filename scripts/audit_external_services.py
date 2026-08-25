from pathlib import Path
import re
from urllib.parse import urlparse

checks=[]
def require(v,label): checks.append((bool(v),label))
def text(path): return Path(path).read_text()

swift=text("LifeRoute/LifeRouteWebView.swift")
info=text("LifeRoute/Info.plist")
google=text("LifeRoute/Web/google-calendar-web.js")
routing=text("LifeRoute/Web/web-routing-bridge.js")
search=text("LifeRoute/Web/stop-place-search-v4.js")
store=text("LifeRoute/Web/web-store-direct-v2.js")
animals=text("LifeRoute/Web/dynamic-animals-v1.js")
nature=text("LifeRoute/Web/photoreal-nature-web.js")
preview=text("scripts/web-preview.js")

# Native Apple integrations: local frameworks, explicit permission, URL handoff only.
require("import EventKit" in swift and "EKEventStore" in swift, "Apple Calendar uses native EventKit")
require("requestFullAccessToEvents" in swift or "requestAccess(to: .event)" in swift, "Apple Calendar permission is explicit")
require("NSCalendars" in info, "calendar permission purpose text exists")
require("import MapKit" in swift, "route calculations use native MapKit")
require("https://maps.apple.com/" in swift, "Apple Maps handoff uses official HTTPS endpoint")
require("https://www.google.com/maps/" in swift, "Google Maps handoff uses official HTTPS endpoint")

# Native Google Calendar OAuth + API safety.
for marker in [
    "https://accounts.google.com/o/oauth2/v2/auth",
    "https://oauth2.googleapis.com/token",
    "https://www.googleapis.com/calendar/v3",
    "https://www.googleapis.com/auth/calendar.readonly",
    "code_challenge_method", "S256", 'params["state"] == state',
    "kSecClassGenericPassword", "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"
]:
    require(marker in swift, f"native Google contract contains {marker}")
require(swift.count("request.timeoutInterval = 20") >= 2, "native Google token/API requests have 20-second deadlines")
require("prefix(40)" in swift, "native Google Calendar working set is capped at 40 calendars")
require("pages < 8" in swift, "native Google event pagination is capped")
require("client_secret" not in swift.lower(), "native OAuth contains no client secret")

# Browser Google Calendar: read-only, memory-only access token, bounded workload/network.
require('SCOPES = "https://www.googleapis.com/auth/calendar.readonly"' in google, "web Google Calendar scope is read-only")
require('let accessToken = ""' in google and 'localStorage.setItem("accessToken"' not in google, "web access token is memory-only")
require("AbortController" in google and "fetchWithTimeout" in google, "web Google API requests have abort deadlines")
require("pages < 8" in google and "slice(0, 40)" in google, "web Google sync bounds calendars and pagination")
require("include_granted_scopes: true" in google, "Google OAuth requests incremental granted scopes")
require("client_secret" not in google.lower(), "browser OAuth contains no client secret")

# Browser routing/search providers: every fetch path has deadlines and explicit fallback behavior.
for host in ["nominatim.openstreetmap.org","router.project-osrm.org","overpass-api.de","overpass.private.coffee"]:
    require(host in routing, f"browser routing declares {host}")
require("AbortController" in routing and "timeoutMs" in routing, "OSM/OSRM/Overpass requests have deadlines")
require("routingConsent" in routing, "browser route calculations require routing consent")
for host in ["photon.komoot.io","nominatim.openstreetmap.org"]:
    require(host in search, f"stop search declares {host}")
require("AbortController" in search and "Promise.allSettled" in search, "stop search has deadlines and independent provider fallback")
require("AbortController" in store and "timeoutMs" in store, "legacy/direct store helper also has deadlines")

# Theme media services: public media only; no user data payload; bounded lookup for dynamic animals.
require("commons.wikimedia.org/w/api.php" in animals, "Living Creatures uses Wikimedia Commons API")
require("fetchWithTimeout" in animals and "AbortController" in animals, "Wikimedia lookup has deadline")
require("credentials:\"omit\"" in animals or 'credentials: "omit"' in animals, "Wikimedia requests omit credentials")
require("LicenseShortName" in animals and "Wikimedia Commons" in animals, "Wikimedia attribution metadata is preserved")
require("https://unsplash.com/photos/" in nature, "Scenery image source is explicit Unsplash media")

# Web/native preview separation.
require("if (window.webkit?.messageHandlers?.lifeRoute) return" in preview, "browser-preview helpers never install in native WKWebView")
require("Apple Calendar, notifications, and Apple MapKit remain iPhone features" in preview, "web preview labels native-only capabilities")

# Runtime external-host inventory. Any new hard-coded runtime service must be reviewed here.
approved_hosts={
    "accounts.google.com","oauth2.googleapis.com","www.googleapis.com","www.google.com",
    "console.cloud.google.com","maps.apple.com","photon.komoot.io","nominatim.openstreetmap.org",
    "router.project-osrm.org","overpass-api.de","overpass.private.coffee","commons.wikimedia.org",
    "unsplash.com","jackersthecoltsfan.github.io","www.icloud.com","icloud.com","support.apple.com",
}
paths=[Path("LifeRoute/LifeRouteWebView.swift"), Path("scripts/web-preview.js")]
paths += list(Path("LifeRoute/Web").glob("*.js")) + [Path("LifeRoute/Web/index.html")]
hosts=set()
for path in paths:
    data=path.read_text(errors="ignore")
    for url in re.findall(r'https://[A-Za-z0-9._-]+[^\s\"\'<>`)]*', data):
        try:
            host=urlparse(url).hostname
            if host: hosts.add(host.lower())
        except Exception: pass
unknown=sorted(hosts-approved_hosts)
require(not unknown, "all hard-coded runtime HTTPS hosts are reviewed/allowlisted")

failed=[label for ok,label in checks if not ok]
print(f"LifeRoute external-services audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
print("Reviewed runtime hosts:", ", ".join(sorted(hosts)))
if unknown: print("UNREVIEWED HOSTS:", ", ".join(unknown))
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Apple native integrations, Google OAuth/API, browser routing/search, media services, privacy boundaries, timeouts, workload caps, and host inventory passed.")
