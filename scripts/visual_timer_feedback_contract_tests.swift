import Foundation

@main
struct VisualTimerFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testToneProfiles()
        testExponentialUrgency()
        testFeedbackBounds()
        testAccessibilityMilestones()
        testPreferenceDefaults()

        print("Visual Timer feedback executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testToneProfiles() {
        expect(VisualTimerToneProfile.allCases == [.warm, .soft, .clear], "audible tone choices remain ordered and bounded")
        expect(VisualTimerToneProfile.defaultProfile == .soft, "Soft is the sensible default audible tone")

        for profile in VisualTimerToneProfile.allCases {
            expect(profile.startFrequency > 0, "\(profile.title) starts above zero Hz")
            expect(profile.endFrequency > profile.startFrequency, "\(profile.title) rises gradually")
            expect(profile.endFrequency <= 523.25, "\(profile.title) avoids the previous harsh high-frequency range")
            expect(profile.completionFrequencies.count == 3, "\(profile.title) has a bounded completion cue")
            expect(profile.completionFrequencies.allSatisfy { $0 <= 523.25 }, "\(profile.title) completion stays soft")
        }
    }

    private static func testExponentialUrgency() {
        let samples = stride(from: 0.0, through: 1.0, by: 0.1).map(VisualTimerFeedbackCurve.urgency)
        expect(abs((samples.first ?? -1) - 0) < 0.000_001, "urgency starts at zero")
        expect(abs((samples.last ?? -1) - 1) < 0.000_001, "urgency ends at one")
        expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 }, "urgency is monotonic")

        let quarters = [0.0, 0.25, 0.5, 0.75, 1.0].map(VisualTimerFeedbackCurve.urgency)
        let deltas = zip(quarters, quarters.dropFirst()).map { $1 - $0 }
        expect(zip(deltas, deltas.dropFirst()).allSatisfy { $0 < $1 }, "late-stage urgency accelerates exponentially")
        expect(VisualTimerFeedbackCurve.urgency(0.5) < 0.25, "the first half remains calm")
    }

    private static func testFeedbackBounds() {
        let profile = VisualTimerToneProfile.soft
        let startRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0)
        let middleRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0.5)
        let endRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 1)
        expect(startRate == VisualTimerFeedbackCurve.minimumPulsesPerSecond, "pulse cadence begins at the lower bound")
        expect(endRate == VisualTimerFeedbackCurve.maximumPulsesPerSecond, "pulse cadence ends at the upper bound")
        expect(middleRate < (startRate + endRate) / 2, "pulse cadence remains restrained through mid-countdown")

        let startPitch = VisualTimerFeedbackCurve.frequency(for: profile, elapsedProgress: 0)
        let middlePitch = VisualTimerFeedbackCurve.frequency(for: profile, elapsedProgress: 0.5)
        let endPitch = VisualTimerFeedbackCurve.frequency(for: profile, elapsedProgress: 1)
        expect(abs(startPitch - profile.startFrequency) < 0.000_001, "pitch begins at the profile start")
        expect(abs(endPitch - profile.endFrequency) < 0.000_001, "pitch ends at the profile ceiling")
        expect(middlePitch < sqrt(startPitch * endPitch), "pitch rises more gradually than the old full-octave sweep")

        expect(VisualTimerFeedbackCurve.signalGain(volume: -1, elapsedProgress: 0.5) == 0, "gain clamps negative volume")
        expect(VisualTimerFeedbackCurve.signalGain(volume: 2, elapsedProgress: 1) == 1, "gain clamps excess volume")
    }

    private static func testAccessibilityMilestones() {
        expect(VisualTimerAccessibilityMilestone.forRemaining(61) == nil, "VoiceOver stays quiet above one minute")
        expect(VisualTimerAccessibilityMilestone.forRemaining(60) == .oneMinute, "one-minute milestone is bounded")
        expect(VisualTimerAccessibilityMilestone.forRemaining(30) == .thirtySeconds, "thirty-second milestone is bounded")
        expect(VisualTimerAccessibilityMilestone.forRemaining(10) == .tenSeconds, "ten-second milestone is bounded")
        expect(VisualTimerAccessibilityMilestone.forRemaining(5) == .fiveSeconds, "five-second milestone is bounded")
        expect(VisualTimerAccessibilityMilestone.forRemaining(0) == .complete, "completion milestone is bounded")
        expect(VisualTimerAccessibilityMilestone.complete.announcement == "Timer complete.", "completion announcement is concise")
    }

    private static func testPreferenceDefaults() {
        let defaults = VisualTimerFeedbackPreferences.default
        expect(defaults.toneProfile == .soft, "preferences default to Soft")
        expect(defaults.soundEnabled, "sound is enabled independently by default")
        expect(defaults.volume == 0.42, "default volume remains restrained")
        expect(defaults.completionHapticsEnabled, "completion haptics remain available by default")

        let mutedWarm = VisualTimerFeedbackPreferences(
            toneProfile: .warm,
            soundEnabled: false,
            volume: defaults.volume,
            completionHapticsEnabled: defaults.completionHapticsEnabled
        )
        expect(mutedWarm.toneProfile == .warm && !mutedWarm.soundEnabled, "disabling sound preserves the selected audible tone")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
