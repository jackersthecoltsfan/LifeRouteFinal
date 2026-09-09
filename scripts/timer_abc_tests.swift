import Foundation
import Combine

// Record the actual core's audio intent at the platform boundary.
@MainActor final class VisualTimerToneEngine {
    static var completions = 0
    static var stops = 0
    static var activeCompletion = false
    func schedulePulse(id: UInt64, plannedUptime: TimeInterval, frequency: Double,
                       profile: VisualTimerToneProfile, gain: Float) {}
    @discardableResult func cancelScheduledPulses() -> Int { 0 }
    func playCompletion(gain: Float) { Self.completions += 1; Self.activeCompletion = true }
    func stop() { Self.stops += 1; Self.activeCompletion = false }
}
@MainActor enum LifeRouteHaptics {
    static func timerCompletion(intensity: Double) {}
    static func timerUrgency(intensity: Double) {}
}
enum UIAccessibility {
    static let isVoiceOverRunning = false
    enum Notification { case announcement }
    static func post(notification: Notification, argument: String) {}
}

@MainActor final class TimerProbe {
    let suite = "LifeRoute.TimerABC.\(UUID().uuidString)"
    let timer: VisualTimerCore
    let presentation: VisualTimerPresentationState
    var cues: [VisualTimerCompletionCueEvent] = []
    var haptics: [Double] = []
    var subscription: AnyCancellable?
    init() {
        let defaults = UserDefaults(suiteName: suite)!
        timer = VisualTimerCore(preferenceStore: defaults)
        presentation = VisualTimerPresentationState(timer: timer, preferenceStore: defaults)
        timer.setSoundEnabled(true)
        subscription = timer.completionCuePublisher.sink { [weak self] in self?.cues.append($0) }
    }
    func close() { timer.reset(); UserDefaults().removePersistentDomain(forName: suite) }
}

