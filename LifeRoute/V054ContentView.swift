import SwiftUI
import UIKit
import AVFoundation

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
        // v0.7.0 Theme Phase 1 single environment shell: background is mounted once by LifeRouteApp chrome.
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
                        providerState: providerState,
                        routingState: routingState
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
        .background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment
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
        let primary = UIColor(palette.textPrimary)
        let secondary = UIColor(palette.textSecondary)
        let background = UIColor(palette.backgroundTop)

        // v0.7.0 Build A shell: premium native navigation and tab chrome; routing remains unchanged.
        let chromeBlurStyle: UIBlurEffect.Style = theme == .light ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = UIBlurEffect(style: chromeBlurStyle)
        navigationAppearance.backgroundColor = background.withAlphaComponent(theme == .light ? 0.84 : 0.76)
        navigationAppearance.shadowColor = accent.withAlphaComponent(0.12)
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: UIFont.systemFont(ofSize: 17, weight: .semibold))
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont.systemFont(ofSize: 32, weight: .bold))
        ]

        let normalTabFont = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .medium))
        let selectedTabFont = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .semibold))
        let tabItems = UITabBarItemAppearance()
        tabItems.normal.iconColor = secondary
        tabItems.normal.titleTextAttributes = [
            .foregroundColor: secondary,
            .font: normalTabFont
        ]
        tabItems.selected.iconColor = accent
        tabItems.selected.titleTextAttributes = [
            .foregroundColor: accent,
            .font: selectedTabFont
        ]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: chromeBlurStyle)
        tabAppearance.backgroundColor = background.withAlphaComponent(theme == .light ? 0.90 : 0.91)
        tabAppearance.shadowColor = accent.withAlphaComponent(0.14)
        tabAppearance.stackedLayoutAppearance = tabItems
        tabAppearance.inlineLayoutAppearance = tabItems
        tabAppearance.compactInlineLayoutAppearance = tabItems

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
            bar.prefersLargeTitles = false
            bar.isTranslucent = true
        }

        if let tabBarController = viewController as? UITabBarController {
            let bar = tabBarController.tabBar
            bar.standardAppearance = tabAppearance
            bar.scrollEdgeAppearance = tabAppearance
            bar.tintColor = accent
            bar.unselectedItemTintColor = secondary
            bar.itemPositioning = .fill
            bar.isTranslucent = true
            bar.layer.masksToBounds = false
            bar.layer.shadowColor = UIColor.black.cgColor
            bar.layer.shadowOpacity = 0.14
            bar.layer.shadowRadius = 10
            bar.layer.shadowOffset = CGSize(width: 0, height: -2)
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
