import Foundation
import Combine
import AVFoundation
import UIKit

enum LifeRouteAudioSessionOwnership {
    // Both the timer engine and SwiftUI theme-change hook access this on the
    // main thread; keeping the tiny ownership flag synchronous avoids moving
    // AVAudioEngine work across actors.
    private(set) static var timerPlaybackActive = false

    static var allowsThemeFeedback: Bool {
        VisualTimerAudioSessionPolicy.allowsThemeFeedback(
            timerPlaybackActive: timerPlaybackActive
        )
    }

    static func timerDidActivatePlayback() {
        timerPlaybackActive = true
    }

    static func timerDidDeactivatePlayback() {
        timerPlaybackActive = false
    }
}

enum SessionToolRoute: Hashable {
    case visualTimer
    case quickNotes
    case firstThen
    case sessionPlan
}

struct QuickSessionNote: Identifiable, Hashable {
    let id: UUID
    let clientCode: String?
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), clientCode: String?, text: String, createdAt: Date = Date()) {
        self.id = id
        self.clientCode = clientCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

struct SessionPlanSnapshot: Hashable {
    let clientCode: String?
    let durationMinutes: Int
    let targets: [String]
    let reinforcers: [String]
    let createdAt: Date
}

enum SessionToolsCoreError: LocalizedError {
    case emptyNote
    case noTargets

    var errorDescription: String? {
        switch self {
        case .emptyNote:
            return "Enter a note before saving."
        case .noTargets:
            return "Add at least one supervisor-approved target or priority."
        }
    }
}

@MainActor
private final class VisualTimerToneEngine {
    private static let sampleRate = 44_100.0
    private static let pulseDuration = 0.085

    private let engine = AVAudioEngine()
    // Pulse cancellation must not cut the independent completion cue.
    private let pulsePlayer = AVAudioPlayerNode()
    private let completionPlayer = AVAudioPlayerNode()
    private let pulseFormat = AVAudioFormat(
        standardFormatWithSampleRate: VisualTimerToneEngine.sampleRate,
        channels: 1
    )!
    private let completionFormat = AVAudioFormat(
        standardFormatWithSampleRate: Double(VisualTimerCompletionCue.sampleRate),
        channels: AVAudioChannelCount(VisualTimerCompletionCue.channelCount)
    )!
    private var isPrepared = false
    private var isSessionActive = false
    private var completionStopTask: Task<Void, Never>?
    private var scheduledPulseIDs: Set<UInt64> = []

    /// ProcessInfo.systemUptime and AVAudioTime host time are both monotonic
    /// seconds since boot. Converting the planned uptime directly keeps the
    /// audio timeline aligned with the scheduler's presentation timeline.
    func schedulePulse(
        id: UInt64,
        plannedUptime: TimeInterval,
        frequency: Double,
        profile: VisualTimerToneProfile,
        gain: Float
    ) {
        guard prepareIfNeeded(),
              let buffer = pulseBuffer(frequency: frequency, profile: profile) else { return }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerDiagnostics") {
            print("PHASE1AJ3_AUDIO scheduled id=\(id) plannedUptime=\(plannedUptime) intervalFromNow=\(plannedUptime - ProcessInfo.processInfo.systemUptime) frequency=\(frequency) gain=\(gain)")
        }
#endif
        pulsePlayer.volume = max(0, min(1, gain))
        let audioTime = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: plannedUptime))
        scheduledPulseIDs.insert(id)
        pulsePlayer.scheduleBuffer(
            buffer,
            at: audioTime,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduledPulseIDs.remove(id)
            }
        }
        if !pulsePlayer.isPlaying { pulsePlayer.play() }
    }

    /// AVAudioPlayerNode.stop() removes pending buffers from this dedicated
    /// pulse player. It cannot retract samples the hardware has already read.
    @discardableResult
    func cancelScheduledPulses() -> Int {
        let canceledCount = scheduledPulseIDs.count
        scheduledPulseIDs.removeAll()
        pulsePlayer.stop()
        return canceledCount
    }

    func playCompletion(gain: Float) {
        guard prepareIfNeeded(),
              let buffer = completionBuffer() else { return }
        completionPlayer.volume = max(0, min(1, gain))
        completionPlayer.scheduleBuffer(buffer, at: nil, options: [])
        if !completionPlayer.isPlaying { completionPlayer.play() }

        completionStopTask?.cancel()
        completionStopTask = Task { [weak self] in
            do {
                let stopDelay = VisualTimerCompletionCue.duration
                    + VisualTimerCompletionCue.playbackTail
                try await Task.sleep(
                    nanoseconds: UInt64(stopDelay * 1_000_000_000)
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        completionStopTask?.cancel()
        completionStopTask = nil
        scheduledPulseIDs.removeAll()
        pulsePlayer.stop()
        completionPlayer.stop()
        engine.stop()
        if isSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
            LifeRouteAudioSessionOwnership.timerDidDeactivatePlayback()
        }
    }

    private func prepareIfNeeded() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            if !isSessionActive {
                // The timer has its own explicit Sound control. Playback keeps that
                // choice audible through Ring/Silent while mixing with other audio.
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                isSessionActive = true
                LifeRouteAudioSessionOwnership.timerDidActivatePlayback()
            }

            if !isPrepared {
                engine.attach(pulsePlayer)
                engine.attach(completionPlayer)
                engine.connect(pulsePlayer, to: engine.mainMixerNode, format: pulseFormat)
                engine.connect(completionPlayer, to: engine.mainMixerNode, format: completionFormat)
                pulsePlayer.volume = 1
                completionPlayer.volume = 1
                isPrepared = true
            }
            if !engine.isRunning { try engine.start() }
            return engine.isRunning
        } catch {
            scheduledPulseIDs.removeAll()
            pulsePlayer.stop()
            completionPlayer.stop()
            engine.stop()
            if isSessionActive {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                isSessionActive = false
            }
            LifeRouteAudioSessionOwnership.timerDidDeactivatePlayback()
            return false
        }
    }

    private func pulseBuffer(
        frequency: Double,
        profile: VisualTimerToneProfile
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(Self.sampleRate * Self.pulseDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pulseFormat, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / Self.sampleRate
            let attack = min(1, t / 0.012)
            let decay = exp(-18 * t)
            let releaseStart = Self.pulseDuration * 0.62
            let releaseProgress = max(0, (t - releaseStart) / (Self.pulseDuration - releaseStart))
            // v0.6.3 cosine release reaches silence smoothly so the buffer cannot end on a click.
            let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
            let fundamental = sin(2 * Double.pi * frequency * t)
            let softSecond = profile.secondHarmonicMix * sin(2 * Double.pi * frequency * 2.0 * t)
            let softDetune = profile.detuneMix * sin(2 * Double.pi * frequency * 1.004 * t)
            samples[frame] = Float(
                (fundamental + softSecond + softDetune)
                    * attack
                    * decay
                    * release
                    * VisualTimerFeedbackCurve.pulseSynthesisAmplitude
            )
        }
        return buffer
    }

    private func completionBuffer() -> AVAudioPCMBuffer? {
        guard let data = NSDataAsset(name: VisualTimerCompletionCue.resourceName)?.data else {
            return nil
        }
        let bytes = [UInt8](data)
        let expectedLength = 44 + VisualTimerCompletionCue.pcmByteCount
        guard bytes.count == expectedLength,
              bytes[0..<4].elementsEqual([0x52, 0x49, 0x46, 0x46]), // RIFF
              bytes[8..<12].elementsEqual([0x57, 0x41, 0x56, 0x45]), // WAVE
              bytes[12..<16].elementsEqual([0x66, 0x6D, 0x74, 0x20]), // fmt chunk
              bytes[36..<40].elementsEqual([0x64, 0x61, 0x74, 0x61]), // data
              unsigned16(in: bytes, at: 20) == 1,
              unsigned16(in: bytes, at: 22) == VisualTimerCompletionCue.channelCount,
              unsigned32(in: bytes, at: 24) == VisualTimerCompletionCue.sampleRate,
              unsigned16(in: bytes, at: 34) == VisualTimerCompletionCue.bitDepth,
              Int(unsigned32(in: bytes, at: 40)) == VisualTimerCompletionCue.pcmByteCount else {
            return nil
        }

        let frameCount = AVAudioFrameCount(VisualTimerCompletionCue.frameCount)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: completionFormat, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<VisualTimerCompletionCue.frameCount {
            let offset = 44 + (frame * 6)
            channels[0][frame] = normalized24BitSample(in: bytes, at: offset)
            channels[1][frame] = normalized24BitSample(in: bytes, at: offset + 3)
        }
        return buffer
    }

    private func unsigned16(in bytes: [UInt8], at offset: Int) -> Int {
        Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }

    private func unsigned32(in bytes: [UInt8], at offset: Int) -> Int {
        Int(bytes[offset])
            | (Int(bytes[offset + 1]) << 8)
            | (Int(bytes[offset + 2]) << 16)
            | (Int(bytes[offset + 3]) << 24)
    }

    private func normalized24BitSample(in bytes: [UInt8], at offset: Int) -> Float {
        let unsigned = Int32(bytes[offset])
            | (Int32(bytes[offset + 1]) << 8)
            | (Int32(bytes[offset + 2]) << 16)
        let signed = unsigned >= 0x80_0000 ? unsigned - 0x1_000000 : unsigned
        return Float(signed) / 8_388_608
    }
}

