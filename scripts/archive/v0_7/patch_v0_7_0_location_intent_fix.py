#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTING = ROOT / "LifeRoute/RoutingLocationDomain.swift"
ADDRESS_FIELD = ROOT / "LifeRoute/V054AddressField.swift"
DAY_ROUTE_VIEW = ROOT / "LifeRoute/DayRoutePlanningView.swift"
DAY_ROUTE_CORE = ROOT / "LifeRoute/DayRoutePlanningCore.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 location intent fix failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_routing_domain() -> None:
    text = ROUTING.read_text(encoding="utf-8")
    if "v0.7.0 flexible destination intents" in text:
        return

    intent_model = r'''
// v0.7.0 flexible destination intents: a To-Do may name the kind/brand of place
// rather than prematurely locking the user to one street address. The stored value
// stays human-readable while routing adapters receive a clean natural-language query.
struct LifeRouteDestinationIntent: Identifiable, Hashable {
    let storedValue: String
    let naturalLanguageQuery: String
    let systemImage: String
    let keywords: [String]

    var id: String { storedValue }

    static let todoOptions: [LifeRouteDestinationIntent] = [
        .init(storedValue: "Any grocery store", naturalLanguageQuery: "grocery store", systemImage: "cart.fill", keywords: ["grocery", "groceries", "supermarket", "food store"]),
        .init(storedValue: "Any Walmart", naturalLanguageQuery: "Walmart", systemImage: "cart.fill", keywords: ["walmart", "wal mart"]),
        .init(storedValue: "Any BJ's", naturalLanguageQuery: "BJ's Wholesale Club", systemImage: "cart.fill", keywords: ["bjs", "bj's", "bj wholesale", "warehouse"]),
        .init(storedValue: "Any Target", naturalLanguageQuery: "Target", systemImage: "scope", keywords: ["target"]),
        .init(storedValue: "Any Costco", naturalLanguageQuery: "Costco", systemImage: "cart.fill", keywords: ["costco", "warehouse"]),
        .init(storedValue: "Any pharmacy", naturalLanguageQuery: "pharmacy", systemImage: "cross.case.fill", keywords: ["pharmacy", "drugstore", "medicine"]),
        .init(storedValue: "Any gas station", naturalLanguageQuery: "gas station", systemImage: "fuelpump.fill", keywords: ["gas", "fuel", "gas station"]),
        .init(storedValue: "Any coffee shop", naturalLanguageQuery: "coffee shop", systemImage: "cup.and.saucer.fill", keywords: ["coffee", "cafe", "coffee shop"]),
        .init(storedValue: "Any convenience store", naturalLanguageQuery: "convenience store", systemImage: "storefront.fill", keywords: ["convenience", "corner store"]),
        .init(storedValue: "Any hardware store", naturalLanguageQuery: "hardware store", systemImage: "wrench.and.screwdriver.fill", keywords: ["hardware", "home improvement"]),
        .init(storedValue: "Any bank", naturalLanguageQuery: "bank", systemImage: "building.columns.fill", keywords: ["bank", "atm"]),
        .init(storedValue: "Any post office", naturalLanguageQuery: "post office", systemImage: "envelope.fill", keywords: ["post", "mail", "usps", "post office"]),
    ]

    static func matches(_ input: String) -> [LifeRouteDestinationIntent] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 2 else { return [] }

        return todoOptions.filter { option in
            let searchable = ([option.storedValue, option.naturalLanguageQuery] + option.keywords)
                .joined(separator: " ")
                .lowercased()
            return searchable.contains(query)
        }.prefix(6).map { $0 }
    }

    static func naturalLanguageQuery(forStoredValue value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let intent = todoOptions.first(where: {
            $0.storedValue.compare(cleaned, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            return cleaned
        }
        return intent.naturalLanguageQuery
    }
}

'''
    text = replace_once(
        text,
        "final class LifeRouteAddressAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {",
        intent_model + "final class LifeRouteAddressAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {",
        "flexible destination intent model",
    )

    text = replace_once(
        text,
        '''    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let next = Array(completer.results.prefix(6)).map {
            LifeRouteAddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = next
            self?.message = nil
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = []
            self?.message = "Address suggestions are temporarily unavailable. You can still type the address manually."
        }
    }''',
        '''    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Ignore a stale delegate callback that arrives after a user has already selected/cleared a result.
        let requestedQuery = lastQuery
        guard !requestedQuery.isEmpty else { return }
        let next = Array(completer.results.prefix(6)).map {
            LifeRouteAddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastQuery == requestedQuery, !requestedQuery.isEmpty else { return }
            self.suggestions = next
            self.message = nil
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let requestedQuery = lastQuery
        guard !requestedQuery.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastQuery == requestedQuery, !requestedQuery.isEmpty else { return }
            self.suggestions = []
            self.message = "Address suggestions are temporarily unavailable. You can still type the address manually."
        }
    }''',
        "stale autocomplete callback guard",
    )

    text = replace_once(
        text,
        "        request.naturalLanguageQuery = cleaned\n",
        "        request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: cleaned)\n",
        "routing destination intent normalization",
    )

    ROUTING.write_text(text, encoding="utf-8")


