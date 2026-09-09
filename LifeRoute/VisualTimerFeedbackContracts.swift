import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum VisualTimerToneProfile: String, CaseIterable, Codable, Identifiable {
    case warm
    case soft
    case clear

    static let defaultProfile: VisualTimerToneProfile = .soft
    static let physicalQAPitchMultiplier = 1.5

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
        case .warm: return 196.00 * Self.physicalQAPitchMultiplier
        case .soft: return 220.00 * Self.physicalQAPitchMultiplier
        case .clear: return 261.63 * Self.physicalQAPitchMultiplier
        }
    }

    var endFrequency: Double {
        switch self {
        case .warm: return 392.00 * Self.physicalQAPitchMultiplier
        case .soft: return 440.00 * Self.physicalQAPitchMultiplier
        case .clear: return 523.25 * Self.physicalQAPitchMultiplier
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
    static let maximumPulsesPerSecond = 7.0
    static let baseExponent = 4.0
    static let referenceDurationSeconds: TimeInterval = 60
    static let continuousOutputRate = 2.5
    static let readoutInterval: TimeInterval = 1.0
    static let pulseSynthesisAmplitude = 0.40
    static let maximumSynthesisSample = 0.92

    static func effectiveExponent(referenceDurationSeconds: TimeInterval) -> Double {
        let duration = referenceDurationSeconds.isFinite ? max(0, referenceDurationSeconds) : 0
        return baseExponent * max(1, duration / Self.referenceDurationSeconds)
    }

    static func urgency(_ elapsedProgress: Double) -> Double {
        urgency(elapsedProgress, referenceDurationSeconds: referenceDurationSeconds)
    }

    static func urgency(
        _ elapsedProgress: Double,
        referenceDurationSeconds: TimeInterval
    ) -> Double {
        let progress = clamped(elapsedProgress)
        let exponent = effectiveExponent(referenceDurationSeconds: referenceDurationSeconds)
        // Algebraically equivalent to (exp(exponent * progress) - 1)
        // / (exp(exponent) - 1), but keeps the normalized curve finite at the
        // supported 180-minute reference duration (exponent == 720).
        let numerator = exp(-exponent * (1 - progress)) * -expm1(-exponent * progress)
        let denominator = -expm1(-exponent)
        return clamped(numerator / denominator)
    }

    static func pulsesPerSecond(
        elapsedProgress: Double,
        referenceDurationSeconds: TimeInterval
    ) -> Double {
        minimumPulsesPerSecond
            + (maximumPulsesPerSecond - minimumPulsesPerSecond)
                * urgency(elapsedProgress, referenceDurationSeconds: referenceDurationSeconds)
    }

    static func pulsesPerSecond(elapsedProgress: Double) -> Double {
        pulsesPerSecond(
            elapsedProgress: elapsedProgress,
            referenceDurationSeconds: referenceDurationSeconds
        )
    }

    static func isContinuousOutputActive(rate: Double) -> Bool {
        rate.isFinite && rate >= continuousOutputRate
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

    /// One soft internal-pressure envelope shared by every visual consumer of
    /// the authoritative presentation beat. The early peak follows the short
    /// audio attack without turning the Orb into a strobe.
    static func presentationPulseEnvelope(phase: Double) -> Double {
        // The pressure crest coincides with the planned beat. The preceding
        // half-cycle anticipates that event; the following half releases it.
        // A raised cosine has continuous position and velocity at crest/rest.
        guard phase.isFinite, abs(phase) < 0.5 else { return 0 }
        return 0.5 + 0.5 * cos(2 * .pi * phase)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, finite(value)))
    }

    private static func finite(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func smooth(_ value: Double) -> Double {
        let value = clamped(value)
        return value * value * (3 - 2 * value)
    }
}

/// A single phase-derived event shared by the audio queue and Orb presentation.
/// `plannedUptime` is ProcessInfo.systemUptime seconds, not a countdown clock.
struct VisualTimerScheduledBeat: Equatable, Hashable {
    let index: UInt64
    let generation: UInt64
    let plannedUptime: TimeInterval
    let interval: TimeInterval
}

struct VisualTimerFeedbackScheduleUpdate: Equatable {
    let scheduled: [VisualTimerScheduledBeat]
    let skipped: [VisualTimerScheduledBeat]
}

/// Keeps exactly one or two future presentation beats derived from the
/// authoritative deadline. This structure never owns remaining time: callers
/// provide it from VisualTimerCore at each replenish point.
struct VisualTimerFeedbackScheduler {
    static let maximumQueuedBeats = 2

    private(set) var generation: UInt64 = 0
    private(set) var queued: [VisualTimerScheduledBeat] = []
    private(set) var nextBeatUptime: TimeInterval?
    private(set) var nextBeatIndex: UInt64 = 0
    private var pausedPhaseDelay: TimeInterval?

    static func lateThreshold(ceilingRate: Double = VisualTimerFeedbackCurve.maximumPulsesPerSecond) -> TimeInterval {
        guard ceilingRate.isFinite, ceilingRate > 0 else { return 0 }
        return 1 / (2 * ceilingRate)
    }

    mutating func begin(
        at uptime: TimeInterval,
        remainingSeconds: TimeInterval,
        rate: (TimeInterval) -> Double
    ) -> VisualTimerFeedbackScheduleUpdate {
        generation &+= 1
        queued.removeAll()
        nextBeatIndex = 0
        pausedPhaseDelay = nil
        nextBeatUptime = uptime + interval(forRemaining: remainingSeconds, rate: rate)
        return replenish(at: uptime, remainingSeconds: remainingSeconds, rate: rate)
    }

    /// Removes future plans for an obsolete timer state but intentionally keeps
    /// the next phase anchor. A replacement rate can therefore rederive future
    /// beats without snapping the shared phase.
    mutating func invalidatePreservingPhase() -> [VisualTimerScheduledBeat] {
        let obsolete = queued
        if let first = obsolete.first {
            nextBeatUptime = first.plannedUptime
        }
        queued.removeAll()
        generation &+= 1
        return obsolete
    }

    mutating func pause(at uptime: TimeInterval) -> [VisualTimerScheduledBeat] {
        let obsolete = invalidatePreservingPhase()
        if let nextBeatUptime {
            pausedPhaseDelay = max(0, nextBeatUptime - uptime)
        }
        return obsolete
    }

    mutating func resume(
        at uptime: TimeInterval,
        remainingSeconds: TimeInterval,
        rate: (TimeInterval) -> Double
    ) -> VisualTimerFeedbackScheduleUpdate {
        let preservedDelay = pausedPhaseDelay
        pausedPhaseDelay = nil
        if let preservedDelay, preservedDelay.isFinite {
            nextBeatUptime = uptime + max(0, preservedDelay)
        } else {
            nextBeatUptime = uptime + interval(forRemaining: remainingSeconds, rate: rate)
        }
        return replenish(at: uptime, remainingSeconds: remainingSeconds, rate: rate)
    }

    mutating func stop() -> [VisualTimerScheduledBeat] {
        let obsolete = queued
        queued.removeAll()
        nextBeatUptime = nil
        pausedPhaseDelay = nil
        generation &+= 1
        return obsolete
    }

    mutating func replenish(
        at uptime: TimeInterval,
        remainingSeconds: TimeInterval,
        rate: (TimeInterval) -> Double
    ) -> VisualTimerFeedbackScheduleUpdate {
        guard uptime.isFinite, remainingSeconds.isFinite, remainingSeconds > 0 else {
            return VisualTimerFeedbackScheduleUpdate(scheduled: [], skipped: [])
        }

        // These beats were already delivered to the native audio player and the
        // visual driver. Retiring bookkeeping must never re-emit them.
        queued.removeAll { $0.plannedUptime <= uptime }

        if nextBeatUptime == nil {
            nextBeatUptime = uptime + interval(forRemaining: remainingSeconds, rate: rate)
        }

        var scheduled: [VisualTimerScheduledBeat] = []
        var skipped: [VisualTimerScheduledBeat] = []
        let lateThreshold = Self.lateThreshold()

        while queued.count < Self.maximumQueuedBeats,
              let plannedUptime = nextBeatUptime {
            let futureRemaining = VisualTimerDuration.clamp(remainingSeconds - max(0, plannedUptime - uptime))
            guard futureRemaining > 0 else { break }
            let interval = interval(forRemaining: futureRemaining, rate: rate)
            let beat = VisualTimerScheduledBeat(
                index: nextBeatIndex,
                generation: generation,
                plannedUptime: plannedUptime,
                interval: interval
            )
            nextBeatIndex &+= 1
            nextBeatUptime = plannedUptime + interval

            if plannedUptime < uptime - lateThreshold {
                skipped.append(beat)
            } else {
                queued.append(beat)
                scheduled.append(beat)
            }
        }

        return VisualTimerFeedbackScheduleUpdate(scheduled: scheduled, skipped: skipped)
    }

    func accepts(_ beat: VisualTimerScheduledBeat) -> Bool {
        beat.generation == generation
    }

    private func interval(
        forRemaining remainingSeconds: TimeInterval,
        rate: (TimeInterval) -> Double
    ) -> TimeInterval {
        let pulsesPerSecond = rate(max(0, remainingSeconds))
        guard pulsesPerSecond.isFinite, pulsesPerSecond > 0 else { return 1 }
        return 1 / pulsesPerSecond
    }
}

/// The audible scheduler publishes this event whether Sound is on or off.
/// Visual consumers use the planned time rather than the earlier enqueue time.
struct VisualTimerPresentationBeat: Equatable {
    let index: UInt64
    let generation: UInt64
    let plannedUptime: TimeInterval
    let interval: TimeInterval

    init(_ scheduled: VisualTimerScheduledBeat) {
        index = scheduled.index
        generation = scheduled.generation
        plannedUptime = scheduled.plannedUptime
        interval = scheduled.interval
    }
}

struct VisualTimerUrgencyHapticEvent: Equatable {
    let index: UInt64
    let generation: UInt64
    let plannedUptime: TimeInterval
    let intensity: Double
}

/// Selects a physically bounded subset of the shared timer beats. This never
/// owns a clock or predicts cadence: it only admits already-planned beats while
/// the authoritative timer is inside its final fifteen seconds.
struct VisualTimerUrgencyHapticSubselector {
    static let window: TimeInterval = 15
    static let minimumRate = 0.65
    static let maximumRate = 2.5
    // A soft generator at the AJ.5 0.42 entry floor was selected and requested
    // correctly, but remained too light in the latest physical final-fifteen
    // review. Keep entry sparse and gentle while making the selected soft
    // impacts more readily perceptible; completion remains a distinct heavy
    // generator rather than a stronger urgency replay.
    static let minimumIntensity = 0.50
    static let maximumIntensity = 0.95
    static let completionSeparation: TimeInterval = 0.35

    private var generation: UInt64?
    private var lastPlannedUptime: TimeInterval?

    mutating func event(
        for beat: VisualTimerPresentationBeat,
        remainingSeconds: TimeInterval
    ) -> VisualTimerUrgencyHapticEvent? {
        guard remainingSeconds.isFinite,
              remainingSeconds >= Self.completionSeparation,
              remainingSeconds <= Self.window else {
            lastPlannedUptime = nil
            return nil
        }
        if generation != beat.generation {
            generation = beat.generation
            lastPlannedUptime = nil
        }

        let progress = min(1, max(0, 1 - remainingSeconds / Self.window))
        let eased = progress * progress * (3 - 2 * progress)
        let targetRate = Self.minimumRate
            + (Self.maximumRate - Self.minimumRate) * eased
        let minimumSpacing = 1 / targetRate
        if let lastPlannedUptime,
           beat.plannedUptime - lastPlannedUptime < minimumSpacing * 0.92 {
            return nil
        }

        lastPlannedUptime = beat.plannedUptime
        return VisualTimerUrgencyHapticEvent(
            index: beat.index,
            generation: beat.generation,
            plannedUptime: beat.plannedUptime,
            intensity: Self.minimumIntensity
                + (Self.maximumIntensity - Self.minimumIntensity) * eased
        )
    }

    mutating func invalidate() {
        generation = nil
        lastPlannedUptime = nil
    }
}

/// Converts authoritative beat events into a continuous local phase. Duplicate
/// events are ignored and a skipped index advances directly to the newest beat,
/// so a late frame never replays a burst of stale pulses.
struct VisualTimerPresentationBeatTracker {
    private(set) var beatIndex: UInt64?
    private var beatElapsed: TimeInterval?
    private var beatInterval: TimeInterval = 1

    mutating func register(_ beat: VisualTimerPresentationBeat, at elapsed: TimeInterval) {
        guard elapsed.isFinite, beat.interval.isFinite, beat.interval > 0,
              beatIndex.map({ beat.index > $0 }) ?? true else { return }
        beatIndex = beat.index
        beatElapsed = elapsed
        beatInterval = beat.interval
    }

    func cyclePhase(at elapsed: TimeInterval, nextBeatElapsed: TimeInterval) -> Double? {
        guard let beatElapsed, elapsed.isFinite, nextBeatElapsed > beatElapsed else { return nil }
        let phase = min(1, max(0, (elapsed - beatElapsed) / (nextBeatElapsed - beatElapsed)))
        return phase > 0.5 ? phase - 1 : phase
    }

    func phase(at elapsed: TimeInterval) -> Double {
        guard elapsed.isFinite, let beatElapsed else { return 1 }
        return min(1, max(0, (elapsed - beatElapsed) / beatInterval))
    }
}

struct VisualTimerAdjustmentResult: Equatable {
    let remainingSeconds: TimeInterval
    let deadline: Date?
    let shouldUseCompletionPath: Bool
}

enum VisualTimerOrbLiquidGeometry {
    static let wellCenter: CGFloat = 170
    static let wellRadius: CGFloat = 146

    static func circularFillSurfaceY(progress: CGFloat) -> CGFloat {
        let boundedProgress = min(1, max(0, progress))
        let top = wellCenter - wellRadius
        let bottom = wellCenter + wellRadius

        guard boundedProgress > 0, boundedProgress < 1 else {
            return boundedProgress >= 1 ? top : bottom
        }

        // Area below a horizontal chord in a circle, solved by bisection.
        // The surface moves upward as the desired filled area increases.
        var lower = top
        var upper = bottom
        for _ in 0..<18 {
            let candidate = (lower + upper) * 0.5
            let normalizedHeight = (candidate - wellCenter) / wellRadius
            let segmentArea = 0.5 - (
                (asin(normalizedHeight) + normalizedHeight * sqrt(max(0, 1 - (normalizedHeight * normalizedHeight))))
                / CGFloat.pi
            )

            if segmentArea > boundedProgress {
                lower = candidate
            } else {
                upper = candidate
            }
        }
        return (lower + upper) * 0.5
    }
}

#if canImport(SwiftUI)
/// Presentation time only. This clock never supplies countdown or progress.
/// Accumulated monotonic time freezes on pause and resumes without a phase reset.
struct VisualTimerOrbMotionClock {
    private var accumulated: TimeInterval = 0
    private var activeSince: TimeInterval?

    func elapsed(at uptime: TimeInterval) -> TimeInterval {
        guard uptime.isFinite, let activeSince else { return accumulated }
        return accumulated + max(0, uptime - activeSince)
    }

    mutating func setActive(_ active: Bool, at uptime: TimeInterval) {
        guard uptime.isFinite, active != (activeSince != nil) else { return }
        accumulated = elapsed(at: uptime)
        activeSince = active ? uptime : nil
    }
}

struct VisualTimerOrbPresentationTiming: Equatable {
    let elapsed: TimeInterval
    let beatIndex: UInt64?
    let pulsePhase: Double
    let pulse: Double
}

/// Shared by the embedded and full-screen material stacks. The active-owner set
/// prevents a cover transition from creating two clocks or stopping the clock
/// when the presentations briefly overlap.
@MainActor
final class VisualTimerOrbPresentationDriver {
    private var motionClock = VisualTimerOrbMotionClock()
    private var beatTracker = VisualTimerPresentationBeatTracker()
    private var activeOwners: Set<UUID> = []
    private var generation: UInt64 = 0
    private var pendingBeats: [VisualTimerPresentationBeat] = []
    private var suspendedPulsePhase: Double = 1
#if DEBUG
    // Opt-in, bounded memory only; emit on lifecycle changes, never per frame.
    private var frameTrace: [[Double]] = []
    private var droppedTraceRecords = 0
    private var lastTraceUptime: TimeInterval = -.infinity

    func traceFrame(scheduleDate: Date, uptime: TimeInterval,
                    timing: VisualTimerOrbPresentationTiming,
                    motion: VisualTimerOrbMotionFrame, active: Bool) {
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerDiagnostics"),
              uptime - lastTraceUptime >= 0.09 else { return }
        lastTraceUptime = uptime
        guard frameTrace.count < 1600 else { droppedTraceRecords += 1; return }
        frameTrace.append([uptime, scheduleDate.timeIntervalSince1970,
                           timing.elapsed, timing.pulsePhase, motion.crystalTime,
                           motion.crystalEnergy, motion.pulse, active ? 1 : 0,
                           Double(activeOwners.count), Double(generation)])
    }

    private func flushTrace(event: String, uptime: TimeInterval) {
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerDiagnostics") else { return }
        let payload: [String: Any] = ["driver": String(describing: ObjectIdentifier(self)),
            "event": event, "uptime": uptime, "owners": activeOwners.count,
            "generation": generation, "dropped": droppedTraceRecords, "frames": frameTrace]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print("AJ4_MOTION \(text)") }
        frameTrace.removeAll(keepingCapacity: true)
        droppedTraceRecords = 0
        fflush(stdout)
    }
#endif

    func setActive(_ active: Bool, owner: UUID, at uptime: TimeInterval) {
        let wasActive = !activeOwners.isEmpty
        if !active, activeOwners == [owner] {
            suspendedPulsePhase = timing(at: uptime).pulsePhase
        }
        if active {
            activeOwners.insert(owner)
        } else {
            activeOwners.remove(owner)
        }
        let isActive = !activeOwners.isEmpty
#if DEBUG
        flushTrace(event: active ? "owner.active" : "owner.inactive", uptime: uptime)
#endif
        if wasActive != isActive {
            motionClock.setActive(isActive, at: uptime)
            if isActive {
                // A screen that becomes visible after a beat has passed joins
                // the next real shared beat; it never replays a stale flash.
                pendingBeats.removeAll { $0.plannedUptime < uptime }
            }
        }
    }

    func register(_ beat: VisualTimerPresentationBeat, at uptime: TimeInterval) {
        guard beat.plannedUptime.isFinite,
              beat.interval.isFinite,
              beat.interval > 0,
              beat.generation >= generation else { return }
        if beat.generation > generation {
            generation = beat.generation
            pendingBeats.removeAll()
            // Scheduler generations intentionally restart their public beat
            // index at zero. Retaining the prior tracker would make the new
            // generation look stale forever, leaving visual consumers settled
            // after a subsequent Start even though shared beats still arrive.
            beatTracker = VisualTimerPresentationBeatTracker()
            suspendedPulsePhase = 1
        }
        guard !pendingBeats.contains(where: { $0.index == beat.index && $0.generation == beat.generation }) else {
            return
        }
        pendingBeats.append(beat)
        pendingBeats.sort { $0.plannedUptime < $1.plannedUptime }
    }

    func invalidate(before generation: UInt64) {
        guard generation >= self.generation else { return }
        self.generation = generation
        pendingBeats.removeAll()
        beatTracker = VisualTimerPresentationBeatTracker()
        suspendedPulsePhase = 1
    }

    func timing(at uptime: TimeInterval) -> VisualTimerOrbPresentationTiming {
        if !activeOwners.isEmpty { consumePlannedBeats(at: uptime) }
        let elapsed = motionClock.elapsed(at: uptime)
        var phase = activeOwners.isEmpty ? suspendedPulsePhase : beatTracker.phase(at: elapsed)
        if !activeOwners.isEmpty, let next = pendingBeats.first {
            phase = beatTracker.cyclePhase(
                at: elapsed, nextBeatElapsed: motionClock.elapsed(at: next.plannedUptime)
            ) ?? ((uptime - next.plannedUptime) / next.interval)
        }
        return VisualTimerOrbPresentationTiming(
            elapsed: elapsed,
            beatIndex: beatTracker.beatIndex,
            pulsePhase: phase,
            pulse: VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: phase)
        )
    }

    private func consumePlannedBeats(at uptime: TimeInterval) {
        guard uptime.isFinite, !pendingBeats.isEmpty else { return }
        let due = pendingBeats.prefix { $0.plannedUptime <= uptime }
        for beat in due {
            beatTracker.register(beat, at: motionClock.elapsed(at: beat.plannedUptime))
        }
        pendingBeats.removeFirst(due.count)
    }
}

