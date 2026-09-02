import SwiftUI
import UIKit
import AVFoundation

typealias ContentView = V054ContentView

#if DEBUG
private enum LifeRouteDebugLaunch {
    static var sectionOverride: AppSection? {
        section(for: "-LifeRouteSectionOverride")
    }

    static var toolsDestinationOverride: SessionToolRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteToolsDestinationOverride") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        switch arguments[valueIndex] {
        case "visualTimer": return .visualTimer
        default: return nil
        }
    }

    private static func section(for argument: String) -> AppSection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: argument) else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return AppSection(rawValue: arguments[valueIndex])
    }
}

#endif

struct V054ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @StateObject private var lifecycleState = AppLifecycleCore()
    @StateObject private var router = AppRouter()
    @StateObject private var calendarState = CalendarCoreState()
    @StateObject private var providerState = CalendarProviderCore()
    @StateObject private var routingState = RoutingLocationCore()
    @StateObject private var dayPlanState = DayRoutePlanningCore()
    @StateObject private var liveDayActivity = LiveDayActivityCore()
    @StateObject private var clientState = ClientProfileCore()
    @StateObject private var toolsState = SessionToolsCore()

    var body: some View {
        rootShell
            .environmentObject(router)
            .tint(themeStore.palette.accent)
        .background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment
        .onAppear {
#if DEBUG
            if let section = LifeRouteDebugLaunch.sectionOverride {
                router.select(section)
            }
#endif
            // v0.7.1 physical-device root environment reveal: wait one run loop so TabView/UIKit children exist.
            DispatchQueue.main.async {
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
            }
        }
        .onChange(of: router.selectedSection) { section in
            router.setBottomToolbarSuppressed(false)
            LifeRouteHaptics.rootNavigation()
        }
        .onChange(of: themeStore.selectedTheme) { theme in
            DispatchQueue.main.async {
                LifeRouteAppearance.refreshVisibleChrome(theme: theme)
            }
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

    private var toolsDashboard: some View {
        V054ToolsDashboard(
            router: router,
            toolsState: toolsState,
            clientState: clientState
        )
    }

    @ViewBuilder
    private var rootShell: some View {
        if #available(iOS 26.0, *) {
            fingerTrackedRootShell
        } else {
            legacyRootShell
        }
    }

    @available(iOS 26.0, *)
    /// Prototype B is the canonical iOS 26 root shell. TabView's page style
    /// owns continuous finger tracking, while the shared router still owns
    /// five root identities, nested paths, and bottom-toolbar visibility.
    private var fingerTrackedRootShell: some View {
        TabView(selection: $router.selectedSection) {
            todayRoot
                .tag(AppSection.today)
            calendarRoot
                .tag(AppSection.schedule)
            toolsRoot
                .tag(AppSection.tools)
            resourcesRoot
                .tag(AppSection.resources)
            setupRoot
                .tag(AppSection.setup)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.shouldShowBottomToolbar {
                LifeRouteRootPagingToolbar(selection: $router.selectedSection)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, ScenicRoyalDesignSystem.Layout.bottomToolbarClearance)
            }
        }
        .modifier(LifeRouteRootPagingAmbientSuspensionModifier(router: router))
    }

    private var legacyRootShell: some View {
            TabView(selection: $router.selectedSection) {
                todayRoot
                    .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
                    .tag(AppSection.today)
                calendarRoot
                    .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
                    .tag(AppSection.schedule)
                toolsRoot
                    .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
                    .tag(AppSection.tools)
                resourcesRoot
                    .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
                    .tag(AppSection.resources)
                setupRoot
                    .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
                    .tag(AppSection.setup)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if router.shouldShowBottomToolbar {
                    ScenicRoyalToolbar(selection: $router.selectedSection)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, ScenicRoyalDesignSystem.Layout.bottomToolbarClearance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }

    private var todayRoot: some View {
        LifeRouteRootNavigationStack(path: $router.todayPath) {
            V054TodayView(
                router: router,
                calendarState: calendarState,
                routingState: routingState,
                planState: dayPlanState,
                liveActivity: liveDayActivity
            )
        }
    }

    private var calendarRoot: some View {
        LifeRouteRootNavigationStack(path: $router.schedulePath) {
            V054ScheduleView(calendarState: calendarState, providerState: providerState)
        }
    }

    private var toolsRoot: some View {
        LifeRouteRootNavigationStack(path: $router.toolsPath) {
#if DEBUG
            if LifeRouteDebugLaunch.toolsDestinationOverride == .visualTimer {
                VisualTimerView(timer: toolsState.timer)
                    .lifeRouteDeepDestination()
            } else {
                toolsDashboard
            }
#else
            toolsDashboard
#endif
        }
    }

    private var resourcesRoot: some View {
        LifeRouteRootNavigationStack(path: $router.resourcesPath) {
            ResourcePortalHubView()
        }
    }

    private var setupRoot: some View {
        LifeRouteRootNavigationStack(path: $router.setupPath) {
            V054SetupView(routingState: routingState, clientState: clientState)
        }
    }
}

/// One material owner wraps the five fixed root destinations. Individual tabs
/// use tint and a compact indicator rather than layered material or capsules.
@available(iOS 26.0, *)
private struct LifeRouteRootPagingToolbar: View {
    @Environment(\.lifeRoutePalette) private var palette

    @Binding var selection: AppSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Capsule()
                            .fill(section == selection ? palette.accent : .clear)
                            .frame(width: 14, height: 3)
                    }
                    .foregroundStyle(section == selection ? palette.accent : palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityValue(section == selection ? "Selected" : "")
                .accessibilityHint("Switches root destination")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .overlay {
            Capsule()
                .stroke(palette.accent.opacity(0.16), lineWidth: 0.8)
        }
        .glassEffect(.clear.tint(palette.accent.opacity(0.12)), in: .capsule)
        .accessibilityElement(children: .contain)
    }
}

