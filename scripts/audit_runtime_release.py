from pathlib import Path
import re

checks = []

def require(condition, label):
    checks.append((bool(condition), label))


def text(path):
    return Path(path).read_text()

root = Path(".")
index = text("LifeRoute/Web/index.html")
prepare = text("scripts/prepare_build.sh")
controls = text("LifeRoute/Web/day-controls-v5.js")
duration = text("LifeRoute/Web/stop-duration-v1.js")
clients = text("LifeRoute/Web/client-picker-sync-v1.js")
toolbar = text("LifeRoute/Web/toolbar-cleanup-v1.js")
location = text("LifeRoute/Web/live-location-v2.js")
timer = text("LifeRoute/Web/visual-timer-v2.js")
first_then = text("LifeRoute/Web/first-then-back.js")
search = text("LifeRoute/Web/stop-place-search-v4.js")
fluid = text("LifeRoute/Web/fluid-scenes-v1.js")
animals = text("LifeRoute/Web/dynamic-animals-v1.js")
dynamic = text("LifeRoute/Web/dynamic-themes-web.js")
catalog = text("LifeRoute/Web/theme-catalog-v3.js")
aesthetic = text("LifeRoute/Web/aesthetic-polish-v1.js")
ui_simplify = text("LifeRoute/Web/ui-simplify-v4.js")
testflight = text(".github/workflows/testflight.yml")
auto_release_path = Path(".github/workflows/auto-testflight.yml")

# A) Observer / timer pressure: high-frequency helpers stay scoped to the UI they own.
require('observer.observe(document.body' not in controls, "Live Day helper no longer watches whole document")
require('observer.observe(todayRoot' in controls, "Live Day helper observes only Today screen")
require('observer.observe(document.body' not in duration, "stop-duration helper does not watch whole document")
require('observer.observe(document.body' not in clients, "client sync does not watch whole document")
require('subtree: true' not in toolbar, "main-toolbar observer does not recurse into unrelated descendants")
require('overlayClassObserver.observe(overlay' in first_then and 'attributeFilter: ["class"]' in first_then, "First/Then class observer is overlay-scoped")
require('overlayContentObserver' not in first_then and 'childList: true' not in first_then and 'subtree: true' not in first_then, "First/Then has no recursive content observer")
require('bodyObserver' not in first_then, "First/Then has no page-wide mutation observer")
require('bodyObserver.disconnect()' in timer, "Visual Timer temporary body observer disconnects")
require('overlayObserver.observe(host' in timer, "Visual Timer ongoing observer is overlay-scoped")
require('document.visibilityState === "hidden"' in timer, "Visual Timer scheduler pauses in background")
require('pagehide' in timer and 'stopScheduler' in timer, "Visual Timer scheduler tears down on page exit")
require('setInterval(' not in duration, "stop-duration UI has no permanent polling interval")
require('setInterval(' not in clients, "client sync has no permanent polling interval")
require('setInterval(' not in toolbar, "toolbar cleanup has no permanent polling interval")
require('setInterval(' not in location, "live location uses platform watcher rather than polling loop")
require('setInterval(' not in fluid, "Fluid Motion has no JS polling loop")
require('setInterval(' not in animals, "Living Creatures has no JS polling loop")
require('setInterval(' not in dynamic, "Dynamic themes have no JS polling loop")
require('observer.observe(document.body' not in catalog, "theme catalog does not watch whole document")
require('observer.observe(sheet' in catalog, "theme catalog observer is Settings-sheet scoped")

# B) Location and network lifecycle: watchers and requests always have stop/timeout paths.
require('navigator.geolocation.watchPosition' in location, "browser location uses continuous geolocation watcher")
require('navigator.geolocation.clearWatch' in location, "browser location watcher is explicitly released")
require('stopWebFallback()' in location and 'stopLiveLocation' in location, "web/native location stop paths exist")
require('new AbortController()' in search and 'setTimeout(() => controller.abort()' in search, "stop search network calls have hard timeout")
require('Promise.allSettled' in search, "parallel stop providers fail independently")

# C) Animation pressure and accessibility.
require('prefers-reduced-motion:reduce' in fluid, "Fluid Motion honors reduced-motion preference")
require('prefers-reduced-motion:reduce' in animals, "Living Creatures honors reduced-motion preference")
require('prefers-reduced-motion:reduce' in dynamic, "Dynamic themes honor reduced-motion preference")
require('prefers-reduced-motion:reduce' in aesthetic, "global aesthetic polish honors reduced-motion preference")
require('characterData: true' not in ui_simplify, "UI simplifier ignores live text-character churn")