// Countdown ownership remains absolute-deadline based. Scenic Royal feedback consumes
// the pure feedback contract without changing start, pause, resume, add-minute, or reset semantics.
@MainActor
final class VisualTimerCore: ObservableObject {
    private enum PreferenceKey {
        static let toneProfile = "liferoute.visualTimer.toneProfile.v1"
        static let soundEnabled = "liferoute.visualTimer.soundEnabled.v1"
        static let volume = "liferoute.visualTimer.volume.v1"
        static let completionHaptics = "liferoute.visualTimer.completionHaptics.v1"
    }

    @Published private(set) var durationSeconds: TimeInterval = VisualTimerDuration.initialSeconds
    @Published private(set) var deadline: Date?
    @Published private(set) var pausedRemainingSeconds: TimeInterval = VisualTimerDuration.initialSeconds
    @Published private(set) var toneProfile: VisualTimerToneProfile
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var volume: Double
    @Published private(set) var completionHapticsEnabled: Bool

    let presentationBeatPublisher = PassthroughSubject<VisualTimerPresentationBeat, Never>()
    let presentationGenerationPublisher = PassthroughSubject<UInt64, Never>()
    let completionCuePublisher = PassthroughSubject<VisualTimerCompletionCueEvent, Never>()
    let completionGenerationPublisher = PassthroughSubject<UInt64, Never>()

