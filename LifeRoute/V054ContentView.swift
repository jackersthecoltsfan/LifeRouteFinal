import SwiftUI
import UIKit
import AVFoundation
import Combine

typealias ContentView = V054ContentView

#if DEBUG
/// Passive, opt-in measurements of the production hierarchy. Never feeds
/// geometry back into layout and records no labels, field values, or app data.
private struct LifeRouteRootGeometryTrace: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    let role: String
    let theme: String
    let root: String
    let toolbarVisible: Bool

    private struct Sample: Hashable {
        let role: String
        let theme: String
        let root: String
        let toolbarVisible: Bool
        let frame: [Double]
        let safeArea: [Double]
        let textSize: String
        let phase: String
    }

    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-LifeRouteRootGeometryTrace") {
            content.background {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    let inset = proxy.safeAreaInsets
                    let sample = Sample(
                        role: role, theme: theme, root: root, toolbarVisible: toolbarVisible,
                        frame: [frame.minX, frame.minY, frame.width, frame.height].map(Double.init),
                        safeArea: [inset.top, inset.leading, inset.bottom, inset.trailing].map(Double.init),
                        textSize: String(describing: dynamicTypeSize), phase: String(describing: scenePhase)
                    )
                    Color.clear.task(id: sample) {
                        // Two matching samples establish settling without a display link.
                        for settleSample in 1...2 {
                            do { try await Task.sleep(nanoseconds: 400_000_000) }
                            catch { return }
                            capture(sample, settleSample: settleSample)
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        } else {
            content
        }
    }

    @MainActor
    private func capture(_ sample: Sample, settleSample: Int) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        func rect(_ value: CGRect) -> [Double] {
            [value.minX, value.minY, value.width, value.height].map(Double.init)
        }
        var scrolls: [[String: Any]] = []
        var hasFirstResponder = false
        func inspect(_ view: UIView) {
            hasFirstResponder = hasFirstResponder || view.isFirstResponder
            if let scroll = view as? UIScrollView, !scroll.isHidden, scroll.alpha > 0 {
                scrolls.append([
                    "frame": rect(scroll.convert(scroll.bounds, to: window)),
                    "offset": [Double(scroll.contentOffset.x), Double(scroll.contentOffset.y)],
                    "contentSize": [Double(scroll.contentSize.width), Double(scroll.contentSize.height)],
                    "adjustedInset": [Double(scroll.adjustedContentInset.top), Double(scroll.adjustedContentInset.bottom)],
                ])
            }
            for child in view.subviews { inspect(child) }
        }
        if sample.role == "root" { inspect(window) }
        let livingOwnership = LivingSceneDebugOwnership.shared.counts
        let data: [String: Any] = [
            "livingRendererOwners": livingOwnership.renderers,
            "livingResourceOwners": livingOwnership.resources,
            "schema": 1, "uptime": ProcessInfo.processInfo.systemUptime,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "role": sample.role, "theme": sample.theme, "root": sample.root,
            "toolbarVisible": sample.toolbarVisible, "frame": sample.frame,
            "swiftUISafeArea": sample.safeArea, "dynamicType": sample.textSize,
            "scenePhase": sample.phase, "settleSample": settleSample,
            "windowBounds": rect(window.bounds), "scale": Double(window.screen.scale),
            "windowSafeArea": [Double(window.safeAreaInsets.top), Double(window.safeAreaInsets.left), Double(window.safeAreaInsets.bottom), Double(window.safeAreaInsets.right)],
            "orientation": window.windowScene?.interfaceOrientation.rawValue ?? 0,
            "visualClearance": Double(ScenicRoyalDesignSystem.Layout.bottomToolbarClearance),
            "reduceMotion": UIAccessibility.isReduceMotionEnabled,
            "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
            "increaseContrast": UIAccessibility.isDarkerSystemColorsEnabled,
            "hasFirstResponder": hasFirstResponder, "scrollViews": scrolls,
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]),
              let line = String(data: bytes, encoding: .utf8) else { return }
        print("LIFEROUTE_ROOT_GEOMETRY " + line)
        fflush(stdout)
    }
}

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
    @EnvironmentObject private var visualActivity: LifeRouteVisualActivityCoordinator
    @StateObject private var timerAmbientLease = LifeRouteOwnedHandle()

    @StateObject private var lifecycleState = AppLifecycleCore()
    @StateObject private var router = AppRouter()
    @StateObject private var visibility = LifeRouteVisibilityOwner()
    @StateObject private var calendarState = CalendarCoreState()
    @StateObject private var providerState = CalendarProviderCore()
    @StateObject private var routingState = RoutingLocationCore()
    @StateObject private var dayPlanState = DayRoutePlanningCore()
    @StateObject private var liveDayActivity = LiveDayActivityCore()
    @StateObject private var clientState = ClientProfileCore()
    @StateObject private var toolsState = SessionToolsCore()
    @StateObject private var sessionNoteRuntime = AISessionNoteRuntimeModel(
        generator: SessionNoteGeneratorFactory.make()
    )
    @StateObject private var timerHero = VisualTimerHeroCoordinator()

    var body: some View {
        rootShell
#if DEBUG
            .modifier(LifeRouteRootGeometryTrace(role: "root", theme: themeStore.selectedTheme.rawValue, root: router.selectedSection.rawValue, toolbarVisible: router.shouldShowBottomToolbar))
#endif
            .environmentObject(router)
            .environmentObject(visibility)
            .tint(themeStore.selectedTheme.scenicRoyalStyle.selectedControlFill)
        .background(Color.clear) // v0.7.0 Theme Phase 1 reveal the single root environment
        .onAppear {
            visibility.scene(scenePhase, immediate: true)
            timerAmbientLease.reconcile(timerHero.blocksNavigation, acquire: visualActivity.acquireAmbientSuspension,
                                        release: visualActivity.releaseAmbientSuspension)
#if DEBUG
            if let section = LifeRouteDebugLaunch.sectionOverride {
                router.select(section)
            }
#endif
            // v0.7.1 physical-device root environment reveal: refresh after UIKit children have mounted.
            DispatchQueue.main.async {
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
            }
        }
        .task(id: "\(scenePhase)-\(liveDayActivity.run?.startedAt.timeIntervalSince1970 ?? 0)-\(dayPlanState.generatedItinerary?.fingerprint ?? "")") {
            guard scenePhase == .active, let itinerary = dayPlanState.generatedItinerary,
                  liveDayActivity.run?.matches(itinerary) == true else { return }
            await liveDayActivity.followWhileActive(itinerary: itinerary)
        }
        .onChange(of: router.selectedSection) { section in
            LifeRouteHaptics.rootNavigation()
        }
        .onChange(of: themeStore.selectedTheme) { _ in
            // Native glass containers were made transparent when the root mounted.
            // Only legacy themed chrome needs another hierarchy walk per selection.
            if LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(ProcessInfo.processInfo.operatingSystemVersion) {
                DispatchQueue.main.async {
                    LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
                }
            }
            LifeRouteThemeFeedbackSound.shared.play()
        }
        // Reuse the root ambient coordinator while Timer D covers the scene.
        // Timer presentation, geometry, feedback and animation remain its owners.
        .onChange(of: timerHero.blocksNavigation) { covered in
            timerAmbientLease.reconcile(covered, acquire: visualActivity.acquireAmbientSuspension,
                                        release: visualActivity.releaseAmbientSuspension)
        }
        .onDisappear {
            timerAmbientLease.reconcile(false, acquire: visualActivity.acquireAmbientSuspension,
                                        release: visualActivity.releaseAmbientSuspension)
        }
        .onOpenURL { url in
            if url.scheme?.lowercased() == "liferoute" {
                router.select(.today)
            }
        }
        .onChange(of: scenePhase) { phase in
            visibility.scene(phase, immediate: true)
            if phase == .active {
                routingState.resumeForegroundLocationIfNeeded()
                LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)
                return
            }

            sessionNoteRuntime.flushDraftPersistence()
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
            clientState: clientState,
            sessionNoteRuntime: sessionNoteRuntime
        )
        .lifeRouteRootScope()
    }

    private var rootShell: some View {
        rootShellContent
            .overlay {
                VisualTimerHeroLayer(hero: timerHero, router: router)
                    .ignoresSafeArea()
                    .allowsHitTesting(timerHero.blocksNavigation)
            }
    }

    @ViewBuilder
    private var rootShellContent: some View {
        if #available(iOS 26.0, *) {
            fingerTrackedRootShell
        } else {
            legacyRootShell
        }
    }

    private var persistentRootPager: some View {
        LifeRoutePersistentRootPager(router: router, visibility: visibility, roots: [
            .init(section: .today, content: AnyView(todayRoot)),
            .init(section: .schedule, content: AnyView(calendarRoot)),
            .init(section: .tools, content: AnyView(toolsRoot)),
            .init(section: .resources, content: AnyView(resourcesRoot)),
            .init(section: .setup, content: AnyView(setupRoot)),
        ])
    }

    @available(iOS 26.0, *)
    private var fingerTrackedRootShell: some View {
        persistentRootPager
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if router.shouldShowBottomToolbar {
                    LifeRouteRootPagingToolbar(selection: $router.selectedSection)
#if DEBUG
                        .modifier(LifeRouteRootGeometryTrace(role: "toolbar", theme: themeStore.selectedTheme.rawValue, root: router.selectedSection.rawValue, toolbarVisible: router.shouldShowBottomToolbar))
#endif
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, rootToolbarBottomClearance)
#if DEBUG
                        .modifier(LifeRouteRootGeometryTrace(role: "toolbar-host", theme: themeStore.selectedTheme.rawValue, root: router.selectedSection.rawValue, toolbarVisible: router.shouldShowBottomToolbar))
#endif
                }
            }
    }

    private var legacyRootShell: some View {
        persistentRootPager
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if router.shouldShowBottomToolbar {
                    ScenicRoyalToolbar(selection: $router.selectedSection)
#if DEBUG
                        .modifier(LifeRouteRootGeometryTrace(role: "toolbar", theme: themeStore.selectedTheme.rawValue, root: router.selectedSection.rawValue, toolbarVisible: router.shouldShowBottomToolbar))
#endif
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, rootToolbarBottomClearance)
#if DEBUG
                        .modifier(LifeRouteRootGeometryTrace(role: "toolbar-host", theme: themeStore.selectedTheme.rawValue, root: router.selectedSection.rawValue, toolbarVisible: router.shouldShowBottomToolbar))
#endif
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    /// `safeAreaInset` places and reserves its content inside the system bottom
    /// safe area. Supplying that live inset again here counted the home-indicator
    /// region twice and lifted the toolbar too far above its native position.
    /// This token is only the established visual breathing room; the inset still
    /// owns the full page-content reservation.
    private var rootToolbarBottomClearance: CGFloat {
        ScenicRoyalDesignSystem.Layout.bottomToolbarClearance
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
            .lifeRouteRootScope()
        }
    }

    private var calendarRoot: some View {
        LifeRouteRootNavigationStack(path: $router.schedulePath) {
            V054ScheduleView(calendarState: calendarState, providerState: providerState)
                .lifeRouteRootScope()
        }
        .ui01ContentStyle()
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
        .environmentObject(timerHero)
        .ui01ContentStyle()
    }

    private var resourcesRoot: some View {
        LifeRouteRootNavigationStack(path: $router.resourcesPath) {
            ResourcePortalHubView().lifeRouteRootScope()
        }
        .ui01ContentStyle()
    }

    private var setupRoot: some View {
        LifeRouteRootNavigationStack(path: $router.setupPath) {
            V054SetupView(
                routingState: routingState,
                clientState: clientState
            )
            .lifeRouteRootScope()
        }
        .ui01ContentStyle()
    }
}

