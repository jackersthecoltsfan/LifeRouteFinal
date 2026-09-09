import Foundation
import Combine

@main struct TimerDHeroTests {
    @MainActor static var assertions = 0
    @MainActor static func expect(_ result: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        precondition(result(), message)
    }
    static let slot = CGRect(x: 74, y: 180, width: 252, height: 252)
    static let full = CGRect(x: 20, y: 100, width: 390, height: 390)
    static func driver() -> VisualTimerHeroTransition {
        var result = VisualTimerHeroTransition()
        result.updateGeometry(anchor: slot, expanded: full)
        return result
    }
    @MainActor static func settle(_ driver: inout VisualTimerHeroTransition) {
        for _ in 0..<300 where driver.needsFrames { driver.advance(by: 1 / 120.0) }
        expect(!driver.needsFrames, "bounded settlement")
    }
    @MainActor static func main() async throws {
        continuity()
        geometry()
        try await interruptionAndCompletion()
        print("PASS Timer D: exactly 3 focused groups; \(assertions) assertions")
    }
    @MainActor static func continuity() {
        let probe = TimerProbe(); defer { probe.close() }
        let timerID = ObjectIdentifier(probe.timer)
        let motionID = ObjectIdentifier(probe.presentation.motionDriver)
        let date = Date().addingTimeInterval(10000)
        probe.presentation.start(minutes: 1, now: date)
        let deadline = probe.timer.deadline
        var d = driver()
        expect(d.frame == slot && d.progress == 0, "collapsed source endpoint")
        probe.presentation.expand(); d.request(expanded: true)
        d.advance(by: 0.115)
        expect(d.progress > 0.3 && d.progress < 0.5 && d.velocity > 0, "mid expansion")
        let p = d.progress, v = d.velocity, f = d.frame
        probe.presentation.close(); d.request(expanded: false)
        expect(d.progress == p && d.velocity == v && d.frame == f, "Close preserves position and momentum")
        d.advance(by: 0.08)
        expect(d.velocity < 0, "spring reverses naturally")
        let cp = d.progress, cv = d.velocity
        probe.presentation.expand(); d.request(expanded: true)
        expect(d.progress == cp && d.velocity == cv, "reverse collapse retains velocity")
        settle(&d)
        expect(d.progress == 1 && d.frame == full, "fullscreen reached")
        d.request(expanded: false); settle(&d)
        expect(d.progress == 0 && d.frame == slot && !d.blocksNavigation, "return reached")
        expect(ObjectIdentifier(probe.timer) == timerID && ObjectIdentifier(probe.presentation.motionDriver) == motionID,
               "same production timer and Orb phase driver")
        expect(probe.timer.deadline == deadline && probe.timer.remainingSeconds(at: date) == 60,
               "presentation leaves running deadline untouched")
        var sixty = driver(), oneTwenty = driver(), delayed = driver()
        sixty.request(expanded: true); oneTwenty.request(expanded: true); delayed.request(expanded: true)
        for _ in 0..<15 { sixty.advance(by: 1 / 60.0) }
        for _ in 0..<30 { oneTwenty.advance(by: 1 / 120.0) }
        delayed.advance(by: 0.25)
        expect(abs(sixty.progress - oneTwenty.progress) < 1e-12 && abs(sixty.progress - delayed.progress) < 1e-12,
               "time-based motion survives late presentation frame without time debt")
        print("PASS D1 presentation continuity / both reversals / production identities")
    }
    @MainActor static func geometry() {
        var d = driver(); d.request(expanded: true); d.advance(by: 0.16)
        let p = d.progress, v = d.velocity, originalFrame = d.frame
        let rotatedSlot = CGRect(x: 130, y: 88, width: 252, height: 252)
        let rotatedFull = CGRect(x: 66, y: 84, width: 300, height: 300)
        d.updateGeometry(anchor: rotatedSlot, expanded: rotatedFull)
        expect(d.progress == p && d.velocity == v, "rotation preserves scalar progress and velocity")
        expect(d.frame != nil && d.frame != originalFrame && !d.isFading,
               "valid geometry update follows fresh endpoints without stale-frame freezing")
        d.request(expanded: false)
        let newest = rotatedSlot.offsetBy(dx: 18, dy: -14)
        d.updateGeometry(anchor: newest, expanded: rotatedFull)
        settle(&d)
        expect(d.frame == newest && d.frame != slot, "return uses newest layout anchor")
        d.request(expanded: true); settle(&d)
        d.updateGeometry(anchor: slot, expanded: full)
        expect(d.progress == 1 && d.frame == full, "expanded rotation adopts latest hero endpoint")
        for safe in [CGRect(x: 0, y: 62, width: 440, height: 860), CGRect(x: 62, y: 0, width: 832, height: 419)] {
            let layout = VisualTimerHeroLayout(safeArea: safe, controlsHeight: 285, accessibilitySize: false)
            expect(layout.orb.width == layout.orb.height && layout.orb.width <= 480, "aspect and accepted scale ceiling")
            expect(safe.contains(layout.orb) && !layout.orb.intersects(layout.controls) && !layout.orb.intersects(layout.header),
                   "live safe-area frame reserves controls")
        }
        var reduced = driver(); reduced.reduceMotion = true; reduced.request(expanded: true)
        reduced.advance(by: 0.02)
        expect(reduced.frame == slot, "Reduce Motion fades at embedded endpoint")
        settle(&reduced)
        expect(reduced.frame == full && reduced.orbOpacity == 1, "Reduce Motion reaches fullscreen without bloom")
        reduced.request(expanded: false); settle(&reduced)
        expect(reduced.frame == slot, "Reduce Motion returns correctly")
        print("PASS D2 geometry / latest anchor / rotation / Reduce Motion")
    }
    @MainActor static func interruptionAndCompletion() async throws {
        var d = driver(); d.request(expanded: true); d.advance(by: 0.12)
        d.requestNavigation()
        expect(!d.takeSettledNavigation(), "Back cannot navigate before collapse")
        settle(&d)
        expect(d.takeSettledNavigation() && !d.takeSettledNavigation(), "Back executes exactly once after settlement")
        d.request(expanded: true); d.advance(by: 0.2)
        let frame = d.frame
        d.updateGeometry(anchor: nil, expanded: full)
        expect(d.isFading && d.frame == frame && d.blocksNavigation, "anchor loss freezes current presentation")
        d.requestNavigation(); d.advance(by: 0.09)
        expect(d.frame == frame && abs(d.fallbackOpacity - 0.5) < 1e-12, "bounded fade without positional return")
        d.request(expanded: true)
        d.advance(by: 0.1)
        expect(!d.blocksNavigation && d.frame == nil && d.takeSettledNavigation(), "fallback clears stranded presentation and navigation")
        d.request(expanded: false)
        expect(d.frame == nil, "old anchor cannot reappear after fallback")

        var combined = driver(); combined.request(expanded: true); combined.advance(by: 0.2)
        let presented = combined.frame!
        let changedSlot = CGRect(x: 112, y: 96, width: 224, height: 224)
        let changedFull = CGRect(x: 122.25, y: 76, width: 298, height: 298)
        combined.updateGeometry(anchor: changedSlot, expanded: changedFull)
        let recomputed = combined.frame!
        expect(recomputed != presented && !combined.isFading,
               "combined regression calculates a distinct geometry frame G")
        combined.updateGeometry(anchor: nil, expanded: changedFull,
                                lastPresentedFrame: presented)
        expect(combined.isFading && combined.frame == presented && combined.frame != recomputed,
               "anchor loss freezes presented frame P without presenting G first")
        combined.updateGeometry(anchor: changedSlot, expanded: full,
                                lastPresentedFrame: recomputed)
        expect(combined.frame == presented,
               "later geometry callbacks cannot replace the fallback frozen frame")
        combined.advance(by: 0.09)
        expect(combined.frame == presented && abs(combined.fallbackOpacity - 0.5) < 1e-12,
               "combined fade begins and remains at presented frame P")
        combined.advance(by: 0.1)
        expect(combined.frame == nil && !combined.blocksNavigation,
               "combined fallback clears hero state after its bounded fade")

        let probe = TimerProbe(); defer { probe.close() }
        let timer = probe.timer
        let t = Date().addingTimeInterval(10000)
        probe.presentation.start(minutes: 1, now: t)
        let generation = timer.completionCueSessionID
        let audioBefore = VisualTimerToneEngine.completions
        d = driver(); d.request(expanded: true); d.advance(by: 0.1)
        let before = d.progress
        expect(before > 0 && before < 1 && d.velocity > 0 && d.target == 1 && d.needsFrames,
               "completion scenario begins with hero transition actually in flight")
        timer.processCompletion(at: t.addingTimeInterval(60), generation: generation)
        timer.processCompletion(at: t.addingTimeInterval(60), generation: generation)
        expect(probe.cues.count == 1 && VisualTimerToneEngine.completions == audioBefore + 1, "one production completion during expansion")
        expect(d.progress == before && d.target == 1, "completion leaves presentation state alone")
        d.request(expanded: false); d.advance(by: 0.05)
        timer.processCompletion(at: t.addingTimeInterval(60), generation: generation)
        settle(&d)
        expect(probe.cues.count == 1 && d.frame == slot && !timer.isRunning, "reversal cannot duplicate completion or corrupt return")
        print("PASS D3 Back ordering / bounded anchor loss / production completion separation")
    }
}
