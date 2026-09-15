import SwiftUI

struct ScenicRoyalCard<Content: View>: View {
    let role: ScenicRoyalSurfaceRole
    let cornerRadius: CGFloat
    let content: Content

    init(
        role: ScenicRoyalSurfaceRole = .majorGroup,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .ui01OpenSection()
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
                UI01MarbleText(title: title, size: 23, relativeTo: .title3)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(style.contentSecondaryForeground)
                }
            }

            Spacer(minLength: 0)
        }
        .ui01ScenicText()
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
            .ui01ScenicText()
            .accessibilityHidden(true)
    }
}

struct ScenicRoyalScreenHeader<Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    let subtitle: String
    let compact: Bool
    private let actions: Actions

    init(
        title: String,
        subtitle: String,
        compact: Bool = false,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.compact = compact
        self.actions = actions()
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            titles
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            actions
        }
        .ui01ScenicText()
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                UI01MarbleText(title: "LifeRoute", size: 25, relativeTo: .title2, branded: true)
            }
            UI01MarbleText(title: title, size: compact ? 26 : 38, relativeTo: compact ? .title2 : .largeTitle)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty { Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(UI01Material.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                .foregroundStyle(UI01Material.silver)
                .frame(
                    width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                    height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                )
                .contentShape(Circle())
                .modifier(UI01CompactControlSurface())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Shared segmented-choice geometry for selections that need Scenic Royal's
/// semantic selected material instead of a flat platform tint.
struct ScenicRoyalSegmentedControl<Option: Identifiable & Hashable, Label: View>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> Label

    init(
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder label: @escaping (Option) -> Label
    ) {
        _selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    label(option)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(selection == option ? UI01Material.navy : UI01Material.silver)
                        .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                        .modifier(UI01SelectionSurface(selected: selection == option))
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}

struct ScenicRoyalInsetRow<Content: View>: View {
    let role: ScenicRoyalSurfaceRole
    private let content: Content

    init(
        role: ScenicRoyalSurfaceRole = .passiveRow,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { UI01Hairline().opacity(0.45) }
            .ui01ScenicText()
    }
}

/// A single hairline between transparent rows owned by one major group.
/// This preserves scanability without turning each row into another surface.
struct ScenicRoyalPassiveRowSeparator: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    var body: some View {
        Rectangle()
            .fill(style.accent.opacity(ScenicRoyalDesignSystem.Opacity.passiveRowSeparator))
            .frame(height: ScenicRoyalDesignSystem.Stroke.subtle)
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .accessibilityHidden(true)
    }
}

struct ScenicRoyalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        UI01GoldButtonStyle().makeBody(configuration: configuration)
    }
}

struct ScenicRoyalSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        UI01SecondaryButtonStyle().makeBody(configuration: configuration)
    }
}

extension View {
    func scenicRoyalCard(
        role: ScenicRoyalSurfaceRole = .majorGroup,
        cornerRadius: CGFloat = ScenicRoyalDesignSystem.Radius.card,
        padding: CGFloat = ScenicRoyalDesignSystem.Spacing.comfortable
    ) -> some View {
        self
            .padding(.vertical, padding)
            .ui01ScenicText()
    }

    func scenicRoyalField() -> some View {
        self
            .padding(12)
            .frame(minHeight: 44)
            .background(UI01Material.navy, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) { UI01Hairline().padding(.horizontal, 8) }
    }
}