def patch_address_field() -> None:
    text = ADDRESS_FIELD.read_text(encoding="utf-8")
    if "enum V054AddressFieldMode" in text:
        return

    text = replace_once(
        text,
        "struct V054AddressField: View {",
        '''enum V054AddressFieldMode {
    case standard
    case todoDestination
}

struct V054AddressField: View {''',
        "address field mode",
    )

    text = replace_once(
        text,
        "    let placeholder: String\n\n    @StateObject private var autocomplete = LifeRouteAddressAutocomplete()\n    @State private var suppressNextQuery = false\n\n    init(_ placeholder: String, text: Binding<String>) {\n        self.placeholder = placeholder\n        self._text = text\n    }\n",
        '''    let placeholder: String
    let mode: V054AddressFieldMode

    @StateObject private var autocomplete = LifeRouteAddressAutocomplete()
    @State private var suppressNextQuery = false
    @FocusState private var isFocused: Bool

    init(_ placeholder: String, text: Binding<String>, mode: V054AddressFieldMode = .standard) {
        self.placeholder = placeholder
        self._text = text
        self.mode = mode
    }

    private var flexibleIntents: [LifeRouteDestinationIntent] {
        guard mode == .todoDestination else { return [] }
        return LifeRouteDestinationIntent.matches(text)
    }
''',
        "address field mode and focus state",
    )

    text = replace_once(
        text,
        '''                TextField(placeholder, text: $text)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.done)
''',
        '''                TextField(placeholder, text: $text)
                    .textContentType(mode == .standard ? .fullStreetAddress : nil)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit {
                        autocomplete.clear()
                        isFocused = false
                    }
''',
        "address field focus binding",
    )

    old_suggestions = r'''            if !autocomplete.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(autocomplete.suggestions) { suggestion in
                        Button {
                            suppressNextQuery = true
                            text = suggestion.addressText
                            autocomplete.clear()
                            LifeRouteHaptics.selection()
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(palette.accent)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(palette.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(palette.textSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != autocomplete.suggestions.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(
                    palette.panelElevated.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                }
            }
'''
    new_suggestions = r'''            if isFocused && (!flexibleIntents.isEmpty || !autocomplete.suggestions.isEmpty) {
                VStack(spacing: 0) {
                    if !flexibleIntents.isEmpty {
                        Text("FLEXIBLE DESTINATIONS")
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11)
                            .padding(.top, 9)
                            .padding(.bottom, 5)

                        ForEach(flexibleIntents) { intent in
                            Button {
                                suppressNextQuery = true
                                text = intent.storedValue
                                autocomplete.clear()
                                isFocused = false
                                LifeRouteHaptics.selection()
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: intent.systemImage)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(intent.storedValue)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(palette.textPrimary)
                                        Text("Choose the best nearby match when routing")
                                            .font(.caption2)
                                            .foregroundStyle(palette.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !autocomplete.suggestions.isEmpty {
                        if !flexibleIntents.isEmpty {
                            Divider().overlay(Color.white.opacity(0.07))
                        }
                        Text(mode == .todoDestination ? "SPECIFIC PLACES" : "SUGGESTIONS")
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11)
                            .padding(.top, 9)
                            .padding(.bottom, 5)

                        ForEach(autocomplete.suggestions) { suggestion in
                            Button {
                                suppressNextQuery = true
                                text = suggestion.addressText
                                autocomplete.clear()
                                isFocused = false
                                LifeRouteHaptics.selection()
                            } label: {
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundStyle(palette.accent)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(palette.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(palette.textSecondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(
                    palette.panelElevated.opacity(0.94),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                }
            }
'''
    text = replace_once(text, old_suggestions, new_suggestions, "address suggestion presentation")

    text = replace_once(
        text,
        '''            if let message = autocomplete.message {
                Text(message)
''',
        '''            if mode == .todoDestination && isFocused {
                Text("Choose a specific place, or a flexible destination such as Any Walmart, Any BJ's, or Any grocery store.")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            if isFocused, let message = autocomplete.message {
                Text(message)
''',
        "todo destination guidance",
    )

    ADDRESS_FIELD.write_text(text, encoding="utf-8")


