#if DEBUG
import SwiftUI
import UIKit

/// Engineering-only launch selection; normal product navigation never owns QA.
enum LivingThemeQALaunch {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-LifeRouteLivingThemeQAViewer")
    }
}

/// This owner has no product route, theme store or persistence mutation API.
@MainActor
final class LivingThemeQAController: ObservableObject {
    @Published private(set) var sceneIdentifier: String
    @Published var isPaused = false
    @Published var previewReduceMotion = false
    @Published var isRunning = true
    private let initialPreferences: NSDictionary

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let key = arguments.firstIndex(of: "-LifeRouteLivingThemeQAScene")
        let requested = key.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        sceneIdentifier = requested.flatMap { LivingThemeScene.scene(for: $0)?.themeIdentifier }
            ?? LivingThemeRegistration.all[0].themeIdentifier
        initialPreferences = Self.productPreferences()
    }

    var preferencesUnchanged: Bool { initialPreferences.isEqual(Self.productPreferences()) }

    private static func productPreferences() -> NSDictionary {
        (UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]) as NSDictionary
    }

    func step(_ offset: Int) {
        let scenes = LivingThemeRegistration.all
        guard let index = scenes.firstIndex(where: { $0.themeIdentifier == sceneIdentifier }) else { return }
        sceneIdentifier = scenes[(index + offset % scenes.count + scenes.count) % scenes.count].themeIdentifier
    }
}

/// Direct-launch harness. The production environment below is the sole rendering
/// path; no product ContentView, navigation, theme store or restoration is used.
struct LivingThemeQAViewer: View {
    @StateObject private var controller = LivingThemeQAController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var controlsVisible = false
    @State private var rendererSummary = "Preparing"
    @State private var rendererValue = "{}"

    private var theme: LifeRouteTheme { LifeRouteTheme(rawValue: controller.sceneIdentifier)! }

    var body: some View {
        ZStack(alignment: .bottom) {
            if controller.isRunning {
                LifeRouteLiveThemeEnvironment(
                    theme: theme, palette: theme.palette,
                    reduceMotion: systemReduceMotion || controller.previewReduceMotion,
                    isActive: scenePhase == .active, renderMode: .full,
                    allowsAnimation: !controller.isPaused
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                Color.black.ignoresSafeArea()
            }

            Button { controlsVisible.toggle() } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controlsVisible ? "Hide QA controls" : "Show QA controls")
            .accessibilityIdentifier("livingQA.toggleControls")
            .ignoresSafeArea()

            if controlsVisible {
                VStack(spacing: 12) {
                    Text(theme.name)
                        .font(.headline)
                        .accessibilityIdentifier("livingQA.sceneName")
                    Text("Source \(Self.sourceCommit) · \(rendererSummary)")
                        .font(.caption.monospaced())
                        .accessibilityIdentifier("livingQA.hud")
                        .accessibilityValue(rendererValue)
                    HStack {
                        Button { controller.step(-1) } label: { Label("Previous", systemImage: "chevron.left") }
                            .accessibilityLabel("Previous Scene")
                            .accessibilityIdentifier("livingQA.previous")
                        Spacer()
                        Button { controller.step(1) } label: { Label("Next", systemImage: "chevron.right") }
                            .accessibilityLabel("Next Scene")
                            .accessibilityIdentifier("livingQA.next")
                    }
                    .disabled(!controller.isRunning)
                    HStack {
                        Button(controller.isPaused ? "Resume" : "Pause") { controller.isPaused.toggle() }
                            .accessibilityIdentifier("livingQA.pause")
                        Button(controller.previewReduceMotion ? "Reduce Motion: On" : "Reduce Motion: Off") {
                            controller.previewReduceMotion.toggle()
                        }
                        .font(.caption)
                        .accessibilityIdentifier("livingQA.reduceMotion")
                        .accessibilityValue(controller.previewReduceMotion ? "On" : "Off")
                    }
                    .disabled(!controller.isRunning)
                    Button(controller.isRunning ? "End QA" : "Restart QA") { controller.isRunning.toggle() }
                        .accessibilityIdentifier("livingQA.session")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .foregroundStyle(.white)
                .tint(.white)
                .task {
                    // Visible engineering HUD only. Unobstructed captures have no
                    // polling task and never feed frame time into production UI.
                    while !Task.isCancelled {
                        updateSnapshot()
                        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                    }
                }
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear { controlsVisible = voiceOver }
        .task(id: controller.sceneIdentifier + "-\(controller.isRunning)") {
            guard controller.isRunning, ProcessInfo.processInfo.arguments.contains("-LifeRouteLivingDiagnostics") else { return }
            for _ in 0..<50 {
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                let state = snapshot()
                if state["renderers"] as? Int == 1, state["resources"] as? Int == 1,
                   state["scene"] as? String == controller.sceneIdentifier,
                   (state["frames"] as? Int ?? 0) > 1 {
                    emit(state, event: "ready")
                    return
                }
            }
            emit(snapshot(), event: "not-ready")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) { _ in
            // Observe the actual window-scene transition. Production rendering
            // has already become inactive before this background notification.
            emit(snapshot(), event: "background")
        }
    }

    private static let sourceCommit: String = {
        guard let url = Bundle.main.url(forResource: "LifeRouteSourceCommit", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "unavailable" }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.count == 7 && value.allSatisfy(Set("0123456789abcdef").contains) ? value : "unavailable"
    }()

    private func snapshot() -> [String: Any] {
        var surfaces: [LivingEnvironmentSurface] = []
        var productRoots = 0
        func inspect(_ view: UIView) {
            if let surface = view as? LivingEnvironmentSurface { surfaces.append(surface) }
            view.subviews.forEach(inspect)
        }
        func inspectController(_ viewController: UIViewController) {
            if String(describing: type(of: viewController)) == "LifeRouteRootPagerController" { productRoots += 1 }
            viewController.children.forEach(inspectController)
            if let presented = viewController.presentedViewController { inspectController(presented) }
        }
        for window in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows) {
            inspect(window)
            if let root = window.rootViewController { inspectController(root) }
        }
        let renderers = surfaces.compactMap(\.debugRenderer)
        let renderer = renderers.first
        let counts = LivingSceneDebugOwnership.shared.counts
        return ["scene": renderer?.debugSceneIdentifier ?? "none", "surfaces": surfaces.count,
                "productRoots": productRoots, "renderers": counts.renderers, "resources": counts.resources,
                "running": renderers.filter(\.debugIsRunning).count,
                "fps": renderer?.debugQuality.framesPerSecond ?? 0,
                "frames": renderer?.debugFrameCount ?? 0, "elapsed": renderer?.debugElapsed ?? 0,
                "preferencesUnchanged": controller.preferencesUnchanged]
    }

    private func updateSnapshot() {
        let state = snapshot()
        rendererSummary = "\(state["renderers"]!) renderer · \(state["fps"]!) fps · \((state["running"] as? Int ?? 0) == 1 ? "Running" : "Paused")"
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]),
           let value = String(data: data, encoding: .utf8) { rendererValue = value }
    }

    private func emit(_ state: [String: Any], event: String) {
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteLivingDiagnostics"),
              let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else { return }
        print("LIVING_QA_\(event.uppercased()) \(value)")
        fflush(stdout)
    }
}
#endif
