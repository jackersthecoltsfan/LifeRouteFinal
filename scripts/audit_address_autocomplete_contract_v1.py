from pathlib import Path

autocomplete = Path("LifeRoute/Web/address-autocomplete-v1.js").read_text()
swift = Path("LifeRoute/LifeRouteWebView.swift").read_text()

checks = []
def require(condition, label): checks.append((bool(condition), label))

for marker in [
    'const looksLikeAddress = input =>',
    'address|street|location|destination|origin|searchable place|service location',
    'input.setAttribute("autocomplete", "street-address")',
    'clearTimeout(debounceTimer)',
    'debounceTimer = setTimeout',
    'query.length < 3',
    'activeRequestID',
    'requestID !== activeRequestID',
    'slice(0, 6)',
    'dataset.lrAutocompleteSelected = "1"',
    'dispatchEvent(new Event("input", { bubbles: true }))',
    'dispatchEvent(new Event("change", { bubbles: true }))',
    'new MutationObserver(queueScan).observe(document.body, { childList: true, subtree: true })',
]:
    require(marker in autocomplete, f"global autocomplete contains {marker}")

for forbidden in ['scrollIntoView(', 'scrollIntoView?.(', 'window.scrollTo(', 'window.scrollBy(']:
    require(forbidden not in autocomplete, f"autocomplete never calls {forbidden}")

for marker in [
    'MKLocalSearchCompleterDelegate',
    'private let addressCompleter = MKLocalSearchCompleter()',
    'case "addressAutocomplete":',
    'addressCompleter.resultTypes = [.address, .pointOfInterest]',
    'addressCompleter.queryFragment = query',
    'func completerDidUpdateResults',
    '"addressAutocompleteResults"',
]:
    require(marker in swift, f"native MapKit autocomplete bridge contains {marker}")

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute address-autocomplete contract audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:", label)
    raise SystemExit(1)
print("Global/dynamic address detection, debounce, stale-result filtering, normalized selection, MapKit bridge, and no-auto-scroll passed.")
