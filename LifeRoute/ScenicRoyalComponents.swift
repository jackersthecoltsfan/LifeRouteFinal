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

struct ScenicRoyalScreenHeader<Actions: View>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    let subtitle: String
    private let actions: Actions

    init(
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(style.primaryText)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(style.secondaryText)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)

            ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    actions
                }
            }
        }
    }
}

struct ScenicRoyalCompactIconButton: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(style.accent)
                .frame(
                    width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                    height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                )
                .contentShape(Circle())
                .scenicRoyalInteractiveSurface(
                    role: .selectedControl,
                    cornerRadius: ScenicRoyalDesignSystem.Layout.minimumTouchTarget / 2
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ScenicRoyalInsetRow<Content: View>: View {
    let role: ScenicRoyalSurfaceRole
    private let content: Content

    init(
        role: ScenicRoyalSurfaceRole = .ambient,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.content = content()
    }

    var body: some View {
        content
            .padding(ScenicRoyalDesignSystem.Spacing.standard)
            .scenicRoyalSurface(
                role: role,
                cornerRadius: ScenicRoyalDesignSystem.Radius.control
            )
    }
}

struct ScenicRoyalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(ScenicRoyalDesignSystem.ColorToken.brandNavyDeep)
            .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .background(
                LinearGradient(
                    colors: [style.accent, ScenicRoyalDesignSystem.ColorToken.brandGoldBright],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: ScenicRoyalDesignSystem.Stroke.subtle)
            }
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : ScenicRoyalDesignSystem.Motion.selection,
                value: configuration.isPressed
            )
    }
}

struct ScenicRoyalSecondaryButtonStyle: ButtonStyle {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(style.primaryText)
            .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous))
            .scenicRoyalInteractiveSurface(role: .selectedControl)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : ScenicRoyalDesignSystem.Motion.selection,
                value: configuration.isPressed
            )
    }
}

extension View {
    func scenicRoyalCard(
        role: ScenicRoyalSurfaceRole = .card,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.card,
        padding: CGFloat = ScenicRoyalDesignSystem.Spacing.comfortable
    ) -> some View {
        self
            .padding(padding)
            .scenicRoyalSurface(role: role, cornerRadius: cornerRadius)
    }

    func scenicRoyalField() -> some View {
        self
            .padding(ScenicRoyalDesignSystem.Spacing.standard)
            .scenicRoyalInteractiveSurface(
                role: .ambient,
                cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
            )
    }
}
