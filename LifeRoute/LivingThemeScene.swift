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
        themeIdentifier == rainforestDay.themeIdentifier ? rainforestDay : nil
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
