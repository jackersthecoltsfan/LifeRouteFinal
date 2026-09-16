import SwiftUI

enum ScenicRoyalThemeCategory: String, CaseIterable, Identifiable {
    case core = "CORE"
    case living = "LIVING THEMES"

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .core: return "CORE"
        case .living: return "LIVING THEMES"
        }
    }

    var sectionDescription: String {
        switch self {
        case .core:
            return "Still app-wide glass environments with no continuous ambient motion."
        case .living:
            return "Day/Night environments with flowing water, evolving weather, and a fixed camera."
        }
    }

    var sectionIcon: String {
        switch self {
        case .core: return "sparkles"
        case .living: return "waveform.path"
        }
    }
}

struct ScenicRoyalSelectedThemeHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let theme: LifeRouteTheme
    let category: ScenicRoyalThemeCategory

    var body: some View {
        ScenicRoyalCard(role: .majorGroup) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        preview
                        details
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        preview
                        details
                        Spacer(minLength: 0)
                        selectionMark
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Active theme, \(theme.name), \(theme.scenicRoyalMotionCharacter)"
        )
        .accessibilityValue("Selected")
    }

    private var preview: some View {
        ScenicRoyalThemePreview(theme: theme)
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 132,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 140 : 110,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? 140 : 110
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl,
                    style: .continuous
                )
                .stroke(style.selectedControlIndicator.opacity(0.62), lineWidth: ScenicRoyalDesignSystem.Stroke.selected)
            }
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("ACTIVE THEME")
                .font(.caption.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(style.accentReflection)

            UI01MarbleText(title: theme.name, size: 28, relativeTo: .title2)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                theme.scenicRoyalMotionCharacter,
                systemImage: theme.scenicRoyalMotionSystemImage
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(style.secondaryText)
        }
    }

    private var selectionMark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(style.selectedControlIndicator)
            .accessibilityHidden(true)
    }
}

struct ScenicRoyalThemeCategoryPicker: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selection: ScenicRoyalThemeCategory
    let onSelection: () -> Void

    var body: some View {
        ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        categoryButtons
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        categoryButtons
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categoryButtons: some View {
        ForEach(ScenicRoyalThemeCategory.allCases) { category in
            Button {
                selection = category
                onSelection()
            } label: {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    if selection == category {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                    Text(category.rawValue)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
                .modifier(UI01SelectionSurface(selected: selection == category))
                .contentShape(
                    RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                )

            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .accessibilityLabel(category == .living ? "Living Themes" : "Core themes")
            .accessibilityValue(selection == category ? "Selected" : "Not selected")
            .accessibilityAddTraits(selection == category ? .isSelected : [])
        }
    }
}

struct ScenicRoyalThemeSectionHeading: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let category: ScenicRoyalThemeCategory
    let count: Int

    var body: some View {
        ScenicRoyalInsetRow(role: .majorGroup) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                        heading
                        countLabel
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        heading
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                        countLabel
                    }
                }
            }
        }
    }

    private var heading: some View {
        ScenicRoyalSectionHeader(
            category.sectionTitle,
            subtitle: category.sectionDescription,
            systemImage: category.sectionIcon
        )
    }

    private var countLabel: some View {
        Text("\(count) theme\(count == 1 ? "" : "s")")
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.accentReflection)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ScenicRoyalThemeCard: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.colorSchemeContrast) private var contrast

    let theme: LifeRouteTheme
    let category: ScenicRoyalThemeCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                preview
                titleBlock
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.control,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.control,
                    style: .continuous
                )
                .stroke(
                    isSelected ? UI01Material.gold : UI01Material.secondary.opacity(contrast == .increased ? 0.6 : 0.28),
                    lineWidth: isSelected ? 1.5 : ScenicRoyalDesignSystem.Stroke.subtle
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(theme.name), \(theme.scenicRoyalMotionCharacter)"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Currently applied" : "Applies this theme immediately")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        ScenicRoyalThemePreview(theme: theme)
                .frame(height: 92)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl,
                        style: .continuous
                    )
                )

        .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                UI01MarbleText(title: theme.name, size: 23, relativeTo: .title3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(theme.scenicRoyalMotionCharacter)
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UI01Material.goldLight)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

        }
    }
}

