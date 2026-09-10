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
            // Actual Metal-backed production surfaces; no mocked driver, GPU,
            // attachment, resource preparation or lifecycle implementation.
            try await Task.sleep(nanoseconds: 500_000_000)
            var assertions = 0
            func expect(_ condition: Bool, _ reason: String) {
                assertions += 1
                guard condition else { print("LIVING_NATIVE_FAIL \(reason)"); fflush(stdout); exit(1) }
            }
            let active = LivingScenePlayback(isActive: true, isExposed: true, allowsAnimation: true, reduceMotion: false, effectsEnabled: true)
            var surface: LivingEnvironmentSurface? = LivingEnvironmentSurface(scene: .rainforestDay, playback: active)
            surface!.frame = controller.view.bounds
            controller.view.addSubview(surface!)
            for _ in 0..<100 {
                if surface!.debugRenderer?.debugFrameCount ?? 0 > 5 { break }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            expect(surface!.debugRenderer?.debugIsRunning == true, "visible scene runs")
            expect(!surface!.debugShowsFallback, "real completed Metal frame replaces fallback")
            let renderer = surface!.debugRenderer!
            expect(renderer.debugFrameCount > 5, "actual frame submissions")
            surface!.update(playback: .init(isActive: true, isExposed: false, allowsAnimation: false, reduceMotion: false, effectsEnabled: true))
            let frozenFrames = renderer.debugFrameCount, frozenTime = renderer.debugElapsed
            try await Task.sleep(nanoseconds: 300_000_000)
            expect(renderer.debugFrameCount == frozenFrames, "covered scene submits no frames")
            expect(renderer.debugElapsed == frozenTime, "covered time is frozen")
            surface!.update(playback: active)
            try await Task.sleep(nanoseconds: 150_000_000)
            expect(renderer.debugFrameCount > frozenFrames, "same renderer resumes")
            expect(renderer.debugElapsed - frozenTime < 0.25, "no hidden-time jump")
            surface!.update(playback: .init(isActive: false, isExposed: true, allowsAnimation: true, reduceMotion: false, effectsEnabled: true))
            let backgroundFrames = renderer.debugFrameCount
            try await Task.sleep(nanoseconds: 250_000_000)
            expect(renderer.debugFrameCount == backgroundFrames, "inactive scene submits no frames")
            surface!.update(playback: .init(isActive: true, isExposed: true, allowsAnimation: true, reduceMotion: true, effectsEnabled: true))
            try await Task.sleep(nanoseconds: 100_000_000)
            let reducedFrames = renderer.debugFrameCount
            try await Task.sleep(nanoseconds: 250_000_000)
            expect(renderer.debugFrameCount == reducedFrames && !renderer.debugIsRunning, "Reduce Motion draws once then stops")
            expect(!surface!.debugShowsFallback, "Reduce Motion retains scenery")
            surface!.update(playback: active)
            surface!.removeFromSuperview()
            let detachedFrames = renderer.debugFrameCount
            try await Task.sleep(nanoseconds: 250_000_000)
            expect(renderer.debugFrameCount == detachedFrames && !renderer.debugIsRunning, "detachment stops actual MTKView")
            weak var weakSurface = surface
            surface!.tearDown()
            surface!.tearDown()
            surface = nil
            expect(weakSurface == nil, "surface and notification observers release")
            expect(!renderer.debugIsRunning, "teardown stops retained renderer reference")
            // Rapid changes cancel queued preparations. Each completed episode
            // also releases its renderer after still/living switching.
            for cycle in 0..<12 {
                var candidate: LivingEnvironmentSurface? = LivingEnvironmentSurface(scene: .rainforestDay, playback: active)
                candidate!.frame = controller.view.bounds
                controller.view.addSubview(candidate!)
                if cycle.isMultiple(of: 3) {
                    try await Task.sleep(nanoseconds: 150_000_000)
                }
                weak var weakRenderer = candidate!.debugRenderer
                weak var weakCandidate = candidate
                candidate!.tearDown()
                candidate!.removeFromSuperview()
                candidate = nil
                try await Task.sleep(nanoseconds: 40_000_000)
                expect(weakCandidate == nil, "switch \(cycle) releases surface")
                expect(weakRenderer == nil, "switch \(cycle) releases renderer")
            }
            print("LIVING_NATIVE_PASS \(assertions) assertions; actual Metal/lifecycle/switching/weak-release")
            fflush(stdout)
          } catch {
            print("LIVING_NATIVE_FAIL interrupted test: \(error)"); fflush(stdout)
          }
        }
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(LivingThemeTestApp.self))
