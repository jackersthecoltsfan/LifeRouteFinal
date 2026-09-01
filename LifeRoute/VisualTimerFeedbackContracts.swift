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

    static func allowsThemeFeedback(timerPlaybackActive: Bool) -> Bool {
        !timerPlaybackActive
    }
}

enum VisualTimerFeedbackCurve {
    static let minimumPulsesPerSecond = 0.72
    static let maximumPulsesPerSecond = 4.20
    /// Visual motion stays calm and independent from the accelerating audio
    /// cadence. Urgency changes emphasis, not animation frequency.
    static let visualPulsesPerSecond = 0.80
    static let visualFrameInterval: TimeInterval = 1.0 / 15.0
    static let readoutInterval: TimeInterval = 1.0
    static let pulseSynthesisAmplitude = 0.40
    static let maximumSynthesisSample = 0.92

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
        let softCrescendo = 0.82 + 0.18 * urgency(elapsedProgress)
        return clamped(boundedVolume * softCrescendo)
    }

    /// Uses elapsed time only, so extending the duration cannot snap the pulse
    /// to a different phase. Audio cadence remains independently accelerating.
    static func visualPulsePhase(
        elapsedSeconds: TimeInterval,
        durationSeconds: TimeInterval
    ) -> Double {
        guard durationSeconds > 0 else { return 0 }
        let elapsed = max(0, finite(elapsedSeconds))
        let cycles = visualPulsesPerSecond * elapsed
        let phase = cycles.truncatingRemainder(dividingBy: 1)
        return phase < 0 ? phase + 1 : phase
    }

    /// Cosine easing closes the old sawtooth discontinuity at the wrap point.
    static func visualPulseEnvelope(phase: Double) -> Double {
        let boundedPhase = clamped(phase)
        return 0.5 - 0.5 * cos(2 * Double.pi * boundedPhase)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, finite(value)))
    }

    private static func finite(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }
}

/// A longer, peak-normalized completion cue raises useful speaker energy while
/// keeping every generated sample finite and below digital full scale. The
/// selected tone still owns the three fundamental completion pitches.
enum VisualTimerCompletionCue {
    static let duration: TimeInterval = 1.20
    static let noteOffsets: [TimeInterval] = [0.00, 0.40, 0.80]
    static let noteDuration: TimeInterval = 0.38
    static let attackDuration: TimeInterval = 0.006
    static let releaseStart: TimeInterval = 0.29
    static let decayRate = 0.70
    static let presenceSecondHarmonicMix = 0.12
    static let presenceThirdHarmonicMix = 0.04
    static let playbackTail: TimeInterval = 0.15

    static func samples(
        for profile: VisualTimerToneProfile,
        sampleRate: Double
    ) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 192_000 else {
            return []
        }

        let frameCount = Int((sampleRate * duration).rounded(.down))
        guard frameCount > 0 else { return [] }

        var rawSamples = [Double](repeating: 0, count: frameCount)
        var rawPeak = 0.0

        for frame in rawSamples.indices {
            let time = Double(frame) / sampleRate
            var value = 0.0

            for (offset, frequency) in zip(noteOffsets, profile.completionFrequencies) {
                let localTime = time - offset
                guard localTime >= 0, localTime <= noteDuration else { continue }

                let attack = min(1, localTime / attackDuration)
                let decay = exp(-decayRate * localTime)
                let releaseProgress = max(
                    0,
                    (localTime - releaseStart) / (noteDuration - releaseStart)
                )
                let release = releaseProgress <= 0
                    ? 1
                    : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
                let fundamental = sin(2 * Double.pi * frequency * localTime)
                let second = (profile.secondHarmonicMix + presenceSecondHarmonicMix)
                    * sin(2 * Double.pi * frequency * 2 * localTime)
                let third = presenceThirdHarmonicMix
                    * sin(2 * Double.pi * frequency * 3 * localTime)

                value += (fundamental + second + third) * attack * decay * release
            }

            rawSamples[frame] = value
            rawPeak = max(rawPeak, abs(value))
        }

        guard rawPeak.isFinite, rawPeak > 0 else { return [] }
        let normalizationGain = VisualTimerFeedbackCurve.maximumSynthesisSample / rawPeak
        return rawSamples.map { Float($0 * normalizationGain) }
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
