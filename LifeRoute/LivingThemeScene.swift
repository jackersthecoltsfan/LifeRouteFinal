import Foundation
import CoreGraphics

/// Scene content is separate from playback. A second environment supplies its
/// own artwork and fragment function; it does not allocate another clock owner.
struct LivingThemeScene: Equatable, Sendable {
    let themeIdentifier: String
    let artworkName: String
    let fragmentFunction: String
    var ocean: LivingOceanConfiguration? = nil
    var atmosphere: LivingAtmosphereConfiguration? = nil

    static let rainforestDay = Self(
        themeIdentifier: "scenery.rainforest.day",
        artworkName: "SceneryRainforestDay",
        fragmentFunction: "livingRainforestFragment"
    )

    static let oceanDay = Self(themeIdentifier: "scenery.ocean.day", artworkName: "SceneryOceanDay",
                               fragmentFunction: "livingOceanFragment", ocean: .day)
    static let oceanNight = Self(themeIdentifier: "scenery.ocean.night", artworkName: "SceneryOceanNight",
                                 fragmentFunction: "livingOceanFragment", ocean: .night)


    static func scene(for themeIdentifier: String) -> Self? {
        LivingThemeRegistration.registration(for: themeIdentifier)?.scene
    }
}

/// The explicit product registry distinguishes implemented programs from physical
/// acceptance. Every active entry has a scene-specific primary environmental system.
enum LivingThemeFamily: String, Sendable { case rainforest, ocean, arctic, mountains, canyon, desert }
enum LivingThemeVariant: String, Sendable { case day, night }
enum LivingThemeMotionStatus: Sendable { case implemented, pending }

struct LivingThemeRegistration: Equatable, Sendable {
    let themeIdentifier: String
    let family: LivingThemeFamily
    let variant: LivingThemeVariant
    let scene: LivingThemeScene?
    var motionStatus: LivingThemeMotionStatus { scene == nil ? .pending : .implemented }
    let primaryMotion: String
    let secondaryEffects: [String]
    let ambientEffects: [String]
    var environmentalProgram: String? { scene?.fragmentFunction }
    let constrainedPolicy = "ambient off, secondary off, cadence/pixels reduced, then still at critical"
    // One common lifecycle and accessibility policy, owned by the native surface.
    let lifecyclePolicy = "single surface; release when hidden; active-time playback"
    let reduceMotionPolicy = "shared LivingSceneQuality"

    static let all: [Self] = [
        .init(themeIdentifier: "scenery.rainforest.day", family: .rainforest, variant: .day, scene: .rainforestDay,
              primaryMotion: "waterfall and winding stream", secondaryEffects: ["localized spray", "leaf flex"], ambientEffects: []),
        .init(themeIdentifier: "scenery.rainforest.night", family: .rainforest, variant: .night, scene: nil,
              primaryMotion: "moonlit stream flow", secondaryEffects: ["layered river mist", "regional foliage"], ambientEffects: ["sparse layered rain"]),
        .init(themeIdentifier: "scenery.ocean.day", family: .ocean, variant: .day, scene: .oceanDay,
              primaryMotion: "finite advancing swell, crest, break and foam decay", secondaryEffects: ["surface ripples", "localized spray", "evolving cloud layers"], ambientEffects: []),
        .init(themeIdentifier: "scenery.ocean.night", family: .ocean, variant: .night, scene: .oceanNight,
              primaryMotion: "finite advancing swell, crest, break and foam decay", secondaryEffects: ["water-bound moon reflection", "surface ripples"], ambientEffects: []),
        .init(themeIdentifier: "scenery.arctic.day", family: .arctic, variant: .day, scene: nil,
              primaryMotion: "broad advecting spindrift and weather banks", secondaryEffects: ["layered haze", "water-channel ripples"], ambientEffects: ["three-depth snow"]),
        .init(themeIdentifier: "scenery.arctic.night", family: .arctic, variant: .night, scene: nil,
              primaryMotion: "evolving aurora curtains", secondaryEffects: ["cold haze", "lake reflection"], ambientEffects: ["sparse snow", "stars", "rare shooting stars"]),
        .init(themeIdentifier: "scenery.mountains.day", family: .mountains, variant: .day, scene: nil,
              primaryMotion: "advecting reforming clouds and valley fog", secondaryEffects: ["depth haze", "lake ripples"], ambientEffects: []),
        .init(themeIdentifier: "scenery.mountains.night", family: .mountains, variant: .night, scene: nil,
              primaryMotion: "rolling valley fog and evolving high cloud", secondaryEffects: ["lake ripples", "night haze"], ambientEffects: ["stars", "rare shooting stars"]),
        .init(themeIdentifier: "scenery.canyon.day", family: .canyon, variant: .day, scene: nil,
              primaryMotion: "evolving sky clouds and broad canyon haze", secondaryEffects: ["directional river flow", "distance haze"], ambientEffects: []),
        .init(themeIdentifier: "scenery.canyon.night", family: .canyon, variant: .night, scene: nil,
              primaryMotion: "evolving cloud and canyon mist", secondaryEffects: ["directional river flow"], ambientEffects: ["stars", "rare shooting stars"]),
        .init(themeIdentifier: "scenery.desert.day", family: .desert, variant: .day, scene: nil,
              primaryMotion: "local heat refraction and moving warm haze", secondaryEffects: ["high cloud evolution"], ambientEffects: ["restrained distant dust"]),
        .init(themeIdentifier: "scenery.desert.night", family: .desert, variant: .night, scene: nil,
              primaryMotion: "evolving night haze within the rock-arch opening", secondaryEffects: ["distant cool haze"], ambientEffects: ["stars", "rare shooting stars"]),
    ]

