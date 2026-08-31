import Foundation

enum VisualTimerToneProfile: String, CaseIterable, Codable, Identifiable {
    case warm
    case soft
    case clear

    static let defaultProfile: VisualTimerToneProfile = .soft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warm: return "Warm"
        case .soft: return "Soft"
        case .clear: return "Clear"
        }
    }

    var detail: String {
        switch self {
        case .warm: return "Lower, mellow pulse"
        case .soft: return "Soft, rounded pulse"
        case .clear: return "Light, focused pulse"
        }
    }

    var systemImage: String {
        switch self {
        case .warm: return "speaker.wave.1.fill"
        case .soft: return "waveform.path"
        case .clear: return "bell.and.waves.left.and.right.fill"
        }
    }

    var startFrequency: Double {
        switch self {
        case .warm: return 196.00
        case .soft: return 220.00
        case .clear: return 261.63
        }
    }

    var endFrequency: Double {
        switch self {
        case .warm: return 392.00
        case .soft: return 440.00
        case .clear: return 523.25
        }
    }

    var completionFrequencies: [Double] {
        switch self {
        case .warm: return [293.66, 349.23, 392.00]
        case .soft: return [329.63, 392.00, 440.00]
        case .clear: return [349.23, 440.00, 523.25]
        }
    }

    var secondHarmonicMix: Double {
        switch self {
        case .warm: return 0.09
        case .soft: return 0.05
        case .clear: return 0.025
        }
    }

    var detuneMix: Double {
        switch self {
        case .warm: return 0.018
        case .soft: return 0.012
        case .clear: return 0.008
        }
    }
}

struct VisualTimerFeedbackPreferences: Equatable {
    let toneProfile: VisualTimerToneProfile
    let soundEnabled: Bool
    let volume: Double
    let completionHapticsEnabled: Bool

    static let `default` = VisualTimerFeedbackPreferences(
        toneProfile: .defaultProfile,
        soundEnabled: true,
        volume: 0.42,
        completionHapticsEnabled: true
    )
}

enum VisualTimerAudioSessionPolicy {
    /// The Visual Timer is intentional playback controlled by its own Sound
    /// setting, so the hardware Ring/Silent switch must not mute it.
    static let playsThroughRingSilentSwitch = true
    static let mixesWithOtherAudio = true

    static func shouldActivate(soundEnabled: Bool, volume: Double) -> Bool {
        soundEnabled && volume > 0
    }
}

enum VisualTimerFeedbackCurve {
    static let minimumPulsesPerSecond = 0.72
    static let maximumPulsesPerSecond = 4.20

    static func urgency(_ elapsedProgress: Double) -> Double {
        let progress = clamped(elapsedProgress)
        let exponent = 4.0
        return (exp(exponent * progress) - 1) / (exp(exponent) - 1)
    }

    static func pulsesPerSecond(elapsedProgress: Double) -> Double {
        minimumPulsesPerSecond
            + (maximumPulsesPerSecond - minimumPulsesPerSecond) * urgency(elapsedProgress)
    }

    static func frequency(
        for profile: VisualTimerToneProfile,
        elapsedProgress: Double
    ) -> Double {
        let gradualPitchProgress = pow(clamped(elapsedProgress), 1.65)
        return profile.startFrequency
            * pow(profile.endFrequency / profile.startFrequency, gradualPitchProgress)
    }

    static func signalGain(volume: Double, elapsedProgress: Double) -> Double {
        let boundedVolume = clamped(volume)
        let softCrescendo = 0.72 + 0.28 * urgency(elapsedProgress)
        return clamped(boundedVolume * softCrescendo)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

enum VisualTimerAccessibilityMilestone: String, Equatable, Hashable {
    case oneMinute
    case thirtySeconds
    case tenSeconds
    case fiveSeconds
    case complete

    static func forRemaining(_ remaining: TimeInterval) -> VisualTimerAccessibilityMilestone? {
        if remaining <= 0 { return .complete }
        if remaining <= 5 { return .fiveSeconds }
        if remaining <= 10 { return .tenSeconds }
        if remaining <= 30 { return .thirtySeconds }
        if remaining <= 60 { return .oneMinute }
        return nil
    }

    var announcement: String {
        switch self {
        case .oneMinute: return "One minute remaining."
        case .thirtySeconds: return "Thirty seconds remaining."
        case .tenSeconds: return "Ten seconds remaining."
        case .fiveSeconds: return "Five seconds remaining."
        case .complete: return "Timer complete."
        }
    }
}
