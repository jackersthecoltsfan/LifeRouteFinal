import Foundation

enum VisualTimerToneProfile: String, CaseIterable, Codable, Identifiable {
    case gentle
    case warm
    case clear
    case silent

    static let defaultProfile: VisualTimerToneProfile = .gentle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .warm: return "Warm"
        case .clear: return "Clear"
        case .silent: return "Silent"
        }
    }

    var detail: String {
        switch self {
        case .gentle: return "Soft, rounded pulse"
        case .warm: return "Lower, mellow pulse"
        case .clear: return "Light, focused pulse"
        case .silent: return "Visual feedback only"
        }
    }

    var systemImage: String {
        switch self {
        case .gentle: return "waveform.path"
        case .warm: return "speaker.wave.1.fill"
        case .clear: return "bell.and.waves.left.and.right.fill"
        case .silent: return "speaker.slash.fill"
        }
    }

    var isSilent: Bool { self == .silent }

    var startFrequency: Double {
        switch self {
        case .gentle: return 220.00
        case .warm: return 196.00
        case .clear: return 261.63
        case .silent: return 0
        }
    }

    var endFrequency: Double {
        switch self {
        case .gentle: return 440.00
        case .warm: return 392.00
        case .clear: return 523.25
        case .silent: return 0
        }
    }

    var completionFrequencies: [Double] {
        switch self {
        case .gentle: return [329.63, 392.00, 440.00]
        case .warm: return [293.66, 349.23, 392.00]
        case .clear: return [349.23, 440.00, 523.25]
        case .silent: return []
        }
    }

    var secondHarmonicMix: Double {
        switch self {
        case .gentle: return 0.05
        case .warm: return 0.09
        case .clear: return 0.025
        case .silent: return 0
        }
    }

    var detuneMix: Double {
        switch self {
        case .gentle: return 0.012
        case .warm: return 0.018
        case .clear: return 0.008
        case .silent: return 0
        }
    }
}

struct VisualTimerFeedbackPreferences: Equatable {
    let toneProfile: VisualTimerToneProfile
    let volume: Double
    let completionHapticsEnabled: Bool

    static let `default` = VisualTimerFeedbackPreferences(
        toneProfile: .defaultProfile,
        volume: 0.42,
        completionHapticsEnabled: true
    )
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
        guard !profile.isSilent else { return 0 }
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
