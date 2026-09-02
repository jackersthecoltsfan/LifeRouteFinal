import SwiftUI

enum ScenicRoyalThemeCategory: String, CaseIterable, Identifiable {
    case core = "Core"
    case dynamic = "Dynamic"
    case scenery = "Scenery"

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .core: return "Core Glass"
        case .dynamic: return "Dynamic Liquid Glass"
        case .scenery: return "Scenery"
        }
    }

    var sectionDescription: String {
        switch self {
        case .core:
            return "12 still app-wide glass environments with no continuous ambient motion."
        case .dynamic:
            return "8 full-frame Liquid Glass environments. Reduce Motion retains a finished still phase."
        case .scenery:
            return "12 cinematic Day/Night environments. Reduce Motion keeps the selected scene and freezes ambience."
        }
    }

    var sectionIcon: String {
        switch self {
        case .core: return "sparkles"
        case .dynamic: return "waveform.path"
        case .scenery: return "mountain.2.fill"
        }
    }
}

struct ScenicRoyalSelectedThemeHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let theme: LifeRouteTheme
    let category: ScenicRoyalThemeCategory

    var body: some View {
        ScenicRoyalCard(role: .card) {
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
            "Active theme, \(theme.name), \(category.rawValue), \(theme.scenicRoyalMotionCharacter)"
        )
        .accessibilityValue("Selected")
    }

    private var preview: some View {
        ScenicRoyalThemePreview(theme: theme)
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 96,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 112 : 78,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? 112 : 78
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
                .stroke(style.accent.opacity(0.62), lineWidth: ScenicRoyalDesignSystem.Stroke.selected)
            }
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("ACTIVE THEME")
                .font(.caption.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(style.accentReflection)

            Text(theme.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(style.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "\(category.rawValue) · \(theme.scenicRoyalMotionCharacter)",
                systemImage: theme.scenicRoyalMotionSystemImage
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(style.secondaryText)
        }
    }

    private var selectionMark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(style.accent)
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
                .foregroundStyle(selection == category ? ScenicRoyalDesignSystem.ColorToken.brandNavyDeep : style.primaryText)
                .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
                .background {
                    if selection == category {
                        RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                            .fill(style.accent)
                    }
                }
                .contentShape(
                    RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                )
                .scenicRoyalInteractiveSurface(
                    role: selection == category ? .selectedControl : .ambient
                )
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .accessibilityLabel("\(category.rawValue) themes")
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
        ScenicRoyalInsetRow(role: .readability) {
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
            .padding(ScenicRoyalDesignSystem.Spacing.compact)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.control,
                    style: .continuous
                )
            )
            .scenicRoyalSurface(
                role: .passiveRow,
                cornerRadius: ScenicRoyalDesignSystem.Radius.control
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.control,
                    style: .continuous
                )
                .stroke(
                    isSelected ? style.accent : Color.white.opacity(contrast == .increased ? 0.30 : 0.08),
                    lineWidth: isSelected ? ScenicRoyalDesignSystem.Stroke.selected : ScenicRoyalDesignSystem.Stroke.subtle
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(theme.name), \(category.rawValue) theme, \(theme.scenicRoyalMotionCharacter)"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Currently applied" : "Applies this theme immediately")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            ScenicRoyalThemePreview(theme: theme)
                .frame(height: 92)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl,
                        style: .continuous
                    )
                )

            Text(theme.scenicRoyalMotionCharacter.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(ScenicRoyalDesignSystem.Spacing.compact)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(theme.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(category.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? style.accent : style.secondaryText)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(style.accent)
                    .accessibilityHidden(true)
            }
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
        ZStack {
            theme.palette.backgroundGradient

            if let assetName = theme.sceneryThumbnailAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(theme.isNightScenery ? 0.12 : 0.02))
            } else if theme.isPhaseTwoDynamic {
                dynamicArtwork
            } else {
                coreArtwork
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var coreArtwork: some View {
        ZStack {
            Circle()
                .fill(theme.palette.accent.opacity(0.30))
                .frame(width: 120, height: 120)
                .blur(radius: 12)
                .offset(x: 34, y: -18)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            theme.palette.accentSecondary.opacity(0.18),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(-14))
                .scaleEffect(1.2)
        }
    }

    private var dynamicArtwork: some View {
        ZStack {
            Capsule()
                .fill(theme.palette.accent.opacity(0.40))
                .frame(width: 180, height: 34)
                .rotationEffect(.degrees(-18))
                .offset(x: -16, y: -18)
            Capsule()
                .fill(theme.palette.accentSecondary.opacity(0.34))
                .frame(width: 170, height: 28)
                .rotationEffect(.degrees(16))
                .offset(x: 22, y: 20)
            Circle()
                .stroke(Color.white.opacity(0.30), lineWidth: 2)
                .frame(width: 48, height: 48)
        }
    }
}

private extension LifeRouteTheme {
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
        isPhaseOneCoreGlass ? "Still" : "Live"
    }

    var scenicRoyalMotionSystemImage: String {
        isPhaseOneCoreGlass ? "photo" : "waveform.path"
    }

}