    private let toneEngine = VisualTimerToneEngine()
    private let preferenceStore: UserDefaults
    private var feedbackTask: Task<Void, Never>?
    private var feedbackScheduler = VisualTimerFeedbackScheduler()
    // Captured only by Start/reset. +/-15 and Add 1 minute continue to alter
    // authoritative remaining time without stretching the crescendo curve.
    private var feedbackReferenceDurationSeconds: TimeInterval = VisualTimerDuration.initialSeconds
    // Completion generations advance only across terminal -> positive.
    // Beat-scheduler generations may change independently on pause/rebuild.
    private(set) var completionCueSessionID: UInt64 = 1
    enum CompletionDisposition { case armed, emitted, silent }
    private(set) var completionDisposition: CompletionDisposition = .armed
    private var completionTerminalDate: Date?
    static let completionStalenessBound: TimeInterval = 30

    private enum FeedbackStartMode {
        case begin
        case resume
        case preservePhase
    }

    init(preferenceStore: UserDefaults = .standard) {
        self.preferenceStore = preferenceStore

        let defaults = VisualTimerFeedbackPreferences.default
        let storedTone = preferenceStore.string(forKey: PreferenceKey.toneProfile)
        switch storedTone {
        case "gentle":
            toneProfile = .soft
        case "silent":
            toneProfile = defaults.toneProfile
        default:
            toneProfile = storedTone.flatMap(VisualTimerToneProfile.init(rawValue:))
                ?? defaults.toneProfile
        }

        if preferenceStore.object(forKey: PreferenceKey.soundEnabled) == nil {
            // Preserve the local Phase 4 preview's explicit Silent choice while
            // migrating it to an independent sound control.
            soundEnabled = storedTone == "silent" ? false : defaults.soundEnabled
        } else {
            soundEnabled = preferenceStore.bool(forKey: PreferenceKey.soundEnabled)
        }

        if preferenceStore.object(forKey: PreferenceKey.volume) == nil {
            volume = defaults.volume
        } else {
            volume = min(1, max(0, preferenceStore.double(forKey: PreferenceKey.volume)))
        }

        if preferenceStore.object(forKey: PreferenceKey.completionHaptics) == nil {
            completionHapticsEnabled = defaults.completionHapticsEnabled
        } else {
            completionHapticsEnabled = preferenceStore.bool(forKey: PreferenceKey.completionHaptics)
        }
    }

    var isRunning: Bool { deadline != nil }

    func start(minutes: Int, now: Date = Date()) {
        let seconds = VisualTimerDuration.clamp(TimeInterval(max(1, minutes)) * 60)
        prepareRemainingTransition(to: seconds, now: now)
        durationSeconds = seconds
        feedbackReferenceDurationSeconds = seconds
        pausedRemainingSeconds = seconds
        deadline = now.addingTimeInterval(seconds)
        startFeedbackLoop(.begin)
    }

    func remainingSeconds(at now: Date = Date()) -> TimeInterval {
        if let deadline {
            return VisualTimerDuration.clamp(deadline.timeIntervalSince(now))
        }
        return VisualTimerDuration.clamp(pausedRemainingSeconds)
    }

