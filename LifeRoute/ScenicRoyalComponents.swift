import SwiftUI

struct ScenicRoyalCard<Content: View>: View {
    let role: ScenicRoyalSurfaceRole
    let cornerRadius: CGFloat
    let content: Content

    init(
        role: ScenicRoyalSurfaceRole = .card,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(ScenicRoyalDesignSystem.Spacing.comfortable)
            .scenicRoyalSurface(role: role, cornerRadius: cornerRadius)
    }
}

struct ScenicRoyalSectionHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    let subtitle: String?
    let systemImage: String?

    init(_ title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScenicRoyalIconBadge: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(style.accent)
            .frame(width: 48, height: 48)
            .scenicRoyalSurface(
                role: .ambient,
                cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
            )
            .accessibilityHidden(true)
    }
}
