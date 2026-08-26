from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PREPARE = ROOT / "scripts" / "prepare_build.sh"

errors = []

def require(condition, message):
    if not condition:
        errors.append(message)


autocomplete = (WEB / "address-autocomplete-v1.js").read_text()
home = (WEB / "home-location-v3.js").read_text()
smart = (WEB / "smart-context.js").read_text()
swift = SWIFT.read_text()
prepare = PREPARE.read_text()
index = (WEB / "index.html").read_text()

for marker in ["address-autocomplete-v1.js", "home-location-v3.js", "patch_address_autocomplete_v1.py", "patch_home_location_v3.py"]:
    require(marker in prepare or marker in index, f"Build integration missing: {marker}")

for marker in ["street-address", "addressAutocomplete", "Nominatim", "MutationObserver", "lrAddressSuggestion"]:
    require(marker in autocomplete, f"Address autocomplete marker missing: {marker}")
for marker in ["MKLocalSearchCompleter", "MKLocalSearchCompleterDelegate", 'case "addressAutocomplete"', "addressAutocompleteResults"]:
    require(marker in swift, f"Native MapKit autocomplete marker missing: {marker}")
for marker in ["liferoute_home_address_v3", "persistHome", "upsertHomePlace", "startLiveLocation", "Use live location"]:
    require(marker in home, f"Home/location reliability marker missing: {marker}")
require("MapKit route intelligence" not in smart, "Obsolete MapKit route intelligence pill still present")
require("Commute intelligence" not in smart, "Old Commute intelligence heading still present")
require("smartContextStrip") in smart, "Smart-strip cleanup contract missing")
require("document.getElementById(\"smartContextStrip\")?.remove();" in smart, "Redundant smart strip is not removed")

if errors:
    print("Address/setup audit failed:")
    for item in errors:
        print(f"- {item}")
    raise SystemExit(1)

print("Address/setup audit passed: home persistence, live location, MapKit autocomplete, and simplified setup are wired.")