/// One presentation frame for crystal, liquid and light. Urgency retains the
/// organic secondary energy while the shared beat adds bounded internal pressure.
/// Neither can change the authoritative countdown. Zero elapsed time and Reduce
/// Motion retain the accepted static finish.
struct VisualTimerOrbMotionFrame: Equatable {
    static let interval: TimeInterval = 1.0 / 30.0
    static let still = Self(elapsed: 0, progress: 0, urgency: 0)

    let surfaceBend: CGFloat
    let surfaceRipple: CGFloat
    let driftX: CGFloat
    let driftY: CGFloat
    let causticGain: Double
    let sheen: Double
    let sheenX: CGFloat
    let crystalTime: Double
    let crystalEnergy: Double
    let alertness: Double
    let pulsePhase: Double
    let pulse: Double

    init(elapsed: TimeInterval, progress: Double, urgency: Double, pulsePhase: Double = 1) {
        func unit(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
        func smooth(_ value: Double) -> Double {
            let t = unit(value)
            return t * t * (3 - 2 * t)
        }
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        let fill = unit(progress)
        let wake = smooth(time / 1.2)
        let urgency = unit(urgency)
        self.pulsePhase = pulsePhase.isFinite ? pulsePhase : 1
        pulse = VisualTimerFeedbackCurve.presentationPulseEnvelope(phase: pulsePhase)
        // Crystal remains awake near full; completed/empty presentations settle.
        // Baseline flow does not contract/restart with each beat. The shader's
        // separate pressure field retains the bold accent and tethered roots.
        crystalEnergy = wake * smooth(fill / 0.02) * (0.82 + 0.12 * urgency)
        crystalTime = crystalEnergy == 0 ? 0 : time
        alertness = crystalEnergy == 0 ? 0 : urgency
        // End-point taper prevents a shallow reservoir from claiming extra volume.
        let amount = wake * smooth(fill / 0.025) * smooth((1 - fill) / 0.035)
        let energy = amount * (0.68 + 0.32 * urgency)
        // A deterministic, quasi-periodic field lets the refractive light
        // wander without a left/right pendulum, random frame jumps, or a
        // second cadence authority. Unequal periods, phases and gentle
        // phase-warping create diagonal drift, curved turns and brief lingers.
        let slowX = sin(time * 2 * .pi / 7.3 + 0.30 * sin(time * 2 * .pi / 17.9 + 0.7))
        let longX = sin(time * 2 * .pi / 13.1 + 1.8)
        let detailX = sin(time * 2 * .pi / 4.7 + 2.4)
        let slowY = sin(time * 2 * .pi / 9.7 + 0.27 * sin(time * 2 * .pi / 15.1 + 1.1))
        let longY = sin(time * 2 * .pi / 18.7 + 2.7)
        let detailY = sin(time * 2 * .pi / 5.9 + 0.35)
        let current = 0.53 * slowX + 0.31 * longX + 0.16 * detailX
        let swell = 0.55 * slowY + 0.29 * longY + 0.16 * detailY
        let beatPressure = amount * pulse
        surfaceBend = CGFloat(energy * swell + 0.78 * beatPressure)
        surfaceRipple = CGFloat(energy * current - 0.62 * beatPressure)
        driftX = CGFloat(29 * energy * current + 10 * beatPressure)
        driftY = CGFloat(15 * energy * swell - 8 * beatPressure)
        causticGain = 1 + 0.58 * energy * sin(time * 2 * .pi / 3.0) + 0.58 * beatPressure
        sheen = 0.28 * energy + 0.24 * beatPressure
        sheenX = CGFloat(170 + 118 * current + 14 * beatPressure)
    }
}

/// Native regions in the 340-point Canvas coordinate space: origin at top-left,
/// positive y downward. Consumers use these paths without reversing their masks.
struct VisualTimerOrbRegions {
    static let canvasSize: CGFloat = 340

