import Foundation

/// Presentation only. Neither timer time, completion nor Orb phase enters this driver.
struct VisualTimerHeroTransition {
    private(set) var progress = 0.0
    private(set) var velocity = 0.0
    private(set) var target = 0.0
    private(set) var anchor: CGRect?
    private(set) var expanded = CGRect.zero
    private(set) var fadingFrame: CGRect?
    private(set) var fadeRemaining = 0.0
    var reduceMotion = false
    private(set) var navigationPending = false

    var isFading: Bool { fadingFrame != nil }
    var blocksNavigation: Bool { progress > 0 || target > 0 || isFading }
    var needsFrames: Bool { isFading || progress != target || velocity != 0 }
    var fallbackOpacity: Double { isFading ? max(0, fadeRemaining / 0.18) : 1 }
    var orbOpacity: Double { fallbackOpacity * (reduceMotion && !isFading ? abs(2 * progress - 1) : 1) }
    var backdropOpacity: Double { progress * fallbackOpacity }
    var frame: CGRect? {
        if let fadingFrame { return fadingFrame }
        guard let anchor else { return nil }
        if reduceMotion { return progress < 0.5 ? anchor : expanded }
        let p = CGFloat(progress)
        return CGRect(x: anchor.minX + (expanded.minX - anchor.minX) * p,
                      y: anchor.minY + (expanded.minY - anchor.minY) * p,
                      width: anchor.width + (expanded.width - anchor.width) * p,
                      height: anchor.height + (expanded.height - anchor.height) * p)
    }

    mutating func updateGeometry(anchor newAnchor: CGRect?, expanded: CGRect,
                                 lastPresentedFrame: CGRect? = nil) {
        let fallbackFrame = lastPresentedFrame ?? frame
        self.expanded = expanded
        guard let newAnchor, Self.valid(newAnchor) else {
            // Freeze the last actually presented rectangle, never guess a return slot.
            if blocksNavigation && !isFading {
                fadingFrame = fallbackFrame
                fadeRemaining = 0.18
                velocity = 0
                target = 0
            }
            anchor = nil
            return
        }
        anchor = newAnchor
        // Endpoint changes deliberately do not project/restart progress or velocity.
    }

    mutating func request(expanded: Bool) {
        guard !isFading, anchor != nil else { return }
        target = expanded ? 1 : 0
        // Retarget changes ONLY the destination. Momentum survives both reversals.
    }

    mutating func requestNavigation() { navigationPending = true; request(expanded: false) }
    mutating func takeSettledNavigation() -> Bool {
        guard navigationPending, !blocksNavigation else { return false }
        navigationPending = false
        return true
    }

    mutating func advance(by dt: TimeInterval) {
        guard dt.isFinite, dt > 0 else { return }
        if isFading {
            fadeRemaining = max(0, fadeRemaining - dt)
            if fadeRemaining == 0 {
                fadingFrame = nil
                anchor = nil
                progress = 0
                velocity = 0
                target = 0
            }
            return
        }
        guard needsFrames else { return }
        // Closed-form critically damped spring: no Euler steps or dt-clamped time debt.
        let omega = reduceMotion ? 38.0 : 12.0
        let displacement = progress - target
        let term = velocity + omega * displacement
        let decay = exp(-omega * dt)
        progress = target + (displacement + term * dt) * decay
        velocity = (velocity - omega * term * dt) * decay
        if progress < 0 { progress = 0; velocity = max(0, velocity) }
        if progress > 1 { progress = 1; velocity = min(0, velocity) }
        if abs(progress - target) < 0.0001 && abs(velocity) < 0.002 {
            progress = target
            velocity = 0
        }
    }

    private static func valid(_ rect: CGRect) -> Bool {
        [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite)
            && rect.width > 0 && rect.height > 0
    }
}

struct VisualTimerHeroLayout {
    let header: CGRect
    let orb: CGRect
    let controls: CGRect