def patch_day_route_view() -> None:
    text = DAY_ROUTE_VIEW.read_text(encoding="utf-8")
    if "suppressStopAutocompleteQuery" in text:
        return

    text = replace_once(
        text,
        "    @State private var stopPosition: LifeRouteDayStop.Position = .before\n    @State private var message: String?\n",
        "    @State private var stopPosition: LifeRouteDayStop.Position = .before\n    @State private var message: String?\n    @State private var suppressStopAutocompleteQuery = false\n    @FocusState private var stopAddressFocused: Bool\n",
        "Day Route autocomplete state",
    )

    text = replace_once(
        text,
        '''            TextField("Stop address", text: $stopAddress)
                .textContentType(.fullStreetAddress)
                .onChange(of: stopAddress) { value in
                    stopAutocomplete.update(query: value)
                }
''',
        '''            TextField("Stop address", text: $stopAddress)
                .textContentType(.fullStreetAddress)
                .focused($stopAddressFocused)
                .onChange(of: stopAddress) { value in
                    if suppressStopAutocompleteQuery {
                        suppressStopAutocompleteQuery = false
                        return
                    }
                    stopAutocomplete.update(query: value)
                }
                .onSubmit {
                    stopAutocomplete.clear()
                    stopAddressFocused = false
                }
''',
        "Day Route autocomplete query suppression",
    )

    text = replace_once(
        text,
        '''                Button {
                    stopAddress = suggestion.addressText
                    stopAutocomplete.clear()
                } label: {''',
        '''                Button {
                    suppressStopAutocompleteQuery = true
                    stopAddress = suggestion.addressText
                    stopAutocomplete.clear()
                    stopAddressFocused = false
                    LifeRouteHaptics.selection()
                } label: {''',
        "Day Route selection dismissal",
    )

    text = replace_once(
        text,
        '''        stopTitle = ""
        stopAddress = ""
        stopAutocomplete.clear()
        message = "Stop added."
''',
        '''        stopTitle = ""
        suppressStopAutocompleteQuery = true
        stopAddress = ""
        stopAutocomplete.clear()
        stopAddressFocused = false
        message = "Stop added."
''',
        "Day Route add-stop dismissal",
    )

    DAY_ROUTE_VIEW.write_text(text, encoding="utf-8")


def patch_day_route_core() -> None:
    text = DAY_ROUTE_CORE.read_text(encoding="utf-8")
    if "LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: query)" in text:
        return

    text = replace_once(
        text,
        '            URLQueryItem(name: "destination", value: leg.toAddress),\n',
        '            URLQueryItem(name: "destination", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress)),\n',
        "Google Maps destination intent",
    )
    text = replace_once(
        text,
        '            items.append(URLQueryItem(name: "origin", value: leg.fromAddress))\n',
        '            items.append(URLQueryItem(name: "origin", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.fromAddress)))\n',
        "Google Maps origin intent",
    )
    text = replace_once(
        text,
        '            URLQueryItem(name: "q", value: leg.toAddress),\n',
        '            URLQueryItem(name: "q", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress)),\n',
        "Waze destination intent",
    )
    text = replace_once(
        text,
        '''        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
''',
        '''        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: query)
''',
        "Day Route MapKit destination intent",
    )

    DAY_ROUTE_CORE.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    if "mode: .todoDestination" in text:
        return

    text = replace_once(
        text,
        '            V054AddressField("Location / store (optional)", text: $todoAddress)\n',
        '            V054AddressField("Location / store (optional)", text: $todoAddress, mode: .todoDestination)\n',
        "To-Do flexible destination field",
    )
    SETUP.write_text(text, encoding="utf-8")


def main() -> None:
    patch_routing_domain()
    patch_address_field()
    patch_day_route_view()
    patch_day_route_core()
    patch_setup()
    print("LifeRoute v0.7.0 location intent fix applied: autocomplete selections dismiss reliably, stale MapKit callbacks are ignored, and To-Dos can store flexible Any-brand/category destinations that routing adapters normalize for Apple Maps, Google Maps, and Waze.")


if __name__ == "__main__":
    main()
