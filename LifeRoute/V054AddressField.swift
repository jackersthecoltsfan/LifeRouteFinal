import SwiftUI

struct V054AddressField: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Binding var text: String
    let placeholder: String

    @StateObject private var autocomplete = LifeRouteAddressAutocomplete()
    @State private var suppressNextQuery = false

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(palette.accent)
                TextField(placeholder, text: $text)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.done)
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

            if !autocomplete.suggestions.isEmpty {
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

            if let message = autocomplete.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
