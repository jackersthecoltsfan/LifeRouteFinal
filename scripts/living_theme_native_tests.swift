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
                    if surface!.debugRenderer?.debugFrameCount ?? 0 > 5,
                       surface!.debugRenderer?.debugSceneIdentifier == surface!.debugRequestedSceneIdentifier,
                       LivingSceneDebugOwnership.shared.counts.resources == 1 { break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                expect(surface!.debugRenderer?.debugIsRunning == true, "visible scene runs")
                expect(!surface!.debugShowsFallback, "completed real Metal frame replaces fallback")
                let counts = LivingSceneDebugOwnership.shared.counts
                expect(counts.renderers == 1 && counts.resources == 1, "one active renderer and one scene resource owner")
            }
            // Enter/exit every scene, both directions of every Day/Night pair,
            // and the six adjacent cross-family transitions, then repeat release.
            let catalogue = LivingThemeRegistration.all.compactMap(\.scene)
            var sequence: [LivingThemeScene] = []
            for family in 0..<6 { sequence += [catalogue[family * 2], catalogue[family * 2 + 1], catalogue[family * 2]] }
            sequence.append(.rainforestDay)
            var lifecycleChecked = Set<String>()
            for (index, selected) in sequence.enumerated() {
                weak var previousRenderer = surface!.debugRenderer
                let previousElapsed = previousRenderer?.debugElapsed ?? 0
                surface!.update(scene: selected, playback: active)
                if index > 0 {
                    expect(surface!.debugRenderer === previousRenderer, "selection retains the one foreground renderer")
                    expect(!surface!.debugShowsFallback, "selection does not reveal a static fallback")
                }
                try await ready()
                expect(surface!.debugRenderer!.debugElapsed >= max(2, previousElapsed), "first and selected frames use continuing nonzero phase")
                expect(surface!.debugRenderer!.debugSceneIdentifier == selected.themeIdentifier, "settled resources match selected scene")
                print("LIVING_TRANSITION \(index) \(selected.themeIdentifier)"); fflush(stdout)
                if !lifecycleChecked.insert(selected.themeIdentifier).inserted { continue }
                // Actual opaque coverage such as Timer D uses this exposure contract.
                // Theme Center and root interaction no longer withdraw exposure.
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
            // L: rapidly superseded preparations cannot replace the final scene;
            // the one renderer remains active throughout selection work.
            weak var switchingRenderer = surface!.debugRenderer
            let switchingElapsed = switchingRenderer!.debugElapsed
            for index in 0..<36 {
                surface!.update(scene: sequence[(index + 1) % sequence.count], playback: active)
                expect(surface!.debugRenderer === switchingRenderer, "rapid selection keeps one renderer authority")
                expect(surface!.debugRenderer!.debugIsRunning && !surface!.debugShowsFallback, "preceding scene stays alive while preparing")
                expect(LivingSceneDebugOwnership.shared.counts.resources <= 2, "only active and one preparing resource set")
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            surface!.update(scene: .oceanNight, playback: active)
            try await ready()
            expect(surface!.debugRenderer!.debugSceneIdentifier == "scenery.ocean.night", "no stale scene published after rapid selection")
            expect(surface!.debugRenderer === switchingRenderer, "final selection retains renderer identity")
            expect(surface!.debugRenderer!.debugElapsed > switchingElapsed, "selection preparation never pauses the foreground clock")
            // M: bounded repeated cross-family cycles each return to zero.
            for index in 0..<24 {
                surface!.update(scene: catalogue[index % catalogue.count], playback: active)
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
            print("LIVING_NATIVE_PASS \(assertions) assertions; real Metal, full catalogue and paired transitions, lifecycle, calm/constrained, cancellation, foreground continuity and bounded release")
            fflush(stdout)
          } catch {
            print("LIVING_NATIVE_FAIL interrupted test: \(error)"); fflush(stdout)
          }
        }
    }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(LivingThemeTestApp.self))
