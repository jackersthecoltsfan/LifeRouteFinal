import UIKit

final class LivingThemeTestApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Living Tests", sessionRole: session.role)
        config.delegateClass = LivingThemeTestScene.self
        return config
    }
}

final class LivingThemeTestScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
        Task { @MainActor in
          do {
            try await Task.sleep(nanoseconds: 500_000_000)
            var assertions = 0
            func expect(_ condition: Bool, _ reason: String) {
                assertions += 1
                guard condition else { print("LIVING_NATIVE_FAIL \(reason)"); fflush(stdout); exit(1) }
            }
            let active = LivingScenePlayback(isActive: true, isExposed: true, allowsAnimation: true, reduceMotion: false, effectsEnabled: true)
            let covered = LivingScenePlayback(isActive: true, isExposed: false, allowsAnimation: false, reduceMotion: false, effectsEnabled: true)
            var surface: LivingEnvironmentSurface? = LivingEnvironmentSurface(scene: .rainforestDay, playback: active)
            surface!.frame = controller.view.bounds
            controller.view.addSubview(surface!)
            func ready() async throws {
                for _ in 0..<120 {
                    if surface!.debugRenderer?.debugFrameCount ?? 0 > 5 { break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                expect(surface!.debugRenderer?.debugIsRunning == true, "visible scene runs")
                expect(!surface!.debugShowsFallback, "completed real Metal frame replaces fallback")
                let counts = LivingSceneDebugOwnership.shared.counts
                expect(counts.renderers == 1 && counts.resources == 1, "one active renderer and one scene resource owner")
            }
            // A-G: enter/exit all three plus the explicit six directed transitions.
            let sequence: [LivingThemeScene] = [.rainforestDay, .oceanDay, .oceanNight, .oceanDay, .rainforestDay, .oceanNight, .rainforestDay]
            for (index, selected) in sequence.enumerated() {
                surface!.update(scene: selected, playback: active)
                if index > 0 { expect(surface!.debugRenderer == nil, "selection immediately releases old renderer") }
                try await ready()
                expect(surface!.debugRenderer!.debugSceneIdentifier == selected.themeIdentifier, "settled resources match selected scene")
                print("LIVING_TRANSITION \(index) \(selected.themeIdentifier)"); fflush(stdout)
                if index > 2 { continue }
                // Timer D / Theme Center use this exact shared exposure contract.
                let elapsed = surface!.debugRenderer!.debugElapsed
                weak var oldRenderer = surface!.debugRenderer
                surface!.update(playback: covered)
                try await Task.sleep(nanoseconds: 150_000_000)
                expect(surface!.debugRenderer == nil && oldRenderer == nil, "cover releases renderer")
                expect(LivingSceneDebugOwnership.shared.counts.resources == 0, "hidden scene owns no expensive resources")
                expect(surface!.debugShowsFallback, "cover retains recognizable still environment")
                surface!.update(playback: active)
                try await ready()
                expect(surface!.debugRenderer!.debugElapsed >= elapsed, "resume preserves active time")
                expect(surface!.debugRenderer!.debugElapsed - elapsed < 0.9, "resume excludes hidden time")
                // Actual production UIApplication notification handlers.
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                expect(surface!.debugRenderer == nil, "background tears down driver and drawables")
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                try await ready()
                surface!.update(playback: .init(isActive: true, isExposed: true, allowsAnimation: true, reduceMotion: true, effectsEnabled: true))
                expect(surface!.debugRenderer!.debugQuality.framesPerSecond == 15, "Reduce Motion lowers cadence")
                expect(surface!.debugRenderer!.debugQuality.motionAmount == 0.25, "Reduce Motion calms primary movement")
                let reducedFrames = surface!.debugRenderer!.debugFrameCount
                try await Task.sleep(nanoseconds: 300_000_000)
                expect(surface!.debugRenderer!.debugFrameCount > reducedFrames, "calm water still renders")
                surface!.update(playback: active)
                surface!.debugSetConstraints(lowPower: true, thermal: .nominal)
                expect(surface!.debugRenderer!.debugQuality.framesPerSecond == 20 && surface!.debugRenderer!.debugQuality.atmosphereAmount == 0, "low-power actual surface drops secondary detail and cadence")
                surface!.debugSetConstraints(lowPower: false, thermal: .serious)
                expect(surface!.debugRenderer!.debugQuality.maximumDrawableDimension == 960, "serious thermal reduces pixels")
                surface!.debugSetConstraints(lowPower: false, thermal: .critical)
                expect(!surface!.debugRenderer!.debugIsRunning, "critical thermal stops continuous driver")
                // MTKView can service the layout/policy redraw already queued
                // before isPaused changed. Observe steady state after that turn.
                try await Task.sleep(nanoseconds: 120_000_000)
                let stillFrames = surface!.debugRenderer!.debugFrameCount
                try await Task.sleep(nanoseconds: 120_000_000)
                expect(stillFrames == surface!.debugRenderer!.debugFrameCount && !surface!.debugShowsFallback, "static rendered scene persists without submissions")
                surface!.debugSetConstraints(lowPower: false, thermal: .nominal)
                surface!.update(playback: .init(isActive: false, isExposed: true, allowsAnimation: true, reduceMotion: false, effectsEnabled: true))
                expect(surface!.debugRenderer == nil, "scenePhase inactivity releases renderer")
                surface!.update(playback: active)
                try await ready()
            }
            // L: changes faster than the settling deadline never publish stale work.
            for index in 0..<24 {
                surface!.update(scene: sequence[(index + 1) % sequence.count], playback: active)
                expect(surface!.debugRenderer == nil, "rapid selection has no obsolete allocation")
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            surface!.update(scene: .oceanNight, playback: active)
            let selectedAt = CACurrentMediaTime()
            try await Task.sleep(nanoseconds: 180_000_000)
            if CACurrentMediaTime() - selectedAt < 0.25 {
                expect(surface!.debugRenderer == nil, "no heavy renderer before 250 ms")
            }
            try await ready()
            expect(surface!.debugRenderer!.debugSceneIdentifier == "scenery.ocean.night", "no stale scene published after rapid selection")
            expect(LivingEnvironmentSurface.activationDelayNanoseconds == 250_000_000, "bounded 250 ms policy")
            // M: bounded repeated cross-family cycles each return to zero.
            for index in 0..<9 {
                surface!.update(scene: sequence[index % 3], playback: active)
                try await ready()
                weak var oldRenderer = surface!.debugRenderer
                surface!.removeFromSuperview()
                try await Task.sleep(nanoseconds: 100_000_000)
                expect(oldRenderer == nil && surface!.debugRenderer == nil, "detachment releases scene")
                let counts = LivingSceneDebugOwnership.shared.counts
                expect(counts.renderers == 0 && counts.resources == 0, "switch release returns resource counts to baseline")
                controller.view.addSubview(surface!)
            }
            weak var weakSurface = surface
            surface!.tearDown(); surface!.tearDown(); surface!.removeFromSuperview(); surface = nil
            try await Task.sleep(nanoseconds: 300_000_000)
            expect(weakSurface == nil, "surface, observers and pending activation release")
            expect(LivingSceneDebugOwnership.shared.counts.renderers == 0 && LivingSceneDebugOwnership.shared.counts.resources == 0, "final ownership baseline")
            print("LIVING_NATIVE_PASS \(assertions) assertions; real Metal, seven transitions, lifecycle, calm/constrained, debounce and bounded release")
            fflush(stdout)
          } catch {
            print("LIVING_NATIVE_FAIL interrupted test: \(error)"); fflush(stdout)
          }
        }
    }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(LivingThemeTestApp.self))