struct ScenicRoyalThemePreview: View {
    let theme: LifeRouteTheme

    var body: some View {
        ScenicRoyalStaticThemeThumbnail(theme: theme)
    }
}

/// Lightweight catalog artwork. This view is deliberately static: Theme
/// Center must not instantiate the live environment or any renderer tree for
/// each cell in its LazyVGrid.
private struct ScenicRoyalStaticThemeThumbnail: View {
    let theme: LifeRouteTheme

    var body: some View {
        Image(decorative: theme.thumbnailAssetName)
            .resizable()
            .scaledToFill()
            .overlay {
                if theme.isPhaseThreeScenery {
                    Color.black.opacity(theme.isNightScenery ? 0.12 : 0.02)
                }
            }
        .clipped()
        .accessibilityHidden(true)
    }
}

private extension LifeRouteTheme {
    /// Every user-facing catalog identity resolves to one committed still.
    /// Core and Dynamic files are fixed-phase captures from their production
    /// environment paths; Scenery reuses the canonical Day/Night artwork.
    var thumbnailAssetName: String {
        switch self {
        case .royal: return "ThemePreviewCoreRoyal"
        case .obsidian: return "ThemePreviewCoreObsidian"
        case .midnight: return "ThemePreviewCoreMidnight"
        case .titanium: return "ThemePreviewCoreTitanium"
        case .coreOcean: return "ThemePreviewCoreOcean"
        case .coreAurora: return "ThemePreviewCoreAurora"
        case .coreSolarFlare: return "ThemePreviewCoreSolarFlare"
        case .coreUltraviolet: return "ThemePreviewCoreUltraviolet"
        case .emerald: return "ThemePreviewCoreEmerald"
        case .roseQuartz: return "ThemePreviewCoreRoseQuartz"
        case .arctic: return "ThemePreviewCoreArctic"
        case .coreEmber: return "ThemePreviewCoreEmber"
        case .royalCurrent: return "ThemePreviewDynamicRoyalCurrent"
        case .midnightPrism: return "ThemePreviewDynamicMidnightPrism"
        case .auroraBloom: return "ThemePreviewDynamicAuroraBloom"
        case .solarPulse: return "ThemePreviewDynamicSolarPulse"
        case .emeraldFlow: return "ThemePreviewDynamicEmeraldFlow"
        case .oceanGlass: return "ThemePreviewDynamicOceanGlass"
        case .obsidianSpectra: return "ThemePreviewDynamicObsidianSpectra"
        case .plasmaOrchid: return "ThemePreviewDynamicPlasmaOrchid"
        default: return sceneryThumbnailAssetName ?? "ThemePreviewCoreRoyal"
        }
    }

    var sceneryThumbnailAssetName: String? {
        switch self {
        case .sceneryMountainsDay: return "SceneryMountainsDay"
        case .sceneryMountainsNight: return "SceneryMountainsNight"
        case .sceneryOceanDay: return "SceneryOceanDay"
        case .sceneryOceanNight: return "SceneryOceanNight"
        case .sceneryDesertDay: return "SceneryDesertDay"
        case .sceneryDesertNight: return "SceneryDesertNight"
        case .sceneryRainforestDay: return "SceneryRainforestDay"
        case .sceneryRainforestNight: return "SceneryRainforestNight"
        case .sceneryCanyonDay: return "SceneryCanyonDay"
        case .sceneryCanyonNight: return "SceneryCanyonNight"
        case .sceneryArcticDay: return "SceneryArcticDay"
        case .sceneryArcticNight: return "SceneryArcticNight"
        default: return nil
        }
    }

    var isNightScenery: Bool {
        guard isPhaseThreeScenery else { return false }
        return rawValue.hasSuffix(".night")
    }

    var scenicRoyalMotionCharacter: String {
        isPhaseOneCoreGlass ? "Still" : (LivingThemeRegistration.registration(for: rawValue)?.motionStatus == .implemented ? "Living motion" : "Motion pending")
    }

    var scenicRoyalMotionSystemImage: String {
        isPhaseOneCoreGlass ? "photo" : "waveform.path"
    }

}
