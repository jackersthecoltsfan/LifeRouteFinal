import SwiftUI
import UIKit
import AVFoundation
#if DEBUG
import Darwin
#endif

typealias ContentView = V054ContentView

#if DEBUG
private enum LifeRouteDebugLaunch {
    static var sectionOverride: AppSection? {
        section(for: "-LifeRouteSectionOverride")
    }

    private static func section(for argument: String) -> AppSection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: argument) else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return AppSection(rawValue: arguments[valueIndex])
    }
}

private final class LifeRouteDebugSectionSignal {
    static let shared = LifeRouteDebugSectionSignal()

    private var source: DispatchSourceSignal?

    private init() {}

    func install(_ handler: @escaping () -> Void) {
        guard source == nil else { return }
        Darwin.signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler(handler: handler)
        source.resume()
        self.source = source
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
                .background(Color.clear)
                .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
                .tag(AppSection.today)

                NavigationStack(path: $router.schedulePath) {
                    V054ScheduleView(
                        calendarState: calendarState,
                        providerState: providerState,
                        routingState: routingState
                    )
                }
                .background(Color.clear)
                .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
                .tag(AppSection.schedule)

                NavigationStack(path: $router.toolsPath) {
                    V054ToolsDashboard(
                        router: router,
                        toolsState: toolsState,
                        clientState: clientState
                    )
                }
                .background(Color.clear)
                .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
                .tag(AppSection.tools)

                NavigationStack(path: $router.resourcesPath) {
                    ResourcePortalHubView()
                }
                .background(Color.clear)
                .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
                .tag(AppSection.resources)

                NavigationStack(path: $router.setupPath) {
                    V054SetupView(
                        routingState: routingState,
                        clientState: clientState
                    )
                }
                .background(Color.clear)
                .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
                .tag(AppSection.setup)
            }
            .tint(themeStore.palette.accent)
            // v0.7.1 custom LifeRoute bottom toolbar: keep TabView/router ownership, replace only presentation.
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LifeRouteBottomToolbar(
                    selection: $router.selectedSection,
                    palette: themeStore.palette
                )
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
        .background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment
        .animation(.easeInOut(duration: 0.28), value: themeStore.selectedTheme)
        .onAppear {
#if DEBUG
            if let section = LifeRouteDebugLaunch.sectionOverride {
                router.select(section)
            }
            LifeRouteDebugSectionSignal.shared.install {
                router.select(.schedule)
            }
#endif
            // v0.7.1 physical-device root environment reveal: wait one run loop so TabView/UIKit children exist.
            DispatchQueue.main.async {
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
            }
        }
        .onChange(of: router.selectedSection) { _ in
            LifeRouteHaptics.selection()
            // A newly selected tab can materialize a fresh UIKit container after selection changes.
            DispatchQueue.main.async {
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
            }
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
}

// v0.7.1 custom LifeRoute bottom toolbar: approved five-destination gold/navy direction.
private extension AppSection {
    var lifeRouteToolbarTitle: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Calendar"
        case .tools: return "Tools"
        case .resources: return "Resources"
        case .setup: return "Setup"
        }
    }
}

// v0.7.1 final toolbar brand lock: LifeRoute navy/gold chrome stays recognizable across every theme.
private struct LifeRouteBottomToolbar: View {
    @Binding var selection: AppSection
    let palette: LifeRouteThemePalette