/// One material owner wraps the five fixed root destinations. Individual tabs
/// use tint and a compact indicator rather than layered material or capsules.
@available(iOS 26.0, *)
private struct LifeRouteRootPagingToolbar: View {

    @Binding var selection: AppSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    UI01DockLabel(section: section, selected: section == selection)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityValue(section == selection ? "Selected" : "")
                .accessibilityAddTraits(section == selection ? .isSelected : [])
                .accessibilityHint("Switches root destination")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .modifier(UI01CompactControlSurface())
        .accessibilityElement(children: .contain)
    }
}

// BEGIN PERMANENT ROOT PAGER
/// Immutable registration. The content value is consumed only when its host is
/// created; subsequent representable updates cannot transplant a root subtree.
private struct LifeRouteRootRegistration {
    let section: AppSection
    let content: AnyView
}

@MainActor
private final class LifeRouteRootEnvironmentRelay: ObservableObject {
    @Published var values: EnvironmentValues

    init(_ values: EnvironmentValues) { self.values = values }
}

private struct LifeRoutePermanentRoot: View {
    @ObservedObject var relay: LifeRouteRootEnvironmentRelay
    let owner: LifeRouteOwningRoot
    let visibility: LifeRouteVisibilityOwner
    let rootVisibility: LifeRouteRootVisibility
    let content: AnyView
    let router: AppRouter
    let themeStore: LifeRouteThemeStore
    let visualActivity: LifeRouteVisualActivityCoordinator

