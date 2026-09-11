import UIKit

final class LivingCaptureApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Living Capture", sessionRole: session.role)
        config.delegateClass = LivingCaptureScene.self
        return config
    }
}

final class LivingCaptureScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var surface: LivingEnvironmentSurface?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene,
              let id = CommandLine.arguments.last, let selected = LivingThemeScene.scene(for: id) else { exit(2) }
        let window = UIWindow(windowScene: ws), controller = UIViewController()
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
        let surface = LivingEnvironmentSurface(scene: selected, playback: .init(isActive: true,
            isExposed: true, allowsAnimation: true, reduceMotion: false, effectsEnabled: true))
        self.surface = surface
        surface.frame = controller.view.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.addSubview(surface)
        Task { @MainActor in
            for _ in 0..<160 {
                if let renderer = surface.debugRenderer, renderer.debugFrameCount > 5, !surface.debugShowsFallback {
                    let counts = LivingSceneDebugOwnership.shared.counts
                    guard counts.renderers == 1 && counts.resources == 1 else { print("CAPTURE_FAIL ownership"); fflush(stdout); exit(1) }
                    print("CAPTURE_READY scene=\(id) program=\(selected.fragmentFunction) rendererCount=1 resourceCount=1"); fflush(stdout)
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            print("CAPTURE_FAIL no completed Metal presentation"); fflush(stdout); exit(1)
        }
    }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(LivingCaptureApp.self))