    func progress(at now: Date = Date()) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, remainingSeconds(at: now) / durationSeconds))
    }

    func isFinished(at now: Date = Date()) -> Bool {
        remainingSeconds(at: now) <= 0
    }

    func isCurrentCompletionCue(_ event: VisualTimerCompletionCueEvent) -> Bool {
        completionCueSessionID == event.sessionID
            && completionDisposition == .emitted
            && deadline == nil
            && pausedRemainingSeconds <= 0
    }

    func pause(now: Date = Date()) {
        if remainingSeconds(at: now) <= 0 {
            processCompletion(at: now, generation: completionCueSessionID)
            return
        }
        pausedRemainingSeconds = remainingSeconds(at: now)
        deadline = nil
        stopFeedbackLoop(preservingCadence: true)
    }

    func resume(now: Date = Date()) {
        guard pausedRemainingSeconds > 0 else { return }
        pausedRemainingSeconds = VisualTimerDuration.clamp(pausedRemainingSeconds)
        deadline = now.addingTimeInterval(pausedRemainingSeconds)
        startFeedbackLoop(.resume)
    }

    func addMinute(now: Date = Date()) {
        durationSeconds = VisualTimerDuration.clamp(durationSeconds + 60)
        adjustRemainingSeconds(by: 60, now: now)
    }

    func adjustRemainingSeconds(by seconds: TimeInterval, now: Date = Date()) {
        let wasRunning = deadline != nil
        let adjustment = VisualTimerAdjustment.apply(
            deadline: deadline,
            pausedRemainingSeconds: pausedRemainingSeconds,
            by: seconds,
            now: now
        )

        prepareRemainingTransition(to: adjustment.remainingSeconds, now: now)
        pausedRemainingSeconds = adjustment.remainingSeconds
        if wasRunning {
            deadline = adjustment.deadline
        } else if adjustment.shouldUseCompletionPath {
            // Route a paused near-zero adjustment through the same deadline
            // expiry loop used by a running timer; there is no second
            // completion implementation.
            deadline = now
        }

        if adjustment.shouldUseCompletionPath {
            rebuildFeedbackLoopPreservingPhase()
        } else if wasRunning {
            rebuildFeedbackLoopPreservingPhase()
        }
    }

    func setVolume(_ value: Double) {
        let wasAudible = volume > 0
        volume = min(1, max(0, value))
        preferenceStore.set(volume, forKey: PreferenceKey.volume)
        if volume == 0 {
            _ = toneEngine.cancelScheduledPulses()
        } else if !wasAudible, isRunning {
            rebuildFeedbackLoopPreservingPhase()
        }
    }

    func setToneProfile(_ profile: VisualTimerToneProfile) {
        toneProfile = profile
        preferenceStore.set(profile.rawValue, forKey: PreferenceKey.toneProfile)
        if isRunning { rebuildFeedbackLoopPreservingPhase() }
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        preferenceStore.set(enabled, forKey: PreferenceKey.soundEnabled)
        if !enabled {
            _ = toneEngine.cancelScheduledPulses()
        } else if isRunning {
            rebuildFeedbackLoopPreservingPhase()
        }
    }

    func setCompletionHapticsEnabled(_ enabled: Bool) {
        completionHapticsEnabled = enabled
        preferenceStore.set(enabled, forKey: PreferenceKey.completionHaptics)
    }

    func normalizedElapsedProgress(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / durationSeconds))
    }

    func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double {
        VisualTimerFeedbackCurve.pulsesPerSecond(
            elapsedProgress: feedbackElapsedProgress(forRemaining: remaining),
            referenceDurationSeconds: feedbackReferenceDurationSeconds
        )
    }

    func toneFrequency(forRemaining remaining: TimeInterval) -> Double {
        VisualTimerFeedbackCurve.frequency(
            for: toneProfile,
            elapsedProgress: normalizedElapsedProgress(forRemaining: remaining)
        )
    }

    func urgency(forRemaining remaining: TimeInterval) -> Double {
        VisualTimerFeedbackCurve.urgency(
            feedbackElapsedProgress(forRemaining: remaining),
            referenceDurationSeconds: feedbackReferenceDurationSeconds
        )
    }

    func reset() {
        prepareRemainingTransition(to: VisualTimerDuration.clamp(durationSeconds), now: Date())
        deadline = nil
        pausedRemainingSeconds = VisualTimerDuration.clamp(durationSeconds)
        feedbackReferenceDurationSeconds = pausedRemainingSeconds
        stopFeedbackLoop()
    }

    private func prepareRemainingTransition(to remaining: TimeInterval, now: Date) {
        if remaining <= 0 {
            // Retain an expired deadline before an adjustment replaces it with now.
            if completionTerminalDate == nil {
                completionTerminalDate = deadline.map { min($0, now) } ?? now
            }
        } else if remainingSeconds(at: now) <= 0 {
            stopFeedbackLoop() // Cancels the old completion player and audio tail.
            completionCueSessionID &+= 1
            completionDisposition = .armed
            completionTerminalDate = nil
            completionGenerationPublisher.send(completionCueSessionID)
        }
    }

    /// Shared by the deadline loop and deterministic tests. The caller's token
    /// cannot consume a newer generation's completion right after a revive.
    func processCompletion(at now: Date, generation: UInt64) {
        guard generation == completionCueSessionID,
              remainingSeconds(at: now) <= 0 else { return }
        let terminalDate = completionTerminalDate ?? deadline ?? now
        completionTerminalDate = terminalDate
        let shouldEmit = completionDisposition == .armed
            && now.timeIntervalSince(terminalDate) <= Self.completionStalenessBound
        if completionDisposition == .armed {
            completionDisposition = shouldEmit ? .emitted : .silent
        }
        pausedRemainingSeconds = VisualTimerDuration.clamp(0)
        deadline = nil
        feedbackTask?.cancel()
        feedbackTask = nil
        _ = feedbackScheduler.stop()
        presentationGenerationPublisher.send(feedbackScheduler.generation)
        _ = toneEngine.cancelScheduledPulses()
        // Recheck after synchronous publication: a subscriber may revive us.
        guard generation == completionCueSessionID,
              remainingSeconds(at: now) <= 0 else { return }
        guard shouldEmit else {
            if completionDisposition == .silent { toneEngine.stop() }
            return
        }
        let event = VisualTimerCompletionCueEvent(
            sessionID: generation,
            cueStartUptime: ProcessInfo.processInfo.systemUptime
        )
        if VisualTimerAudioSessionPolicy.shouldActivate(soundEnabled: soundEnabled, volume: volume) {
            toneEngine.playCompletion(gain: Float(volume))
        }
        completionCuePublisher.send(event)
    }

    private func feedbackElapsedProgress(forRemaining remaining: TimeInterval) -> Double {
        guard feedbackReferenceDurationSeconds > 0 else { return 0 }
        // A +15 adjustment may exceed the started duration. That is safely an
        // early-session rate, never a negative urgency or a new timer authority.
        return min(1, max(0, 1 - remaining / feedbackReferenceDurationSeconds))
    }

    private func startFeedbackLoop(_ mode: FeedbackStartMode) {
        feedbackTask?.cancel()
        if case .begin = mode {
            toneEngine.stop()
        }

        let uptime = ProcessInfo.processInfo.systemUptime
        let remaining = remainingSeconds()
        let update: VisualTimerFeedbackScheduleUpdate
        switch mode {
        case .begin:
            update = feedbackScheduler.begin(
                at: uptime,
                remainingSeconds: remaining,
                rate: pulsesPerSecond(forRemaining:)
            )
        case .resume:
            update = feedbackScheduler.resume(
                at: uptime,
                remainingSeconds: remaining,
                rate: pulsesPerSecond(forRemaining:)
            )
        case .preservePhase:
            update = feedbackScheduler.replenish(
                at: uptime,
                remainingSeconds: remaining,
                rate: pulsesPerSecond(forRemaining:)
            )
        }
        presentationGenerationPublisher.send(feedbackScheduler.generation)
        publishScheduledBeats(update, at: uptime, remainingSeconds: remaining)

        let completionGeneration = completionCueSessionID
        feedbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard self.completionCueSessionID == completionGeneration,
                      self.deadline != nil else { return }
                let remaining = self.remainingSeconds()

                if remaining <= 0 {
                    self.processCompletion(at: Date(), generation: completionGeneration)
                    return
                }

                let uptime = ProcessInfo.processInfo.systemUptime
                let update = self.feedbackScheduler.replenish(
                    at: uptime,
                    remainingSeconds: remaining,
                    rate: self.pulsesPerSecond(forRemaining:)
                )
                self.publishScheduledBeats(update, at: uptime, remainingSeconds: remaining)
                let generation = self.feedbackScheduler.generation
                let wakeUptime = self.feedbackScheduler.queued.first?.plannedUptime
                    ?? (uptime + 0.05)
                let delay = max(0.001, wakeUptime - uptime)
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
                guard self.feedbackScheduler.generation == generation else { return }
            }
        }
    }

    private func rebuildFeedbackLoopPreservingPhase() {
        feedbackTask?.cancel()
        _ = feedbackScheduler.invalidatePreservingPhase()
        presentationGenerationPublisher.send(feedbackScheduler.generation)
        _ = toneEngine.cancelScheduledPulses()
        startFeedbackLoop(.preservePhase)
    }

    private func publishScheduledBeats(
        _ update: VisualTimerFeedbackScheduleUpdate,
        at uptime: TimeInterval,
        remainingSeconds: TimeInterval
    ) {
        for scheduled in update.scheduled where feedbackScheduler.accepts(scheduled) {
            let remainingAtBeat = VisualTimerDuration.clamp(remainingSeconds - max(0, scheduled.plannedUptime - uptime))
            // Every calculated beat is published from Start. The duration-aware
            // law supplies a calm 0.72-Hz opening without a separate mute gate.
            presentationBeatPublisher.send(VisualTimerPresentationBeat(scheduled))
            guard VisualTimerAudioSessionPolicy.shouldActivate(
                soundEnabled: soundEnabled,
                volume: volume
            ) else { continue }
            toneEngine.schedulePulse(
                id: scheduled.index,
                plannedUptime: scheduled.plannedUptime,
                frequency: toneFrequency(forRemaining: remainingAtBeat),
                profile: toneProfile,
                gain: Float(signalGain(forRemaining: remainingAtBeat))
            )
        }
    }

    private func stopFeedbackLoop(preservingCadence: Bool = false) {
        if preservingCadence {
            _ = feedbackScheduler.pause(at: ProcessInfo.processInfo.systemUptime)
        } else {
            _ = feedbackScheduler.stop()
        }
        presentationGenerationPublisher.send(feedbackScheduler.generation)
        feedbackTask?.cancel()
        feedbackTask = nil
        _ = toneEngine.cancelScheduledPulses()
        if !preservingCadence { toneEngine.stop() }
    }

    private func signalGain(forRemaining remaining: TimeInterval) -> Double {
        VisualTimerFeedbackCurve.signalGain(
            volume: volume,
            elapsedProgress: normalizedElapsedProgress(forRemaining: remaining)
        )
    }
}