    init(safeArea: CGRect, controlsHeight: CGFloat, accessibilitySize: Bool) {
        let area = safeArea.insetBy(dx: 20, dy: 8)
        header = CGRect(x: area.minX, y: area.minY, width: area.width, height: 56)
        let body = CGRect(x: area.minX, y: header.maxY + 12,
                          width: area.width, height: max(1, area.maxY - header.maxY - 12))
        if body.width > safeArea.height && !accessibilitySize {
            let orbWidth = body.width * 0.55 - 12
            let side = min(480, orbWidth, body.height)
            orb = CGRect(x: body.minX + (orbWidth - side) / 2,
                         y: body.midY - side / 2, width: side, height: side)
            controls = CGRect(x: body.minX + orbWidth + 24, y: body.minY,
                              width: max(1, body.width - orbWidth - 24), height: body.height)
        } else {
            let controlsSpace = min(controlsHeight, body.height * 0.49)
            let orbSpace = max(1, body.height - controlsSpace - 16)
            let side = min(480, body.width, orbSpace)
            orb = CGRect(x: body.midX - side / 2, y: body.minY + (orbSpace - side) / 2,
                         width: side, height: side)
            controls = CGRect(x: body.minX, y: body.maxY - controlsSpace,
                              width: body.width, height: controlsSpace)
        }
    }
}

#if canImport(UIKit)
import SwiftUI
import UIKit
import Combine

/// Root-owned bridge. The destination supplies its EXISTING presentation object.
@MainActor
final class VisualTimerHeroCoordinator: ObservableObject {
    @Published private(set) var blocksNavigation = false
    @Published private(set) var orbActive = false
    private(set) var presentation: VisualTimerPresentationState?
    private(set) var minutes = 5
    var start: (() -> Void)?
    var back: (() -> Void)?
    weak var controller: VisualTimerHeroController?
    weak var anchorView: UIView?
    weak var router: AppRouter?
    private var presentationSubscription: AnyCancellable?

    func bind(_ presentation: VisualTimerPresentationState, minutes: Int,
              start: @escaping () -> Void, back: @escaping () -> Void) {
        self.minutes = minutes
        self.start = start
        self.back = back
        guard self.presentation !== presentation else { controller?.refreshControls(); return }
        self.presentation = presentation
        controller?.installOrb(presentation)
        presentationSubscription = presentation.$isFullScreen.removeDuplicates().sink { [weak self] expanded in
            // Published values precede storage; controller uses the delivered intent.
            self?.controller?.request(expanded: expanded)
        }
    }

    func setActive(_ active: Bool) {
        if orbActive != active { orbActive = active }
        controller?.refreshGeometry()
    }

    func setBlocked(_ blocked: Bool) {
        guard blocksNavigation != blocked else { return }
        blocksNavigation = blocked
        router?.setTimerHeroNavigationBlocked(blocked)
    }

    func navigate(_ action: @escaping () -> Void) {
        controller?.navigate(action)
    }

    func unmount(_ view: UIView) {
        guard anchorView === view else { return }
        anchorView = nil
        controller?.refreshGeometry()
    }
}

struct VisualTimerHeroAnchor: UIViewRepresentable {
    let hero: VisualTimerHeroCoordinator
    func makeUIView(context: Context) -> VisualTimerHeroAnchorView {
        let view = VisualTimerHeroAnchorView()
        view.hero = hero
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: VisualTimerHeroAnchorView, context: Context) { view.publish() }
    static func dismantleUIView(_ view: VisualTimerHeroAnchorView, coordinator: ()) {
        view.hero?.unmount(view)
    }
}