    var body: some View {
        content
            .transformEnvironment(\.self) { values in
                let parent = relay.values
                // Copy effective parent inputs, never a parent's dismiss/focus
                // action. Each retained NavigationStack owns those locally.
                values.scenePhase = parent.scenePhase
                values.lifeRouteTheme = parent.lifeRouteTheme
                values.lifeRoutePalette = parent.lifeRoutePalette
                values.scenicRoyalThemeStyle = parent.scenicRoyalThemeStyle
                values.dynamicTypeSize = parent.dynamicTypeSize
                values.colorScheme = parent.colorScheme
                // Read-only contrast/accessibility/VoiceOver inputs come from
                // native traits and system notifications in each retained host.
                values.legibilityWeight = parent.legibilityWeight
                values.displayScale = parent.displayScale
                values.horizontalSizeClass = parent.horizontalSizeClass
                values.verticalSizeClass = parent.verticalSizeClass
                values.layoutDirection = parent.layoutDirection
                values.locale = parent.locale
                values.calendar = parent.calendar
                values.timeZone = parent.timeZone
                values.openURL = parent.openURL
                values.isEnabled = parent.isEnabled
                values.defaultMinListRowHeight = parent.defaultMinListRowHeight
                values.lifeRouteOwningRoot = owner
            }
            .environmentObject(router)
            .environmentObject(themeStore)
            .environmentObject(visualActivity)
            .environmentObject(visibility)
            .scrollContentBackground(.hidden)
            .tint(relay.values.scenicRoyalThemeStyle.selectedControlFill)
            .preferredColorScheme(relay.values.scenicRoyalThemeStyle.nativeColorScheme)
    }
}

