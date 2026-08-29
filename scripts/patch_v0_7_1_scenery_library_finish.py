from pathlib import Path


APP_PATH = Path("LifeRoute/LifeRouteApp.swift")
THEME_CENTER_PATH = Path("LifeRoute/V054ThemeCenterView.swift")
MARKER = "v0.7.1 retained Scenery library: eleven optimized scenes join Canyon Day"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 Scenery finish patch failed: expected one {label}, found {count}")
    return text.replace(old, new, 1)


def replace_one_of(text: str, candidates: list[str], new: str, label: str) -> str:
    matches = [candidate for candidate in candidates if candidate in text]
    if len(matches) != 1:
        raise SystemExit(
            f"v0.7.1 Scenery finish patch failed: expected one compatible {label}, found {len(matches)}"
        )
    return text.replace(matches[0], new, 1)


app = APP_PATH.read_text()
themes = THEME_CENTER_PATH.read_text()

if MARKER in app:
    print("LifeRoute v0.7.1 retained Scenery library is already materialized.")
    raise SystemExit(0)

for prerequisite in [
    "v0.7.1 Canyon Day exemplar",
    "v0.7.1 retained Dynamic library",
    "struct LifeRouteLiveThemeEnvironment: View",
]:
    if prerequisite not in app:
        raise SystemExit(f"v0.7.1 Scenery finish patch failed: missing prerequisite {prerequisite}")


SCENERY_CATALOG = r'''// v0.7.1 retained Scenery library: eleven optimized scenes join Canyon Day.
extension LifeRouteTheme {
    static let v071RetainedSceneryCatalog: [LifeRouteTheme] = [
        .sceneryMountainsDay,
        .sceneryMountainsNight,
        .sceneryOceanDay,
        .sceneryOceanNight,
        .sceneryDesertDay,
        .sceneryDesertNight,
        .sceneryRainforestDay,
        .sceneryRainforestNight,
        .sceneryCanyonDay,
        .sceneryCanyonNight,
        .sceneryArcticDay,
        .sceneryArcticNight,
    ]

    var isV071RetainedScenery: Bool {
        Self.v071RetainedSceneryCatalog.contains(self)
    }

    fileprivate var v071SceneryAssetName: String? {
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
}

'''

app = replace_once(
    app,
    "private enum LifeRouteSceneryFamily {",
    SCENERY_CATALOG + "private enum LifeRouteSceneryFamily {",
    "retained Scenery catalog insertion",
)


SCENERY_RENDERER = r'''// MARK: - v0.7.1 retained Scenery production renderer

private struct LifeRouteBundledSceneryAssetFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let assetName: String
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 5.2)
            let breathe = 0.5 + 0.5 * cos(phase * 3.8)

            ZStack {
                Image(decorative: assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.026 + breathe * 0.008)
                    .offset(x: drift * 4.2, y: -breathe * 2.2)

                LinearGradient(
                    colors: [
                        Color.black.opacity(theme.sceneryIsNight ? 0.08 : 0.04),
                        Color.clear,
                        Color.black.opacity(theme.sceneryIsNight ? 0.20 : 0.13),
                        Color.black.opacity(theme.sceneryIsNight ? 0.34 : 0.25),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.10 + breathe * 0.03 : 0.08 + breathe * 0.035),
                        palette.accent.opacity(0.025),
                        Color.clear,
                    ],
                    center: UnitPoint(x: CGFloat(0.68 + drift * 0.018), y: theme.sceneryIsNight ? 0.24 : 0.18),
                    startRadius: 2,
                    endRadius: longSide * 0.62
                )
                .blendMode(.screen)

                familyAmbience(size: size, drift: drift, breathe: breathe)

                LinearGradient(
                    colors: [Color.white.opacity(theme.sceneryIsNight ? 0.025 : 0.045), Color.clear, palette.accent.opacity(0.020), Color.clear],
                    startPoint: UnitPoint(x: CGFloat(0.12 + drift * 0.025), y: 0),
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func familyAmbience(size: CGSize, drift: Double, breathe: Double) -> some View {
        switch theme.sceneryFamily {
        case .mountains:
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.028 : 0.050))
                .frame(width: size.width * 0.90, height: max(34, size.height * 0.052))
                .blur(radius: 20)
                .offset(x: drift * size.width * 0.035, y: -size.height * 0.08)
            Capsule()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.022 : 0.034))
                .frame(width: size.width * 0.76, height: max(26, size.height * 0.040))
                .blur(radius: 17)
                .offset(x: -drift * size.width * 0.025, y: size.height * 0.16)

        case .ocean:
            LifeRouteSceneryWave(
                phase: phase * 8.4,
                verticalBias: 0.62,
                amplitude: max(4, size.height * 0.008),
                frequency: 1.18
            )
            .stroke(Color.white.opacity(theme.sceneryIsNight ? 0.15 : 0.24), lineWidth: 2.0)
            .blur(radius: 0.8)
            .blendMode(.screen)
            LifeRouteSceneryWave(
                phase: -phase * 7.2 + 1.4,
                verticalBias: 0.76,
                amplitude: max(5, size.height * 0.010),
                frequency: 0.92
            )
            .stroke(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.16 : 0.26), lineWidth: 2.4)
            .blur(radius: 1.2)
            .blendMode(.screen)

        case .desert:
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.028 : 0.060 + breathe * 0.018))
                .frame(width: size.width * 1.16, height: size.height * 0.16)
                .blur(radius: 24)
                .offset(x: drift * size.width * 0.025, y: size.height * 0.18)
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(theme.sceneryIsNight ? 0.018 : 0.045), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(-16 + drift * 1.8))
            .offset(y: size.height * 0.20)

        case .rainforest:
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.040 : 0.060))
                .frame(width: size.width * 0.98, height: max(48, size.height * 0.075))
                .blur(radius: 26)
                .offset(x: drift * size.width * 0.030, y: size.height * 0.10)
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.040 : 0.055))
                .frame(width: size.width * 0.78, height: size.height * 0.18)
                .blur(radius: 24)
                .offset(x: -drift * size.width * 0.024, y: -size.height * 0.18)

        case .canyon:
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.030 : 0.044))
                .frame(width: size.width * 0.94, height: max(42, size.height * 0.060))
                .blur(radius: 24)
                .offset(x: drift * size.width * 0.028, y: -size.height * 0.04)
            RadialGradient(
                colors: [palette.accent.opacity(theme.sceneryIsNight ? 0.055 : 0.075), Color.clear],
                center: UnitPoint(x: CGFloat(0.54 + drift * 0.025), y: 0.58),
                startRadius: 2,
                endRadius: max(size.width, size.height) * 0.42
            )
            .blendMode(.screen)

        case .arctic:
            if theme.sceneryIsNight {
                LifeRouteSceneryWave(phase: phase * 5.8, verticalBias: 0.24, amplitude: 14, frequency: 0.72)
                    .stroke(palette.accentSecondary.opacity(0.17 + breathe * 0.04), lineWidth: 18)
                    .blur(radius: 13)
                    .blendMode(.screen)
                LifeRouteSceneryWave(phase: -phase * 4.9 + 1.4, verticalBias: 0.31, amplitude: 11, frequency: 0.86)
                    .stroke(palette.accent.opacity(0.11 + breathe * 0.03), lineWidth: 13)
                    .blur(radius: 11)
                    .blendMode(.screen)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.065 + breathe * 0.020))
                    .frame(width: size.width * 1.04, height: max(42, size.height * 0.055))
                    .blur(radius: 20)
                    .offset(x: drift * size.width * 0.025, y: -size.height * 0.17)
            }

        case .alpine, .grassland, .volcanic, .coastalCliffs, nil:
            EmptyView()
        }
    }
}

'''

