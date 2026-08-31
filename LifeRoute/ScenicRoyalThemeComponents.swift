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
            .scenicRoyalInteractiveSurface(
                role: isSelected ? .selectedControl : .card,
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

            if isSelected {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
                    .frame(minHeight: 28)
                    .background(Color.black.opacity(0.58), in: Capsule())
                    .padding(ScenicRoyalDesignSystem.Spacing.compact)
            }

            Text(theme.scenicRoyalMotionCharacter.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
                .frame(minHeight: 24)
                .background(Color.black.opacity(0.52), in: Capsule())
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

    @ViewBuilder
    var body: some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)
        } else if theme.isPhaseTwoDynamic {
            LifeRouteDynamicGlassFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.scenicRoyalStaticDynamicPhase
            )
        } else if theme.isPhaseThreeScenery {
            LifeRouteSceneryFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.sceneryPreviewPhase
            )
        } else {
            ZStack {
                theme.palette.backgroundGradient
                LifeRouteThemeArtwork(theme: theme, palette: theme.palette, compact: true)
            }
        }
    }
}

private extension LifeRouteTheme {
    var scenicRoyalMotionCharacter: String {
        isPhaseOneCoreGlass ? "Still" : "Live"
    }

    var scenicRoyalMotionSystemImage: String {
        isPhaseOneCoreGlass ? "photo" : "waveform.path"
    }

    var scenicRoyalStaticDynamicPhase: Double {
        switch self {
        case .royalCurrent: return 0.7
        case .midnightPrism: return 1.4
        case .auroraBloom: return 2.1
        case .solarPulse: return 0.2
        case .emeraldFlow: return 1.8
        case .arcticHalo: return 2.7
        case .oceanGlass: return 1.1
        case .roseEmber: return 2.4
        case .obsidianSpectra: return 0.9
        case .plasmaOrchid: return 1.6
        case .verdantMist: return 2.9
        case .titaniumGlow: return 0.4
        default: return 0.8
        }
    }
}
