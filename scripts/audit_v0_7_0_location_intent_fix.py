#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTING = (ROOT / "LifeRoute/RoutingLocationDomain.swift").read_text(encoding="utf-8")
ADDRESS = (ROOT / "LifeRoute/V054AddressField.swift").read_text(encoding="utf-8")
DAY_VIEW = (ROOT / "LifeRoute/DayRoutePlanningView.swift").read_text(encoding="utf-8")
DAY_CORE = (ROOT / "LifeRoute/DayRoutePlanningCore.swift").read_text(encoding="utf-8")
SETUP = (ROOT / "LifeRoute/V054SetupView.swift").read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.0 location intent audit failed: missing {label}: {token}")


def forbid(text: str, token: str, label: str) -> None:
    if token in text:
        raise SystemExit(f"v0.7.0 location intent audit failed: forbidden {label}: {token}")


# Flexible To-Do destination contract.
require(ROUTING, "struct LifeRouteDestinationIntent: Identifiable, Hashable", "destination intent model")
for value in [
    "Any grocery store",
    "Any Walmart",
    "Any BJ's",
    "Any Target",
    "Any Costco",
    "Any pharmacy",
    "Any gas station",
    "Any coffee shop",
]:
    require(ROUTING, value, f"flexible destination {value}")
require(ROUTING, "static func naturalLanguageQuery(forStoredValue value: String)", "routing intent normalizer")
require(SETUP, 'V054AddressField("Location / store (optional)", text: $todoAddress, mode: .todoDestination)', "To-Do destination mode")
require(ADDRESS, "case todoDestination", "To-Do address field mode")
require(ADDRESS, 'Text("FLEXIBLE DESTINATIONS")', "flexible destination section")
require(ADDRESS, 'Text(mode == .todoDestination ? "SPECIFIC PLACES" : "SUGGESTIONS")', "specific places section")
require(ADDRESS, "LifeRouteDestinationIntent.matches(text)", "typed intent matching")

# Selection must dismiss both the result surface and keyboard, and must not immediately re-query.
require(DAY_VIEW, "@State private var suppressStopAutocompleteQuery = false", "Day Route query suppression")
require(DAY_VIEW, "@FocusState private var stopAddressFocused: Bool", "Day Route focus owner")
require(DAY_VIEW, "suppressStopAutocompleteQuery = true\n                    stopAddress = suggestion.addressText", "Day Route selection suppression order")
require(DAY_VIEW, "stopAutocomplete.clear()\n                    stopAddressFocused = false", "Day Route result/keyboard dismissal")
require(ADDRESS, "@FocusState private var isFocused: Bool", "shared field focus owner")
require(ADDRESS, "autocomplete.clear()\n                                isFocused = false", "shared field selection dismissal")
require(ROUTING, "guard let self, self.lastQuery == requestedQuery, !requestedQuery.isEmpty else { return }", "stale autocomplete callback guard")

# Flexible stored values are translated to clean natural-language searches for every supported route adapter.
require(ROUTING, "request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: cleaned)", "RoutingLocation MapKit normalization")
require(DAY_CORE, "request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: query)", "Day Route MapKit normalization")
require(DAY_CORE, 'URLQueryItem(name: "destination", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress))', "Google Maps normalization")
require(DAY_CORE, 'URLQueryItem(name: "q", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress))', "Waze normalization")

# The fix stays native and does not create an alternate routing/to-do owner.
for text, label in [(ROUTING, "routing"), (ADDRESS, "address field"), (DAY_VIEW, "Day Route"), (SETUP, "Setup")]:
    forbid(text, "WKWebView", f"WebView fallback in {label}")
    forbid(text, "localStorage", f"web persistence in {label}")

require(ROUTING, "@Published private(set) var todos: [LifeRouteTodo] = []", "existing To-Do owner retained")
require(ROUTING, "@Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []", "existing Saved Places owner retained")

print("LifeRoute v0.7.0 location intent audit passed: autocomplete selections dismiss reliably, stale completer callbacks cannot repopulate the menu, flexible Any-brand/category To-Do destinations coexist with specific places, and all native routing adapters normalize the stored intent without introducing new state owners or web runtime.")
