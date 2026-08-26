from pathlib import Path

home = Path("LifeRoute/Web/home-location-v3.js").read_text()
smart = Path("LifeRoute/Web/smart-context.js").read_text()

checks = []
def require(condition, label): checks.append((bool(condition), label))

for marker in [
    'const HOME_KEY = "liferoute_home_address_v3"',
    'localStorage.getItem(HOME_KEY)',
    'localStorage.setItem(HOME_KEY, address)',
    'window.prefs.homeAddress = address',
    'upsertHomePlace(address)',
    'window.persist?.()',
    'const canonicalHome = () =>',
    'const reconcileHome = () =>',
    'field.value !== address',
    'window.LifeRouteHomeLocationV3 = { persistHome, canonicalHome, reconcileHome, startLiveLocation }',
]:
    require(marker in home, f"Home state layer contains {marker}")

require('window.LifeRouteHomeLocationV3.persistHome(rawAddress)' in smart,
        "Save Home delegates to the canonical Home persistence layer")
require('setStatus(savedAddress ? "Home address saved" : "Home address cleared")' in smart,
        "Save Home exposes concise saved/cleared status")
require('id="homeAddressField"' in smart and 'id="saveHomeButton"' in smart,
        "prepared Home panel retains the address field and Save Home control")
require('id="locationButton"' in smart,
        "prepared Home panel retains the live-location control")
require('MapKit route intelligence' not in smart,
        "obsolete MapKit route intelligence badge is absent")
require('Commute intelligence' not in smart,
        "overexplained Commute intelligence heading is absent")
require('For today, LifeRoute starts your first commute' not in smart,
        "verbose commute explanation is absent")
require('document.addEventListener("click"' not in home,
        "Home state layer does not duplicate UI click ownership")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute Home persistence audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Home persistence, repopulation, saved-place synchronization, simple UI, and single-handler ownership passed.")
