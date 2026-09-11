// App-hosted UIKit tests appended to exact production source extractions.
// Theme values below are fixtures for otherwise unrelated domain dependencies.
// The pager, relay, owning-root/token modifier, AppRouter, NavigationStack wrapper,
// and ambient coordinator under test are production declarations, not replicas.
import SwiftUI
import UIKit
import Combine

private struct PagerFixtureThemeStyle {
    let selectedControlFill = Color.blue
    let nativeColorScheme = ColorScheme.dark
}
private enum PagerFixtureTheme { case royal }
private struct PagerFixturePalette {}
private struct PagerFixtureStyleKey: EnvironmentKey { static let defaultValue = PagerFixtureThemeStyle() }
private struct PagerFixtureThemeKey: EnvironmentKey { static let defaultValue = PagerFixtureTheme.royal }
private struct PagerFixturePaletteKey: EnvironmentKey { static let defaultValue = PagerFixturePalette() }
private extension EnvironmentValues {
    var scenicRoyalThemeStyle: PagerFixtureThemeStyle {
        get { self[PagerFixtureStyleKey.self] }
        set { self[PagerFixtureStyleKey.self] = newValue }
    }
    var lifeRouteTheme: PagerFixtureTheme {
        get { self[PagerFixtureThemeKey.self] }
        set { self[PagerFixtureThemeKey.self] = newValue }
    }
    var lifeRoutePalette: PagerFixturePalette {
        get { self[PagerFixturePaletteKey.self] }
        set { self[PagerFixturePaletteKey.self] = newValue }
    }
}
@MainActor private final class LifeRouteThemeStore: ObservableObject {}

@MainActor private final class PagerFixtureState: ObservableObject {
    @Published var pushed = false
    @Published var draft = "synthetic draft"
    var identities = Set<UUID>()
    var appearances = 0
    var disappearances = 0
    var detailAppearances = 0
    var detailDisappearances = 0
    var detailEffectActive = false
    var detailEffectEdges = 0
    var phases: [ScenePhase] = []
}

private struct PagerFixtureRoot: View {
    @ObservedObject var state: PagerFixtureState
    @State private var identity = UUID()
    @Environment(\.scenePhase) private var scenePhase
    let title: String

    var body: some View {
        VStack {
            TextField("Synthetic draft", text: $state.draft)
            NavigationLink(isActive: $state.pushed) {
                Text("Synthetic destination")
                    .navigationTitle("Detail")
                    .onAppear { state.detailAppearances += 1 }
                    .onDisappear { state.detailDisappearances += 1 }
                    .lifeRouteReconcile { context in
                        if state.detailEffectActive != context.active {
                            state.detailEffectActive = context.active; state.detailEffectEdges += 1
                        }
                    }
                    .lifeRouteDeepDestination()
            } label: { Text("Open synthetic destination") }
        }
        .navigationTitle(title)
        .onAppear { state.identities.insert(identity); state.appearances += 1 }
        .onDisappear { state.disappearances += 1 }
        .onChange(of: scenePhase) { state.phases.append($0) }
    }
}

extension LifeRouteVisibilityOwner {
    fileprivate func fixtureNativeObservations() -> [[String: String]] {
        nativeProbes.values.map { $0.fixtureObservation() }
    }
}
extension LifeRouteNativeScopeController {
    fileprivate func fixtureObservation() -> [String: String] {
        var chain: [String] = []; var cursor: UIViewController? = self
        while let current = cursor {
            chain.append("\(type(of: current)):\(ObjectIdentifier(current))")
            cursor = current.parent
        }
        return ["scope": scope.id.uuidString, "kind": scope.kind.rawValue,
                "chain": chain.joined(separator: " -> "), "transitioning": String(transitioning),
                "top": navigation?.topViewController.map { String(describing: ObjectIdentifier($0)) } ?? "nil",
                "member": navigationOwner.map { String(describing: ObjectIdentifier($0)) } ?? "nil",
                "windowed": String(viewIfLoaded?.window != nil)]
    }
}

// Native responder sensor, not an implementation of product focus behavior.
// The real Session Note FocusState bridge remains an independent app/HID gate.
private final class PagerResponderSensor: UITextView {
    var acquisitions = 0
    var resignations = 0
    override func becomeFirstResponder() -> Bool {
        let was = isFirstResponder
        let result = super.becomeFirstResponder()
        if result && !was { acquisitions += 1 }
        return result
    }
    override func resignFirstResponder() -> Bool {
        let was = isFirstResponder
        let result = super.resignFirstResponder()
        if result && was { resignations += 1 }
        return result
    }
}

