import SwiftUI

struct ScenicRoyalResourceHeader: View {
    var body: some View {
        ScenicRoyalCard(role: .majorGroup) {
            titleBlock
        }
    }

    private struct ResourceTitle: View {
        @ScaledMetric(relativeTo: .largeTitle) private var pointSize: CGFloat = 32

        var body: some View {
            Text("Resources")
                .font(.system(size: pointSize, weight: .semibold))
                .foregroundStyle(UI01Material.silver)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResourceTitle()
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScenicRoyalResourceCategorySection: View {
    let category: LifeRoutePortalCategory
    let portals: [LifeRoutePortalLink]
    let onOpen: (LifeRoutePortalLink) -> Void
    let onDelete: (LifeRoutePortalLink) -> Void

    var body: some View {
        ScenicRoyalCard(role: .majorGroup) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ScenicRoyalSectionHeader(
                    category.rawValue,
                    subtitle: "\(portals.count) portal\(portals.count == 1 ? "" : "s")",
                    systemImage: category.systemImage
                )

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
}

struct ScenicRoyalResourceRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let portal: LifeRoutePortalLink
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScenicRoyalInsetRow(role: .passiveRow) {
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
                    .ui01ScenicText()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text(portal.title)
                        .font(.headline)
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
        Group {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ScenicRoyalSectionHeader(
                    "Add company portal",
                    subtitle: "Saved locally on this device.",
                    systemImage: "plus.app"
                )

                TextField("Portal name", text: $title, prompt: Text("Portal name").foregroundColor(UI01Material.secondary))
                    .textContentType(.organizationName)
                    .scenicRoyalField()

                TextField("Website address", text: $urlString, prompt: Text("Website address").foregroundColor(UI01Material.secondary))
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
                .tint(style.selectedControlFill)
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
        .ui01ReadingPlane()
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
