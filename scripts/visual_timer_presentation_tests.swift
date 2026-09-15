import Foundation
import Combine

// Platform endpoints only: the runner compiles the production core and UI
// presentation state without changing either implementation.
@MainActor
final class VisualTimerToneEngine {
    static var completions = 0
    static var pulses = 0
    static var canceledPulses = 0
    func schedulePulse(
        id: UInt64,
        plannedUptime: TimeInterval,
        frequency: Double,
        profile: VisualTimerToneProfile,
        gain: Float
    ) { Self.pulses += 1 }
    @discardableResult func cancelScheduledPulses() -> Int {
        Self.canceledPulses += 1
        return 1
    }
    func playCompletion(gain: Float) { Self.completions += 1 }
    func stop() {}
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

@main
struct VisualTimerPresentationTests {
    @MainActor static var assertions = 0
    @MainActor static func expect(_ result: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        precondition(result(), message)
    }

    // Source-bound ownership contract; native rendering remains a separate check.
    private static func hasSingleRootTimerOwner(root: String, view: String, hero: String) -> Bool {
        func compact(_ text: String) -> String {
            text.components(separatedBy: .whitespacesAndNewlines).joined()
        }
        let root = compact(root), view = compact(view), hero = compact(hero)
        let all = root + view + hero
        func count(_ token: String) -> Int { all.components(separatedBy: token).count - 1 }
        return count("VisualTimerHeroCoordinator()") == 1
            && count("VisualTimerHeroLayer(") == 1
            && count("VisualTimerHeroController(hero:") == 1
            && root.contains("rootShellContent.overlay{VisualTimerHeroLayer(hero:timerHero,router:router)")
            && hero.contains("VisualTimerHeroLayer:UIViewControllerRepresentable")
            && hero.contains("addChild(host)")
            && ["orbHost!", "controlsHost!", "headerHost!"].allSatisfy { host in
                guard let attached = hero.range(of: "addSubview(\(host).view)"),
                      let contained = hero.range(of: "\(host).didMove(toParent:self)") else { return false }
                return attached.lowerBound < contained.lowerBound
            }
            && hero.contains("letwindow=view.window") && hero.contains("slot.window===window")
            && !all.contains(".fullScreenCover(") && !all.contains(".sheet(")
            && !all.contains(".present(") && !all.contains("UIWindow(") && !all.contains("UIWindow.init(")
    }