/// Prototype B keeps its native finger-tracked page gesture. This observer
/// pauses only the shared ambient clock while that gesture and its settling
/// animation are active, avoiding competing per-frame scenery redraws.
@MainActor
@available(iOS 26.0, *)
private struct LifeRouteRootPagingAmbientSuspensionModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var visualActivityCoordinator: LifeRouteVisualActivityCoordinator
    @StateObject private var suspension = LifeRouteRootPagingAmbientSuspension()
    @ObservedObject var router: AppRouter

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard router.shouldShowBottomToolbar,
                              abs(value.translation.width) >= abs(value.translation.height) * 1.2
                        else {
                            return
                        }
                        suspension.begin(using: visualActivityCoordinator)
                    }
                    .onEnded { _ in
                        suspension.finish(using: visualActivityCoordinator)
                    }
            )
            .onDisappear {
                suspension.releaseImmediately(using: visualActivityCoordinator)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    suspension.releaseImmediately(using: visualActivityCoordinator)
                }
            }
            .onChange(of: router.shouldShowBottomToolbar) { _, shouldShow in
                if !shouldShow {
                    suspension.releaseImmediately(using: visualActivityCoordinator)
                }
            }
    }
}

@MainActor
private final class LifeRouteRootPagingAmbientSuspension: ObservableObject {
    private static let settleDelayNanoseconds: UInt64 = 320_000_000

    private var requestID: UUID?
    private var releaseTask: Task<Void, Never>?

    func begin(using coordinator: LifeRouteVisualActivityCoordinator) {
        releaseTask?.cancel()
        releaseTask = nil
        guard requestID == nil else { return }
        requestID = coordinator.acquireAmbientSuspension()
    }

    func finish(using coordinator: LifeRouteVisualActivityCoordinator) {
        releaseTask?.cancel()
        guard let requestID else { return }

        releaseTask = Task { @MainActor [weak self, weak coordinator] in
            try? await Task.sleep(nanoseconds: Self.settleDelayNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  let coordinator,
                  self.requestID == requestID
            else {
                return
            }
            self.requestID = nil
            self.releaseTask = nil
            coordinator.releaseAmbientSuspension(requestID)
        }
    }

    func releaseImmediately(using coordinator: LifeRouteVisualActivityCoordinator) {
        releaseTask?.cancel()
        releaseTask = nil
        guard let requestID else { return }
        self.requestID = nil
        coordinator.releaseAmbientSuspension(requestID)
    }
}
/// Owns the transparent navigation-container surface once for every paged root.
/// On iOS 26 this replaces the former live UIKit controller-tree mutation that
/// could both expose black lazy-page backgrounds and assert inside navigation layout.
private struct LifeRouteRootNavigationStack<Content: View>: View {
    @Binding var path: NavigationPath
    private let content: Content

