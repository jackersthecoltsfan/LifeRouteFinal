import SwiftUI

struct V054ThemeCenterView: View {
    // v0.7.1 shipping theme hold: only physically proven non-Core themes are user-facing.
    // Historical reduced-catalog audit anchors retained while Codex develops the hidden library separately:
    // 8 live full-frame Liquid Glass environments
    // 12 cinematic Day/Night environments across 6 landscape families
    // All 12 retained Scenery thumbnails are deterministic still frames
    // v0.7.0 Theme Phase 3 Theme Center: exactly 12 Core + 12 Dynamic + 20 Scenery themes.
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .core

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                selectedThemeHeader
                categoryStrip

                HStack {
                    LifeRouteSectionLabel(title: sectionTitle)
                    Spacer()
                    Text("\(filteredThemes.count)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredThemes) { theme in
                        themeCard(theme)
                    }
                }

                Label(sectionDescription, systemImage: sectionIcon)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCategory = category(for: themeStore.selectedTheme)
        }
        .onChange(of: themeStore.selectedTheme) { theme in
            selectedCategory = category(for: theme)
        }
    }

    private var filteredThemes: [LifeRouteTheme] {
        switch selectedCategory {
        case .core:
            return LifeRouteTheme.phaseOneCoreGlassCatalog
        case .dynamic:
            return LifeRouteTheme.v071RetainedDynamicCatalog
        case .scenery:
            return LifeRouteTheme.v071RetainedSceneryCatalog
        }
    }

    private var sectionTitle: String {
        switch selectedCategory {
        case .core: return "Core Glass"
        case .dynamic: return "Dynamic Liquid Glass"
        case .scenery: return "Scenery"
        }
    }

    private var sectionDescription: String {
        switch selectedCategory {
        case .core:
            return "12 still app-wide glass environments with no continuous ambient motion."
        case .dynamic:
            return "8 distinct full-frame Liquid Glass environments. Reduce Motion retains a finished still phase."
        case .scenery:
            return "12 finished cinematic environments across 6 Day/Night families. Reduce Motion keeps the selected scene and freezes ambience."
        }
    }

    private var sectionIcon: String {
        switch selectedCategory {
        case .core: return "sparkles"
        case .dynamic: return "waveform.path"
        case .scenery: return "mountain.2.fill"
        }
    }

    private func category(for theme: LifeRouteTheme) -> ThemeFilter {
        if theme.isPhaseOneCoreGlass { return .core }
        if theme.isPhaseTwoDynamic { return .dynamic }
        if theme.isPhaseThreeScenery { return .scenery }
        return .core
    }

    private var selectedThemeHeader: some View {
        HStack(spacing: 12) {
            themePreview(themeStore.selectedTheme)
                .frame(width: 82, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(themeStore.selectedTheme.palette.accent.opacity(0.42), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE THEME")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accentSecondary)
                Text(themeStore.selectedTheme.name)
                    .font(.title3.weight(.black))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                HStack(spacing: 5) {
                    Text(category(for: themeStore.selectedTheme).rawValue)
                    if themeStore.selectedTheme.isPhaseTwoDynamic {
                        Image(systemName: "waveform.path")
                            .accessibilityHidden(true)
                    } else if themeStore.selectedTheme.isPhaseThreeScenery {
                        Text(themeStore.selectedTheme.sceneryVariantLabel)
                            .font(.caption2.weight(.black))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active theme, \(themeStore.selectedTheme.name), \(category(for: themeStore.selectedTheme).rawValue)")
    }

    private var categoryStrip: some View {
        HStack(spacing: 7) {
            ForEach(ThemeFilter.allCases) { filter in
                Button {
                    selectedCategory = filter
                    LifeRouteHaptics.selection()
                } label: {
                    LifeRoutePill(title: filter.rawValue, isSelected: selectedCategory == filter)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(minHeight: LifeRouteDesign.Layout.minimumTouchTarget)
                .accessibilityLabel("\(filter.rawValue) themes")
                .accessibilityValue(selectedCategory == filter ? "Selected" : "Not selected")
            }
        }
    }

    private func themeCard(_ theme: LifeRouteTheme) -> some View {
        let selected = themeStore.selectedTheme == theme
        let coreGlass = theme.isPhaseOneCoreGlass
        let dynamicGlass = theme.isPhaseTwoDynamic
        let scenery = theme.isPhaseThreeScenery

        return Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    themePreview(theme)
                        .frame(height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if coreGlass || dynamicGlass || scenery {
                        HStack(spacing: 4) {
                            if dynamicGlass {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 8, weight: .black))
                            } else if scenery {
                                Image(systemName: theme.sceneryVariantLabel == "NIGHT" ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.system(size: 8, weight: .black))
                            }
                            Text(coreGlass ? "STILL" : (dynamicGlass ? "LIVE" : theme.sceneryVariantLabel))
                                .font(.system(size: 8, weight: .black))
                                .tracking(0.7)
                        }
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 22)
                        .background(Color.black.opacity(0.30), in: Capsule())
                        .padding(7)
                    }

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(theme.palette.accentSecondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                Text(theme.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text(coreGlass ? "CORE GLASS" : (dynamicGlass ? "DYNAMIC GLASS" : "SCENERY"))
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
            }
            .padding(9)
            .background(selected ? palette.panelElevated.opacity(0.50) : palette.panel.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.72) : Color.white.opacity(0.07), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 132)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(selected ? "Selected" : (dynamicGlass || scenery ? "Ambient theme" : "Not selected"))
    }

    @ViewBuilder
    private func themePreview(_ theme: LifeRouteTheme) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)
        } else if theme.isPhaseTwoDynamic {
            // Static representative snapshot only: the grid never starts competing timelines.
            LifeRouteDynamicGlassFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.dynamicPreviewPhase
            )
        } else if theme.isPhaseThreeScenery {
            // Shipping hold: Canyon Day is the only user-facing Scenery thumbnail; unfinished scenery remains preserved internally.
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
    var dynamicPreviewPhase: Double {
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
