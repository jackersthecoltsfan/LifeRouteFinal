import Foundation

@main
struct SceneryEffectContractTests {
    private static var assertionCount = 0

    static func main() {
        testCatalogIntegrity()
        testDayNightMatrix()
        testLocalizedTextureMotionMatrix()
        testArcticNightBoundary()
        testOccasionalGustPolicy()

        print("Scenery effect executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testCatalogIntegrity() {
        expect(LifeRouteScenerySceneProfile.all.count == 12, "all twelve retained Day/Night scenes have profiles")
        expect(Set(LifeRouteScenerySceneProfile.all.map(\.scene)).count == 12, "each retained scene has one authoritative profile")
        expect(
            LifeRouteScenerySceneProfile.all.allSatisfy { $0.cameraPolicy == .fixedAspectFill },
            "every retained scene uses the fixed aspect-fill camera policy"
        )
        expect(
            LifeRouteScenerySceneProfile.all.allSatisfy { !$0.effects.isEmpty },
            "every retained scene has localized environmental life"
        )
        expect(
            Set(LifeRouteScenerySceneProfile.all.flatMap(\.effects)) == Set(LifeRouteSceneryEffect.allCases),
            "the profile matrix exercises every bounded effect family"
        )
    }

    private static func testDayNightMatrix() {
        expectEffects(.mountainsDay, [.clouds, .valleyFog])
        expectEffects(.mountainsNight, [.clouds, .valleyFog])
        expectEffects(.oceanDay, [.waterRipple, .clouds])
        expectEffects(.oceanNight, [.waterRipple, .clouds])
        expectEffects(.desertDay, [.heatMirage, .clouds, .sandGust])
        expectEffects(.desertNight, [.clouds, .sandGust])
        expectEffects(.rainforestDay, [.waterfallFlow, .streamFlow, .mistCycle, .rain])
        expectEffects(.rainforestNight, [.waterfallFlow, .streamFlow, .clouds, .rain])
        expectEffects(.canyonDay, [.clouds, .riverFlow, .fogCycle])
        expectEffects(.canyonNight, [.clouds, .riverFlow, .celestialDrift])
        expectEffects(.arcticDay, [.waterRipple, .snowfall, .clouds])
        expectEffects(.arcticNight, [.aurora, .snowfall, .snowGust])

        expect(!profile(.desertNight).includes(.heatMirage), "Desert Night explicitly omits daytime heat mirage")
        expect(profile(.desertDay).includes(.heatMirage), "Desert Day retains perceptible heat mirage")
        expect(profile(.rainforestDay).includes(.mistCycle), "Rainforest Day mist can recede and return")
        expect(profile(.canyonDay).includes(.fogCycle), "Canyon Day fog has a slow arrival and recession cycle")
        expect(profile(.canyonNight).includes(.celestialDrift), "Canyon Night retains extremely slow celestial movement")
    }

    private static func testArcticNightBoundary() {
        let night = profile(.arcticNight)
        expect(!night.includes(.clouds), "Arctic Night has no animated or generated cloud effect")
        expect(night.includes(.aurora), "Arctic Night aurora remains visibly alive")
        expect(night.includes(.snowfall), "Arctic Night preserves gentle snowfall")
        expect(night.includes(.snowGust), "Arctic Night includes occasional loose-snow gusts")
        expect(profile(.arcticDay).includes(.clouds), "Arctic Day retains its requested cloud motion")
        expect(LifeRouteScenerySceneID.arcticNight.isNight, "Arctic Night is classified as night")
        expect(!LifeRouteScenerySceneID.arcticDay.isNight, "Arctic Day is classified as day")
        expect(
            LifeRouteSceneryArtworkLimitation.documentedByScene[.arcticNight]
                == [.arcticNightContainsBakedClouds],
            "Arctic Night baked-cloud conflict is explicit rather than silently changing artwork"
        )
        expect(
            LifeRouteSceneryArtworkLimitation.documentedByScene[.canyonNight]
                == [.canyonNightContainsBakedMoonAndStars],
            "Canyon Night baked celestial limitation remains explicit"
        )
        expect(
            LifeRouteSceneryArtworkLimitation.documentedByScene[.rainforestNight]
                == [.rainforestNightHasNoDistinctBakedWaterfall],
            "Rainforest Night waterfall limitation remains explicit"
        )
    }

    private static func testLocalizedTextureMotionMatrix() {
        expectTextureRegions(.mountainsDay, [])
        expectTextureRegions(.mountainsNight, [])
        expectTextureRegions(.oceanDay, [.oceanFar, .oceanNear])
        expectTextureRegions(.oceanNight, [.oceanFar, .oceanNear])
        expectTextureRegions(.desertDay, [])
        expectTextureRegions(.desertNight, [])
        expectTextureRegions(.rainforestDay, [.rainforestDayWaterfall, .rainforestDayStream])
        expectTextureRegions(.rainforestNight, [.rainforestNightStream])
        expectTextureRegions(.canyonDay, [.canyonDayRiver])
        expectTextureRegions(.canyonNight, [.canyonNightRiver])
        expectTextureRegions(.arcticDay, [.arcticDayWater])
        expectTextureRegions(.arcticNight, [])

        let selected = Set(LifeRouteScenerySceneProfile.all.flatMap(\.textureMotionRegions))
        expect(selected == Set(LifeRouteSceneryTextureMotionRegion.allCases), "every approved moving-water mask is selected by the scene matrix")
        expect(profile(.arcticNight).textureMotionRegions.isEmpty, "Arctic Night does not animate its frozen foreground as open water")
        expect(
            profile(.rainforestNight).textureMotionRegions == [.rainforestNightStream],
            "Rainforest Night moves its visible stream without inventing a waterfall absent from the artwork"
        )
    }

    private static func testOccasionalGustPolicy() {
        let seed = 8.3
        let samples = stride(from: 0.0, through: 240.0, by: 0.25).map {
            LifeRouteSceneryGustPolicy.envelope(at: $0, seed: seed)
        }
        expect(samples.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, "gust envelopes are finite and bounded")
        expect(samples.contains(where: { $0 > 0.75 }), "gusts become clearly perceptible during an event")
        expect(samples.filter { $0 == 0 }.count > samples.count * 4 / 5, "gusts remain occasional rather than constant particle noise")
        expect(
            LifeRouteSceneryGustPolicy.envelope(at: 97.5, seed: seed)
                == LifeRouteSceneryGustPolicy.envelope(at: 97.5, seed: seed),
            "gust timing is deterministic without an independent timer"
        )
        expect(
            LifeRouteSceneryGustPolicy.envelope(at: 97.5, seed: 23.7)
                != LifeRouteSceneryGustPolicy.envelope(at: 97.5, seed: seed),
            "sand and snow gusts use varied timing"
        )
        expect(LifeRouteSceneryGustPolicy.envelope(at: .nan, seed: seed).isFinite, "non-finite time cannot destabilize rendering")
        expect(LifeRouteSceneryGustPolicy.envelope(at: 10, seed: .infinity).isFinite, "non-finite seed cannot destabilize rendering")
    }

    private static func profile(_ scene: LifeRouteScenerySceneID) -> LifeRouteScenerySceneProfile {
        .profile(for: scene)
    }

    private static func expectEffects(_ scene: LifeRouteScenerySceneID, _ effects: [LifeRouteSceneryEffect]) {
        expect(profile(scene).effects == effects, "\(scene.rawValue) selects its exact required effect matrix")
    }

    private static func expectTextureRegions(
        _ scene: LifeRouteScenerySceneID,
        _ regions: [LifeRouteSceneryTextureMotionRegion]
    ) {
        expect(
            profile(scene).textureMotionRegions == regions,
            "\(scene.rawValue) selects its exact localized moving-texture masks"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