    private let brandNavy = Color(red: 0.025, green: 0.070, blue: 0.145)
    private let brandNavyDeep = Color(red: 0.008, green: 0.026, blue: 0.065)
    private let brandGold = Color(red: 0.93, green: 0.70, blue: 0.31)
    private let brandGoldBright = Color(red: 1.00, green: 0.83, blue: 0.49)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppSection.allCases) { section in
                let selected = selection == section

                Button {
                    selection = section
                } label: {
                    VStack(spacing: 4) {
                        LifeRouteTabGlyph(
                            section: section,
                            color: selected ? brandGoldBright : brandGold.opacity(0.78)
                        )
                        .frame(width: 30, height: 28)

                        Text(section.lifeRouteToolbarTitle)
                            .font(.system(size: 10.0, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(selected ? brandGoldBright : Color.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 2)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(brandNavy.opacity(0.96))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [brandGold.opacity(0.11), Color.white.opacity(0.018)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [brandGoldBright.opacity(0.95), brandGold.opacity(0.64)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.25
                                        )
                                }
                                .shadow(color: brandGold.opacity(0.23), radius: 8, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.lifeRouteToolbarTitle)
                // v0.7.1 toolbar accessibility hardening: explicit value avoids conditional OptionSet inference.
                .accessibilityValue(selected ? "Selected" : "")
            }
        }
        .padding(5)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(brandNavyDeep.opacity(0.92))
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(brandNavy.opacity(0.30))
                // Theme color is reflection only; it never owns the navigation chrome.
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(palette.accent.opacity(0.035))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [brandGoldBright.opacity(0.72), Color.white.opacity(0.10), brandGold.opacity(0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.05
                )
        }
        .shadow(color: brandNavyDeep.opacity(0.68), radius: 16, y: 5)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }
}

private struct LifeRouteTabGlyph: View {
    let section: AppSection
    let color: Color

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 32
            let sy = size.height / 30
            let stroke = StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            func strokePath(_ path: Path) {
                context.stroke(path, with: .color(color), style: stroke)
            }

            switch section {
            case .today:
                var mountains = Path()
                mountains.move(to: point(2, 20))
                mountains.addLine(to: point(9, 11))
                mountains.addLine(to: point(15, 18))
                mountains.addLine(to: point(21, 10))
                mountains.addLine(to: point(30, 20))
                strokePath(mountains)

                var route = Path()
                route.move(to: point(5, 26))
                route.addCurve(to: point(17, 21), control1: point(9, 22), control2: point(12, 27))
                route.addCurve(to: point(23, 18), control1: point(19, 20), control2: point(21, 19))
                strokePath(route)

                var star = Path()
                star.move(to: point(18, 3))
                star.addLine(to: point(18, 8))
                star.move(to: point(15.5, 5.5))
                star.addLine(to: point(20.5, 5.5))
                strokePath(star)

            case .schedule:
                let rect = CGRect(x: 5 * sx, y: 5 * sy, width: 22 * sx, height: 20 * sy)
                strokePath(Path(roundedRect: rect, cornerRadius: 3.5 * sx))

                var header = Path()
                header.move(to: point(5, 10))
                header.addLine(to: point(27, 10))
                header.move(to: point(10, 3.5))
                header.addLine(to: point(10, 7))
                header.move(to: point(22, 3.5))
                header.addLine(to: point(22, 7))
                strokePath(header)

                for row in 0..<2 {
                    for column in 0..<3 {
                        let cx = CGFloat(10 + column * 6)
                        let cy = CGFloat(15 + row * 5)
                        let dot = CGRect(x: (cx - 0.9) * sx, y: (cy - 0.9) * sy, width: 1.8 * sx, height: 1.8 * sy)
                        context.fill(Path(ellipseIn: dot), with: .color(color))
                    }
                }

            case .tools:
                var tools = Path()
                tools.move(to: point(6, 24))
                tools.addLine(to: point(24, 6))
                tools.move(to: point(9, 5))
                tools.addLine(to: point(27, 23))
                tools.move(to: point(21.5, 5.5))
                tools.addLine(to: point(26, 4))
                tools.addLine(to: point(28, 6))
                tools.addLine(to: point(25, 9))
                tools.move(to: point(5, 7))
                tools.addLine(to: point(9, 4))
                tools.addLine(to: point(12, 7))
                strokePath(tools)

            case .resources:
                var book = Path()
                book.move(to: point(3, 7))
                book.addCurve(to: point(15.5, 9), control1: point(8, 5), control2: point(12, 6))
                book.addLine(to: point(15.5, 25))
                book.addCurve(to: point(3, 22), control1: point(11, 22), control2: point(7, 21))
                book.closeSubpath()
                book.move(to: point(29, 7))
                book.addCurve(to: point(16.5, 9), control1: point(24, 5), control2: point(20, 6))
                book.addLine(to: point(16.5, 25))
                book.addCurve(to: point(29, 22), control1: point(21, 22), control2: point(25, 21))
                book.closeSubpath()
                strokePath(book)

                var tree = Path()
                tree.move(to: point(23, 11))
                tree.addLine(to: point(20.5, 15))
                tree.addLine(to: point(22.2, 15))
                tree.addLine(to: point(20, 18.5))
                tree.addLine(to: point(26, 18.5))
                tree.addLine(to: point(23.8, 15))
                tree.addLine(to: point(25.5, 15))
                tree.closeSubpath()
                tree.move(to: point(23, 18.5))
                tree.addLine(to: point(23, 21))
                strokePath(tree)

            case .setup:
                let outer = CGRect(x: 5 * sx, y: 4 * sy, width: 22 * sx, height: 22 * sy)
                let inner = CGRect(x: 9 * sx, y: 8 * sy, width: 14 * sx, height: 14 * sy)
                strokePath(Path(ellipseIn: outer))
                strokePath(Path(ellipseIn: inner))

                var spokes = Path()
                for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                    let radians = angle * .pi / 180
                    let x1 = 16 + CGFloat(cos(radians)) * 11
                    let y1 = 15 + CGFloat(sin(radians)) * 11
                    let x2 = 16 + CGFloat(cos(radians)) * 13
                    let y2 = 15 + CGFloat(sin(radians)) * 13
                    spokes.move(to: point(x1, y1))
                    spokes.addLine(to: point(x2, y2))
                }
                strokePath(spokes)

                var needle = Path()
                needle.move(to: point(18.5, 10.5))
                needle.addLine(to: point(14.5, 17.5))
                needle.addLine(to: point(13.5, 19.5))
                needle.addLine(to: point(17.5, 12.5))
                needle.closeSubpath()
                strokePath(needle)
            }
        }
        .accessibilityHidden(true)
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

    @MainActor
    private static func refresh(
        viewController: UIViewController?,
        navigationAppearance: UINavigationBarAppearance,
        tabAppearance: UITabBarAppearance,
        accent: UIColor,
        secondary: UIColor
    ) {
        guard let viewController else { return }

        // v0.7.1 physical-device root environment reveal: UIKit host/controller fills must not cover the shared SwiftUI environment.
        viewController.view.backgroundColor = .clear

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
            // v0.7.1 single-toolbar physical fix: SwiftUI's hidden modifier did not suppress the real iPhone UITabBar.
            // Keep UITabBarController/TabView as the navigation owner, but remove only the stock bar presentation.
            bar.isHidden = true
            bar.alpha = 0
            bar.isUserInteractionEnabled = false
            tabBarController.view.setNeedsLayout()
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