@main struct TimerABCTests {
    @MainActor static var assertions = 0
    @MainActor static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        precondition(value(), message)
    }
    @MainActor static func bounded(_ timer: VisualTimerCore, at now: Date, _ path: String) {
        for value in [timer.durationSeconds, timer.pausedRemainingSeconds, timer.remainingSeconds(at: now)] {
            expect(value.isFinite && value >= 0 && value <= 3600, "\(path): state outside 0...3600")
        }
    }
    @MainActor static func main() async throws {
        try testClampWritePaths()
        try await testExactlyOncePerGeneration()
        try await testStaleDelayedCue()
        print("PASS exactly 3 focused logical timer groups; \(assertions) assertions")
    }

    @MainActor static func testClampWritePaths() throws {
        let p = TimerProbe(); defer { p.close() }
        let timer = p.timer
        let t = Date().addingTimeInterval(10000)
        bounded(timer, at: t, "initial duration/paused state/reference")
        expect(timer.remainingSeconds(at: t) == 300, "initial ready state preserved")
        for minutes in [1, 2, 3, 5, 10, 60, 61, 180, Int.max] {
            p.presentation.start(minutes: minutes, now: t)
            bounded(timer, at: t, "core/presentation/preset/custom/fullscreen/debug Start")
            expect(timer.remainingSeconds(at: t) == (minutes >= 60 ? 3600 : Double(minutes * 60)), "start duration")
            expect(timer.deadline == t.addingTimeInterval(timer.remainingSeconds(at: t)), "start deadline")
        }
        timer.setVolume(0)
        timer.setVolume(0.4)
        timer.setToneProfile(.warm)
        timer.setSoundEnabled(false)
        timer.setSoundEnabled(true)
        bounded(timer, at: t, "volume/tone/sound setter rebuilds")
        timer.pause(now: t)
        timer.adjustRemainingSeconds(by: -5, now: t)
        expect(timer.remainingSeconds(at: t) == 3595, "paused -15 helper accepts arbitrary adjustment")
        timer.adjustRemainingSeconds(by: 15, now: t)
        expect(timer.remainingSeconds(at: t) == 3600, "paused +15 near cap")
        timer.adjustRemainingSeconds(by: -15, now: t)
        timer.addMinute(now: t)
        bounded(timer, at: t, "paused plus/minus15/Add Minute/duration write")
        expect(timer.remainingSeconds(at: t) == 3600, "paused Add Minute cap")
        timer.resume(now: t)
        expect(timer.deadline == t.addingTimeInterval(3600), "resume deadline cap")
        timer.adjustRemainingSeconds(by: -5, now: t)
        timer.adjustRemainingSeconds(by: 15, now: t)
        expect(timer.deadline == t.addingTimeInterval(3600), "running +15 effective deadline cap")
        timer.adjustRemainingSeconds(by: -15, now: t)
        timer.addMinute(now: t)
        bounded(timer, at: t, "running plus/minus15/Add Minute")
        expect(timer.deadline == t.addingTimeInterval(3600), "running Add Minute cap")
        bounded(timer, at: t.addingTimeInterval(-7200), "deadline recompute/backward clock equivalent")
        timer.pause(now: t.addingTimeInterval(-7200))
        bounded(timer, at: t, "pause captures clamped deadline equivalent")
        p.presentation.reset()
        bounded(timer, at: t, "reset duration/reference snapshot")
        expect(timer.remainingSeconds(at: t) == 3600, "reset remains capped")
        for deadline in [t.addingTimeInterval(3600), t.addingTimeInterval(7200), nil] {
            let adjustment = VisualTimerAdjustment.apply(deadline: deadline,
                pausedRemainingSeconds: 7200, by: 15, now: t)
            expect(adjustment.remainingSeconds == 3600, "restored/deadline helper equivalent")
            expect(adjustment.deadline == (deadline == nil ? nil : t.addingTimeInterval(3600)), "replacement deadline cap")
        }
        timer.adjustRemainingSeconds(by: -10000, now: t)
        timer.processCompletion(at: t, generation: timer.completionCueSessionID)
        bounded(timer, at: t, "paused-zero completion clears deadline")
        timer.adjustRemainingSeconds(by: 9000, now: t)
        expect(timer.remainingSeconds(at: t) == 3600, "terminal +15 helper revive caps")
        timer.start(minutes: 1, now: t)
        timer.addMinute(now: t.addingTimeInterval(200))
        expect(timer.remainingSeconds(at: t.addingTimeInterval(200)) == 60, "expired deadline Add Minute revives from effective zero")
        expect(timer.deadline == t.addingTimeInterval(260), "revive deadline based on now")
        timer.processCompletion(at: t.addingTimeInterval(260), generation: timer.completionCueSessionID)
        timer.addMinute(now: t.addingTimeInterval(260))
        expect(timer.deadline == nil && timer.remainingSeconds(at: t) == 60, "completed Add Minute retains paused revive")
        p.presentation.reset()
        bounded(timer, at: t, "reset after completion/revive")
        var scheduler = VisualTimerFeedbackScheduler()
        var projected: [Double] = []
        _ = scheduler.begin(at: 100, remainingSeconds: 9000, rate: { projected.append($0); return 1 })
        // Initial cadence lookup is read-only; future beat projections use the clamp.
        expect(projected.dropFirst().allSatisfy { $0 <= 3600 }, "scheduler future projections capped")
        for value in [3600.0, 3601, 10800, .infinity] {
            expect(VisualTimerDuration.clamp(value) == 3600, "canonical positive cap")
        }
        expect(VisualTimerDuration.clamp(-15) == 0 && VisualTimerDuration.clamp(.nan) == 0, "terminal floor/nonfinite safety")
        // These source checks bind all view-only ledger call sites to exercised APIs.
        let view = try String(contentsOfFile: "LifeRoute/ScenicRoyalVisualTimerView.swift", encoding: .utf8)
        let legacy = try String(contentsOfFile: "LifeRoute/SessionToolsViews.swift", encoding: .utf8)
        for call in ["startTimer(minutes:", "presentation.start(minutes:", "timer.start(minutes:", "timer.pause()", "timer.resume()", "timer.addMinute()", "timer.adjustRemainingSeconds(by: -VisualTimerAdjustment.quickAdjustmentSeconds)", "timer.adjustRemainingSeconds(by: VisualTimerAdjustment.quickAdjustmentSeconds)", "timer.reset()"] {
            expect(view.contains(call), "ledger delegation missing: \(call)")
        }
        expect(view.contains("@State private var minutes = 5") && view.contains("self.minutes = minutes"), "local selected-duration initialization and preset write delegate to bounded Start")
        expect(view.contains("in: 1...VisualTimerDuration.maximumMinutes") && legacy.contains("in: 1...VisualTimerDuration.maximumMinutes"), "both duration selectors share authority")
        expect(view.contains("let boundedSeconds = VisualTimerDuration.clamp(seconds)"), "readout projection shares authority")
        expect(view.contains("timer.remainingSeconds(at: date)") && view.contains("timer.remainingSeconds(at: frameDate)"), "both display snapshots use authority")
        let fresh = VisualTimerCore(preferenceStore: UserDefaults(suiteName: p.suite)!)
        expect(fresh.deadline == nil && fresh.durationSeconds == 300 && fresh.remainingSeconds(at: t) == 300,
               "preferences restore does not invent native duration/deadline persistence")
        print("PASS TEST 1 — CLAMP AT EVERY WRITE PATH (71 reconciled donor ledger entries, shared-core delegation)")
    }

    @MainActor static func testExactlyOncePerGeneration() async throws {
        let p = TimerProbe(); defer { p.close() }
        let timer = p.timer, t = Date().addingTimeInterval(10000)
        expect(timer.completionCueSessionID == 1, "initial positive state owns generation 1")
        let n = timer.completionCueSessionID
        p.presentation.start(minutes: 1, now: t)
        timer.adjustRemainingSeconds(by: 15, now: t)
        timer.addMinute(now: t)
        timer.pause(now: t); timer.resume(now: t); timer.reset()
        expect(timer.completionCueSessionID == n, "positive Start/reset/adjust/pause/resume never advance")
        timer.resume(now: t)
        timer.processCompletion(at: t.addingTimeInterval(5), generation: n)
        p.presentation.setHapticsActive(false, owner: UUID())
        p.presentation.setHapticsActive(true, owner: UUID())
        expect(timer.completionCueSessionID == n && p.cues.isEmpty,
               "positive execution gap/background-foreground presentation changes preserve generation")
        timer.start(minutes: 1, now: t)
        let audioBefore = VisualTimerToneEngine.completions
        timer.processCompletion(at: t.addingTimeInterval(60), generation: n)
        expect(p.cues.count == 1 && VisualTimerToneEngine.completions == audioBefore + 1, "generation N dispatch once")
        timer.processCompletion(at: t.addingTimeInterval(60), generation: n)
        timer.adjustRemainingSeconds(by: -15, now: t.addingTimeInterval(60))
        timer.processCompletion(at: t.addingTimeInterval(60), generation: n)
        expect(p.cues.count == 1 && VisualTimerToneEngine.completions == audioBefore + 1, "duplicate terminal stays one")
        let stops = VisualTimerToneEngine.stops
        timer.addMinute(now: t.addingTimeInterval(60))
        expect(timer.completionCueSessionID == n + 1 && timer.completionDisposition == .armed, "revive increments/rearms")
        expect(VisualTimerToneEngine.stops > stops && !VisualTimerToneEngine.activeCompletion, "revive cancels old audio/tail")
        timer.resume(now: t.addingTimeInterval(60))
        timer.processCompletion(at: t.addingTimeInterval(120), generation: n + 1)
        timer.processCompletion(at: t.addingTimeInterval(120), generation: n + 1)
        expect(p.cues.count == 2 && VisualTimerToneEngine.completions == audioBefore + 2, "revived generation dispatch once; total two")
        for action in 0..<4 {
            let probe = TimerProbe(); let g = probe.timer.completionCueSessionID
            probe.timer.start(minutes: 1, now: t)
            probe.timer.processCompletion(at: t.addingTimeInterval(60), generation: g)
            switch action {
            case 0: probe.timer.start(minutes: 1, now: t.addingTimeInterval(60))
            case 1: probe.timer.reset()
            case 2: probe.timer.addMinute(now: t.addingTimeInterval(60))
            default: probe.timer.adjustRemainingSeconds(by: 15, now: t.addingTimeInterval(60))
            }
            expect(probe.timer.completionCueSessionID == g + 1, "each authorized revive advances once")
            probe.close()
        }
        print("PASS TEST 2 — EXACTLY ONCE PER GENERATION (cue/audio dispatch 1,1,2,2; revive re-arms)")
    }

    @MainActor static func testStaleDelayedCue() async throws {
        let t = Date().addingTimeInterval(10000)
        for late in [0.0, 29.999, 30.0, 30.001, 300.0] {
            let p = TimerProbe(); let g = p.timer.completionCueSessionID
            p.timer.start(minutes: 1, now: t)
            let count = VisualTimerToneEngine.completions
            p.timer.processCompletion(at: t.addingTimeInterval(60 + late), generation: g)
            p.timer.processCompletion(at: t.addingTimeInterval(60 + late), generation: g)
            let expected = late <= 30 ? 1 : 0
            expect(p.cues.count == expected && VisualTimerToneEngine.completions == count + expected, "30s boundary dispatch \(late)")
            expect(p.timer.completionDisposition == (expected == 1 ? .emitted : .silent), "late terminal consumed")
            p.close()
        }
        for pauseFirst in [true, false] {
            let p = TimerProbe(); let g = p.timer.completionCueSessionID
            p.timer.start(minutes: 1, now: t)
            let count = VisualTimerToneEngine.completions
            if pauseFirst { p.timer.pause(now: t.addingTimeInterval(100)) }
            else { p.timer.adjustRemainingSeconds(by: -15, now: t.addingTimeInterval(100)) }
            p.timer.processCompletion(at: t.addingTimeInterval(100), generation: g)
            expect(p.cues.isEmpty && VisualTimerToneEngine.completions == count, "pause/zero adjust preserve original stale deadline")
            p.close()
        }
        let p = TimerProbe(); defer { p.close() }
        let old = p.timer.completionCueSessionID
        p.timer.start(minutes: 1, now: t)
        let count = VisualTimerToneEngine.completions
        p.timer.addMinute(now: t.addingTimeInterval(70)) // Revive before old pending delivery.
        let current = p.timer.completionCueSessionID
        expect(current == old + 1, "expired effective deadline revive creates new identity")
        p.timer.processCompletion(at: t.addingTimeInterval(75), generation: old)
        expect(p.cues.isEmpty && VisualTimerToneEngine.completions == count, "late old generation cue silent")
        expect(p.timer.remainingSeconds(at: t.addingTimeInterval(75)) == 55, "old callback cannot zero revived timer")
        p.timer.processCompletion(at: t.addingTimeInterval(130), generation: old)
        expect(p.cues.isEmpty, "old callback rejected even when new generation also terminal")
        p.timer.processCompletion(at: t.addingTimeInterval(130), generation: current)
        expect(p.cues.map(\.sessionID) == [current] && VisualTimerToneEngine.completions == count + 1, "new generation retains own cue right")
        // Production feedback Task (not only direct dispatch seam) catches up.
        let natural = TimerProbe(); defer { natural.close() }
        natural.timer.start(minutes: 1, now: Date().addingTimeInterval(-61))
        try await Task.sleep(nanoseconds: 80_000_000)
        expect(natural.cues.count == 1, "actual feedback task delivers valid delayed completion")
        let stale = TimerProbe(); defer { stale.close() }
        stale.timer.start(minutes: 1, now: Date().addingTimeInterval(-91))
        try await Task.sleep(nanoseconds: 80_000_000)
        expect(stale.cues.isEmpty && stale.timer.completionDisposition == .silent, "actual feedback task suppresses stale completion")
        // Observe actual presentation haptic tasks across revive, using only an
        // injected platform actuator. The four accepted impacts remain intact.
        let h = TimerProbe(); defer { h.close() }
        let defaults = UserDefaults(suiteName: h.suite)!
        var impacts: [Double] = []
        let presentation = VisualTimerPresentationState(timer: h.timer, preferenceStore: defaults,
            completionHapticFeedback: { impacts.append($0) })
        presentation.setHapticsActive(true, owner: UUID())
        h.timer.start(minutes: 1, now: t)
        h.timer.processCompletion(at: t.addingTimeInterval(60), generation: h.timer.completionCueSessionID)
        try await Task.sleep(nanoseconds: 80_000_000)
        expect(impacts == [0.70], "initial accepted completion impact")
        h.timer.addMinute(now: t.addingTimeInterval(60))
        try await Task.sleep(nanoseconds: 2_400_000_000)
        expect(impacts == [0.70], "revive cancels all old remaining haptic beats")
        h.timer.resume(now: t.addingTimeInterval(60))
        h.timer.processCompletion(at: t.addingTimeInterval(120), generation: h.timer.completionCueSessionID)
        try await Task.sleep(nanoseconds: 2_400_000_000)
        expect(impacts == [0.70, 0.70, 0.76, 0.84, 1.00], "new completion preserves four accepted haptic beats")
        let beforeExpiredTail = impacts.count
        h.timer.completionCuePublisher.send(VisualTimerCompletionCueEvent(
            sessionID: h.timer.completionCueSessionID,
            cueStartUptime: ProcessInfo.processInfo.systemUptime - 10
        ))
        try await Task.sleep(nanoseconds: 80_000_000)
        expect(impacts.count == beforeExpiredTail, "expired haptic tail suppressed after suspension equivalent")
        print("PASS TEST 3 — STALE DELAYED CUE (<=30 emits, >30 silent, old generation rejected)")
    }
}
