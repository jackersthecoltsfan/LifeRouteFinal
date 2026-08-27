import SwiftUI
import UIKit
import AVFoundation

typealias ContentView = V054ContentView

struct V054ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @StateObject private var lifecycleState = AppLifecycleCore()
    @StateObject private var router = AppRouter()
    @StateObject private var calendarState = CalendarCoreState()
    @StateObject private var providerState = CalendarProviderCore()
    @StateObject private var routingState = RoutingLocationCore()
    @StateObject private var clientState = ClientProfileCore()
    @StateObject private var toolsState = SessionToolsCore()

    var body: some View {
        ZStack {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.palette
            )
            .ignoresSafeArea()

            TabView(selection: $router.selectedSection) {
                NavigationStack(path: $router.todayPath) {
                    V054TodayView(
                        router: router,
                        calendarState: calendarState,
                        routingState: routingState
                    )
                }
                .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
                .tag(AppSection.today)

                NavigationStack(path: $router.schedulePath) {
                    V054ScheduleView(
                        calendarState: calendarState,
                        providerState: providerState
                    )
                }
                .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
                .tag(AppSection.schedule)

                NavigationStack(path: $router.toolsPath) {
                    V054ToolsDashboard(
                        router: router,
                        toolsState: toolsState,
                        clientState: clientState
                    )
                }
                .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
                .tag(AppSection.tools)

                NavigationStack(path: $router.resourcesPath) {
                    ResourcePortalHubView()
                }
                .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
                .tag(AppSection.resources)

                NavigationStack(path: $router.setupPath) {
                    V054SetupView(
                        routingState: routingState,
                        clientState: clientState
                    )
                }
                .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
                .tag(AppSection.setup)
            }
            .tint(themeStore.palette.accent)
        }
        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)
        .onChange(of: router.selectedSection) { _ in
            LifeRouteHaptics.selection()
        }
        .onChange(of: themeStore.selectedTheme) { theme in
            LifeRouteAppearance.refreshVisibleChrome(theme: theme)
            LifeRouteThemeFeedbackSound.shared.play()
        }
        .onOpenURL { url in
            if url.scheme?.lowercased() == "liferoute" {
                router.select(.today)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                routingState.resumeForegroundLocationIfNeeded()
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
                return
            }

            lifecycleState.flushPersistenceForSceneTransition()
            if phase == .background {
                routingState.cancelPendingOperations()
            }
        }
    }
}

extension LifeRouteAppearance {
    @MainActor
    static func refreshVisibleChrome(theme: LifeRouteTheme) {
        let palette = theme.palette
        let accent = UIColor(palette.accent)
        let secondary = UIColor.white.withAlphaComponent(0.58)
        let background = UIColor(palette.backgroundTop)

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navigationAppearance.backgroundColor = background.withAlphaComponent(0.78)
        navigationAppearance.shadowColor = accent.withAlphaComponent(0.10)
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabAppearance.backgroundColor = background.withAlphaComponent(0.88)
        tabAppearance.shadowColor = accent.withAlphaComponent(0.09)

        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where !window.isHidden {
                refresh(
                    viewController: window.rootViewController,
                    navigationAppearance: navigationAppearance,
                    tabAppearance: tabAppearance,
                    accent: accent,
                    secondary: secondary
                )
            }
        }
    }

    @MainActor
    private static func refresh(
        viewController: UIViewController?,
        navigationAppearance: UINavigationBarAppearance,
        tabAppearance: UITabBarAppearance,
        accent: UIColor,
        secondary: UIColor
    ) {
        guard let viewController else { return }

        if let navigationController = viewController as? UINavigationController {
            let bar = navigationController.navigationBar
            bar.standardAppearance = navigationAppearance
            bar.scrollEdgeAppearance = navigationAppearance
            bar.compactAppearance = navigationAppearance
            bar.tintColor = accent
        }

        if let tabBarController = viewController as? UITabBarController {
            let bar = tabBarController.tabBar
            bar.standardAppearance = tabAppearance
            bar.scrollEdgeAppearance = tabAppearance
            bar.tintColor = accent
            bar.unselectedItemTintColor = secondary
        }

        if let presented = viewController.presentedViewController {
            refresh(
                viewController: presented,
                navigationAppearance: navigationAppearance,
                tabAppearance: tabAppearance,
                accent: accent,
                secondary: secondary
            )
        }

        for child in viewController.children {
            refresh(
                viewController: child,
                navigationAppearance: navigationAppearance,
                tabAppearance: tabAppearance,
                accent: accent,
                secondary: secondary
            )
        }
    }
}

private final class LifeRouteThemeFeedbackSound {
    static let shared = LifeRouteThemeFeedbackSound()

    private let queue = DispatchQueue(label: "LifeRoute.ThemeFeedbackSound")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var isPrepared = false

    private lazy var format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate,
        channels: 1
    )!

    func play() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)

                if !self.isPrepared {
                    self.engine.attach(self.player)
                    self.engine.connect(self.player, to: self.engine.mainMixerNode, format: self.format)
                    self.player.volume = 0.16
                    self.isPrepared = true
                }
                if !self.engine.isRunning { try self.engine.start() }
                guard let buffer = self.makeBuffer() else { return }
                self.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
                if !self.player.isPlaying { self.player.play() }
            } catch {
                // UI sound is optional; never block a theme change if audio is unavailable.
            }
        }
    }

    private func makeBuffer() -> AVAudioPCMBuffer? {
        let duration = 0.18
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = min(1, t / 0.008) * exp(-21 * t)
            let first = sin(2 * Double.pi * 660 * t)
            let second = 0.42 * sin(2 * Double.pi * 990 * t)
            samples[frame] = Float((first + second) * envelope * 0.38)
        }
        return buffer
    }
}
