import SwiftUI

struct ScenicRoyalResourceHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let builtInCount: Int
    let customCount: Int

    var body: some View {
        ScenicRoyalCard(role: .card) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        countBlock
                    }
                } else {
                    HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                        countBlock
                    }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("Resources")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(style.primaryText)

            Text("Clinical, work, training, and company portals.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(style.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var countBlock: some View {
        VStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
            spacing: ScenicRoyalDesignSystem.Spacing.hairline
        ) {
            Text("\(builtInCount)")
                .font(.title2.weight(.bold))
                .foregroundStyle(style.accent)

            Text("built-in portal\(builtInCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.secondaryText)

            if customCount > 0 {
                Label("\(customCount) custom", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.accentReflection)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(builtInCount) built-in portal\(builtInCount == 1 ? "" : "s"), "
                + "\(customCount) custom portal\(customCount == 1 ? "" : "s")"
        )
    }
}

struct ScenicRoyalResourceCategorySection: View {
    let category: LifeRoutePortalCategory
    let portals: [LifeRoutePortalLink]
    let onOpen: (LifeRoutePortalLink) -> Void
    let onDelete: (LifeRoutePortalLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            ScenicRoyalInsetRow(role: .readability) {
                ScenicRoyalSectionHeader(
                    category.rawValue,
                    subtitle: "\(portals.count) portal\(portals.count == 1 ? "" : "s")",
                    systemImage: category.systemImage
                )
            }

            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach(portals) { portal in
                    ScenicRoyalResourceRow(
                        portal: portal,
                        onOpen: { onOpen(portal) },
                        onDelete: { onDelete(portal) }
                    )
                }
            }
        }
    }
}

struct ScenicRoyalResourceRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let portal: LifeRoutePortalLink
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScenicRoyalInsetRow(role: .readability) {
            Group {
                if dynamicTypeSize.isAccessibilitySize, portal.isCustom {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        launchButton
                        deleteButton(expanded: true)
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        launchButton
                        if portal.isCustom {
                            deleteButton(expanded: false)
                        }
                    }
                }
            }
        }
    }

    private var launchButton: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: portal.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.accent)
                    .frame(
                        width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                        height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                    )
                    .scenicRoyalSurface(
                        role: .ambient,
                        cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text(portal.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(style.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(portal.subtitle)
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if portal.isCustom {
                        Label("Custom portal", systemImage: "person.crop.circle.badge.plus")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(style.accentReflection)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.secondaryText)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(portal.title). \(portal.subtitle)")
        .accessibilityValue(portal.isCustom ? "Custom portal" : "Built-in portal")
        .accessibilityHint("Opens external website in your browser")
    }

    private func deleteButton(expanded: Bool) -> some View {
        Button(role: .destructive, action: onDelete) {
            Group {
                if expanded {
                    Label("Remove custom portal", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "trash")
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.red)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel("Remove \(portal.title)")
        .accessibilityHint("Deletes this custom portal from LifeRoute")
    }
}

struct ScenicRoyalCustomPortalForm: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    @Binding var title: String
    @Binding var urlString: String
    @Binding var category: LifeRoutePortalCategory

    let message: String?
    let onSave: () -> Void

    var body: some View {
        ScenicRoyalCard(role: .readability) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ScenicRoyalSectionHeader(
                    "Add company portal",
                    subtitle: "Saved locally on this device.",
                    systemImage: "plus.app"
                )

                TextField("Portal name", text: $title)
                    .textContentType(.organizationName)
                    .scenicRoyalField()

                TextField("Website address", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .scenicRoyalField()

                Picker("Category", selection: $category) {
                    ForEach(LifeRoutePortalCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(style.accent)
                .scenicRoyalField()

                Button("Save portal", action: onSave)
                    .buttonStyle(ScenicRoyalPrimaryButtonStyle())

                if let message {
                    Text(message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Portal status: \(message)")
                }
            }
        }
    }
}

struct ScenicRoyalResourcePrivacyNote: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    var body: some View {
        Label(
            "LifeRoute launches third-party portals only. Credentials, sign-in, and data entered there remain with the destination service.",
            systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(style.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