@MainActor
final class SessionToolsCore: ObservableObject {
    @Published private(set) var notes: [QuickSessionNote] = []
    @Published private(set) var lastPlan: SessionPlanSnapshot?
    let timer = VisualTimerCore()

    func addNote(text: String, clientCode: String?) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw SessionToolsCoreError.emptyNote }
        notes.append(QuickSessionNote(clientCode: normalizedClientCode(clientCode), text: clean))
    }

    func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    @discardableResult
    func buildPlan(
        clientCode: String?,
        durationMinutes: Int,
        targetsText: String,
        reinforcersText: String
    ) throws -> SessionPlanSnapshot {
        let targets = Self.list(from: targetsText)
        guard !targets.isEmpty else { throw SessionToolsCoreError.noTargets }
        let snapshot = SessionPlanSnapshot(
            clientCode: normalizedClientCode(clientCode),
            durationMinutes: max(15, min(480, durationMinutes)),
            targets: targets,
            reinforcers: Self.list(from: reinforcersText),
            createdAt: Date()
        )
        lastPlan = snapshot
        return snapshot
    }

    static func list(from value: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for part in value.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" }) {
            let item = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = item.lowercased()
            guard !item.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
            if result.count == 60 { break }
        }
        return result
    }

    private func normalizedClientCode(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? nil : clean
    }
}