    @MainActor static func main() async throws {
        let suite = "LifeRoute.Phase1AH.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let timer = VisualTimerCore(preferenceStore: defaults)
        var completionHaptics: [Double] = []
        var urgencyHaptics: [Double] = []
        let presentation = VisualTimerPresentationState(
            timer: timer,
            preferenceStore: defaults,
            completionHapticFeedback: { completionHaptics.append($0) },
            urgencyHapticFeedback: { urgencyHaptics.append($0) }
        )
        let hapticOwner = UUID()
        presentation.setHapticsActive(true, owner: hapticOwner)
        var beats: [VisualTimerPresentationBeat] = []
        let beatSubscription = timer.presentationBeatPublisher.sink { beats.append($0) }
        let now = Date()
        expect(presentation.timer === timer, "presentations must share the exact SessionToolsCore timer object")
        expect(!presentation.isFullScreen, "new UI starts embedded")
        expect(!presentation.opensFullScreenOnStart, "unset automatic opening defaults OFF")
        expect(defaults.object(forKey: VisualTimerPresentationState.preferenceKey) == nil, "reading an unset preference does not write or migrate it")
        expect(timer.durationSeconds == 300 && timer.deadline == nil, "existing ready timer defaults remain intact")

        for _ in 0..<5 {
            presentation.expand()
            expect(presentation.isFullScreen && timer.deadline == nil && timer.remainingSeconds() == 300,
                   "manual ready expansion is presentation-only")
            presentation.close()
            expect(!presentation.isFullScreen && timer.remainingSeconds() == 300, "ready close preserves timer")
        }
        presentation.start(minutes: 1, now: now)
        for _ in 0..<10 where beats.isEmpty { await Task.yield() }
        let initialDeadline = timer.deadline
        expect(beats.count == 2 && VisualTimerToneEngine.pulses == 2,
               "early 0.72-Hz beats schedule audible and visual output from Start")
        presentation.start(minutes: 1, now: now.addingTimeInterval(-45))
        for _ in 0..<10 where beats.count < 4 { await Task.yield() }
        expect(beats.count == 4 && VisualTimerToneEngine.pulses == 4,
               "late queued beats remain one-to-one with enabled audio scheduling")
        timer.setSoundEnabled(false)
        expect(VisualTimerToneEngine.canceledPulses > 0,
               "Sound Off actively cancels queued pulse-player output rather than ignoring callbacks")
        presentation.start(minutes: 1, now: now.addingTimeInterval(-45))
        for _ in 0..<10 where beats.count < 6 { await Task.yield() }
        expect(beats.count == 6 && VisualTimerToneEngine.pulses == 4,
               "Sound Off preserves the shared visual cadence without scheduling audible output")
        timer.setSoundEnabled(true)
        presentation.start(minutes: 1, now: now)
        expect(initialDeadline == now.addingTimeInterval(60), "Start uses existing minutes API and absolute deadline")
        expect(!presentation.isFullScreen, "Start with preference OFF stays embedded")
        presentation.opensFullScreenOnStart = true
        expect(defaults.bool(forKey: VisualTimerPresentationState.preferenceKey), "preference ON is persisted")
        expect(!presentation.isFullScreen && timer.deadline == initialDeadline, "toggling preference during a run does not present or restart")
        presentation.start(minutes: 2, now: now)
        let runningDeadline = timer.deadline
        expect(presentation.isFullScreen && runningDeadline == now.addingTimeInterval(120), "explicit Start with ON expands the successful run")
        presentation.start(minutes: 1, now: now)
        expect(presentation.isFullScreen && timer.durationSeconds == 60, "Start already full screen stays in the same presentation")
        for _ in 0..<5 {
            presentation.close()
            expect(!presentation.isFullScreen && timer.deadline == initialDeadline, "closing running timer never changes its deadline")
            _ = timer.progress(at: now.addingTimeInterval(7))
            _ = timer.remainingSeconds(at: now.addingTimeInterval(7))
            expect(!presentation.isFullScreen, "observed running-state updates cannot reopen the cover")
            presentation.expand()
            expect(timer.deadline == initialDeadline, "manual running expansion never restarts")
        }
        expect(timer.remainingSeconds(at: now.addingTimeInterval(7)) == 53, "elapsed time continues from the same deadline")

        presentation.start(minutes: 1, now: Date().addingTimeInterval(-45))
        try await Task.sleep(nanoseconds: 500_000_000)
        expect(!urgencyHaptics.isEmpty, "entering final fifteen schedules an urgency haptic from the shared beat")
        let beforeExit = urgencyHaptics.count
        timer.adjustRemainingSeconds(by: 15)
        try await Task.sleep(nanoseconds: 600_000_000)
        expect(urgencyHaptics.count == beforeExit, "+15 leaving final fifteen cancels pending urgency haptics")
        timer.adjustRemainingSeconds(by: -15)
        try await Task.sleep(nanoseconds: 500_000_000)
        expect(urgencyHaptics.count > beforeExit, "-15 entering final fifteen resumes bounded urgency haptics")
        let beforePause = urgencyHaptics.count
        timer.pause()
        try await Task.sleep(nanoseconds: 500_000_000)
        expect(urgencyHaptics.count == beforePause, "pause cancels urgency haptics")
        presentation.expand()
        presentation.close()
        expect(urgencyHaptics.count == beforePause, "opening and closing full screen cannot duplicate a haptic")
        presentation.setHapticsActive(false, owner: hapticOwner)
        timer.resume()
        try await Task.sleep(nanoseconds: 500_000_000)
        expect(urgencyHaptics.count == beforePause, "inactive or background presentation does not fire urgency haptics")
        timer.reset()
        presentation.setHapticsActive(true, owner: hapticOwner)
        presentation.start(minutes: 1, now: now)
        presentation.close()
        timer.pause(now: now.addingTimeInterval(8))
        expect(timer.deadline == nil && timer.remainingSeconds() == 52, "pause uses existing remaining time")
        for _ in 0..<5 {
            presentation.expand()
            presentation.close()
            expect(timer.deadline == nil && timer.remainingSeconds() == 52 && !presentation.isFullScreen,
                   "pause close reopen retains paused state")
        }
        timer.adjustRemainingSeconds(by: 15, now: now)
        expect(!timer.isRunning && timer.remainingSeconds() == 67, "paused adjustment above original duration remains resumable")
        timer.adjustRemainingSeconds(by: -15, now: now)
        expect(timer.remainingSeconds() == 52 && !presentation.isFullScreen, "paused adjustments do not present")
        timer.resume(now: now.addingTimeInterval(20))
        expect(timer.deadline == now.addingTimeInterval(72) && !presentation.isFullScreen, "Resume uses the paused remainder without auto-open")
        let resumedDeadline = timer.deadline!
        timer.adjustRemainingSeconds(by: 15, now: now.addingTimeInterval(21))
        expect(timer.deadline == resumedDeadline.addingTimeInterval(15) && !presentation.isFullScreen, "running +15 uses canonical adjustment without presenting")
        timer.adjustRemainingSeconds(by: -15, now: now.addingTimeInterval(21))
        expect(timer.deadline == resumedDeadline && !presentation.isFullScreen, "running -15 restores the canonical deadline")
        presentation.expand()
        presentation.opensFullScreenOnStart = false
        expect(presentation.isFullScreen && timer.deadline == resumedDeadline, "preference OFF does not dismiss an existing cover")
        presentation.reset()
        expect(presentation.isFullScreen && timer.deadline == nil && timer.remainingSeconds() == 60, "Reset retains full screen and normal ready duration")
        expect(completionHaptics.isEmpty && VisualTimerToneEngine.completions == 0, "ordinary presentation/pause/reset actions do not complete")

        // Normal near-zero subtraction enters the production feedback loop.
        presentation.start(minutes: 1)
        timer.adjustRemainingSeconds(by: -45)
        expect(timer.remainingSeconds() > 0 && timer.remainingSeconds() <= 15, "full-screen subtraction reaches normal low time")
        timer.adjustRemainingSeconds(by: -15)
        for _ in 0..<20 where timer.isRunning { await Task.yield() }
        expect(timer.isFinished() && !timer.isRunning, "near-zero subtraction completes through the existing loop")
        for _ in 0..<20 where completionHaptics.count < 1 { await Task.yield() }
        expect(completionHaptics == [0.70] && VisualTimerToneEngine.completions == 1, "one completion reference starts the first cue-matched haptic and one audio path")
        expect(presentation.isFullScreen, "completion stays in its existing full-screen presentation")
        for _ in 0..<5 {
            presentation.close()
            presentation.expand()
            expect(timer.isFinished() && timer.deadline == nil, "finished expansion does not reset or complete again")
        }
        expect(completionHaptics == [0.70] && VisualTimerToneEngine.completions == 1, "repeated presentation cannot duplicate feedback")
        try await Task.sleep(nanoseconds: 2_500_000_000)
        expect(completionHaptics == [0.70, 0.76, 0.84, 1.00], "one completion schedules the complete source-derived four-beat pattern")
        presentation.reset()
        expect(completionHaptics.count == 4 && timer.remainingSeconds() == 60, "reset after completion does not replay a completion edge")
        let beatCountBeforePause = beats.count
        presentation.start(minutes: 1, now: Date().addingTimeInterval(-45))
        for _ in 0..<10 where beats.count < beatCountBeforePause + 2 { await Task.yield() }
        expect(beats.count == beatCountBeforePause + 2, "a running timer establishes its bounded two-beat shared cadence queue")
        timer.pause()
        timer.adjustRemainingSeconds(by: -60)
        for _ in 0..<20 where timer.isRunning { await Task.yield() }
        for _ in 0..<20 where completionHaptics.count < 5 { await Task.yield() }
        expect(timer.isFinished() && completionHaptics.count == 5 && VisualTimerToneEngine.completions == 2,
               "paused near-zero subtraction bypasses the preserved beat delay and uses the sole completion path")
        presentation.start(minutes: 1)
        try await Task.sleep(nanoseconds: 2_500_000_000)
        expect(completionHaptics.count == 5, "a new session cancels every stale future completion haptic")

        timer.setCompletionHapticsEnabled(false)
        presentation.start(minutes: 1, now: Date().addingTimeInterval(-61))
        for _ in 0..<20 where timer.isRunning { await Task.yield() }
        expect(timer.isFinished() && completionHaptics.count == 5 && VisualTimerToneEngine.completions == 3,
               "natural deadline expiry honors independent haptic preference")
        presentation.opensFullScreenOnStart = true
        // A fresh UI owner reads the stored choice; a fresh core still follows
        // the existing process-relaunch contract (ready at five minutes).
        let freshTimer = VisualTimerCore(preferenceStore: defaults)
        var freshPresentation: VisualTimerPresentationState? = VisualTimerPresentationState(timer: freshTimer, preferenceStore: defaults)
        weak let releasedPresentation = freshPresentation
        expect(freshPresentation!.opensFullScreenOnStart && !freshPresentation!.isFullScreen, "relaunch persists only preference, never a cover")
        expect(freshTimer.deadline == nil && freshTimer.durationSeconds == 300 && freshTimer.remainingSeconds() == 300,
               "timer persistence across relaunch is unchanged")
        freshPresentation = nil
        expect(releasedPresentation == nil, "presentation subscription does not retain a duplicate controller")
        presentation.close()
        timer.reset()
        _ = beatSubscription

        let view = try String(contentsOfFile: "LifeRoute/ScenicRoyalVisualTimerView.swift", encoding: .utf8)
        let domain = try String(contentsOfFile: "LifeRoute/SessionToolsDomain.swift", encoding: .utf8)
        let embedded = view.components(separatedBy: "var body: some View {")[1]
            .components(separatedBy: "@MainActor\nfinal class VisualTimerPresentationState:")[0]
        expect(embedded.range(of: "ScenicRoyalTimerReadout(")!.lowerBound < embedded.range(of: "ScenicRoyalTimerControls(")!.lowerBound,
               "embedded hierarchy leads with the Orb and remaining time")
        expect(embedded.range(of: "durationCard")!.lowerBound < embedded.range(of: "ScenicRoyalTimerControls(")!.lowerBound,
               "duration selection precedes the primary action and compact preferences")
        expect(embedded.range(of: "durationCard")!.lowerBound < embedded.range(of: "feedbackCard")!.lowerBound,
               "duration and feedback remain available in one secondary flow")
        let root = try String(contentsOfFile: "LifeRoute/V054ContentView.swift", encoding: .utf8)
        let hero = try String(contentsOfFile: "LifeRoute/VisualTimerHero.swift", encoding: .utf8)
        let layer = "VisualTimerHeroLayer(hero: timerHero, router: router)"
        let duplicateRoot = root.replacingOccurrences(of: layer, with: layer + "\n" + layer)
        expect(duplicateRoot != root && !hasSingleRootTimerOwner(root: duplicateRoot, view: view, hero: hero),
               "ownership contract rejects a deliberately duplicated root Timer layer")
        expect(!hasSingleRootTimerOwner(root: root, view: view + ".fullScreenCover(isPresented: $expanded) { TimerView() }", hero: hero),
               "ownership contract rejects an added modal beside the root Timer owner")
        expect(!hasSingleRootTimerOwner(root: root, view: view, hero: hero + "let duplicateWindow = UIWindow(frame: .zero)"),
               "ownership contract rejects a second window for the Timer")
        expect(!hasSingleRootTimerOwner(root: root.replacingOccurrences(of: layer, with: "EmptyView()"), view: view, hero: hero),
               "ownership contract requires a Timer owner rather than merely banning modals")
        expect(hasSingleRootTimerOwner(root: root, view: view, hero: hero),
               "one root-hosted fullscreen Timer owner uses the existing UIWindow without a duplicate modal")
        print("Timer ownership controls passed: duplicate root, modal, extra window and missing owner rejected; accepted Timer D passed.")
        expect(!view.contains("VisualTimerCore()"), "neither presentation constructs a second core")
        expect(view.components(separatedBy: "completionSubscription = timer.completionCuePublisher").count == 2,
               "one UI-lifetime completion subscription")
        expect(!view.contains(".onReceive(timer.$deadline)"), "mounted readout views have no duplicate completion listener")
        let readout = view.components(separatedBy: "struct ScenicRoyalTimerReadout: View {")[1]
            .components(separatedBy: "struct ScenicRoyalTimerControls: View {")[0]
        expect(readout.components(separatedBy: "TimelineView(").count == 2
                && readout.contains("isActive ? VisualTimerFeedbackCurve.readoutInterval : 86_400"),
               "the shared readout uses the existing active cadence and sleeps when inactive")
        expect(readout.contains("if let hero {") && readout.contains("VisualTimerHeroAnchor(hero: hero)")
                && view.components(separatedBy: "ScenicRoyalTimerOrb(").count == 2,
               "embedded presentation supplies an anchor for the sole root-hosted Orb")
        expect(hero.contains(".environment(\\.scenicRoyalThemeStyle, themeStore.selectedTheme.scenicRoyalStyle)"),
               "root-hosted fullscreen content uses the actual selected LifeRoute theme")
        expect(view.contains(".scaleEffect(canvasSize / 340)"), "full canvas and liquid scale uniformly")
        expect(!view.contains("timer.remainingSeconds() >= timer.durationSeconds"), "controls must not mistake an adjusted paused timer for a ready timer")
        let fullscreen = view.components(separatedBy: "struct ScenicRoyalFullScreenTimerView: View {")[1]
            .components(separatedBy: "struct ScenicRoyalHeroOrbReadout: View {")[0]
        expect(!fullscreen.contains("NavigationStack") && !fullscreen.contains("ScenicRoyalToolbar"),
               "fullscreen header has no separate navigation root or toolbar")
        expect(!fullscreen.contains("timer.start") && !fullscreen.contains("timer.reset") && !fullscreen.contains("timer.pause"),
               "fullscreen lifecycle never mutates the timer")
        expect(hero.contains("view.convert(window.safeAreaLayoutGuide.layoutFrame, from: window)")
                && hero.contains("headerHost?.view.frame = layout.header"),
               "root Timer host positions Close inside the existing window safe area")
        expect(fullscreen.contains("Button { hero.presentation?.close() }")
                && fullscreen.contains(".accessibilityAction(.escape) { hero.presentation?.close() }"),
               "Close and accessibility escape collapse the shared presentation without modal dismissal")
        expect(hero.contains("headerHost?.view.alpha = blocked ? 1 : 0")
                && hero.contains("headerHost?.view.accessibilityElementsHidden = !blocked"),
               "fullscreen header remains visible and accessible for the whole expansion")
        expect(hero.contains("surface.capturesInput = blocked")
                && hero.contains("surface.accessibilityViewIsModal = blocked"),
               "the one root Timer surface owns fullscreen hit testing and accessibility scope")
        expect(view.contains("presentation.motionDriver"), "embedded and fullscreen readouts share one motion/cadence state")
        expect(fullscreen.contains("frame(width: 44, height: 44)")
                && fullscreen.contains(".accessibilityIdentifier(\"visualTimer.close\")"),
               "Close retains its accepted native hit target and accessible identity")
        expect(hero.contains("view.addSubview(headerHost!.view)")
                && fullscreen.contains("hero.navigate { [weak hero] in hero?.back?() }"),
               "root host owns the header and settles fullscreen presentation before Back navigation")
        let driver = VisualTimerOrbPresentationDriver()
        let driverOwner = UUID()
        driver.setActive(true, owner: driverOwner, at: 100)
        driver.register(VisualTimerPresentationBeat(VisualTimerScheduledBeat(index: 7, generation: 1, plannedUptime: 101, interval: 1)), at: 100)
        expect(driver.timing(at: 101).pulse > 0.99, "first shared generation reaches the active rim consumer")
        for generation in 2...8 {
            let plannedUptime = 100 + Double(generation)
            driver.invalidate(before: UInt64(generation))
            driver.register(
                VisualTimerPresentationBeat(
                    VisualTimerScheduledBeat(index: 0, generation: UInt64(generation), plannedUptime: plannedUptime, interval: 1)
                ),
                at: plannedUptime - 1
            )
            expect(driver.timing(at: plannedUptime).pulse > 0.99,
                   "restarted generation \(generation) with beat index zero reaches the active rim consumer")
        }
        driver.setActive(false, owner: driverOwner, at: 109)
        expect(view.contains("#if DEBUG\n            if !didApplyFullScreenFixture"), "full-screen capture override is debug-only")
        let core = domain.components(separatedBy: "final class VisualTimerCore:")[1]
            .components(separatedBy: "final class SessionToolsCore:")[0]
        expect(!core.contains("isContinuousOutputActive"), "production output no longer applies the old 2.5-Hz silence gate")
        print("Visual Timer presentation fixtures passed (\(assertions) assertions); production core/state, platform audio/UI doubles.")
    }
}