    let surfaceY: CGFloat
    let well: Path
    let liquid: Path
    let unsubmerged: Path
    let meniscus: Path

    /// The lower optical accent follows the same surface and is clipped to liquid.
    var meniscusLower: Path {
        meniscus.applying(CGAffineTransform(translationX: 0, y: 10))
    }

    init(progress: CGFloat, motion: VisualTimerOrbMotionFrame = .still) {
        let center = VisualTimerOrbLiquidGeometry.wellCenter
        let radius = VisualTimerOrbLiquidGeometry.wellRadius
        let top = center - radius
        let bottom = center + radius
        let y = VisualTimerOrbLiquidGeometry.circularFillSurfaceY(progress: progress)
        surfaceY = y
        well = Path(ellipseIn: CGRect(x: top, y: top, width: radius * 2, height: radius * 2))

        guard y > top, y < bottom else {
            liquid = y <= top ? well : Path()
            unsubmerged = y >= bottom ? well : Path()
            meniscus = Path()
            return
        }

        let offset = y - center
        let halfChord = sqrt(max(0, radius * radius - offset * offset))
        let left = CGPoint(x: center - halfChord, y: y)
        let right = CGPoint(x: center + halfChord, y: y)
        let width = halfChord * 2
        let staticCurve = min(4.5, width * 0.025, min(y - top, bottom - y) * 0.25)
        let clearance = min(y - top, bottom - y)
        let bend = min(15, width * 0.09, clearance * 0.32) * motion.surfaceBend
        let wave = min(20, width * 0.10, clearance * 0.38) * motion.surfaceRipple

        // Keep the complete Bezier control hull inside the convex circular well.
        // Limit only poses that reach a contact-side wall, retaining the same
        // area-neutral coefficient ratios and continuous middle tangent.
        var containment: CGFloat = 1
        let controls: [(CGFloat, CGFloat, CGFloat)] = [
            (left.x + width / 6, y + 2 * staticCurve, 2 * bend + wave),
            (left.x + width / 3, y - staticCurve, -bend + wave),
            (center, y - staticCurve, -bend),
            (center + width / 6, y - staticCurve, -bend - wave),
            (center + width / 3, y + 2 * staticCurve, 2 * bend - wave),
        ]
        for (x, baseline, delta) in controls where delta != 0 {
            let extent = sqrt(max(0, radius * radius - (x - center) * (x - center)))
            let boundary = center + (delta > 0 ? extent : -extent)
            containment = min(containment, max(0, (boundary - baseline) / delta))
        }
        let curve = staticCurve + bend * containment
        let ripple = wave * containment

        // Both cubic segments have linear x(t), and their control-point y
        // offsets sum to zero, including motion:
        // [0, 2c+r, -c+r, -c], [-c, -c-r, 2c-r, 0].
        // Thus the curved surface preserves the scalar chord's enclosed area.
        // Endpoints stay exactly on the well; the center has a smooth tangent.
        let surface = Path { path in
            path.move(to: left)
            path.addCurve(
                to: CGPoint(x: center, y: y - curve),
                control1: CGPoint(x: left.x + width / 6, y: y + 2 * curve + ripple),
                control2: CGPoint(x: left.x + width / 3, y: y - curve + ripple)
            )
            path.addCurve(
                to: right,
                control1: CGPoint(x: center + width / 6, y: y - curve - ripple),
                control2: CGPoint(x: center + width / 3, y: y + 2 * curve - ripple)
            )
        }
        meniscus = surface

        let rightAngle = atan2(offset, halfChord)
        func closingSurface(throughBottom: Bool) -> Path {
            var path = surface
            // SwiftUI's y-down transform reverses the visual arc direction.
            // Increasing angles (clockwise:false) traverse the LOWER circle.
            path.addArc(
                center: CGPoint(x: center, y: center),
                radius: radius,
                startAngle: .radians(Double(rightAngle)),
                endAngle: .radians(Double((throughBottom ? CGFloat.pi : -CGFloat.pi) - rightAngle)),
                clockwise: !throughBottom
            )
            path.closeSubpath()
            return path
        }
        liquid = closingSurface(throughBottom: true)
        unsubmerged = closingSurface(throughBottom: false)
    }
}
#endif

/// The single positive-duration bound for timer state and its projections.
/// Zero remains terminal; non-finite positive input saturates at one hour.
enum VisualTimerDuration {
    static let maximumSeconds: TimeInterval = 3_600
    static let maximumMinutes = Int(maximumSeconds / 60)
    static let initialSeconds = clamp(5 * 60)