app = replace_once(
    app,
    "struct LifeRouteSceneryFrame: View {",
    SCENERY_RENDERER + "struct LifeRouteSceneryFrame: View {",
    "retained Scenery renderer insertion",
)


OLD_SCENERY_DISPATCH = r'''    @ViewBuilder
    var body: some View {
        if theme == .sceneryCanyonDay {
            LifeRouteCanyonDayAssetFrame(palette: palette, phase: phase)
        } else {
            legacyFrame
        }
    }
'''

NEW_SCENERY_DISPATCH = r'''    @ViewBuilder
    var body: some View {
        if theme == .sceneryCanyonDay {
            // Preserve the physically validated Build #98 Canyon Day reference verbatim.
            LifeRouteCanyonDayAssetFrame(palette: palette, phase: phase)
        } else if let assetName = theme.v071SceneryAssetName {
            LifeRouteBundledSceneryAssetFrame(
                theme: theme,
                palette: palette,
                assetName: assetName,
                phase: phase
            )
        } else {
            // Retired identifiers keep their procedural migration fallback but are not user-facing.
            legacyFrame
        }
    }
'''

app = replace_once(app, OLD_SCENERY_DISPATCH, NEW_SCENERY_DISPATCH, "Scenery renderer dispatch")

# Build #104 keeps the physically validated shipping canonicalizer. Expand only its retained
# Scenery allow-list so retired migration identifiers still resolve to Canyon Day.
app = replace_one_of(
    app,
    [
        '''        if theme == .sceneryCanyonDay { return theme }
        if theme.category == .scenery { return .sceneryCanyonDay }
''',
        '''        if theme.isV071RetainedScenery { return theme }
        if theme.category == .scenery { return .sceneryCanyonDay }
''',
    ],
    '''        if theme.isV071RetainedScenery { return theme }
        if theme.category == .scenery { return .sceneryCanyonDay }
''',
    "Build #104 Scenery shipping canonicalizer",
)

themes = replace_one_of(
    themes,
    [
        "            return LifeRouteTheme.phaseThreeSceneryCatalog\n",
        "            return [.sceneryCanyonDay]\n",
    ],
    "            return LifeRouteTheme.v071RetainedSceneryCatalog\n",
    "Theme Center Scenery catalog",
)
themes = replace_one_of(
    themes,
    [
        '            return "20 cinematic environments across 10 families, with Day and Night selected independently. Reduce Motion keeps the chosen scene and freezes ambient motion."\n',
        '            return "Canyon Day is the currently validated Scenery theme. Additional scenery environments are being finished separately."\n',
    ],
    '            return "12 finished cinematic environments across 6 Day/Night families. Reduce Motion keeps the selected scene and freezes ambience."\n',
    "Theme Center Scenery description",
)

APP_PATH.write_text(app)
THEME_CENTER_PATH.write_text(themes)

print(
    "LifeRoute v0.7.1 retained Scenery library applied: Canyon Day remains on its physically validated "
    "renderer; Mountains, Ocean, Desert, Rainforest, Canyon Night, and Arctic use optimized bundled "
    "artwork with family-specific root-phase ambience; retired families remain migration-compatible but "
    "are hidden from the retained Theme Center catalog."
)
