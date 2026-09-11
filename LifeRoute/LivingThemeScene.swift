import Foundation
import CoreGraphics

/// Scene content is separate from playback. A second environment supplies its
/// own artwork and fragment function; it does not allocate another clock owner.
struct LivingThemeScene: Equatable, Sendable {
    let themeIdentifier: String
    let artworkName: String
    let fragmentFunction: String

    static let rainforestDay = Self(
        themeIdentifier: "scenery.rainforest.day",
        artworkName: "SceneryRainforestDay",
        fragmentFunction: "livingRainforestFragment"
    )

    static func scene(for themeIdentifier: String) -> Self? {
        LivingThemeRegistration.registration(for: themeIdentifier)?.scene
    }
}

/// Product registry: inclusion in Living Themes does not imply completed motion
/// or physical acceptance. Pending scenes keep their fixed Scenic Royal artwork.
enum LivingThemeFamily: String, Sendable { case rainforest, ocean, arctic, mountains, canyon, desert }
enum LivingThemeVariant: String, Sendable { case day, night }
enum LivingThemeMotionStatus: Sendable { case implemented, pending }

struct LivingThemeRegistration: Equatable, Sendable {
    let themeIdentifier: String
    let family: LivingThemeFamily
    let variant: LivingThemeVariant
    let scene: LivingThemeScene?
    var motionStatus: LivingThemeMotionStatus { scene == nil ? .pending : .implemented }
    // One common lifecycle and accessibility policy, owned by the native surface.
    let lifecyclePolicy = "single surface; release when hidden; active-time playback"
    let reduceMotionPolicy = "shared LivingSceneQuality"

    static let all: [Self] = [
        .init(themeIdentifier: "scenery.rainforest.day", family: .rainforest, variant: .day, scene: .rainforestDay),
        .init(themeIdentifier: "scenery.rainforest.night", family: .rainforest, variant: .night, scene: nil),
        .init(themeIdentifier: "scenery.ocean.day", family: .ocean, variant: .day, scene: nil),
        .init(themeIdentifier: "scenery.ocean.night", family: .ocean, variant: .night, scene: nil),
        .init(themeIdentifier: "scenery.arctic.day", family: .arctic, variant: .day, scene: nil),
        .init(themeIdentifier: "scenery.arctic.night", family: .arctic, variant: .night, scene: nil),
        .init(themeIdentifier: "scenery.mountains.day", family: .mountains, variant: .day, scene: nil),
        .init(themeIdentifier: "scenery.mountains.night", family: .mountains, variant: .night, scene: nil),
        .init(themeIdentifier: "scenery.canyon.day", family: .canyon, variant: .day, scene: nil),
        .init(themeIdentifier: "scenery.canyon.night", family: .canyon, variant: .night, scene: nil),
        .init(themeIdentifier: "scenery.desert.day", family: .desert, variant: .day, scene: nil),
        .init(themeIdentifier: "scenery.desert.night", family: .desert, variant: .night, scene: nil),
    ]

    static func registration(for identifier: String) -> Self? {
        all.first { $0.themeIdentifier == identifier }
    }
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
        guard !reduceMotion, effectsEnabled, thermal != .critical else {
            return .init(framesPerSecond: 0, maximumDrawableDimension: 1280,
                         motionAmount: 0, atmosphereAmount: 0)
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
