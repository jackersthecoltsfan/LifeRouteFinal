import SwiftUI

enum V054AddressFieldMode {
    case standard
    case todoDestination
}

struct V054AddressField: View {
    @Environment(\.lifeRoutePalette) private var palette
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(palette.accent)
                TextField(placeholder, text: $text)
                    .textContentType(mode == .standard ? .fullStreetAddress : nil)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit {
                        autocomplete.clear()
                        isFocused = false
                    }
            }
            .padding(12)
            .background(
                palette.panelElevated.opacity(0.32),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .onChange(of: text) { value in
                if suppressNextQuery {
                    suppressNextQuery = false
                    return
                }
                autocomplete.update(query: value)
            }

            if isFocused && (!flexibleIntents.isEmpty || !autocomplete.suggestions.isEmpty) {
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

            if mode == .todoDestination && isFocused {
                Text("Choose a specific place, or a flexible destination such as Any Walmart, Any BJ's, or Any grocery store.")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            if isFocused, let message = autocomplete.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
