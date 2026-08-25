from pathlib import Path
import re
from urllib.parse import urlparse

checks=[]
def require(v,label): checks.append((bool(v),label))
def text(path): return Path(path).read_text()

swift=text("LifeRoute/LifeRouteWebView.swift")
info=text("LifeRoute/Info.plist")
google=text("LifeRoute/Web/google-calendar-web.js")
calendar=text("LifeRoute/Web/calendar-hub.js")
routing=text("LifeRoute/Web/web-routing-bridge.js")
search=text("LifeRoute/Web/stop-place-search-v4.js")
store=text("LifeRoute/Web/web-store-direct-v2.js")
visual=text("LifeRoute/Web/visual-resolver.js")
visual_bridge=text("LifeRoute/Web/visual-resolver-bridge.js")
animals=text("LifeRoute/Web/dynamic-animals-v1.js")
nature=text("LifeRoute/Web/photoreal-nature-web.js")
resources=text("LifeRoute/Web/resources-hub-web.js")
config=text("LifeRoute/Web/config.js")
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

# Read-only arbitrary calendar feeds: URLs may themselves contain secret tokens,
# so both web and native enforce HTTPS and request deadlines without credentials.
require("fetchCalendarFeedWithTimeout" in calendar and "AbortController" in calendar, "browser calendar feeds have abort deadline")
require('credentials: "omit"' in calendar, "browser calendar feeds omit browser credentials")
require('if (!/^(https:\\/\\/|webcal:\\/\\/)/i.test(url))' in calendar, "saved calendar links are HTTPS/webcal only")
require('case "fetchReadOnlyCalendarFeed"' in swift and "private func fetchReadOnlyCalendarFeed" in swift, "native calendar-feed bridge exists")
require('request.timeoutInterval = 25' in swift, "native read-only calendar feed has 25-second deadline")
require('scheme == "https" else' in swift, "native calendar feeds reject plaintext HTTP")

# Browser routing/search providers: every fetch path has deadlines and explicit fallback behavior.
for host in ["nominatim.openstreetmap.org","router.project-osrm.org","overpass-api.de","overpass.private.coffee"]:
    require(host in routing, f"browser routing declares {host}")
require("AbortController" in routing and "timeoutMs" in routing, "OSM/OSRM/Overpass requests have deadlines")
require("routingConsent" in routing, "browser route calculations require routing consent")
for host in ["photon.komoot.io","nominatim.openstreetmap.org"]:
    require(host in search, f"stop search declares {host}")
require("AbortController" in search and "Promise.allSettled" in search, "stop search has deadlines and independent provider fallback")
require("AbortController" in store and "timeoutMs" in store, "direct store search helper has deadlines")

# Public visual/media services. Curated static photos carry no app payload. Generic
# Wikimedia lookup is allowed only for safe generic terms and has a hard deadline.
require("commons.wikimedia.org/w/api.php" in visual, "generic visual resolver uses Wikimedia Commons")
require("safeForPublicLookup" in visual and "if (/\\d/.test(normalized)) return false" in visual, "visual lookup blocks likely private/name-like terms")
require("fetchWithTimeout" in visual and "AbortController" in visual, "generic visual lookup has deadline")
require('credentials: "omit"' in visual, "generic Wikimedia lookup omits credentials")
require("fetchWithTimeout" in visual_bridge and "AbortController" in visual_bridge, "First/Then fallback visual lookup has deadline")
require('credentials: "omit"' in visual_bridge, "First/Then Wikimedia fallback omits credentials")
require("bodyObserver.observe(document.body" not in visual_bridge, "First/Then resolver has no page-wide wiring observer")
require("commons.wikimedia.org/w/api.php" in animals, "Living Creatures uses Wikimedia Commons API")
require("fetchWithTimeout" in animals and "AbortController" in animals, "Living Creature Wikimedia lookup has deadline")
require("credentials:\"omit\"" in animals or 'credentials: "omit"' in animals, "Living Creature requests omit credentials")
require("LicenseShortName" in animals and "Wikimedia Commons" in animals, "Wikimedia attribution metadata is preserved")
require("https://unsplash.com/photos/" in nature, "Scenery image source is explicit Unsplash media")
require("images.unsplash.com" in visual and "images.pexels.com" in visual, "curated visual media hosts are explicit")

# Resource Hub links are explicit user navigation, never background integrations.
require("window.open(safeURL" in resources and '"_blank", "noopener,noreferrer"' in resources, "resource links open only after explicit launch action")
require('url.protocol === "https:"' in resources, "custom resource links are HTTPS-only")
require("fetch(" not in resources and "XMLHttpRequest" not in resources, "Resource Hub does not call portal APIs or transmit credentials")
require("does not sign in to these services or store their credentials" in resources, "Resource Hub privacy boundary is visible to user")