final class VisualTimerHeroAnchorView: UIView {
    weak var hero: VisualTimerHeroCoordinator?
    private var observations: [NSKeyValueObservation] = []
    private var publicationPending = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        observations.removeAll()
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                observations.append(scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.publish() }
                })
            }
            ancestor = view.superview
        }
        publish()
    }
    override func layoutSubviews() { super.layoutSubviews(); publish() }
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); publish() }
    func publish() {
        guard !publicationPending else { return }
        publicationPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publicationPending = false
            if self.window != nil { self.hero?.anchorView = self }
            else { self.hero?.unmount(self) }
            self.hero?.controller?.refreshGeometry()
        }
    }
}

struct VisualTimerHeroLayer: UIViewControllerRepresentable {
    @Environment(\.self) private var environment
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
    let hero: VisualTimerHeroCoordinator
    let router: AppRouter
    func makeUIViewController(context: Context) -> VisualTimerHeroController {
        let controller = VisualTimerHeroController(hero: hero, themeStore: themeStore, environment: environment)
        hero.router = router
        router.collapseTimerHeroBeforeNavigation = { [weak hero] action in hero?.navigate(action) }
        controller.loadViewIfNeeded()
        if let presentation = hero.presentation { controller.installOrb(presentation) }
        return controller
    }
    func updateUIViewController(_ controller: VisualTimerHeroController, context: Context) {
        controller.updateEnvironment(environment)
    }
    static func dismantleUIViewController(_ controller: VisualTimerHeroController, coordinator: ()) {
        controller.tearDown()
    }
}

private final class VisualTimerHeroSurface: UIView {
    var capturesInput = false
    var geometryChanged: (() -> Void)?
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard capturesInput else { return nil }
        return super.hitTest(point, with: event)
    }
    override func layoutSubviews() { super.layoutSubviews(); geometryChanged?() }
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); geometryChanged?() }
    override func didMoveToWindow() { super.didMoveToWindow(); geometryChanged?() }
}

@MainActor
final class VisualTimerHeroController: UIViewController {
    private let hero: VisualTimerHeroCoordinator
    private let themeStore: LifeRouteThemeStore
    private var environment: EnvironmentValues
    private var transition = VisualTimerHeroTransition()
    private let surface = VisualTimerHeroSurface()
    private let backdrop = UIView()
    private let orbClip = UIView()
    private var orbHost: UIHostingController<AnyView>?
    private var controlsHost: UIHostingController<AnyView>?
    private var headerHost: UIHostingController<AnyView>?
    private var displayLink: CADisplayLink?
    private var previousUptime: TimeInterval?
    private var pendingNavigation: (() -> Void)?
    private var geometryPending = false
    private var clipFrame = CGRect.zero
    private var navigationTransition: UIViewControllerTransitionCoordinator?
    private weak var completedNavigationTransition: AnyObject?
    private weak var navigationAnchor: UIView?
    private weak var anchorNavigationController: UINavigationController?
#if DEBUG
    private var tracedVisibleOrb = false
#endif

    init(hero: VisualTimerHeroCoordinator, themeStore: LifeRouteThemeStore, environment: EnvironmentValues) {
        self.hero = hero
        self.themeStore = themeStore
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
        hero.controller = self
    }
    required init?(coder: NSCoder) { fatalError("Use the root Timer D layer") }
    override func loadView() {
        view = surface
        view.backgroundColor = .clear
        backdrop.backgroundColor = UIColor(themeStore.selectedTheme.scenicRoyalStyle.readabilityBase)
        backdrop.alpha = 0
        view.addSubview(backdrop)
        orbClip.isUserInteractionEnabled = false
        view.addSubview(orbClip)
        surface.geometryChanged = { [weak self] in self?.scheduleGeometry() }
    }

    private func host<V: View>(_ content: V) -> UIHostingController<AnyView> {
        let host = UIHostingController(rootView: styled(content))
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        addChild(host)
        host.view.backgroundColor = .clear
        return host
    }
    private func styled<V: View>(_ content: V) -> AnyView {
        AnyView(content
            .environment(\.scenicRoyalThemeStyle, themeStore.selectedTheme.scenicRoyalStyle)
            .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
            .environment(\.colorScheme, environment.colorScheme)
            .environment(\.scenePhase, environment.scenePhase)
            .tint(themeStore.selectedTheme.scenicRoyalStyle.selectedControlFill))
    }