private struct LifeRoutePersistentRootPager: UIViewControllerRepresentable {
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
    @EnvironmentObject private var visualActivity: LifeRouteVisualActivityCoordinator
    let router: AppRouter
    let visibility: LifeRouteVisibilityOwner
    let roots: [LifeRouteRootRegistration]

    func makeUIViewController(context: Context) -> LifeRouteRootPagerController {
        LifeRouteRootPagerController(roots: roots, router: router, visibility: visibility,
                                    themeStore: themeStore, visualActivity: visualActivity,
                                    environment: context.environment)
    }

    func updateUIViewController(_ controller: LifeRouteRootPagerController, context: Context) {
        precondition(roots.map(\.section) == AppSection.allCases, "Unexpected root registry")
        controller.receiveEnvironment(context.environment)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: LifeRouteRootPagerController,
                     context: Context) -> CGSize? {
        // The strip's content size never participates in SwiftUI measurement.
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    static func dismantleUIViewController(_ controller: LifeRouteRootPagerController, coordinator: ()) {
        controller.tearDown()
    }
}

private final class LifeRouteRootPagerScrollView: UIScrollView {
    var moveAccessibilityPage: ((UIAccessibilityScrollDirection) -> Bool)?
    // New contacts have one admitted root. Keeping the hosting views enabled
    // preserves an existing responder through provisional, reversible motion.
    weak var admittedRootView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        guard let root = admittedRootView,
              hit === root || hit.isDescendant(of: root) else { return self }
        return hit
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        moveAccessibilityPage?(direction) ?? false
    }
}

/// One scene-lifetime parent and one non-recycling viewport. UIKit owns only
/// transient progress; AppRouter remains the sole discrete selection authority.
@MainActor
private final class LifeRouteRootPagerController: UIViewController, UIScrollViewDelegate {
    private enum Motion {
        case idle
        case dragging(UInt64)
        case decelerating(UInt64)
    }