# CentralReach remains dormant configuration until an authenticated API is intentionally enabled.
require('centralReach: {' in config and 'enabled: false' in config, "CentralReach API scaffold is disabled")
require("partners-api.centralreach.com" in config, "CentralReach scaffold endpoint is explicit and reviewable")
require("fetch(" not in config, "disabled CentralReach config performs no network request")

# Web/native preview separation.
require("if (window.webkit?.messageHandlers?.lifeRoute) return" in preview, "browser-preview helpers never install in native WKWebView")
require("Apple Calendar, notifications, and Apple MapKit remain iPhone features" in preview, "web preview labels native-only capabilities")

# Fresh-angle rule: any JS module issuing a direct fetch must own an AbortController.
# This catches future network paths that were not manually added above.
direct_fetch_files=[]
for path in sorted(Path("LifeRoute/Web").glob("*.js")):
    data=path.read_text(errors="ignore")
    if re.search(r'\bfetch\s*\(', data):
        direct_fetch_files.append(path.name)
        require("AbortController" in data, f"direct fetch in {path.name} has an AbortController deadline")

# External-host inventory classified by execution role. Any newly hard-coded host
# fails this audit until it is deliberately reviewed.
runtime_service_hosts={
    "accounts.google.com","oauth2.googleapis.com","www.googleapis.com",
    "photon.komoot.io","nominatim.openstreetmap.org","router.project-osrm.org",
    "overpass-api.de","overpass.private.coffee","commons.wikimedia.org",
}
map_handoff_hosts={"maps.apple.com","www.google.com"}
media_hosts={"unsplash.com","images.unsplash.com","images.pexels.com"}
setup_attribution_hosts={
    "console.cloud.google.com","jackersthecoltsfan.github.io","www.icloud.com","icloud.com",
    "support.apple.com","www.openstreetmap.org",
}
resource_navigation_hosts={
    "my.adp.com","app.bamboohr.com","app.gusto.com","www.paycomonline.net","access.paylocity.com",
    "www.ukg.com","app.rippling.com","www.workday.com","workforce.intuit.com","www.viventium.com",
    "members.centralreach.com","webapp.rethinkbehavioralhealth.com","www.theralytics.net","secure.datafinch.com",
    "www.motivity.net","app.hirasmus.com","alohaaba.com","portal.bacb.com","login.reliaslearning.com",
    "hhaexchange.com","www.sandata.com","www.office.com","workspace.google.com","app.slack.com","teams.microsoft.com",
}
dormant_config_hosts={"partners-api.centralreach.com"}
approved_hosts=(runtime_service_hosts|map_handoff_hosts|media_hosts|setup_attribution_hosts|resource_navigation_hosts|dormant_config_hosts)

paths=[Path("LifeRoute/LifeRouteWebView.swift"), Path("scripts/web-preview.js")]
paths += list(Path("LifeRoute/Web").glob("*.js")) + [Path("LifeRoute/Web/index.html")]
hosts=set(); host_sources={}
for path in paths:
    data=path.read_text(errors="ignore")
    for url in re.findall(r'https://[A-Za-z0-9._-]+[^\s\"\'<>`)]*', data):
        try:
            host=urlparse(url).hostname
            if host:
                host=host.lower(); hosts.add(host); host_sources.setdefault(host,set()).add(path.name)
        except Exception: pass
unknown=sorted(hosts-approved_hosts)
require(not unknown, "all hard-coded HTTPS hosts are explicitly classified by execution role")

# Classification invariants: portals are launch-hub only; static media hosts are
# confined to visual/scenery modules; dormant CentralReach API stays config-only.
for portal in resource_navigation_hosts & hosts:
    require(host_sources.get(portal,set()) <= {"resources-hub-web.js"}, f"resource portal {portal} is navigation-only")
for host in {"images.unsplash.com","images.pexels.com"} & hosts:
    sources=host_sources.get(host,set())
    require(all(name.startswith("visual-") or name == "photoreal-nature-web.js" for name in sources), f"curated media host {host} is visual-only")
require(host_sources.get("partners-api.centralreach.com",set()) <= {"config.js"}, "CentralReach partner API remains dormant configuration only")

failed=[label for ok,label in checks if not ok]
print(f"LifeRoute external-services audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
print("Direct-fetch modules:", ", ".join(direct_fetch_files))
print("Runtime API hosts:", ", ".join(sorted(runtime_service_hosts & hosts)))
print("Media hosts:", ", ".join(sorted(media_hosts & hosts)))
print("User-navigation hosts:", ", ".join(sorted(resource_navigation_hosts & hosts)))
print("Dormant config hosts:", ", ".join(sorted(dormant_config_hosts & hosts)))
if unknown: print("UNREVIEWED HOSTS:", ", ".join(unknown))
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Apple native integrations, Google OAuth/API, secure calendar subscriptions, browser routing/search, all direct fetch paths, visual media, resource-link boundaries, timeouts, workload caps, and host classification passed.")