    func installOrb(_ presentation: VisualTimerPresentationState) {
        loadViewIfNeeded()
#if DEBUG
        tracedVisibleOrb = false
#endif
        trace("orb.install.begin")
        // A new destination may bind later, but expansion/collapse NEVER enters this branch.
        for old in [orbHost, controlsHost, headerHost].compactMap({ $0 }) {
            old.willMove(toParent: nil); old.view.removeFromSuperview(); old.removeFromParent()
        }
        orbHost = host(ScenicRoyalHeroOrbReadout(hero: hero, presentation: presentation))
        trace("orb.host.created")
        orbHost!.view.bounds = CGRect(x: 0, y: 0, width: 340, height: 340)
        orbClip.addSubview(orbHost!.view)
        orbHost!.didMove(toParent: self)
        trace("orb.host.attached")
        controlsHost = host(controls(presentation))
        headerHost = host(ScenicRoyalFullScreenTimerView(hero: hero))
        view.addSubview(controlsHost!.view)
        view.addSubview(headerHost!.view)
        controlsHost!.didMove(toParent: self)
        headerHost!.didMove(toParent: self)
        trace("chrome.hosts.attached")
        refreshGeometry()
        trace("orb.installed")
    }

    private func controls(_ presentation: VisualTimerPresentationState) -> some View {
        ScrollView {
            ScenicRoyalTimerControls(timer: presentation.timer, reset: presentation.reset,
                start: { [weak hero] in hero?.start?() }, startTitle: "Start \(hero.minutes)-minute timer")
        }
    }

    func refreshControls() {
        guard let presentation = hero.presentation else { return }
        controlsHost?.rootView = styled(controls(presentation))
        scheduleGeometry()
    }
    func updateEnvironment(_ values: EnvironmentValues) {
        environment = values
        backdrop.backgroundColor = UIColor(themeStore.selectedTheme.scenicRoyalStyle.readabilityBase)
        guard let presentation = hero.presentation else { return }
        // Environment changes update the same hosting root type and identity, never per frame.
        orbHost?.rootView = styled(ScenicRoyalHeroOrbReadout(hero: hero, presentation: presentation))
        refreshControls()
        headerHost?.rootView = styled(ScenicRoyalFullScreenTimerView(hero: hero))
        scheduleGeometry()
    }