    static func registration(for identifier: String) -> Self? {
        all.first { $0.themeIdentifier == identifier }
    }
}

/// Artwork-calibrated geometry and lighting for one physical ocean program.
/// Eight floats match buffer(1) in Metal; the Rainforest uniform ABI is unchanged.
struct LivingOceanConfiguration: Equatable, Sendable {
    var horizon: Float
    var crestIntercept: Float
    var crestSlope: Float
    var shallow: Float
    var reflectionX: Float
    var night: Float
    var swellAmplitude: Float
    var padding: Float = 0
    static let day = Self(horizon: 0.306, crestIntercept: 0.61, crestSlope: -0.18,
                          shallow: 1, reflectionX: 0.72, night: 0, swellAmplitude: 1)
    static let night = Self(horizon: 0.337, crestIntercept: 0.76, crestSlope: -0.25,
                            shallow: 0, reflectionX: 0.343, night: 1, swellAmplitude: 0.82)
}

/// Artwork-space conservative sky silhouettes, light position and physical air
/// parameters. Four float4 values match Metal buffer(2); no frame-published state.
struct LivingAtmosphereConfiguration: Equatable, Sendable {
    var skyA: SIMD4<Float>
    var skyB: SIMD4<Float>
    var light: SIMD4<Float> // night, deterministic scene seed, moon x/y
    var air: SIMD4<Float> // cloud velocity, cloud strength, fog strength, weather density
    static let rainforestNight = Self(skyA: SIMD4(0.05, 0.05, 0.05, 0.05), skyB: SIMD4(0.05, 0.05, 0.05, 0.05),
        light: SIMD4(1, 11, 0.54, 0.174), air: SIMD4(0.008, 0.15, 0.65, 0.12))
    static let arcticDay = Self(skyA: SIMD4(0.28, 0.31, 0.34, 0.34), skyB: SIMD4(0.31, 0.29, 0.28, 0.26),
        light: SIMD4(0, 23, -1, -1), air: SIMD4(0.022, 0.4, 0.8, 0.7))
    static let arcticNight = Self(skyA: SIMD4(0.36, 0.43, 0.49, 0.47), skyB: SIMD4(0.42, 0.35, 0.32, 0.3),
        light: SIMD4(1, 37, 0.283, 0.435), air: SIMD4(0.006, 0, 0.3, 0.16))
    static let mountainsDay = Self(skyA: SIMD4(0.25, 0.26, 0.24, 0.28), skyB: SIMD4(0.28, 0.29, 0.3, 0.28),
        light: SIMD4(0, 41, -1, -1), air: SIMD4(0.02, 0.7, 0.7, 0))
    static let mountainsNight = Self(skyA: SIMD4(0.18, 0.25, 0.35, 0.37), skyB: SIMD4(0.39, 0.4, 0.38, 0.36),
        light: SIMD4(1, 53, 0.32, 0.13), air: SIMD4(0.013, 0.45, 0.85, 0))
    static let canyonDay = Self(skyA: SIMD4(0.25, 0.25, 0.34, 0.38), skyB: SIMD4(0.39, 0.35, 0.34, 0.33),
        light: SIMD4(0, 67, -1, -1), air: SIMD4(0.014, 0.55, 0.4, 0))
    static let canyonNight = Self(skyA: SIMD4(0.25, 0.28, 0.31, 0.32), skyB: SIMD4(0.29, 0.23, 0.16, 0.13),
        light: SIMD4(1, 79, 0.197, 0.13), air: SIMD4(0.012, 0.48, 0.6, 0))
    static let desertDay = Self(skyA: SIMD4(0.16, 0.16, 0.19, 0.2), skyB: SIMD4(0.2, 0.21, 0.2, 0.17),
        light: SIMD4(0, 89, -1, -1), air: SIMD4(0.009, 0.3, 0.65, 0.07))
    static let desertNight = Self(skyA: SIMD4(0.35, 0.37, 0.42, 0.44), skyB: SIMD4(0.46, 0.44, 0.4, 0.33),
        light: SIMD4(1, 103, 0.68, 0.247), air: SIMD4(0.009, 0.34, 0.6, 0))
}

