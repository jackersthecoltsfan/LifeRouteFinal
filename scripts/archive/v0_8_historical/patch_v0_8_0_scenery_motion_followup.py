from pathlib import Path


APP_PATH = Path("LifeRoute/LifeRouteApp.swift")
MARKER = "v0.8.0 follow-up Scenery ambient motion"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"v0.8.0 Scenery follow-up failed: expected one {label}, found {count}"
        )
    return text.replace(old, new, 1)


app = APP_PATH.read_text(encoding="utf-8")
if MARKER in app:
    print("LifeRoute v0.8.0 Scenery motion follow-up is already materialized.")
    raise SystemExit(0)


particle_field = r'''// v0.8.0 follow-up Scenery ambient motion:
// Small deterministic Canvas fields reuse the protected root phase; they add no clock or state.
private struct LifeRouteSceneryAmbientParticleField: View {
    enum Kind {
        case rainforestLeaves
        case arcticSnow
    }

    let kind: Kind
    let phase: Double
    let isNight: Bool

    var body: some View {
        Canvas { context, size in
            switch kind {
            case .rainforestLeaves:
                for index in 0..<9 {
                    let seed = Double(index) * 1.731 + 0.47
                    let baseX = size.width * CGFloat(0.08 + Double(index % 5) * 0.205)
                    let baseY = size.height * CGFloat(0.08 + Double(index / 5) * 0.17 + Double(index % 3) * 0.035)
                    let swayX = CGFloat(sin(phase * 6.2 + seed) * (4.0 + Double(index % 3)))
                    let swayY = CGFloat(cos(phase * 4.6 + seed * 1.3) * 2.4)
                    let leafWidth = CGFloat(7 + index % 3 * 2)
                    let leafHeight = leafWidth * 0.46

                    var leafContext = context
                    leafContext.translateBy(x: baseX + swayX, y: baseY + swayY)
                    leafContext.rotate(by: .degrees(sin(phase * 5.4 + seed) * 13 + Double(index % 2) * 18))
                    leafContext.fill(
                        Path(ellipseIn: CGRect(
                            x: -leafWidth / 2,
                            y: -leafHeight / 2,
                            width: leafWidth,
                            height: leafHeight
                        )),
                        with: .color(
                            Color(red: 0.62, green: 0.90, blue: 0.56)
                                .opacity(isNight ? 0.055 : 0.085)
                        )
                    )
                }

            case .arcticSnow:
                for index in 0..<18 {
                    let seed = Double(index) * 0.61803398875
                    let baseX = (seed * 0.754877666).truncatingRemainder(dividingBy: 1)
                    let fall = (phase * 2.6 + seed).truncatingRemainder(dividingBy: 1)
                    let sway = sin(phase * 7.0 + seed * 9.0) * 0.014
                    let diameter = CGFloat(1.6 + Double(index % 4) * 0.62)
                    let x = size.width * CGFloat((baseX + sway + 1).truncatingRemainder(dividingBy: 1))
                    let y = size.height * CGFloat(fall)
                    let flake = Path(ellipseIn: CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    ))
                    context.fill(
                        flake,
                        with: .color(Color.white.opacity(isNight ? 0.11 : 0.16))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

'''
app = replace_once(
    app,
    "private struct LifeRouteBundledSceneryAssetFrame: View {",
    particle_field + "private struct LifeRouteBundledSceneryAssetFrame: View {",
    "ambient particle field insertion",
)

app = replace_once(
    app,
    '''        case .rainforest:
            Capsule()''',
    '''        case .rainforest:
            LifeRouteSceneryAmbientParticleField(
                kind: .rainforestLeaves,
                phase: phase,
                isNight: theme.sceneryIsNight
            )
            Capsule()''',
    "rainforest leaf sway",
)

app = replace_once(
    app,
    '''        case .arctic:
            if theme.sceneryIsNight {''',
    '''        case .arctic:
            LifeRouteSceneryAmbientParticleField(
                kind: .arcticSnow,
                phase: phase,
                isNight: theme.sceneryIsNight
            )
            if theme.sceneryIsNight {''',
    "Arctic snow field",
)


APP_PATH.write_text(app, encoding="utf-8")
print(
    "LifeRoute v0.8.0 Scenery follow-up applied: Rainforest gains restrained deterministic leaf "
    "sway and Arctic gains subtle drifting snow, both driven only by the protected root phase so "
    "Reduce Motion and lifecycle pausing remain authoritative."
)
