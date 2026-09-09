import Foundation

@main
struct VisualTimerFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testToneProfiles()
        testExponentialUrgency()
        testDurationAwareCrescendo()
        testMaximumDurationCrescendoStability()
        testFeedbackBounds()
        testShortHorizonScheduler()
        testSharedPresentationCadence()
        testUrgencyHapticSubselection()
        testOrganicShimmerWander()
        testVisualRenderingBudget()
        testCompletionCueContract()
        testAccessibilityMilestones()
        testPreferenceDefaults()
        testAudioSessionPolicy()
        testQuickAdjustments()
        testOrbLiquidAreaMapping()

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
            expect(profile.endFrequency <= 785, "\(profile.title) remains within the bounded raised pitch range")
        }

        expect(VisualTimerToneProfile.physicalQAPitchMultiplier == 1.5, "physical QA pitch multiplier is exactly 1.5")
        expect(abs(VisualTimerToneProfile.warm.startFrequency - 294.00) < 0.000_001, "Warm start pitch is raised from 196 Hz to 294 Hz")
        expect(abs(VisualTimerToneProfile.soft.startFrequency - 330.00) < 0.000_001, "Soft start pitch is raised from 220 Hz to 330 Hz")
        expect(abs(VisualTimerToneProfile.clear.startFrequency - 392.445) < 0.000_001, "Clear start pitch is raised from 261.63 Hz to 392.445 Hz")
        expect(abs(VisualTimerToneProfile.soft.endFrequency - 660.00) < 0.000_001, "Soft completion-bound pitch is raised from 440 Hz to 660 Hz")
        expect(abs(VisualTimerToneProfile.clear.endFrequency - 784.875) < 0.000_001, "Clear final tick pitch is raised from 523.25 Hz to 784.875 Hz")
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

    private static func testDurationAwareCrescendo() {
        expect(VisualTimerFeedbackCurve.effectiveExponent(referenceDurationSeconds: 60) == 4,
               "one-minute sessions retain the accepted base exponent")
        expect(VisualTimerFeedbackCurve.effectiveExponent(referenceDurationSeconds: 300) == 20,
               "five-minute sessions use the duration-aware exponent")
        expect(VisualTimerFeedbackCurve.effectiveExponent(referenceDurationSeconds: 600) == 40,
               "ten-minute sessions use the duration-aware exponent")
        for duration in [60.0, 300.0, 600.0] {
            let early = VisualTimerFeedbackCurve.pulsesPerSecond(
                elapsedProgress: 0,
                referenceDurationSeconds: duration
            )
            let late = VisualTimerFeedbackCurve.pulsesPerSecond(
                elapsedProgress: 1,
                referenceDurationSeconds: duration
            )
            expect(early == VisualTimerFeedbackCurve.minimumPulsesPerSecond,
                   "duration-aware curve preserves the lower endpoint for \(duration) seconds")
            expect(late == VisualTimerFeedbackCurve.maximumPulsesPerSecond,
                   "duration-aware curve preserves the seven-Hz endpoint for \(duration) seconds")
            let crossing = remainingSecondsAtContinuousGate(duration: duration)
            expect((15...21).contains(crossing),
                   "the retained urgency-reference rate occurs near the same real-time tail for \(duration) seconds")
        }
        expect(!VisualTimerFeedbackCurve.isContinuousOutputActive(rate: 2.49),
               "the legacy threshold remains available only as an urgency reference")
        expect(VisualTimerFeedbackCurve.isContinuousOutputActive(rate: 2.5),
               "the urgency reference remains exact")
    }

    private static func remainingSecondsAtContinuousGate(duration: TimeInterval) -> Int {
        var lower = 0.0
        var upper = duration
        for _ in 0..<80 {
            let remaining = (lower + upper) / 2
            let elapsed = min(1, max(0, 1 - remaining / duration))
            let rate = VisualTimerFeedbackCurve.pulsesPerSecond(
                elapsedProgress: elapsed,
                referenceDurationSeconds: duration
            )
            if rate >= VisualTimerFeedbackCurve.continuousOutputRate {
                lower = remaining
            } else {
                upper = remaining
            }
        }
        return Int(((lower + upper) / 2).rounded())
    }

    private static func testMaximumDurationCrescendoStability() {
        let duration = 180.0 * 60
        let exponent = VisualTimerFeedbackCurve.effectiveExponent(referenceDurationSeconds: duration)
        expect(exponent == 720, "the configured 180-minute maximum uses the expected duration-scaled exponent")

        let samples = (0...Int(duration)).map { elapsed -> (urgency: Double, rate: Double) in
            let progress = Double(elapsed) / duration
            return (
                VisualTimerFeedbackCurve.urgency(progress, referenceDurationSeconds: duration),
                VisualTimerFeedbackCurve.pulsesPerSecond(
                    elapsedProgress: progress,
                    referenceDurationSeconds: duration
                )
            )
        }
        expect(samples.allSatisfy { $0.urgency.isFinite && $0.urgency >= 0 && $0.urgency <= 1 },
               "180-minute urgency remains finite and bounded")
        expect(samples.allSatisfy { $0.rate.isFinite && $0.rate >= VisualTimerFeedbackCurve.minimumPulsesPerSecond && $0.rate <= VisualTimerFeedbackCurve.maximumPulsesPerSecond },
               "180-minute cadence remains finite within the selected rate bounds")
        expect(zip(samples, samples.dropFirst()).allSatisfy { $0.urgency <= $1.urgency && $0.rate <= $1.rate },
               "180-minute urgency and cadence remain monotonic without precision reversals")
        expect(samples.first?.urgency == 0 && samples.first?.rate == VisualTimerFeedbackCurve.minimumPulsesPerSecond,
               "180-minute cadence preserves the minimum-rate start")
        expect(samples.last?.urgency == 1 && samples.last?.rate == VisualTimerFeedbackCurve.maximumPulsesPerSecond,
               "180-minute cadence preserves the seven-Hz endpoint")

        let crossing = remainingSecondsAtContinuousGate(duration: duration)
        expect((15...21).contains(crossing),
               "180-minute rate gate still opens in the intended real-time tail")
    }

    private static func testFeedbackBounds() {
        let profile = VisualTimerToneProfile.soft
        let startRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0)
        let middleRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0.5)
        let endRate = VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 1)
        expect(startRate == VisualTimerFeedbackCurve.minimumPulsesPerSecond, "pulse cadence begins at the lower bound")
        expect(endRate == VisualTimerFeedbackCurve.maximumPulsesPerSecond, "pulse cadence ends at the upper bound")
        expect(endRate == 7, "seven-tick audition changes only the shared cadence ceiling")
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

    private static func testSharedPresentationCadence() {
        var tracker = VisualTimerPresentationBeatTracker()
        let interval = 1 / VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0.5)
        let first = VisualTimerPresentationBeat(
            VisualTimerScheduledBeat(index: 12, generation: 4, plannedUptime: 40, interval: interval)
        )
        tracker.register(first, at: 40)

        expect(tracker.phase(at: 40) == 0, "shared visual pulse begins on the authoritative audible beat")
        expect(tracker.phase(at: 40 + interval * 0.08) > 0.079, "shared beat phase advances from Orb-local active time")
        let beforeDuplicate = tracker.phase(at: 40 + interval * 0.25)
        tracker.register(first, at: 40 + interval * 0.25)
        expect(tracker.phase(at: 40 + interval * 0.25) == beforeDuplicate, "duplicate beat delivery cannot reset visual phase")

        let skipped = VisualTimerPresentationBeat(
            VisualTimerScheduledBeat(index: 15, generation: 4, plannedUptime: 41, interval: interval * 0.5)
        )
        tracker.register(skipped, at: 41)
        expect(tracker.beatIndex == 15 && tracker.phase(at: 41) == 0, "skipped frames consume only the newest beat without replaying a burst")
        expect(abs(tracker.phase(at: 41 + skipped.interval) - 1) < 0.000_001,
               "pulse phase settles at the end of the current beat interval")
        expect(tracker.phase(at: .nan) == 1, "non-finite presentation time safely produces a settled pulse")
    }

    private static func testUrgencyHapticSubselection() {
        var selector = VisualTimerUrgencyHapticSubselector()
        let interval = 1 / VisualTimerFeedbackCurve.maximumPulsesPerSecond
        let beforeWindow = VisualTimerPresentationBeat(
            VisualTimerScheduledBeat(index: 1, generation: 1, plannedUptime: 10, interval: interval)
        )
        expect(selector.event(for: beforeWindow, remainingSeconds: 15.01) == nil,
               "urgency haptics never begin before the final fifteen seconds")

        var events: [VisualTimerUrgencyHapticEvent] = []
        var selectedBeatTimes: [String: TimeInterval] = [:]
        for index in 2..<212 {
            let beat = VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(
                    index: UInt64(index),
                    generation: 1,
                    plannedUptime: 10 + Double(index - 1) * interval,
                    interval: interval
                )
            )
            let remaining = max(0.01, 15 - Double(index - 2) * interval)
            if let event = selector.event(for: beat, remainingSeconds: remaining) {
                events.append(event)
                selectedBeatTimes["\(event.generation):\(event.index)"] = beat.plannedUptime
            }
        }
        expect(!events.isEmpty, "final-fifteen shared beats produce a bounded haptic subset")
        expect(events.allSatisfy { (VisualTimerUrgencyHapticSubselector.minimumIntensity...VisualTimerUrgencyHapticSubselector.maximumIntensity).contains($0.intensity) },
               "urgency haptic intensity stays within the selected physical audition range")
        expect(VisualTimerUrgencyHapticSubselector.minimumIntensity == 0.50,
               "final-fifteen entry uses the restrained but perceptible soft floor")
        expect(VisualTimerUrgencyHapticSubselector.maximumIntensity == 0.95,
               "urgency remains a soft-generator progression below the distinct heavy completion")
        expect(events.allSatisfy { event in
            selectedBeatTimes["\(event.generation):\(event.index)"] == event.plannedUptime
        }, "selected urgency events retain the shared beat planned due-time")
        expect((events.last?.intensity ?? 0) > (events.first?.intensity ?? 1),
               "urgency haptic intensity increases toward completion")
        let spacings = zip(events, events.dropFirst()).map { $1.plannedUptime - $0.plannedUptime }
        expect(spacings.allSatisfy { $0 >= 1 / VisualTimerUrgencyHapticSubselector.maximumRate * 0.90 },
               "urgency haptics never follow the full seven-Hz audio ceiling")

        selector.invalidate()
        let reentered = VisualTimerPresentationBeat(
            VisualTimerScheduledBeat(index: 0, generation: 2, plannedUptime: 50, interval: interval)
        )
        expect(selector.event(for: reentered, remainingSeconds: 14) != nil,
               "a new valid generation can enter the urgency window without stale suppression")
        expect(selector.event(for: reentered, remainingSeconds: 16) == nil,
               "moving outside the final-fifteen window cancels haptic eligibility")
    }

    private static func testOrganicShimmerWander() {
        let frames = stride(from: 1.5, through: 180.0, by: VisualTimerOrbMotionFrame.interval).map {
            VisualTimerOrbMotionFrame(elapsed: $0, progress: 0.55, urgency: 0.35)
        }
        expect(frames.allSatisfy { $0.driftX.isFinite && $0.driftY.isFinite && $0.sheenX.isFinite },
               "organic shimmer positions remain finite")
        expect(frames.allSatisfy { abs($0.driftX) < 34 && abs($0.driftY) < 21 && $0.sheenX > 48 && $0.sheenX < 292 },
               "organic shimmer remains spatially bounded inside the Orb")
        let steps = zip(frames, frames.dropFirst()).map {
            hypot(Double($1.driftX - $0.driftX), Double($1.driftY - $0.driftY))
        }
        expect(steps.allSatisfy { $0 < 1.1 }, "organic shimmer has no frame-to-frame position jitter")
        let early = Array(frames.prefix(600))
        let delayed = Array(frames.dropFirst(600).prefix(600))
        let repeated = zip(early, delayed).allSatisfy {
            abs($0.driftX - $1.driftX) < 0.15 && abs($0.driftY - $1.driftY) < 0.15
        }
        expect(!repeated, "organic shimmer has no short repeated trajectory loop")
        expect(VisualTimerOrbMotionFrame.still == VisualTimerOrbMotionFrame(elapsed: 0, progress: 0, urgency: 0),
               "Reduce Motion retains the accepted static shimmer frame")
    }

    private static func testShortHorizonScheduler() {
        let rate: (TimeInterval) -> Double = { _ in VisualTimerFeedbackCurve.maximumPulsesPerSecond }
        var scheduler = VisualTimerFeedbackScheduler()
        let initial = scheduler.begin(at: 100, remainingSeconds: 60, rate: rate)
        expect(initial.scheduled.count == 2 && initial.skipped.isEmpty, "planner predicts exactly two initial beats")
        expect(scheduler.queued.count == 2, "planner retains no more than two queued beats")
        expect(initial.scheduled[0].plannedUptime > 100, "first planned beat is ahead of the monotonic scheduling instant")
        expect(initial.scheduled[1].plannedUptime > initial.scheduled[0].plannedUptime,
               "short-horizon prediction keeps future beats ordered")
        expect(
            initial.scheduled[1].plannedUptime - 100
                <= 2 / VisualTimerFeedbackCurve.maximumPulsesPerSecond + 0.000_001,
            "initial planning horizon stays within two current-ceiling intervals"
        )
        expect(
            abs(VisualTimerFeedbackScheduler.lateThreshold() - 1 / (2 * VisualTimerFeedbackCurve.maximumPulsesPerSecond)) < 0.000_001,
            "late threshold is derived from the selected ceiling"
        )
        expect(
            abs(VisualTimerFeedbackScheduler.lateThreshold() - 1 / 14) < 0.000_001,
            "seven-tick late threshold is the derived 71.43 milliseconds, not a magic constant"
        )

        let obsolete = scheduler.invalidatePreservingPhase()
        let replacement = scheduler.replenish(at: 100, remainingSeconds: 45, rate: rate)
        expect(obsolete.count == 2 && replacement.scheduled.count == 2,
               "state replacement cancels the old short queue and rederives two beats")
        expect(replacement.scheduled[0].plannedUptime == obsolete[0].plannedUptime,
               "time adjustment retains the next shared phase anchor")
        expect(!scheduler.accepts(obsolete[0]) && scheduler.accepts(replacement.scheduled[0]),
               "new generation rejects obsolete callbacks without restarting phase")

        let paused = scheduler.pause(at: 100.01)
        let resumed = scheduler.resume(at: 200, remainingSeconds: 45, rate: rate)
        expect(!paused.isEmpty && resumed.scheduled.count == 2,
               "pause cancels real future plans and resume restores a bounded queue")
        expect(resumed.scheduled[0].plannedUptime > 200,
               "resume retains a forward phase delay instead of replaying an old beat")

        _ = scheduler.invalidatePreservingPhase()
        let delayed = scheduler.replenish(at: 205, remainingSeconds: 40, rate: rate)
        expect(!delayed.skipped.isEmpty && delayed.scheduled.count == 2,
               "delayed replan skips overdue beats and restores only the future short queue")
        expect(
            delayed.scheduled.allSatisfy { $0.plannedUptime >= 205 - VisualTimerFeedbackScheduler.lateThreshold() },
            "late scheduling never emits an accumulated historical beat burst"
        )
    }

    private static func testVisualRenderingBudget() {
        let samplesPerFastestCycle = (1 / VisualTimerOrbMotionFrame.interval)
            / VisualTimerFeedbackCurve.maximumPulsesPerSecond
        expect(samplesPerFastestCycle >= 4, "seven-tick pulse retains four 30 Hz samples for bounded audition review")
        expect(VisualTimerFeedbackCurve.readoutInterval == 1, "timer readout uses a bounded one-second cadence")

        let phases = stride(from: 0.0, through: 1.0, by: 0.025)
        let envelopes = phases.map(VisualTimerFeedbackCurve.presentationPulseEnvelope)
        expect(envelopes.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, "visual pulse envelope is finite and bounded")
        expect(abs(VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: 0) - 1) < 0.000_001, "spatial pressure crests at the scheduled audible onset")
        expect(abs(VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: -0.00001) - VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: 0.00001)) < 0.000_001, "anticipation and release meet continuously at the beat")
        expect(abs(VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: 1)) < 0.000_001, "visual pulse settles before the next beat")
        expect(VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: .infinity) == 0, "non-finite pulse phase is safely bounded")
    }

    private static func testCompletionCueContract() {
        let beats = VisualTimerCompletionCue.hapticBeatMap
        expect(VisualTimerCompletionCue.resourceName == "TimerCompletionCue", "completion cue loads from the dedicated bundled data asset")
        expect(VisualTimerCompletionCue.sourceFilename == "TIMER_SOUND_3s.wav", "completion cue retains Brandon's supplied filename")
        expect(VisualTimerCompletionCue.approvedSourceSHA256 == "ddde780da9eb13cc1b7f00f0f7ba03d7f4bd50e8f480574078fd20092174e52b", "completion cue declares the approved source hash")
        expect(VisualTimerCompletionCue.duration == 3, "supplied completion cue remains exactly three seconds")
        expect(VisualTimerCompletionCue.sampleRate == 44_100, "supplied completion cue remains 44.1 kHz")
        expect(VisualTimerCompletionCue.channelCount == 2 && VisualTimerCompletionCue.bitDepth == 24, "supplied completion cue remains stereo 24-bit PCM")
        expect(VisualTimerCompletionCue.frameCount == 132_300 && VisualTimerCompletionCue.pcmByteCount == 793_800, "supplied completion cue retains its exact PCM frame and byte counts")
        expect(VisualTimerCompletionCue.playbackTail >= 0.15, "audio ownership retains a bounded post-playback cleanup tail")
        expect(beats.count == 4, "completion celebration uses a bounded four-attack haptic map")
        expect(beats.map(\.cueOffset) == [0, 0.96, 1.68, 2.27], "completion haptics follow the selected source attacks")
        expect(beats.map(\.intensity) == [0.70, 0.76, 0.84, 1.00], "completion haptics resolve with the intended restrained-to-strong progression")
        expect(beats.allSatisfy { $0.cueOffset >= 0 && $0.cueOffset < VisualTimerCompletionCue.duration }, "completion haptic offsets remain inside the audio cue")
        expect(zip(beats, beats.dropFirst()).allSatisfy { $1.cueOffset - $0.cueOffset >= 0.5 }, "completion haptics never become continuous vibration")
        expect(beats.last?.intensity == 1, "the final selected source attack owns the resolved completion impact")
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

    private static func testQuickAdjustments() {
        let now = Date(timeIntervalSince1970: 10_000)
        let runningDeadline = now.addingTimeInterval(60)
        let runningPlus = VisualTimerAdjustment.apply(
            deadline: runningDeadline,
            pausedRemainingSeconds: 60,
            by: VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(VisualTimerAdjustment.quickAdjustmentSeconds == 15, "quick timer adjustment is exactly fifteen seconds")
        expect(runningPlus.remainingSeconds == 75, "running +15 sec adds exactly fifteen seconds")
        expect(runningPlus.deadline == now.addingTimeInterval(75), "running +15 sec moves the existing deadline by fifteen seconds")
        expect(!runningPlus.shouldUseCompletionPath, "running +15 sec does not enter completion")

        let runningMinus = VisualTimerAdjustment.apply(
            deadline: runningDeadline,
            pausedRemainingSeconds: 60,
            by: -VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(runningMinus.remainingSeconds == 45, "running −15 sec removes exactly fifteen seconds")
        expect(runningMinus.deadline == now.addingTimeInterval(45), "running −15 sec moves the existing deadline earlier")

        let pausedMinus = VisualTimerAdjustment.apply(
            deadline: nil,
            pausedRemainingSeconds: 60,
            by: -VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(pausedMinus.remainingSeconds == 45 && pausedMinus.deadline == nil, "paused −15 sec updates paused remaining time without creating a deadline")

        let readyPlus = VisualTimerAdjustment.apply(
            deadline: nil,
            pausedRemainingSeconds: 0,
            by: VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(readyPlus.remainingSeconds == 15 && readyPlus.deadline == nil, "ready +15 sec remains a coherent paused value")

        let runningNearZero = VisualTimerAdjustment.apply(
            deadline: now.addingTimeInterval(10),
            pausedRemainingSeconds: 10,
            by: -VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(runningNearZero.remainingSeconds == 0, "running near-zero −15 sec clamps remaining time to zero")
        expect(runningNearZero.deadline == now && runningNearZero.shouldUseCompletionPath, "running completion-edge adjustment uses the existing deadline completion path")

        let pausedNearZero = VisualTimerAdjustment.apply(
            deadline: nil,
            pausedRemainingSeconds: 10,
            by: -VisualTimerAdjustment.quickAdjustmentSeconds,
            now: now
        )
        expect(pausedNearZero.remainingSeconds == 0, "paused near-zero −15 sec clamps remaining time to zero")
        expect(pausedNearZero.deadline == nil && pausedNearZero.shouldUseCompletionPath, "paused completion-edge adjustment requests the existing completion path")

        let belowZero = VisualTimerAdjustment.apply(
            deadline: nil,
            pausedRemainingSeconds: 1,
            by: -60,
            now: now
        )
        expect(belowZero.remainingSeconds == 0, "large negative adjustment never produces a negative remaining value")
    }

    private static func testOrbLiquidAreaMapping() {
        let progressValues = [0.0, 0.10, 0.25, 0.50, 0.75, 0.98, 1.0]
        let surfaces = progressValues.map {
            VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: CGFloat($0))
        }

        expect(surfaces.allSatisfy { $0.isFinite }, "liquid surfaces remain finite")
        expect(
            surfaces.allSatisfy {
                $0 >= VisualTimerOrbLiquidGeometry.wellCenter - VisualTimerOrbLiquidGeometry.wellRadius
                    && $0 <= VisualTimerOrbLiquidGeometry.wellCenter + VisualTimerOrbLiquidGeometry.wellRadius
            },
            "liquid surfaces remain within the circular well"
        )
        expect(surfaces == surfaces.sorted(by: >), "liquid surface rises monotonically as remaining area increases")
        expect(
            VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: 0) == 316,
            "zero progress reaches the bottom of the liquid well"
        )
        expect(
            VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: 1) == 24,
            "full progress reaches the top of the liquid well"
        )
        expect(
            abs(VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: 0.5) - 170) < 0.001,
            "half area places the surface through the circular well center"
        )

        for progress in progressValues {
            let surface = VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: CGFloat(progress))
            let normalizedHeight = (surface - VisualTimerOrbLiquidGeometry.wellCenter)
                / VisualTimerOrbLiquidGeometry.wellRadius
            let areaFraction = 0.5 - (
                (asin(normalizedHeight) + normalizedHeight * sqrt(max(0, 1 - (normalizedHeight * normalizedHeight))))
                / CGFloat.pi
            )
            expect(
                abs(areaFraction - CGFloat(progress)) < 0.000_01,
                "solved surface preserves the requested circular area at \(progress)"
            )
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