struct LivingSceneQuality: Equatable, Sendable {
    enum Thermal: Sendable { case nominal, fair, serious, critical }
    let framesPerSecond: Int
    let maximumDrawableDimension: Int
    let motionAmount: Float
    let atmosphereAmount: Float

    static func resolve(reduceMotion: Bool, lowPower: Bool, thermal: Thermal,
                        effectsEnabled: Bool) -> Self {
        // Static scenery remains attractive, including on the iOS 16 path.
        guard effectsEnabled, thermal != .critical else {
            return .init(framesPerSecond: 0, maximumDrawableDimension: 1280,
                         motionAmount: 0, atmosphereAmount: 0)
        }
        if reduceMotion {
            return .init(framesPerSecond: 15, maximumDrawableDimension: 960,
                         motionAmount: 0.25, atmosphereAmount: 0)
        }
        if lowPower || thermal == .serious {
            return .init(framesPerSecond: 20, maximumDrawableDimension: 960,
                         motionAmount: 0.7, atmosphereAmount: 0)
        }
        return .init(framesPerSecond: 30, maximumDrawableDimension: 1280,
                     motionAmount: 1, atmosphereAmount: 1)
    }

    func drawableSize(for bounds: CGSize, scale: CGFloat) -> CGSize {
        guard bounds.width.isFinite, bounds.height.isFinite, scale.isFinite,
              bounds.width > 0, bounds.height > 0, scale > 0 else { return .zero }
        let ratio = min(scale, CGFloat(maximumDrawableDimension) / max(bounds.width, bounds.height))
        return CGSize(width: max(1, floor(bounds.width * ratio)),
                      height: max(1, floor(bounds.height * ratio)))
    }
}

/// Monotonic ACTIVE time, never wall-clock phase. Pause/resume is idempotent,
/// and a hitch does not become a large visible simulation jump or catch-up loop.
struct LivingSceneClock {
    private(set) var elapsed: TimeInterval = 0
    private(set) var isRunning = false
    private var lastSample: TimeInterval?

    mutating func setRunning(_ running: Bool) {
        guard isRunning != running else { return }
        isRunning = running
        lastSample = nil
    }

    mutating func sample(at timestamp: TimeInterval) -> TimeInterval {
        guard isRunning, timestamp.isFinite else { return elapsed }
        if let previous = lastSample {
            elapsed += min(0.1, max(0, timestamp - previous))
        }
        lastSample = timestamp
        return elapsed
    }
}

struct LivingScenePlayback: Equatable, Sendable {
    let isActive: Bool
    let isExposed: Bool
    let allowsAnimation: Bool
    let reduceMotion: Bool
    let effectsEnabled: Bool

    func runsContinuously(attached: Bool, applicationActive: Bool,
                          quality: LivingSceneQuality) -> Bool {
        isActive && isExposed && attached && applicationActive
            && allowsAnimation && quality.framesPerSecond > 0
    }
}

/// Same centered aspect-fill mapping for every scene and every orientation.
/// Motion masks operate in artwork coordinates, never viewport coordinates.
struct LivingSceneFraming {
    static func uvScale(viewport: CGSize, artwork: CGSize) -> SIMD2<Float> {
        guard viewport.width > 0, viewport.height > 0,
              artwork.width > 0, artwork.height > 0 else { return SIMD2(repeating: 1) }
        let fill = max(viewport.width / artwork.width, viewport.height / artwork.height)
        return SIMD2(Float(viewport.width / (artwork.width * fill)),
                     Float(viewport.height / (artwork.height * fill)))
    }
}

/// Shared Swift/Metal layout: two float2s followed by four floats (32 bytes).
struct LivingSceneUniforms {
    var uvScale: SIMD2<Float>
    var textureSize: SIMD2<Float>
    var time: Float
    var motion: Float
    var atmosphere: Float
    var padding: Float = 0
}