    let scrollView = LifeRouteRootPagerScrollView()
    private(set) var hosts: [AppSection: UIHostingController<LifeRoutePermanentRoot>] = [:]
    private let router: AppRouter
    let visibility: LifeRouteVisibilityOwner
    private var visibilitySubscription: AnyCancellable?
    private var timerHeroSubscription: AnyCancellable?
    private var layoutRevision: UInt64 = 0
    private var transitionOrigin: AppSection?
    private var actuallyExposed = false
    private let visualActivity: LifeRouteVisualActivityCoordinator
    private let relay: LifeRouteRootEnvironmentRelay
    private var selectionSubscription: AnyCancellable?
    private var motion = Motion.idle
    private var generation: UInt64 = 0
    private var writesSelection = false
    private var requestedSelection: AppSection
    private var settledSelection: AppSection
    private var pendingSelection: (generation: UInt64, section: AppSection)?
    private var pendingEnvironment: EnvironmentValues?
    private var environmentUpdateScheduled = false
    private var viewport = CGSize.zero
    private var rightToLeft: Bool
    private var laysOutStrip = false
    private var parentVisible = false
    private var appeared = Set<AppSection>()
    private var appearing = Set<AppSection>()
    private var parentDisappearing = Set<AppSection>()
    private var ambientRequest: UUID?
    private(set) var allocationCount = 0
    private(set) var teardownCount = 0
    private var tornDown = false
#if DEBUG
    private var traceBand = -1
#endif

