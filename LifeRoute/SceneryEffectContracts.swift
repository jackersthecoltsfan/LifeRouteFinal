import Foundation

enum LifeRouteScenerySceneID: String, CaseIterable, Codable, Hashable, Sendable {
    case mountainsDay
    case mountainsNight
    case oceanDay
    case oceanNight
    case desertDay
    case desertNight
    case rainforestDay
    case rainforestNight
    case canyonDay
    case canyonNight
    case arcticDay
    case arcticNight

    var isNight: Bool {
        switch self {
        case .mountainsNight, .oceanNight, .desertNight, .rainforestNight,
             .canyonNight, .arcticNight:
            return true
        default:
            return false
        }
    }

    var assetName: String {
        switch self {
        case .mountainsDay: return "SceneryMountainsDay"
        case .mountainsNight: return "SceneryMountainsNight"
        case .oceanDay: return "SceneryOceanDay"
        case .oceanNight: return "SceneryOceanNight"
        case .desertDay: return "SceneryDesertDay"
        case .desertNight: return "SceneryDesertNight"
        case .rainforestDay: return "SceneryRainforestDay"
        case .rainforestNight: return "SceneryRainforestNight"
        case .canyonDay: return "SceneryCanyonDay"
        case .canyonNight: return "SceneryCanyonNight"
        case .arcticDay: return "SceneryArcticDay"
        case .arcticNight: return "SceneryArcticNight"
        }
    }
}

enum LifeRouteSceneryEffect: String, CaseIterable, Codable, Hashable, Sendable {
    case clouds
    case valleyFog
    case waterRipple
    case heatMirage
    case sandGust
    case waterfallFlow
    case streamFlow
    case mistCycle
    case rain
    case riverFlow
    case fogCycle
    case celestialDrift
    case snowfall
    case aurora
    case snowGust
}

enum LifeRouteSceneryTextureMotionRegion: String, CaseIterable, Codable, Hashable, Sendable {
    case oceanFar
    case oceanNear
    case rainforestDayWaterfall
    case rainforestDayStream
    case rainforestNightStream
    case canyonDayRiver
    case canyonNightRiver
    case arcticDayWater
}

enum LifeRouteSceneryCameraPolicy: String, Codable, Sendable {
    case fixedAspectFill
}

struct LifeRouteScenerySceneProfile: Equatable, Sendable {
    let scene: LifeRouteScenerySceneID
    let effects: [LifeRouteSceneryEffect]
    let cameraPolicy: LifeRouteSceneryCameraPolicy

    func includes(_ effect: LifeRouteSceneryEffect) -> Bool {
        effects.contains(effect)
    }

    var textureMotionRegions: [LifeRouteSceneryTextureMotionRegion] {
        switch scene {
        case .oceanDay, .oceanNight:
            return [.oceanFar, .oceanNear]
        case .rainforestDay:
            return [.rainforestDayWaterfall, .rainforestDayStream]
        case .rainforestNight:
            return [.rainforestNightStream]
        case .canyonDay:
            return [.canyonDayRiver]
        case .canyonNight:
            return [.canyonNightRiver]
        case .arcticDay:
            return [.arcticDayWater]
        default:
            return []
        }
    }

    static let all: [Self] = [
        .init(scene: .mountainsDay, effects: [.clouds, .valleyFog], cameraPolicy: .fixedAspectFill),
        .init(scene: .mountainsNight, effects: [.clouds, .valleyFog], cameraPolicy: .fixedAspectFill),
        .init(scene: .oceanDay, effects: [.waterRipple, .clouds], cameraPolicy: .fixedAspectFill),
        .init(scene: .oceanNight, effects: [.waterRipple, .clouds], cameraPolicy: .fixedAspectFill),
        .init(scene: .desertDay, effects: [.heatMirage, .clouds, .sandGust], cameraPolicy: .fixedAspectFill),
        .init(scene: .desertNight, effects: [.clouds, .sandGust], cameraPolicy: .fixedAspectFill),
        .init(scene: .rainforestDay, effects: [.waterfallFlow, .streamFlow, .mistCycle, .rain], cameraPolicy: .fixedAspectFill),
        .init(scene: .rainforestNight, effects: [.waterfallFlow, .streamFlow, .clouds, .rain], cameraPolicy: .fixedAspectFill),
        .init(scene: .canyonDay, effects: [.clouds, .riverFlow, .fogCycle], cameraPolicy: .fixedAspectFill),
        .init(scene: .canyonNight, effects: [.clouds, .riverFlow, .celestialDrift], cameraPolicy: .fixedAspectFill),
        .init(scene: .arcticDay, effects: [.waterRipple, .snowfall, .clouds], cameraPolicy: .fixedAspectFill),
        .init(scene: .arcticNight, effects: [.aurora, .snowfall, .snowGust], cameraPolicy: .fixedAspectFill),
    ]

    static func profile(for scene: LifeRouteScenerySceneID) -> Self {
        all.first(where: { $0.scene == scene })!
    }
}

enum LifeRouteSceneryGustPolicy {
    /// Four deterministic, scene-seeded events use varied 53, 68, 79, and 57
    /// second gaps. No timer, allocation, or independently owned clock is needed.
    static func envelope(at time: TimeInterval, seed: Double) -> Double {
        let safeTime = time.isFinite ? max(0, time) : 0
        let safeSeed = seed.isFinite ? abs(seed) : 0
        let cycleLength = 257.0
        let offset = (safeSeed * 7.31).truncatingRemainder(dividingBy: cycleLength)
        let local = (safeTime + offset).truncatingRemainder(dividingBy: cycleLength)
        let starts = [11.0, 64.0, 132.0, 211.0]

        for (index, start) in starts.enumerated() {
            let duration = 3.8 + Double(index) * 0.43 + safeSeed.truncatingRemainder(dividingBy: 0.7)
            guard local >= start, local < start + duration else { continue }
            let progress = (local - start) / duration
            let eased = sin(Double.pi * progress)
            return eased * eased
        }
        return 0
    }
}

enum LifeRouteSceneryArtworkLimitation: String, Sendable {
    case arcticNightContainsBakedClouds
    case canyonNightContainsBakedMoonAndStars
    case rainforestNightHasNoDistinctBakedWaterfall

    static let documentedByScene: [LifeRouteScenerySceneID: [Self]] = [
        .arcticNight: [.arcticNightContainsBakedClouds],
        .canyonNight: [.canyonNightContainsBakedMoonAndStars],
        .rainforestNight: [.rainforestNightHasNoDistinctBakedWaterfall],
    ]
}
