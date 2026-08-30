import SwiftUI

struct ScenicRoyalToolTile: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            HStack(alignment: .top) {
                ScenicRoyalIconBadge(systemImage: systemImage)
                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.accentReflection)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(ScenicRoyalDesignSystem.Spacing.comfortable)
        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.card, style: .continuous))
        .scenicRoyalInteractiveSurface(
            role: .card,
            cornerRadius: ScenicRoyalDesignSystem.Radius.card
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens \(title)")
    }
}
