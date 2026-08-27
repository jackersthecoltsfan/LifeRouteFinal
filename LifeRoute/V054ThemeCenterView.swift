import SwiftUI

struct V054ThemeCenterView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .all

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case core = "Core"
        case scenery = "Scenery"
        case metallic = "Metallic"
        case dynamic = "Dynamic"
        case fluid = "Fluid"

        var id: String { rawValue }

        func matches(_ theme: LifeRouteTheme) -> Bool {
            switch self {
            case .all:
                return true
            case .core:
                return [.royal, .obsidian, .carbon, .midnight, .navyNoir].contains(theme)
            case .scenery:
                return [.forest, .plum, .ember].contains(theme)
            case .metallic:
                return [.titanium, .slate, .moltenGold, .phantomSilver].contains(theme)
            case .dynamic:
                return [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse].contains(theme)
            case .fluid:
                return [.ocean, .aurora, .sapphireTide].contains(theme)
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 17) {
                selectedThemeHero
                categoryStrip

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredThemes) { theme in
                        themeCard(theme)
                    }
                }

                Text("Core stays premium and dark. Scenery is environment-led. Metallic themes use material depth, Dynamic themes use energy treatments, and Fluid themes emphasize water, aurora, and flowing light. Every category now has at least three distinct choices.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredThemes: [LifeRouteTheme] {
        LifeRouteTheme.allCases.filter(selectedCategory.matches)
    }

    private var selectedThemeHero: some View {
        ZStack(alignment: .bottomLeading) {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.selectedTheme.palette
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("CURRENT THEME")
                        .font(.caption2.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.70))
                    Spacer()
                    Label("ACTIVE", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(themeStore.selectedTheme.palette.accentSecondary)
                }

                Spacer(minLength: 100)

                Text(themeStore.selectedTheme.name)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(themeStore.selectedTheme.cinematicTreatmentLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(18)
        }
        .frame(height: 245)
        .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(themeStore.selectedTheme.palette.accent.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: themeStore.selectedTheme.palette.accent.opacity(0.18), radius: 24, y: 12)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ThemeFilter.allCases) { filter in
                    Button {
                        selectedCategory = filter
                        LifeRouteHaptics.selection()
                    } label: {
                        HStack(spacing: 5) {
                            Text(filter.rawValue)
                            if filter != .all {
                                Text("\(LifeRouteTheme.allCases.filter(filter.matches).count)")
                                    .font(.caption2.weight(.black))
                                    .opacity(0.72)
                            }
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedCategory == filter ? Color.black.opacity(0.82) : palette.textPrimary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            selectedCategory == filter ? palette.accent : palette.panelElevated.opacity(0.72),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(palette.accent.opacity(selectedCategory == filter ? 0 : 0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func themeCard(_ theme: LifeRouteTheme) -> some View {
        Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            ZStack(alignment: .topTrailing) {
                LifeRouteCinematicThemeThumbnail(theme: theme)
                    .frame(height: 165)

                if themeStore.selectedTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(theme.palette.accentSecondary)
                        .padding(10)
                        .shadow(color: .black.opacity(0.55), radius: 5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        themeStore.selectedTheme == theme ? theme.palette.accentSecondary : Color.white.opacity(0.08),
                        lineWidth: themeStore.selectedTheme == theme ? 2 : 1
                    )
            }
            .shadow(color: theme.palette.accent.opacity(0.10), radius: 12, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(themeStore.selectedTheme == theme ? "Selected" : "Not selected")
    }
}