    static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        guard !seconds.isNaN else { return 0 }
        return min(maximumSeconds, max(0, seconds))
    }
}

enum VisualTimerAdjustment {
    static let quickAdjustmentSeconds: TimeInterval = 15

    static func apply(
        deadline: Date?,
        pausedRemainingSeconds: TimeInterval,
        by seconds: TimeInterval,
        now: Date
    ) -> VisualTimerAdjustmentResult {
        let currentRemaining = VisualTimerDuration.clamp(
            deadline?.timeIntervalSince(now) ?? pausedRemainingSeconds
        )
        let delta = finite(seconds)
        let adjustedRemaining = VisualTimerDuration.clamp(currentRemaining + delta)

        return VisualTimerAdjustmentResult(
            remainingSeconds: adjustedRemaining,
            deadline: deadline == nil ? nil : now.addingTimeInterval(adjustedRemaining),
            shouldUseCompletionPath: adjustedRemaining == 0
        )
    }

    private static func finite(_ value: TimeInterval) -> TimeInterval {
        value.isFinite ? value : 0
    }
}

/// A completion is owned by the absolute-deadline timer. The monotonic start
/// reference is shared by audio and the presentation-owned haptic pattern;
/// neither becomes a second countdown or feedback cadence authority.
struct VisualTimerCompletionCueEvent: Equatable {
    let sessionID: UInt64
    let cueStartUptime: TimeInterval
}