// MARK: - Checkpoint 03F / 04A: client-specific persistent visual supports

struct ClientVisualIcon: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var label: String
    let imageData: Data?
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, label: String, imageData: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.label = label
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

struct ClientChoiceBoard: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var title: String
    var iconIDs: [UUID]
    var columns: Int
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, title: String, iconIDs: [UUID], columns: Int, createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.title = title
        self.iconIDs = iconIDs
        self.columns = columns
        self.createdAt = createdAt
    }
}

struct ClientVisualScheduleStep: Identifiable, Hashable {
    let id: UUID
    var label: String
    var iconID: UUID?

    init(id: UUID = UUID(), label: String, iconID: UUID? = nil) {
        self.id = id
        self.label = label
        self.iconID = iconID
    }
}

struct ClientVisualSchedule: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var title: String
    var steps: [ClientVisualScheduleStep]
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, title: String, steps: [ClientVisualScheduleStep], createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.title = title
        self.steps = steps
        self.createdAt = createdAt
    }
}

enum ClientVisualSupportError: LocalizedError {
    case missingClient
    case missingLabel
    case missingTitle
    case noIcons
    case noSteps
    case crossClientReference

    var errorDescription: String? {
        switch self {
        case .missingClient:
            return "Choose a client or the General visual library before creating a visual support."
        case .missingLabel:
            return "Add a label for the visual icon."
        case .missingTitle:
            return "Add a title before saving this visual support."
        case .noIcons:
            return "Choose at least one icon from this visual library."
        case .noSteps:
            return "Add at least one step before saving the visual schedule."
        case .crossClientReference:
            return "A visual support can only use icons saved to the same visual library."
        }
    }
}

@MainActor
final class ClientVisualSupportCore: ObservableObject {
    nonisolated static let generalClientCode = "GENERAL"
    static let generalDisplayName = "General / no client"
    private static let generalClientID = UUID(uuidString: "7F164E34-BD4A-4A30-AFDB-70A4AE8C7D3E")!

    @Published private(set) var icons: [ClientVisualIcon]
    @Published private(set) var choiceBoards: [ClientChoiceBoard]
    @Published private(set) var schedules: [ClientVisualSchedule]

