import Foundation

@main
struct VisualTimerFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testToneProfiles()
        testExponentialUrgency()
        testFeedbackBounds()
        testVisualPulsePhase()
        testVisualRenderingBudget()
        testCompletionOutputBudget()
        testSpeakerEffectiveCompletionSpectrum()
        testAccessibilityMilestones()
        testPreferenceDefaults()
        testAudioSessionPolicy()

        precondition(
            assertionCount >= 119,
            "Visual Timer regression floor requires at least 119 assertions; found \(assertionCount)."
        )
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
        expect(VisualTimerFeedbackCurve.pulseSynthesisAmplitude <= 0.5, "pulse synthesis remains pleasantly bounded")
        expect(VisualTimerFeedbackCurve.maximumSynthesisSample < 1, "synthesized completion retains clipping headroom")
    }

    private static func testVisualPulsePhase() {
        let phases = stride(from: 0.0, through: 300.0, by: 0.25).map {
            VisualTimerFeedbackCurve.visualPulsePhase(
                elapsedSeconds: $0,
                durationSeconds: 300
            )
        }
        expect(phases.allSatisfy { $0 >= 0 && $0 < 1 }, "timer-relative visual phase stays within one cycle")
        expect(
            VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: -5, durationSeconds: 300) == 0,
            "visual phase clamps negative elapsed time"
        )
        expect(
            VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: 12, durationSeconds: 0) == 0,
            "visual phase handles an invalid duration safely"
        )

        let before = VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: 120, durationSeconds: 300)
        let after = VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: 120.01, durationSeconds: 300)
        let directDistance = abs(after - before)
        let wrappedDistance = min(directDistance, 1 - directDistance)
        expect(wrappedDistance < 0.05, "timer-relative pulse advances continuously between display frames")
        expect(
            before == VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: 120, durationSeconds: 300),
            "paused visual phase stays stable without depending on wall-clock time"
        )
        expect(
            before == VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: 120, durationSeconds: 360),
            "adding one minute preserves the current visual pulse phase"
        )
        expect(
            VisualTimerFeedbackCurve.visualPulsePhase(elapsedSeconds: .nan, durationSeconds: 300) == 0,
            "non-finite elapsed time cannot reach the renderer"
        )
    }

    private static func testVisualRenderingBudget() {
        let samplesPerCycle = (1 / VisualTimerFeedbackCurve.visualFrameInterval)
            / VisualTimerFeedbackCurve.visualPulsesPerSecond
        expect(samplesPerCycle >= 15, "localized visual pulse retains at least fifteen samples per cycle")
        expect(VisualTimerFeedbackCurve.readoutInterval == 1, "timer readout uses a bounded one-second cadence")
        expect(VisualTimerFeedbackCurve.visualPulsesPerSecond <= 1, "visual motion remains calm while audio cadence accelerates independently")

        let phases = stride(from: 0.0, through: 1.0, by: 0.025)
        let envelopes = phases.map(VisualTimerFeedbackCurve.visualPulseEnvelope)
        expect(envelopes.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, "visual pulse envelope is finite and bounded")
        expect(abs(VisualTimerFeedbackCurve.visualPulseEnvelope(phase: 0)) < 0.000_001, "visual pulse wrap begins continuously at rest")
        expect(abs(VisualTimerFeedbackCurve.visualPulseEnvelope(phase: 1)) < 0.000_001, "visual pulse wrap ends continuously at rest")
        expect(abs(VisualTimerFeedbackCurve.visualPulseEnvelope(phase: 0.5) - 1) < 0.000_001, "visual pulse reaches one smooth midpoint peak")
        expect(VisualTimerFeedbackCurve.visualPulseEnvelope(phase: .infinity) == 0, "non-finite pulse phase is safely bounded")
    }

    private static func testCompletionOutputBudget() {
        let sampleRate = 44_100.0
        let newSamples = VisualTimerToneProfile.allCases.map {
            VisualTimerCompletionCue.samples(for: $0, sampleRate: sampleRate)
        }
        let newMetrics = newSamples.map(sampleMetrics)
        let build120Metrics = VisualTimerToneProfile.allCases.map {
            build120CompletionMetrics(profile: $0, sampleRate: sampleRate)
        }
        let build122Metrics = VisualTimerToneProfile.allCases.map {
            build122CompletionMetrics(profile: $0, sampleRate: sampleRate)
        }

        expect(
            newSamples.allSatisfy {
                $0.count == Int(sampleRate * VisualTimerCompletionCue.duration)
            },
            "completion cue duration remains deterministic and bounded"
        )
        expect(
            newSamples.allSatisfy { $0.allSatisfy(\.isFinite) },
            "every completion sample remains finite"
        )
        expect(
            newMetrics.allSatisfy {
                abs($0.peak - VisualTimerFeedbackCurve.maximumSynthesisSample) < 0.000_01
            },
            "maximum completion output uses the retained digital headroom"
        )
        expect(
            newMetrics.allSatisfy { $0.rms >= 0.65 },
            "completion cue carries calibrated sustained output instead of relying on isolated peaks"
        )
        expect(
            newMetrics.allSatisfy { $0.peak / $0.rms <= 1.42 },
            "completion cue crest factor stays bounded for useful perceived loudness"
        )
        expect(
            zip(newMetrics, build120Metrics).allSatisfy { $0.rms / $1.rms > 1.90 },
            "maximum completion RMS is at least ninety percent stronger than Build 120"
        )
        expect(
            zip(newMetrics, build120Metrics).allSatisfy { $0.energy / $1.energy > 8.5 },
            "maximum completion cue carries more than eight times Build 120 signal energy"
        )
        expect(
            zip(newMetrics, build122Metrics).allSatisfy { $0.rms / $1.rms > 1.16 },
            "maximum completion RMS is measurably stronger than Build 122 on every tone"
        )
        expect(
            zip(newMetrics, build122Metrics).allSatisfy { $0.energy / $1.energy > 2.45 },
            "the mastered completion pattern carries more than twice Build 122 total signal energy"
        )
        expect(
            newSamples.allSatisfy { strongSampleFraction(in: $0) >= 0.64 },
            "at least sixty-four percent of the cue carries half-scale-or-stronger output"
        )
        expect(
            newSamples.allSatisfy {
                longestNearPeakRun(in: $0) <= 2
            },
            "peak normalization does not introduce a clipped plateau"
        )
        expect(
            VisualTimerCompletionCue.noteOffsets.count == 5,
            "one completion event contains a bounded five-note alert pattern"
        )
        expect(
            VisualTimerCompletionCue.notePitchIndices == [0, 1, 2, 1, 2],
            "the repeated alert pattern preserves the selected three-pitch identity"
        )
        expect(
            VisualTimerCompletionCue.softLimiterDrive >= 1.25
                && VisualTimerCompletionCue.softLimiterDrive <= 1.60,
            "soft limiting raises average energy without an extreme distortion drive"
        )
        expect(
            VisualTimerCompletionCue.duration >= 2.0 && VisualTimerCompletionCue.duration <= 2.2,
            "completion sustains useful output for a bounded alert-length window"
        )
        expect(
            VisualTimerCompletionCue.noteDuration <= 0.42,
            "completion notes remain separated instead of overlapping into excess gain"
        )
        expect(
            VisualTimerCompletionCue.samples(for: .soft, sampleRate: 0).isEmpty
                && VisualTimerCompletionCue.samples(for: .soft, sampleRate: .infinity).isEmpty,
            "invalid sample rates fail silently and deterministically"
        )
        expect(VisualTimerFeedbackCurve.maximumSynthesisSample < 1, "stronger completion output cannot reach digital full scale")
    }

    // Build 122: broadband RMS alone did not predict physical iPhone output.
    // Every repeated completion note must carry a musically related upper-mid
    // partial while retaining the selected profile's fundamental identity.
    private static func testSpeakerEffectiveCompletionSpectrum() {
        let sampleRate = 44_100.0
        expect(
            zip(VisualTimerCompletionCue.noteOffsets, VisualTimerCompletionCue.noteOffsets.dropFirst())
                .allSatisfy { $1 - $0 >= VisualTimerCompletionCue.noteDuration },
            "completion notes never overlap into duplicate gain"
        )
        expect(
            (VisualTimerCompletionCue.noteOffsets.last ?? 0) + VisualTimerCompletionCue.noteDuration
                <= VisualTimerCompletionCue.duration,
            "the full repeated completion envelope fits before playback ends"
        )
        expect(
            VisualTimerCompletionCue.playbackTail >= 0.15,
            "the audio engine retains a bounded tail after the final envelope"
        )

        var profileWaveforms: [[Float]] = []
        for profile in VisualTimerToneProfile.allCases {
            let samples = VisualTimerCompletionCue.samples(for: profile, sampleRate: sampleRate)
            profileWaveforms.append(samples)
            for (offset, frequency) in zip(
                VisualTimerCompletionCue.noteOffsets,
                VisualTimerCompletionCue.noteFrequencies(for: profile)
            ) {
                let fundamental = spectralProjection(
                    samples,
                    sampleRate: sampleRate,
                    offset: offset,
                    duration: VisualTimerCompletionCue.noteDuration,
                    frequency: frequency
                )
                let fourthPartial = spectralProjection(
                    samples,
                    sampleRate: sampleRate,
                    offset: offset,
                    duration: VisualTimerCompletionCue.noteDuration,
                    frequency: frequency * 4
                )
                expect(
                    fundamental > 0 && fourthPartial / fundamental >= 0.09,
                    "\(profile.title) repeats speaker-effective upper-mid energy on every completion note"
                )
                expect(
                    frequency * 4 >= 1_100 && frequency * 4 <= 2_100,
                    "\(profile.title) fourth partial remains in a bounded iPhone-speaker-effective range"
                )
            }
        }
        expect(profileWaveforms[0] != profileWaveforms[1], "Warm and Soft completion identities remain distinct")
        expect(profileWaveforms[1] != profileWaveforms[2], "Soft and Clear completion identities remain distinct")
    }

    private static func build120CompletionMetrics(
        profile: VisualTimerToneProfile,
        sampleRate: Double
    ) -> (peak: Double, rms: Double, energy: Double) {
        let sampleCount = Int(sampleRate * 0.52)
        let notes = zip([0.00, 0.15, 0.30], profile.completionFrequencies)
        var peak = 0.0
        var energy = 0.0

        for frame in 0..<sampleCount {
            let t = Double(frame) / sampleRate
            var value = 0.0
            for note in notes {
                let localTime = t - note.0
                guard localTime >= 0, localTime <= 0.19 else { continue }
                let attack = min(1, localTime / 0.012)
                let decay = exp(-12 * localTime)
                let releaseProgress = max(0, (localTime - 0.12) / 0.07)
                let release = releaseProgress <= 0
                    ? 1
                    : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
                let fundamental = sin(2 * Double.pi * note.1 * localTime)
                let second = profile.secondHarmonicMix
                    * sin(2 * Double.pi * note.1 * 2 * localTime)
                value += (fundamental + second) * attack * decay * release * 0.84
            }
            value = max(
                -VisualTimerFeedbackCurve.maximumSynthesisSample,
                min(VisualTimerFeedbackCurve.maximumSynthesisSample, value)
            )
            peak = max(peak, abs(value))
            energy += value * value
        }
        return (peak, sqrt(energy / Double(sampleCount)), energy)
    }

    private static func build122CompletionMetrics(
        profile: VisualTimerToneProfile,
        sampleRate: Double
    ) -> (peak: Double, rms: Double, energy: Double) {
        let duration = 1.20
        let noteOffsets = [0.00, 0.40, 0.80]
        let noteDuration = 0.38
        let attackDuration = 0.006
        let releaseStart = 0.29
        let decayRate = 0.70
        let sampleCount = Int(sampleRate * duration)
        var rawSamples = [Double](repeating: 0, count: sampleCount)
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
                let second = (profile.secondHarmonicMix + 0.12)
                    * sin(2 * Double.pi * frequency * 2 * localTime)
                let third = 0.12 * sin(2 * Double.pi * frequency * 3 * localTime)
                let fourth = 0.12 * sin(2 * Double.pi * frequency * 4 * localTime)
                value += (fundamental + second + third + fourth) * attack * decay * release
            }
            rawSamples[frame] = value
            rawPeak = max(rawPeak, abs(value))
        }

        let gain = VisualTimerFeedbackCurve.maximumSynthesisSample / rawPeak
        let values = rawSamples.map { $0 * gain }
        let energy = values.reduce(0) { $0 + $1 * $1 }
        return (
            values.map(abs).max() ?? 0,
            sqrt(energy / Double(values.count)),
            energy
        )
    }

    private static func sampleMetrics(_ samples: [Float]) -> (peak: Double, rms: Double, energy: Double) {
        let values = samples.map(Double.init)
        let energy = values.reduce(0) { $0 + $1 * $1 }
        return (
            values.map(abs).max() ?? 0,
            values.isEmpty ? 0 : sqrt(energy / Double(values.count)),
            energy
        )
    }

    private static func longestNearPeakRun(in samples: [Float]) -> Int {
        let threshold = Float(VisualTimerFeedbackCurve.maximumSynthesisSample * 0.999)
        var longest = 0
        var current = 0
        for sample in samples {
            if abs(sample) >= threshold {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func strongSampleFraction(in samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let threshold = Float(VisualTimerFeedbackCurve.maximumSynthesisSample * 0.5)
        let strongSamples = samples.lazy.filter { abs($0) >= threshold }.count
        return Double(strongSamples) / Double(samples.count)
    }

    private static func spectralProjection(
        _ samples: [Float],
        sampleRate: Double,
        offset: TimeInterval,
        duration: TimeInterval,
        frequency: Double
    ) -> Double {
        let start = max(0, Int((offset * sampleRate).rounded(.down)))
        let end = min(samples.count, Int(((offset + duration) * sampleRate).rounded(.down)))
        guard start < end else { return 0 }

        var real = 0.0
        var imaginary = 0.0
        for frame in start..<end {
            let localTime = Double(frame - start) / sampleRate
            let angle = 2 * Double.pi * frequency * localTime
            let sample = Double(samples[frame])
            real += sample * cos(angle)
            imaginary -= sample * sin(angle)
        }
        return hypot(real, imaginary) / Double(end - start)
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

    private static func testAudioSessionPolicy() {
        expect(
            VisualTimerAudioSessionPolicy.playsThroughRingSilentSwitch,
            "timer playback remains audible when the Ring/Silent switch is Silent"
        )
        expect(
            VisualTimerAudioSessionPolicy.mixesWithOtherAudio,
            "timer playback mixes instead of unnecessarily interrupting other audio"
        )
        expect(
            VisualTimerAudioSessionPolicy.shouldActivate(soundEnabled: true, volume: 0.42),
            "enabled timer sound with positive volume activates playback"
        )
        expect(
            !VisualTimerAudioSessionPolicy.shouldActivate(soundEnabled: false, volume: 0.42),
            "LifeRoute Sound Off remains authoritative"
        )
        expect(
            !VisualTimerAudioSessionPolicy.shouldActivate(soundEnabled: true, volume: 0),
            "zero percent volume remains silent"
        )
        expect(
            VisualTimerAudioSessionPolicy.allowsThemeFeedback(timerPlaybackActive: false),
            "optional theme feedback may play when timer playback is inactive"
        )
        expect(
            !VisualTimerAudioSessionPolicy.allowsThemeFeedback(timerPlaybackActive: true),
            "timer playback ownership prevents a theme sound from downgrading the audio session"
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