    init(roots: [LifeRouteRootRegistration], router: AppRouter, visibility: LifeRouteVisibilityOwner,
         themeStore: LifeRouteThemeStore, visualActivity: LifeRouteVisualActivityCoordinator,
         environment: EnvironmentValues) {
        precondition(roots.map(\.section) == AppSection.allCases && roots.count == 5,
                     "Exactly five fixed root registrations required")
        self.router = router
        self.visibility = visibility
        visibility.scene(environment.scenePhase)
        self.visualActivity = visualActivity
        self.relay = LifeRouteRootEnvironmentRelay(environment)
        self.requestedSelection = router.selectedSection
        self.settledSelection = router.selectedSection
        self.rightToLeft = environment.layoutDirection == .rightToLeft
        super.init(nibName: nil, bundle: nil)
        loadViewIfNeeded()
        for root in roots {
            let host = UIHostingController(rootView: LifeRoutePermanentRoot(
                relay: relay, owner: LifeRouteOwningRoot(section: root.section),
                visibility: visibility, rootVisibility: visibility.roots[root.section]!, content: root.content,
                router: router, themeStore: themeStore, visualActivity: visualActivity))
            precondition(hosts[root.section] == nil)
            hosts[root.section] = host
            allocationCount += 1
            addChild(host)
            host.view.backgroundColor = .clear
            scrollView.addSubview(host.view)
            host.view.frame = pageFrame(root.section, size: view.bounds.size)
            host.didMove(toParent: self)
        }
        visibilitySubscription = visibility.revisions.sink { [weak self] _ in self?.updateInteraction() }
        timerHeroSubscription = router.$timerHeroNavigationBlocked.sink { [weak self] blocked in
            self?.updateInteraction(timerHeroBlocked: blocked)
        }
        updateInteraction()
        selectionSubscription = router.$selectedSection.dropFirst().sink { [weak self] section in
            guard let self, !self.writesSelection else { return }
            // @Published delivers before storage changes. Invalidate old gesture
            // completions now; consume the request after that publication ends.
            self.generation &+= 1
            self.requestedSelection = section
            self.pendingSelection = (self.generation, section)
            self.updateInteraction()
            self.visibility.requested(section, generation: self.generation)
            let requestGeneration = self.generation
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.tornDown,
                      let request = self.pendingSelection,
                      request.generation == requestGeneration,
                      self.generation == requestGeneration else { return }
                self.pendingSelection = nil
                self.stopMechanicalMotion()
                self.settle(on: request.section, publish: false)
            }
        }
        scrollView.moveAccessibilityPage = { [weak self] direction in
            self?.accessibilityPage(direction) ?? false
        }
        trace("created")
    }

    required init?(coder: NSCoder) { fatalError("Use the fixed root registry") }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.isPagingEnabled = true
        scrollView.bounces = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.semanticContentAttribute = .forceLeftToRight
        view.addSubview(scrollView)
    }

    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        parentVisible = true
        actuallyExposed = true
        publishVisibility()
        beginIncoming(requestedSelection, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        finishAppearance(on: requestedSelection)
        publishVisibility()
        trace("parent.appeared")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelInteraction()
        parentVisible = false
        for section in appeared {
            hosts[section]?.beginAppearanceTransition(false, animated: animated)
        }
        parentDisappearing = appeared
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        for section in parentDisappearing { hosts[section]?.endAppearanceTransition() }
        appeared.subtract(parentDisappearing)
        parentDisappearing.removeAll()
        actuallyExposed = false
        publishVisibility()
        trace("parent.disappeared")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else {
            layoutRevision &+= 1
            publishVisibility()
            return
        }
        let newRTL = relay.values.layoutDirection == .rightToLeft
        guard viewport != size || newRTL != rightToLeft else { return }
        var progress = viewport.width > 0 ? scrollView.contentOffset.x / viewport.width : CGFloat(index(requestedSelection))
        if newRTL != rightToLeft { progress = 4 - progress }
        rightToLeft = newRTL
        if case .idle = motion { progress = CGFloat(index(requestedSelection)) }
        laysOutStrip = true
        viewport = size
        layoutRevision &+= 1
        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: size.width * 5, height: size.height)
        for section in AppSection.allCases { hosts[section]?.view.frame = pageFrame(section, size: size) }
        scrollView.contentOffset = CGPoint(x: min(4, max(0, progress)) * size.width, y: 0)
        laysOutStrip = false
        stageVisiblePages()
        publishVisibility()
        trace("layout")
    }

    func receiveEnvironment(_ environment: EnvironmentValues) {
        visibility.scene(environment.scenePhase)
        pendingEnvironment = environment
        guard !environmentUpdateScheduled else { return }
        environmentUpdateScheduled = true
        // Coalesce SwiftUI transactions outside updateUIViewController; this is
        // a publication boundary, never a navigation timing/settling heuristic.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.tornDown, let environment = self.pendingEnvironment else { return }
            self.environmentUpdateScheduled = false
            self.pendingEnvironment = nil
            self.relay.values = environment
            if environment.scenePhase != .active { self.cancelInteraction() }
            if !self.router.shouldShowBottomToolbar { self.releaseAmbient() }
            self.view.setNeedsLayout()
            self.trace("environment")
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard pendingSelection == nil else { return }
        generation &+= 1
        motion = .dragging(generation)
        transitionOrigin = settledSelection
        publishVisibility()
        if router.shouldShowBottomToolbar, ambientRequest == nil {
            ambientRequest = visualActivity.acquireForegroundInteraction()
        }
        updateInteraction()
        trace("drag.begin")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !laysOutStrip, !tornDown else { return }
        stageVisiblePages()
        publishVisibility()
#if DEBUG
        let band = viewport.width > 0 ? Int(scrollView.contentOffset.x / viewport.width * 4) : 0
        if band != traceBand { traceBand = band; trace("drag.progress") }
#endif
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard case let .dragging(id) = motion, id == generation, pendingSelection == nil else { return }
        if decelerate { motion = .decelerating(id); publishVisibility() }
        else { completeGesture(id) }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard case let .decelerating(id) = motion, !scrollView.isDragging,
              !scrollView.isDecelerating else { return }
        completeGesture(id)
    }

    private func completeGesture(_ id: UInt64) {
        guard id == generation, pendingSelection == nil else { return }
        settle(on: section(at: scrollView.contentOffset.x), publish: true)
    }

    private func settle(on section: AppSection, publish: Bool) {
        guard !tornDown else { return }
        motion = .idle
        let old = settledSelection
        settledSelection = section
        if publish {
            requestedSelection = section
            writesSelection = true
            router.select(section)
            writesSelection = false
        }
        laysOutStrip = true
        scrollView.setContentOffset(CGPoint(x: CGFloat(index(section)) * viewport.width, y: 0), animated: false)
        laysOutStrip = false
        transitionOrigin = nil
        publishVisibility(committedFrom: old != section ? old : nil)
        // Focus belongs to a visible native modal independently of its presenter.
        // A cancelled root gesture never normalizes the origin's editing.
        if old != section { hosts[old]?.view.endEditing(true) }
        if parentVisible { finishAppearance(on: section) }
        updateInteraction()
        releaseAmbient()
        if old != section, UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .pageScrolled, argument: section.title)
        }
        trace("settled")
    }

    private func stopMechanicalMotion() {
        motion = .idle
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        if scrollView.isTracking || scrollView.isDragging {
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.panGestureRecognizer.isEnabled = true
        }
    }

    private func cancelInteraction() {
        // Repeated real-scene environment deliveries are not new transitions.
        // Once settled, there is no mechanical request left to cancel.
        if case .idle = motion, pendingSelection == nil { return }
        generation &+= 1
        pendingSelection = nil
        // requestedSelection is the latest delivered value, including willSet.
        stopMechanicalMotion()
        settle(on: requestedSelection, publish: false)
    }

    private func index(_ section: AppSection) -> Int {
        let logical = AppSection.allCases.firstIndex(of: section)!
        return rightToLeft ? 4 - logical : logical
    }

    private func section(at offset: CGFloat) -> AppSection {
        guard viewport.width > 0 else { return requestedSelection }
        let physical = min(4, max(0, Int((offset / viewport.width).rounded())))
        return AppSection.allCases[rightToLeft ? 4 - physical : physical]
    }

    private func pageFrame(_ section: AppSection, size: CGSize) -> CGRect {
        CGRect(x: CGFloat(index(section)) * size.width, y: 0, width: size.width, height: size.height)
    }

    private func beginIncoming(_ section: AppSection, animated: Bool) {
        if parentDisappearing.remove(section) != nil {
            hosts[section]?.beginAppearanceTransition(true, animated: animated)
            appeared.remove(section)
            appearing.insert(section)
        } else if !appeared.contains(section), appearing.insert(section).inserted {
            hosts[section]?.beginAppearanceTransition(true, animated: animated)
        }
    }

    private func cancelIncoming(_ section: AppSection) {
        guard appearing.remove(section) != nil else { return }
        // UIKit reverses the pending appearance before its final end callback.
        hosts[section]?.beginAppearanceTransition(false, animated: true)
        hosts[section]?.endAppearanceTransition()
    }

    private func stageVisiblePages() {
        guard parentVisible, viewport.width > 0 else { return }
        let visible = CGRect(origin: scrollView.contentOffset, size: viewport)
        let incoming = Set(AppSection.allCases.filter {
            pageFrame($0, size: viewport).intersection(visible).width > 0.5
        })
        for section in incoming { beginIncoming(section, animated: true) }
        for section in appearing.subtracting(incoming) { cancelIncoming(section) }
        // Keep the origin appeared/focused until a committed departure.
    }

    private func finishAppearance(on section: AppSection) {
        beginIncoming(section, animated: false)
        for root in appearing where root != section { cancelIncoming(root) }
        for root in appeared where root != section {
            hosts[root]?.beginAppearanceTransition(false, animated: false)
            hosts[root]?.endAppearanceTransition()
        }
        if appearing.remove(section) != nil { hosts[section]?.endAppearanceTransition() }
        appeared = [section]
    }

    private func publishVisibility(committedFrom: AppSection? = nil) {
        let state: LifeRouteRootMotion
        switch motion {
        case .idle: state = pendingSelection == nil ? .idle : .requested
        case .dragging: state = .dragging
        case .decelerating: state = .decelerating
        }
        let visible = CGRect(origin: scrollView.contentOffset, size: viewport)
        let fractions = Dictionary(uniqueKeysWithValues: AppSection.allCases.map { section in
            (section, viewport.width > 0 && view.bounds.width > 0 && view.bounds.height > 0 ? Double(max(0, pageFrame(section, size: viewport).intersection(visible).width) / viewport.width) : 0)
        })
        visibility.mechanics(requested: requestedSelection, settled: settledSelection, origin: transitionOrigin,
            target: state == .idle ? nil : (pendingSelection?.section ?? fractions.filter { $0.key != settledSelection && $0.value > 0 }.max { $0.value < $1.value }?.key), motion: state,
            generation: generation, layout: layoutRevision, fractions: fractions,
            parent: actuallyExposed, window: viewIfLoaded?.window != nil, committedFrom: committedFrom)
    }

    private func updateInteraction(timerHeroBlocked: Bool? = nil) {
        let heroBlocked = timerHeroBlocked ?? router.timerHeroNavigationBlocked
        scrollView.isScrollEnabled = !heroBlocked
        // Mechanical ingress is synchronous; the installed visibility snapshot
        // can still describe idle until its deferred publication is drained.
        let settledInput: Bool
        if case .idle = motion {
            settledInput = !heroBlocked && !tornDown && pendingSelection == nil && requestedSelection == settledSelection
        } else {
            settledInput = false
        }
        scrollView.admittedRootView = nil
        for (section, host) in hosts {
            let current = visibility.snapshot.root(section)
            if settledInput && current.interaction { scrollView.admittedRootView = host.view }
            host.view.accessibilityElementsHidden = !(settledInput && current.accessibility)
        }
        // Do not toggle host interaction: UIKit would resign, remember and then
        // promote its retained editor. Only committed settlement ends editing.
    }

    private func accessibilityPage(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard !router.timerHeroNavigationBlocked else { return false }
        let delta: Int
        switch direction {
        case .left: delta = 1
        case .right: delta = -1
        case .next: delta = rightToLeft ? -1 : 1
        case .previous: delta = rightToLeft ? 1 : -1
        default: return false
        }
        let destination = index(requestedSelection) + delta
        guard (0..<5).contains(destination) else { return false }
        router.select(AppSection.allCases[rightToLeft ? 4 - destination : destination])
        return true
    }

    private func releaseAmbient() {
        guard let request = ambientRequest else { return }
        ambientRequest = nil
        visualActivity.releaseAmbientSuspension(request)
    }

    func tearDown() {
        guard !tornDown else { return }
        tornDown = true
        visibility.teardown()
        releaseAmbient()
        visibilitySubscription = nil
        for section in appearing { cancelIncoming(section) }
        for section in appeared {
            if !parentDisappearing.contains(section) { hosts[section]?.beginAppearanceTransition(false, animated: false) }
            hosts[section]?.endAppearanceTransition()
        }
        appeared.removeAll()
        parentDisappearing.removeAll()
        selectionSubscription = nil
        scrollView.delegate = nil
        scrollView.moveAccessibilityPage = nil
        for section in AppSection.allCases {
            guard let host = hosts[section] else { continue }
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            teardownCount += 1
        }
        hosts.removeAll()
        trace("teardown")
    }

    private func trace(_ event: String) {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteRootOwnershipTrace") else { return }
        func identity(_ object: AnyObject?) -> String {
            object.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
        }
        var bars: [[String: Any]] = []
        var itemOwners: [String: Set<String>] = [:]
        var rootRows: [[String: Any]] = []
        var retiredCells = 0
        func inspect(_ view: UIView, root: String) -> Bool {
            var responder = view.isFirstResponder
            if String(describing: type(of: view)).contains("UIKitPagingCell") { retiredCells += 1 }
            if let bar = view as? UINavigationBar, bar.window != nil {
                let items = (bar.items ?? []).map { identity($0) }
                let barID = identity(bar)
                for item in items { itemOwners[item, default: []].insert(barID) }
                bars.append(["root": root, "bar": barID, "delegate": identity(bar.delegate), "items": items])
            }
            for child in view.subviews { responder = inspect(child, root: root) || responder }
            return responder
        }
        for section in AppSection.allCases {
            guard let host = hosts[section] else { continue }
            let responder = inspect(host.view, root: section.rawValue)
            var ancestry: [String] = []
            var ancestor: UIView? = host.view
            while let current = ancestor { ancestry.append(identity(current)); ancestor = current.superview }
            rootRows.append(["root": section.rawValue, "host": identity(host), "parent": identity(host.parent),
                             "view": identity(host.view), "ancestry": ancestry,
                             "children": host.children.map { ["id": identity($0), "type": String(describing: type(of: $0))] },
                             "interactive": scrollView.admittedRootView === host.view,
                             "nativeInteractionEnabled": host.view.isUserInteractionEnabled,
                             "accessibilityHidden": host.view.accessibilityElementsHidden, "firstResponder": responder])
        }
        let duplicates = itemOwners.filter { $0.value.count > 1 }.mapValues { Array($0).sorted() }
        let valid = tornDown || (hosts.count == 5 && allocationCount == 5 && teardownCount == 0 && hosts.values.allSatisfy { $0.parent === self && $0.view.superview === scrollView } && duplicates.isEmpty && retiredCells == 0)
        let row: [String: Any] = ["event": event, "pid": ProcessInfo.processInfo.processIdentifier,
            "uptime": ProcessInfo.processInfo.systemUptime, "pager": identity(self), "scroll": identity(scrollView),
            "selected": router.selectedSection.rawValue, "requested": requestedSelection.rawValue,
            "generation": generation, "motion": String(describing: motion), "offset": Double(scrollView.contentOffset.x),
            "viewport": [Double(viewport.width), Double(viewport.height)], "roots": rootRows, "bars": bars,
            "duplicates": duplicates, "retiredPagingCells": retiredCells, "allocations": allocationCount,
            "teardowns": teardownCount, "ambientSuspensions": visualActivity.ambientSuspensionCount,
            "scenePhase": String(describing: relay.values.scenePhase), "invariant": valid]
        if let bytes = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
           let line = String(data: bytes, encoding: .utf8) {
            print("LIFEROUTE_ROOT_OWNERSHIP " + line)
            fflush(stdout)
        }
        assert(valid, "Permanent root ownership invariant failed")
#endif
    }
}
// END PERMANENT ROOT PAGER

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