    private var iconsByClientID: [UUID: [ClientVisualIcon]] = [:]
    private var choiceBoardsByClientID: [UUID: [ClientChoiceBoard]] = [:]
    private var schedulesByClientID: [UUID: [ClientVisualSchedule]] = [:]
    private var iconsByID: [UUID: ClientVisualIcon] = [:]
    private var iconIDsByClientID: [UUID: Set<UUID>] = [:]

    init(restoredState: RestoredClientVisualSupportState? = nil) {
        let restored = restoredState ?? LifeRoutePersistenceStore.shared.loadClientVisualSupports()
        self.icons = restored.icons
        self.choiceBoards = restored.choiceBoards
        self.schedules = restored.schedules
        rebuildVisualIndexes()
    }

    func icons(for clientCode: String) -> [ClientVisualIcon] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return iconsByClientID[owner.id] ?? []
    }

    func choiceBoards(for clientCode: String) -> [ClientChoiceBoard] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return choiceBoardsByClientID[owner.id] ?? []
    }

    func schedules(for clientCode: String) -> [ClientVisualSchedule] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return schedulesByClientID[owner.id] ?? []
    }

    @discardableResult
    func addIcon(clientCode: String, label: String, imageData: Data?) throws -> ClientVisualIcon {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { throw ClientVisualSupportError.missingLabel }
        let icon = ClientVisualIcon(clientID: owner.id, clientCode: owner.code, label: cleanLabel, imageData: imageData)
        icons.append(icon)
        rebuildVisualIndexes()
        persistVisualSupports()
        return icon
    }

    func removeIcon(id: UUID) {
        icons.removeAll { $0.id == id }
        choiceBoards = choiceBoards.compactMap { board in
            var updated = board
            updated.iconIDs.removeAll { $0 == id }
            return updated.iconIDs.isEmpty ? nil : updated
        }
        schedules = schedules.map { schedule in
            var updated = schedule
            updated.steps = updated.steps.map { step in
                var item = step
                if item.iconID == id { item.iconID = nil }
                return item
            }
            return updated
        }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    @discardableResult
    func saveChoiceBoard(clientCode: String, title: String, iconIDs: [UUID], columns: Int) throws -> ClientChoiceBoard {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }

        let allowed = iconIDsByClientID[owner.id] ?? []
        var seen = Set<UUID>()
        let requested = iconIDs.filter { seen.insert($0).inserted }
        guard !requested.isEmpty else { throw ClientVisualSupportError.noIcons }
        guard requested.allSatisfy(allowed.contains) else { throw ClientVisualSupportError.crossClientReference }

        let board = ClientChoiceBoard(
            clientID: owner.id,
            clientCode: owner.code,
            title: cleanTitle,
            iconIDs: Array(requested.prefix(9)),
            columns: columns == 3 ? 3 : 2
        )
        choiceBoards.append(board)
        rebuildVisualIndexes()
        persistVisualSupports()
        return board
    }

    func removeChoiceBoard(id: UUID) {
        choiceBoards.removeAll { $0.id == id }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    @discardableResult
    func saveSchedule(clientCode: String, title: String, steps: [ClientVisualScheduleStep]) throws -> ClientVisualSchedule {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }
        guard !steps.isEmpty else { throw ClientVisualSupportError.noSteps }

        let allowed = iconIDsByClientID[owner.id] ?? []
        let cleanedSteps = steps.compactMap { step -> ClientVisualScheduleStep? in
            let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            if let iconID = step.iconID, !allowed.contains(iconID) { return nil }
            return ClientVisualScheduleStep(id: step.id, label: label, iconID: step.iconID)
        }
        guard cleanedSteps.count == steps.count else { throw ClientVisualSupportError.crossClientReference }

        let schedule = ClientVisualSchedule(
            clientID: owner.id,
            clientCode: owner.code,
            title: cleanTitle,
            steps: cleanedSteps
        )
        schedules.append(schedule)
        rebuildVisualIndexes()
        persistVisualSupports()
        return schedule
    }

    func removeSchedule(id: UUID) {
        schedules.removeAll { $0.id == id }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    func icon(id: UUID, for clientCode: String) -> ClientVisualIcon? {
        guard let owner = visualOwner(for: clientCode) else { return nil }
        guard let icon = iconsByID[id], icon.clientID == owner.id else { return nil }
        return icon
    }

    func retainClients(_ clients: [LifeRouteClientProfile]) {
        let clientIDs = Set(clients.map(\.id)).union([Self.generalClientID])
        var codeByID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, normalizedRequiredClientCode($0.code)) })
        codeByID[Self.generalClientID] = Self.generalClientCode

        var changed = false
        let updatedIcons = icons.compactMap { icon -> ClientVisualIcon? in
            guard clientIDs.contains(icon.clientID), let currentCode = codeByID[icon.clientID] else {
                changed = true
                return nil
            }
            var updated = icon
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            return updated
        }
        let survivingIconIDs = Set(updatedIcons.map(\.id))
        let updatedBoards = choiceBoards.compactMap { board -> ClientChoiceBoard? in
            guard clientIDs.contains(board.clientID), let currentCode = codeByID[board.clientID] else {
                changed = true
                return nil
            }
            var updated = board
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            let originalIconIDs = updated.iconIDs
            updated.iconIDs.removeAll { !survivingIconIDs.contains($0) }
            if updated.iconIDs != originalIconIDs { changed = true }
            if updated.iconIDs.isEmpty {
                changed = true
                return nil
            }
            return updated
        }
        let updatedSchedules = schedules.compactMap { schedule -> ClientVisualSchedule? in
            guard clientIDs.contains(schedule.clientID), let currentCode = codeByID[schedule.clientID] else {
                changed = true
                return nil
            }
            var updated = schedule
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            updated.steps = updated.steps.map { step in
                var item = step
                if let iconID = item.iconID, !survivingIconIDs.contains(iconID) {
                    item.iconID = nil
                    changed = true
                }
                return item
            }
            return updated
        }
        guard changed else { return }

        icons = updatedIcons
        choiceBoards = updatedBoards
        schedules = updatedSchedules
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    private func rebuildVisualIndexes() {
        iconsByClientID = Dictionary(grouping: icons, by: \.clientID).mapValues { clientIcons in
            clientIcons.sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        }
        choiceBoardsByClientID = Dictionary(grouping: choiceBoards, by: \.clientID).mapValues { boards in
            boards.sorted { $0.createdAt > $1.createdAt }
        }
        schedulesByClientID = Dictionary(grouping: schedules, by: \.clientID).mapValues { clientSchedules in
            clientSchedules.sorted { $0.createdAt > $1.createdAt }
        }

        var iconLookup: [UUID: ClientVisualIcon] = [:]
        for icon in icons { iconLookup[icon.id] = icon }
        iconsByID = iconLookup
        iconIDsByClientID = iconsByClientID.mapValues { Set($0.map(\.id)) }
    }

    private func persistVisualSupports() {
        LifeRoutePersistenceStore.shared.saveClientVisualSupports(
            icons: icons,
            choiceBoards: choiceBoards,
            schedules: schedules
        )
    }

    private func visualOwner(for value: String) -> (id: UUID, code: String)? {
        let code = normalizedRequiredClientCode(value)
        if code.isEmpty || code.caseInsensitiveCompare(Self.generalClientCode) == .orderedSame {
            return (Self.generalClientID, Self.generalClientCode)
        }
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: code) else { return nil }
        return (clientID, code)
    }

    private func normalizedRequiredClientCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ABAVisualSupportConceptInterpreter {
    static func describe(label: String, visualDescription: String, hasReference: Bool) -> String {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = visualDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = "\(cleanLabel) \(cleanDescription)".lowercased()

        let functionalConcept: String
        switch true {
        case lowered.contains("water play"):
            functionalConcept = "A child-friendly water play cue showing hands in a small water table or basin with simple water toys."
        case lowered.contains("outside"), lowered.contains("outdoor"):
            functionalConcept = "A clear outside cue showing a doorway, yard, or playground setting that signals going outdoors."
        case lowered.contains("break"):
            functionalConcept = "A quiet break cue showing a calm resting spot or a child sitting peacefully for a short pause."
        case lowered.contains("help"):
            functionalConcept = "A clear help request cue showing a child asking an adult for assistance."
        case lowered.contains("more"):
            functionalConcept = "A simple more request cue showing a child requesting additional access, items, or activity."
        case lowered.contains("bathroom"), lowered.contains("toilet"), lowered.contains("restroom"):
            functionalConcept = "A bathroom cue showing a clearly recognizable toilet or bathroom doorway."
        case lowered.contains("eat"), lowered.contains("food"), lowered.contains("snack"):
            functionalConcept = "A food or eating cue showing a child with simple meal or snack items."
        case lowered.contains("sleep"), lowered.contains("bed"), lowered.contains("nap"):
            functionalConcept = "A sleep cue showing a bed or calm resting environment that clearly signals bedtime or nap time."
        default:
            functionalConcept = cleanDescription.isEmpty
                ? "A simple child-readable ABA visual support for \(cleanLabel)."
                : cleanDescription
        }

        let referenceNote = hasReference
            ? "Preserve the identifying features of the supplied reference image when they help the child connect the visual support to the real item, place, or activity."
            : "Create the most functionally recognizable version of the concept without decorative distractions."

        return "\(functionalConcept) \(referenceNote)"
    }
}