    init(path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
        _path = path
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            navigationContent
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var navigationContent: some View {
        if #available(iOS 26.0, *) {
            content.containerBackground(Color.clear, for: .navigation)
        } else {
            content
        }
    }
}

extension LifeRouteAppearance {
    @MainActor
    static func refreshVisibleChrome(theme: LifeRouteTheme) {
        guard LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(
            ProcessInfo.processInfo.operatingSystemVersion
        ) else {
            clearNativeContainerBackgrounds()
            return
        }

        let palette = theme.palette
        let accent = UIColor(palette.accent)
        let primary = UIColor(palette.textPrimary)
        let secondary = UIColor(palette.textSecondary)
        let background = UIColor(palette.backgroundTop)
        let needsOpaqueChrome = UIAccessibility.isReduceTransparencyEnabled
            || UIAccessibility.isDarkerSystemColorsEnabled

        // Pre-iOS 26 UIKit appearance fallback; routing remains unchanged.
        let chromeBlurStyle: UIBlurEffect.Style = theme == .light ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark

        let navigationAppearance: UINavigationBarAppearance?
        if LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(
            ProcessInfo.processInfo.operatingSystemVersion
        ) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = needsOpaqueChrome ? UIBlurEffect(style: chromeBlurStyle) : nil
            appearance.backgroundColor = needsOpaqueChrome
                ? background.withAlphaComponent(theme == .light ? 0.92 : 0.88)
                : .clear
            appearance.shadowColor = accent.withAlphaComponent(0.12)
            appearance.titleTextAttributes = [
                .foregroundColor: primary,
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: UIFont.systemFont(ofSize: 17, weight: .semibold))
            ]
            appearance.largeTitleTextAttributes = [
                .foregroundColor: primary,
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont.systemFont(ofSize: 32, weight: .bold))
            ]
            navigationAppearance = appearance
        } else {
            // iOS 26 native Liquid Glass must remain the visible navigation
            // surface; do not rewrite a live UINavigationBar during layout.
            navigationAppearance = nil
        }

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
                window.backgroundColor = .clear
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

    /// Native iOS 26 TabView provides the system tab bar, but its UIKit host
    /// views otherwise default to opaque black and cover the single Scenic
    /// Royal environment behind the five roots. This intentionally clears only
    /// host fills after creation; it never rewrites navigation/tab-bar layout
    /// or appearance during a transition.
    @MainActor
    private static func clearNativeContainerBackgrounds() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where !window.isHidden {
                clearContainerBackgrounds(in: window.rootViewController)
            }
        }
    }

    @MainActor
    private static func clearContainerBackgrounds(in viewController: UIViewController?) {
        guard let viewController else { return }
        viewController.view.backgroundColor = .clear

        if let presented = viewController.presentedViewController {
            clearContainerBackgrounds(in: presented)
        }

        for child in viewController.children {
            clearContainerBackgrounds(in: child)
        }
    }

    @MainActor
    private static func refresh(
        viewController: UIViewController?,
        navigationAppearance: UINavigationBarAppearance?,
        tabAppearance: UITabBarAppearance,
        accent: UIColor,
        secondary: UIColor
    ) {
        guard let viewController else { return }

        // v0.7.1 physical-device root environment reveal: UIKit host/controller fills must not cover the shared SwiftUI environment.
        viewController.view.backgroundColor = .clear

        if let navigationAppearance, let navigationController = viewController as? UINavigationController {
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
            // v0.7.1 single-toolbar physical fix: SwiftUI's hidden modifier did not suppress the real iPhone UITabBar.
            // Keep UITabBarController/TabView as the navigation owner, but remove only the stock bar presentation.
            bar.isHidden = true
            bar.alpha = 0
            bar.isUserInteractionEnabled = false
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
        guard LifeRouteAudioSessionOwnership.allowsThemeFeedback else { return }
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