# D) Canonical core startup is deterministic and not duplicated in the prepared HTML.
script_tags = re.findall(r'<script\s+src="([^"?]+\.js)(?:\?[^\"]*)?"></script>', index)
require(len(script_tags) == len(set(script_tags)), "prepared HTML contains no duplicate core script tags")
for required in (
    'client-picker-sync-v1.js', 'toolbar-cleanup-v1.js', 'live-location-v2.js',
    'visual-timer-v2.js', 'first-then-back.js', 'stop-place-search-v4.js',
    'stop-duration-v1.js', 'live-day.js', 'day-controls-v5.js',
    'nature-settings-web.js', 'settings-classic-themes-web.js', 'dynamic-themes-web.js',
    'fluid-scenes-v1.js', 'dynamic-animals-v1.js', 'theme-catalog-v3.js', 'stability-runtime.js'
):
    require(script_tags.count(required) == 1, f"{required} loads exactly once in shared runtime")

def idx(name):
    try: return script_tags.index(name)
    except ValueError: return -1
require(0 <= idx('selected-gap-routes.js') < idx('live-day.js'), "selected routes load before Live Day")
require(0 <= idx('boundary-stop-planner.js') < idx('stop-duration-v1.js'), "boundary planner loads before duration wrapper")
require(0 <= idx('stop-place-search-v4.js') < idx('stop-duration-v1.js'), "search engine loads before duration interaction layer")
require(0 <= idx('live-day.js') < idx('day-controls-v5.js'), "Live Day core loads before control/Live Activity wrapper")
require(0 <= idx('nature-settings-web.js') < idx('theme-catalog-v3.js'), "Settings shell loads before theme catalog normalization")
require('loadHelper(' not in text('LifeRoute/Web/settings-classic-themes-web.js'), "classic themes do not inject duplicate theme scripts")

# E) Release pipeline must rebuild/audit before a signed archive and upload,
# but that pipeline may only be entered by explicit manual dispatch. The
# obsolete automatic TestFlight workflow must remain deleted.
prepare_pos = testflight.find('bash scripts/prepare_build.sh')
audit_pos = testflight.find('python3 scripts/audit_liferoute_build.py')
archive_pos = testflight.find('Archive LifeRoute')
upload_pos = testflight.find('Upload to TestFlight')
require(min(prepare_pos, audit_pos, archive_pos, upload_pos) >= 0, "TestFlight workflow contains prepare, audit, archive, and upload stages")
require(prepare_pos < audit_pos < archive_pos < upload_pos, "TestFlight stages execute in safe order")
require('concurrency:' in testflight and 'group: liferoute-testflight' in testflight, "TestFlight uploads are serialized")
require('cancel-in-progress: false' in testflight, "an active TestFlight upload cannot be cancelled by a duplicate request")
require('CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER}"' in testflight, "each TestFlight run gets a unique build number")
require('Clean temporary Apple signing assets' in testflight and 'if: always()' in testflight, "temporary signing assets are cleaned even after failure")
automatic_triggers = ('workflow_run:', 'repository_dispatch:', 'schedule:', 'push:', 'pull_request:')
require('workflow_dispatch:' in testflight, "TestFlight upload requires explicit workflow dispatch")
require(all(trigger not in testflight for trigger in automatic_triggers), "TestFlight upload has no automatic trigger")
require(not auto_release_path.exists(), "legacy auto-TestFlight workflow is removed")

# F) Repository safety/privacy: no user fixtures, private keys, or signing payloads are distributable source.
for forbidden in (
    'Brandon Good', '600 Valley Rd', '9611 Cowden St',
    '-----BEGIN PRIVATE KEY-----', '-----BEGIN EC PRIVATE KEY-----',
    'client_secret', 'PREVIEW_CODE', '246810'
):
    found = False
    for path in list(Path('LifeRoute').rglob('*')) + list(Path('LifeRouteShared').rglob('*')) + list(Path('LifeRouteLiveActivity').rglob('*')):
        if not path.is_file() or path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.pdf'}:
            continue
        try:
            if forbidden.lower() in path.read_text(errors='ignore').lower():
                found = True
                break
        except Exception:
            pass
    require(not found, f"distributed app source excludes forbidden fixture/secret marker: {forbidden}")

private_extensions = {'.p8', '.p12', '.mobileprovision', '.cer'}
private_files = [str(path) for path in root.rglob('*') if path.is_file() and path.suffix.lower() in private_extensions and '.git' not in path.parts]
require(not private_files, "repository contains no committed private signing credential files")

# G) Build-time hardening and independent audits must be permanent gates.
require('patch_release_hardening_v1.py' in prepare, "release-hardening patch is part of deterministic preparation")
require('patch_theme_runtime_hardening_v1.py' in prepare, "theme-runtime hardening is part of deterministic preparation")
require('audit_user_journeys.py' in prepare, "user-journey audit is part of build preparation")
require('audit_runtime_release.py' in prepare, "runtime/release audit is part of build preparation")
require('audit_theme_runtime_deep.py' in prepare, "deep theme audit is part of build preparation")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute runtime/release audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    if private_files:
        print("Private files:", private_files)
    raise SystemExit(1)
print("LifeRoute runtime pressure, lifecycle, privacy, deterministic loading, and manual-only release ordering audit passed.")