    private func scheduleGeometry() {
        guard !geometryPending else { return }
        geometryPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.geometryPending = false
            self.refreshGeometry()
        }
    }

    func refreshGeometry() {
        guard isViewLoaded, let window = view.window else { return }
        let safe = view.convert(window.safeAreaLayoutGuide.layoutFrame, from: window).intersection(view.bounds)
        let layout = VisualTimerHeroLayout(safeArea: safe, controlsHeight: 285,
                                          accessibilitySize: environment.dynamicTypeSize.isAccessibilitySize)
        // The presentation layer is the last frame actually committed to screen. Sample it
        // before changing either endpoint so adjacent geometry/anchor callbacks cannot replace
        // the fallback position with a model-layer frame that was never displayed.
        let lastPresentedFrame = presentedOrbFrame() ?? transition.frame
        backdrop.frame = view.bounds
        headerHost?.view.frame = layout.header
        controlsHost?.view.frame = layout.controls
        var anchor: CGRect?
        clipFrame = view.bounds
        if let slot = hero.anchorView, slot.window === window {
            observeNavigationTransition(containing: slot)
            anchor = presentedBounds(slot.bounds, of: slot)
            // Respect every clipping scroll/host ancestor while collapsed.
            var ancestor = slot.superview
            while let current = ancestor, current !== window {
                if current.clipsToBounds {
                    let bounds = (current as? UIScrollView).map { $0.bounds.inset(by: $0.adjustedContentInset) } ?? current.bounds
                    clipFrame = clipFrame.intersection(presentedBounds(bounds, of: current))
                }
                ancestor = current.superview
            }
            clipFrame = clipFrame.intersection(safe)
        }
        transition.updateGeometry(anchor: anchor, expanded: layout.orb,
                                  lastPresentedFrame: lastPresentedFrame)
        if let presentation = hero.presentation, presentation.isFullScreen,
           !transition.blocksNavigation, anchor != nil { request(expanded: true) }
        render()
        startFramesIfNeeded()
        trace("geometry")
    }

    /// Incoming destinations acquire semantic activity after UIKit's push finishes.
    /// During that push, draw the existing Orb at its actual animated anchor without
    /// activating its motion, timer feedback, or another navigation owner.
    private func observeNavigationTransition(containing slot: UIView) {
        guard navigationTransition == nil, slot.window?.windowScene?.activationState == .foregroundActive else { return }
        if navigationAnchor !== slot {
            navigationAnchor = slot
            anchorNavigationController = nil
        }
        var responder: UIResponder? = slot
        while let current = responder {
            if let owner = current as? UIViewController,
               let navigation = owner.navigationController ?? anchorNavigationController,
               let coordinator = navigation.transitionCoordinator,
               navigation.viewIfLoaded?.window === slot.window,
               coordinator.containerView.isDescendant(of: navigation.view),
               coordinator.isAnimated,
               [UITransitionContextViewControllerKey.from, .to].contains(where: { key in
                   guard let endpoint = coordinator.viewController(forKey: key), endpoint.isViewLoaded else { return false }
                   return slot.isDescendant(of: endpoint.view)
               }) {
                anchorNavigationController = navigation
                let identity = ObjectIdentifier(coordinator as AnyObject)
                guard completedNavigationTransition !== coordinator as AnyObject else { return }
                navigationTransition = coordinator
                let registered = coordinator.animate(alongsideTransition: nil) { [weak self, weak coordinator] _ in
                    guard let self, self.navigationTransition.map({ ObjectIdentifier($0 as AnyObject) }) == identity else { return }
                    self.completedNavigationTransition = coordinator as AnyObject?
                    self.navigationTransition = nil
                    self.scheduleGeometry()
                }
                if !registered { navigationTransition = nil }
                if registered { trace("navigation.tracking") }
                return
            }
            responder = current.next
        }
    }

    private func presentedBounds(_ bounds: CGRect, of source: UIView) -> CGRect {
        if navigationTransition != nil,
           let sourceLayer = source.layer.presentation(), let destinationLayer = view.layer.presentation() {
            let insets = UIEdgeInsets(top: bounds.minY - source.bounds.minY,
                                      left: bounds.minX - source.bounds.minX,
                                      bottom: source.bounds.maxY - bounds.maxY,
                                      right: source.bounds.maxX - bounds.maxX)
            return sourceLayer.convert(sourceLayer.bounds.inset(by: insets), to: destinationLayer)
        }
        return source.convert(bounds, to: view)
    }

    private var nativeTransitionOpacity: CGFloat {
        guard navigationTransition != nil, let slot = hero.anchorView else { return 1 }
        var opacity: CGFloat = 1
        var current: UIView? = slot
        while let ancestor = current, ancestor !== view.window {
            if ancestor.isHidden { return 0 }
            opacity *= CGFloat(ancestor.layer.presentation()?.opacity ?? ancestor.layer.opacity)
            current = ancestor.superview
        }
        return opacity
    }

    private func presentedOrbFrame() -> CGRect? {
        guard let layer = orbHost?.view.layer.presentation() else { return nil }
        let frame = layer.frame.offsetBy(dx: orbClip.frame.minX, dy: orbClip.frame.minY)
        guard [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
              frame.width > 0, frame.height > 0 else { return nil }
        return frame
    }

    func request(expanded: Bool) {
        guard isViewLoaded else { return }
        transition.reduceMotion = environment.accessibilityReduceMotion
        transition.request(expanded: expanded)
        render()
        startFramesIfNeeded()
        trace(expanded ? "expand" : "close")
    }
    func navigate(_ action: @escaping () -> Void) {
        pendingNavigation = action
        transition.requestNavigation()
        hero.presentation?.close()
        render()
        startFramesIfNeeded()
        finishNavigationIfReady()
    }

    func tearDown() {
        displayLink?.invalidate()
        displayLink = nil
        pendingNavigation = nil
        navigationTransition = nil
        transition = VisualTimerHeroTransition()
        hero.setBlocked(false)
        hero.router?.collapseTimerHeroBeforeNavigation = nil
        hero.controller = nil
    }

    private func startFramesIfNeeded() {
        guard transition.needsFrames || navigationTransition != nil, displayLink == nil else { return }
        previousUptime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        transition.advance(by: now - (previousUptime ?? now))
        previousUptime = now
        if navigationTransition != nil { refreshGeometry() }
        else { render() }
        if !transition.needsFrames && navigationTransition == nil {
            link.invalidate(); displayLink = nil; previousUptime = nil
            if !transition.blocksNavigation { hero.presentation?.close() }
            trace("settled")
            finishNavigationIfReady()
        }
    }
    private func finishNavigationIfReady() {
        guard transition.takeSettledNavigation() else { return }
        let action = pendingNavigation
        pendingNavigation = nil
        action?()
    }

    private func render() {
        let blocked = transition.blocksNavigation
        surface.capturesInput = blocked
        surface.accessibilityViewIsModal = blocked
        hero.setBlocked(blocked)
        backdrop.alpha = transition.backdropOpacity * 0.94
        controlsHost?.view.alpha = transition.backdropOpacity
        headerHost?.view.alpha = blocked ? 1 : 0
        controlsHost?.view.accessibilityElementsHidden = !blocked
        headerHost?.view.accessibilityElementsHidden = !blocked
        orbClip.clipsToBounds = !blocked
        let clipping = blocked ? view.bounds : clipFrame
        orbClip.frame = clipping.isNull ? .zero : clipping
        guard let frame = transition.frame, let orb = orbHost?.view else { orbClip.alpha = 0; return }
        let nativeTransitionVisible = navigationTransition != nil && view.window?.windowScene?.activationState == .foregroundActive
        orbClip.alpha = (hero.orbActive || blocked || nativeTransitionVisible) ? transition.orbOpacity : 0
        if !blocked { orbClip.alpha *= nativeTransitionOpacity }
        // The expensive accepted hierarchy remains a fixed 340-point canvas.
        // Only its enclosing transform/position and simple alpha change each frame.
        orb.transform = CGAffineTransform(scaleX: frame.width / 340, y: frame.height / 340)
        orb.center = CGPoint(x: frame.midX - orbClip.frame.minX, y: frame.midY - orbClip.frame.minY)
#if DEBUG
        if !tracedVisibleOrb, orbClip.alpha > 0, !orbClip.frame.isEmpty {
            tracedVisibleOrb = true
            trace("orb.visible.requested")
        }
#endif
    }
    private func trace(_ event: String) {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerDiagnostics") else { return }
        FileHandle.standardError.write(Data("TIMER_D event=\(event) uptime=\(ProcessInfo.processInfo.systemUptime) active=\(hero.orbActive) progress=\(transition.progress) velocity=\(transition.velocity) target=\(transition.target) blocked=\(transition.blocksNavigation) fallback=\(transition.isFading) frame=\(String(describing: transition.frame)) anchor=\(String(describing: transition.anchor)) orb=\(String(describing: orbHost.map(ObjectIdentifier.init))) timer=\(String(describing: hero.presentation.map { ObjectIdentifier($0.timer) }))\n".utf8))
#endif
    }
}
#endif