@MainActor private final class PagerOwnershipTests {
    private var assertions = 0
    private let router = AppRouter()
    private let activity = LifeRouteVisualActivityCoordinator()
    private let visibility = LifeRouteVisibilityOwner()
    private var originalVisibility: [AppSection: ObjectIdentifier] = [:]
    private let theme = LifeRouteThemeStore()
    private let states = Dictionary(uniqueKeysWithValues: AppSection.allCases.map { ($0, PagerFixtureState()) })
    private var window: UIWindow!
    private var pager: LifeRouteRootPagerController!
    private var originalHosts: [AppSection: ObjectIdentifier] = [:]

    private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard condition() else {
            print("ROOT_OWNERSHIP_TEST_FAIL \(assertions): \(message)")
            fflush(stdout)
            exit(1)
        }
    }

    private func turn() async {
        // Allow actual UIKit/SwiftUI appearance and rendering transactions.
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func invariant(_ label: String) {
        check(pager.hosts.count == 5, label + " fixed host count")
        check(pager.allocationCount == 5 && pager.teardownCount == 0, label + " allocation lifetime")
        for root in AppSection.allCases {
            let host = pager.hosts[root]!
            check(ObjectIdentifier(host) == originalHosts[root], label + " stable host")
            check(host.parent === pager && host.view.superview === pager.scrollView, label + " permanent parent/view owner")
            check(host.rootView.owner.section == root, label + " immutable root")
            check(host.rootView.router === router, label + " same router")
            check(ObjectIdentifier(visibility.roots[root]!) == originalVisibility[root], label + " stable visibility reference")
        }
        var ownership: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
        func walk(_ view: UIView) {
            if let bar = view as? UINavigationBar, bar.window != nil {
                for item in bar.items ?? [] { ownership[ObjectIdentifier(item), default: []].insert(ObjectIdentifier(bar)) }
            }
            view.subviews.forEach(walk)
        }
        walk(window)
        check(ownership.values.allSatisfy { $0.count == 1 }, label + " unique attached navigation items")
    }

    private func drag(to fraction: CGFloat, decelerates: Bool = false) async {
        pager.scrollViewWillBeginDragging(pager.scrollView)
        pager.scrollView.contentOffset.x = fraction * pager.scrollView.bounds.width
        pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: decelerates)
        if decelerates { pager.scrollViewDidEndDecelerating(pager.scrollView) }
        await turn()
    }

    private func rootInputOracle() async {
        let host = pager.hosts[.today]!
        let editor = PagerResponderSensor(frame: CGRect(x: 36, y: 100, width: 240, height: 120))
        editor.text = "Retained native editing episode"
        host.view.addSubview(editor)
        check(editor.becomeFirstResponder(), "native fixture editor can acquire focus")
        editor.selectedRange = NSRange(location: 9, length: 6)
        await turn()
        let acquisitions = editor.acquisitions
        let resignations = editor.resignations
        let departure = visibility.snapshot.root(.today).departure
        let revision = visibility.snapshot.snapshotRevision
        pager.scrollViewWillBeginDragging(pager.scrollView)
        // No flush, await or run-loop turn before inspecting the production adapter.
        check(visibility.snapshot.snapshotRevision == revision, "oracle observes before deferred mechanics drain")
        let point = editor.convert(CGPoint(x: 20, y: 20), to: pager.scrollView)
        check(pager.scrollView.hitTest(point, with: nil) === pager.scrollView, "same-turn drag ingress rejects a new root contact")
        check(pager.hosts.values.allSatisfy { $0.view.accessibilityElementsHidden }, "same-turn drag ingress withdraws all root accessibility")
        check(host.view.isUserInteractionEnabled && editor.isFirstResponder, "same-turn withdrawal preserves existing native editor")
        check(editor.acquisitions == acquisitions && editor.resignations == resignations, "ingress creates no responder episode")
        pager.scrollView.contentOffset.x = pager.scrollView.bounds.width * 0.28
        await turn()
        check(editor.isFirstResponder, "partial exposure preserves the native responder")
        pager.scrollView.contentOffset.x = 0
        pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: false)
        await turn()
        check(editor.isFirstResponder && editor.acquisitions == acquisitions && editor.resignations == resignations, "cancelled settlement has no resign or become cycle")
        check(visibility.snapshot.root(.today).departure == departure, "cancelled motion has no committed departure")
        check(editor.text == "Retained native editing episode" && editor.selectedRange == NSRange(location: 9, length: 6), "cancel retains text and selection")
        await drag(to: 1)
        check(!editor.isFirstResponder && editor.resignations == resignations + 1, "committed departure resigns exactly once")
        check(visibility.snapshot.root(.today).departure == departure + 1, "committed departure increments once")
        await drag(to: 0)
        check(!editor.isFirstResponder && editor.acquisitions == acquisitions, "retained root return cannot restore the editor")
        check(editor.becomeFirstResponder(), "a new explicit native focus request works")
        editor.insertText("typed")
        check(editor.text.contains("typed"), "editing works after a new explicit request")
        editor.resignFirstResponder()
        editor.removeFromSuperview()
        print("ROOT_INPUT_ORACLE_PASS synchronous hit-test/AX withdrawal; cancelled native episode continuous; committed single resign/no return promotion. Fixture input is not an app HID/FocusState result.")
        invariant("root input oracle")
    }

    func run(in windowScene: UIWindowScene) async {
        var environment = EnvironmentValues()
        environment.scenePhase = .active
        visibility.scene(.active, immediate: true) // Fixture supplies the real-scene input seam.
        originalVisibility = visibility.roots.mapValues(ObjectIdentifier.init)
        let roots = AppSection.allCases.map { section in
            LifeRouteRootRegistration(section: section, content: AnyView(
                LifeRouteRootNavigationStack(path: Binding(get: {
                    switch section {
                    case .today: return self.router.todayPath
                    case .schedule: return self.router.schedulePath
                    case .tools: return self.router.toolsPath
                    case .resources: return self.router.resourcesPath
                    case .setup: return self.router.setupPath
                    }
                }, set: { path in
                    switch section {
                    case .today: self.router.todayPath = path
                    case .schedule: self.router.schedulePath = path
                    case .tools: self.router.toolsPath = path
                    case .resources: self.router.resourcesPath = path
                    case .setup: self.router.setupPath = path
                    }
                })) { PagerFixtureRoot(state: self.states[section]!, title: section.title).lifeRouteRootScope() }
            ))
        }
        pager = LifeRouteRootPagerController(roots: roots, router: router, visibility: visibility, themeStore: theme,
                                            visualActivity: activity, environment: environment)
        originalHosts = pager.hosts.mapValues(ObjectIdentifier.init)
        window = UIWindow(windowScene: windowScene)
        window.rootViewController = pager
        window.makeKeyAndVisible()
        await turn()
        invariant("initial")
        check(router.selectedSection == .today, "initial selection")
        for root in AppSection.allCases {
            check(pager.hosts[root]!.view.accessibilityElementsHidden == (root != .today), "initial accessibility visibility")
        }
        await rootInputOracle()
        await drag(to: 1)
        check(router.selectedSection == .schedule, "forward settle")
        check(activity.ambientSuspensionCount == 0, "settle releases ambient")
        await drag(to: 1.2)
        check(router.selectedSection == .schedule, "partial cancellation retains selection")
        pager.scrollViewWillBeginDragging(pager.scrollView)
        pager.scrollView.contentOffset.x = 1.7 * pager.scrollView.bounds.width
        pager.scrollView.contentOffset.x = 1.1 * pager.scrollView.bounds.width
        pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: false)
        await turn()
        check(router.selectedSection == .schedule, "reversed drag retains origin")
        await drag(to: 2, decelerates: true)
        check(router.selectedSection == .tools, "deceleration commits")
        pager.scrollViewWillBeginDragging(pager.scrollView)
        pager.scrollView.contentOffset.x = 2.6 * pager.scrollView.bounds.width
        router.select(.setup)
        // Old delegate completion arrives before deferred request consumption.
        pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: false)
        await turn()
        check(router.selectedSection == .setup, "programmatic request wins over old gesture")
        check(abs(pager.scrollView.contentOffset.x / pager.scrollView.bounds.width - 4) < 0.01, "requested page settles")
        pager.scrollViewDidEndDecelerating(pager.scrollView)
        check(router.selectedSection == .setup, "stale callback ignored")
        invariant("interrupted gesture")
        states[.setup]!.pushed = true
        await turn(); await turn(); await turn()
        check(states[.setup]!.detailAppearances > 0, "real direct NavigationLink destination appeared")
        check(!router.shouldShowBottomToolbar, "owning-root destination suppresses toolbar")
        // Await native settlement, rather than assuming a fixed animation duration.
        let pushDeadline = Date().addingTimeInterval(5)
        while !states[.setup]!.detailEffectActive && Date() < pushDeadline { await turn() }
        if !states[.setup]!.detailEffectActive {
            print("NATIVE_SCOPE_OBSERVATION \(visibility.fixtureNativeObservations())")
        }
        check(states[.setup]!.detailEffectActive, "exposed destination effect active")
        let nativeAppearances = states[.setup]!.detailAppearances
        let nativeDisappearances = states[.setup]!.detailDisappearances
        router.select(.today)
        await turn(); await turn()
        check(router.shouldShowBottomToolbar, "offscreen deep root does not suppress current toolbar")
        check(states[.setup]!.pushed, "direct-link selection retained offscreen")
        check(!states[.setup]!.detailEffectActive, "retained destination effect inactive offscreen")
        print("NATIVE_LIFECYCLE_OBSERVATION offscreen appearances=\(states[.setup]!.detailAppearances) disappearances=\(states[.setup]!.detailDisappearances) prior=\(nativeAppearances)/\(nativeDisappearances)")
        router.select(.setup)
        await turn(); await turn()
        check(states[.setup]!.pushed && states[.setup]!.detailEffectActive, "retained direct destination effect resumes without replacing root")
        check(!router.shouldShowBottomToolbar, "deep toolbar suppression reacquired for owner")
        states[.setup]!.pushed = false
        await turn(); await turn(); await turn()
        let popDeadline = Date().addingTimeInterval(5)
        while !router.shouldShowBottomToolbar && Date() < popDeadline { await turn() }
        if !router.shouldShowBottomToolbar {
            print("NATIVE_SCOPE_OBSERVATION \(visibility.fixtureNativeObservations())")
        }
        check(router.shouldShowBottomToolbar, "Back releases exact token")
        check(!states[.setup]!.detailEffectActive, "Back deactivates destination effect")
        check(states[.setup]!.detailDisappearances > nativeDisappearances, "actual local pop still delivers native disappearance")
        check(states[.setup]!.detailEffectEdges == 4, "one active edge each for enter leave return Back")
        for _ in 0..<10 {
            for i in (0...4) { await drag(to: CGFloat(i)) }
            for i in (0...4).reversed() { await drag(to: CGFloat(i)) }
            invariant("round trip")
        }
        for state in states.values {
            check(state.identities.count == 1, "root local State identity retained")
            check(state.draft == "synthetic draft", "draft retained")
        }
        pager.scrollViewWillBeginDragging(pager.scrollView)
        pager.scrollView.contentOffset.x = pager.scrollView.bounds.width * 0.4
        environment.scenePhase = .background
        visibility.scene(.background, immediate: true)
        pager.receiveEnvironment(environment)
        await turn()
        check(router.selectedSection == .today, "background cancels incomplete movement")
        check(activity.ambientSuspensionCount == 0, "background releases paging suspension")
        check(pager.hosts.values.allSatisfy { $0.rootView.relay.values.scenePhase == .background }, "actual scene phase reaches all retained roots")
        let idleGeneration = visibility.snapshot.transitionGeneration
        let sceneRevision = visibility.snapshot.sceneEventRevision
        for _ in 0..<8 {
            pager.receiveEnvironment(environment)
            await turn()
        }
        check(visibility.snapshot.transitionGeneration == idleGeneration, "identical background environment cannot mint idle transitions")
        check(visibility.snapshot.sceneEventRevision == sceneRevision, "identical background environment cannot fabricate scene events")
        environment.scenePhase = .active
        visibility.scene(.active, immediate: true)
        environment.locale = Locale(identifier: "fr_FR")
        environment.dynamicTypeSize = .accessibility2
        pager.receiveEnvironment(environment)
        await turn()
        invariant("environment update")
        check(pager.hosts.values.allSatisfy { $0.rootView.relay.values.dynamicTypeSize == .accessibility2 }, "environment relay reaches five hosts")
        let token = router.beginDeepDestination(in: .tools)
        check(router.shouldShowBottomToolbar, "nonselected token never hides current toolbar")
        router.select(.tools)
        await turn()
        check(!router.shouldShowBottomToolbar, "token remains owned by Tools")
        router.endDeepDestination(token)
        check(router.shouldShowBottomToolbar, "exact token release")
        invariant("final")
        pager.tearDown()
        check(pager.hosts.isEmpty && pager.teardownCount == 5, "balanced whole-pager teardown")
        check(pager.children.isEmpty, "teardown removes all child containment")
        print("ROOT_OWNERSHIP_TEST_PASS \(assertions) assertions; exact production controller/relay/router; synthetic content, manual delegate transport")
        fflush(stdout)
        exit(0)
    }
}

private final class PagerTestAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Ownership Fixture", sessionRole: session.role)
        configuration.delegateClass = PagerTestSceneDelegate.self
        return configuration
    }
}

private final class PagerTestSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { preconditionFailure("Expected window scene") }
        Task { @MainActor in await PagerOwnershipTests().run(in: windowScene) }
    }
}

_ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(PagerTestAppDelegate.self))