struct VisualTimerCompletionHapticBeat: Equatable {
    let cueOffset: TimeInterval
    let intensity: Double
}

/// Brandon's approved three-second completion recording. The raw WAV remains
/// an unchanged Data Set resource; playback decodes its native PCM samples.
enum VisualTimerCompletionCue {
    static let resourceName = "TimerCompletionCue"
    static let sourceFilename = "TIMER_SOUND_3s.wav"
    static let approvedSourceSHA256 = "ddde780da9eb13cc1b7f00f0f7ba03d7f4bd50e8f480574078fd20092174e52b"
    static let duration: TimeInterval = 3.0
    static let sampleRate = 44_100
    static let channelCount = 2
    static let bitDepth = 24
    static let frameCount = 132_300
    static let pcmByteCount = 793_800
    static let playbackTail: TimeInterval = 0.15
    // The initial 0.00 attack is followed by the three strongest separated
    // phrase attacks found in the approved source's 10-ms RMS inspection.
    // Four impacts avoid vibrating on minor transients, and the final 2.27-s
    // strike resolves the cue rather than adding an unrelated zero haptic.
    static let hapticBeatMap: [VisualTimerCompletionHapticBeat] = [
        .init(cueOffset: 0.00, intensity: 0.70),
        .init(cueOffset: 0.96, intensity: 0.76),
        .init(cueOffset: 1.68, intensity: 0.84),
        .init(cueOffset: 2.27, intensity: 1.00),
    ]
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
