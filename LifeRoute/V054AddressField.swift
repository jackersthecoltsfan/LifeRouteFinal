import SwiftUI

enum V054AddressFieldMode {
    case standard
    case todoDestination
}

struct V054AddressField: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    @Binding var text: String
    let placeholder: String
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

    var body: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            addressInput

            if isFocused && (!flexibleIntents.isEmpty || !autocomplete.suggestions.isEmpty) {
                suggestionList
            }

            if mode == .todoDestination && isFocused {
                Text("Choose a specific place, or a flexible destination such as Any Walmart, Any BJ's, or Any grocery store.")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isFocused, let message = autocomplete.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Address suggestion status: \(message)")
            }
        }
    }

    private var addressInput: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            Image(systemName: "mappin.circle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(style.accent)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textContentType(mode == .standard ? .fullStreetAddress : nil)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(dismissSuggestions)
                .accessibilityLabel(placeholder)
                .accessibilityHint(addressFieldHint)
        }
        .padding(ScenicRoyalDesignSystem.Spacing.standard)
        .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .scenicRoyalInteractiveSurface(
            role: .readability,
            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
        )
        .onChange(of: text, perform: updateSuggestions)
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            if !flexibleIntents.isEmpty {
                suggestionHeading("Flexible destinations")

                ForEach(flexibleIntents) { intent in
                    flexibleIntentButton(intent)
                }
            }

            if !autocomplete.suggestions.isEmpty {
                if !flexibleIntents.isEmpty {
                    Divider()
                        .overlay(style.secondaryText.opacity(0.24))
                        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
                }

                suggestionHeading(mode == .todoDestination ? "Specific places" : "Suggestions")

                ForEach(autocomplete.suggestions) { suggestion in
                    suggestionButton(suggestion)
                }
            }
        }
        .scenicRoyalSurface(
            role: .readability,
            cornerRadius: ScenicRoyalDesignSystem.Radius.control
        )
    }

    private func suggestionHeading(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(style.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.standard)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.hairline)
            .accessibilityAddTraits(.isHeader)
    }

    private func flexibleIntentButton(_ intent: LifeRouteDestinationIntent) -> some View {
        Button {
            selectFlexibleIntent(intent)
        } label: {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: intent.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(style.accent)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text(intent.storedValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choose the best nearby match when routing")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .padding(.vertical, ScenicRoyalDesignSystem.Spacing.compact)
            .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(intent.storedValue)
        .accessibilityValue("Flexible destination")
        .accessibilityHint("Uses the best nearby matching place when routing")
    }

    private func suggestionButton(_ suggestion: LifeRouteAddressSuggestion) -> some View {
        Button {
            selectSuggestion(suggestion)
        } label: {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(style.accent)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .padding(.vertical, ScenicRoyalDesignSystem.Spacing.compact)
            .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(suggestionAccessibilityLabel(suggestion))
        .accessibilityHint("Fills the address field and dismisses suggestions")
    }

    private var addressFieldHint: String {
        if mode == .todoDestination {
            return "Type a specific place or a flexible destination. Suggestions appear after you type. Submit to keep manual entry."
        }
        return "Type at least three characters for address suggestions. Submit to keep manual entry."
    }

    private func suggestionAccessibilityLabel(_ suggestion: LifeRouteAddressSuggestion) -> String {
        guard !suggestion.subtitle.isEmpty else { return suggestion.title }
        return "\(suggestion.title), \(suggestion.subtitle)"
    }

    private func updateSuggestions(_ value: String) {
        if suppressNextQuery {
            suppressNextQuery = false
            return
        }
        autocomplete.update(query: value)
    }

    private func dismissSuggestions() {
        autocomplete.clear()
        isFocused = false
    }

    private func selectFlexibleIntent(_ intent: LifeRouteDestinationIntent) {
        suppressNextQuery = true
        text = intent.storedValue
        autocomplete.clear()
        isFocused = false
        LifeRouteHaptics.selection()
    }

    private func selectSuggestion(_ suggestion: LifeRouteAddressSuggestion) {
        suppressNextQuery = true
        text = suggestion.addressText
        autocomplete.clear()
        isFocused = false
        LifeRouteHaptics.selection()
    }
}
