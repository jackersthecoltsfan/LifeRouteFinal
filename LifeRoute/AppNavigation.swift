import SwiftUI
import UIKit
import Combine
import PhotosUI

// Checkpoint 02: one explicit owner for all top-level and stack navigation.
// No feature or cosmetic module should create a competing navigation state.
enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case schedule
    case tools
    case resources
    case setup

    var id: Self { self }

    var title: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Calendar"
        case .tools: return "Tools"
        case .resources: return "Resources"
        case .setup: return "Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver.fill"
        case .resources: return "books.vertical"
        case .setup: return "gearshape"
        }
    }

}

enum AppRoute: Hashable {
    case todayDetails
    case scheduleDetails
    case toolsDetails
    case resourcesDetails
    case setupDetails

    var title: String {
        switch self {
        case .todayDetails: return "Today"
        case .scheduleDetails: return "Calendar"
        case .toolsDetails: return "Session Tools"
        case .resourcesDetails: return "Resources"
        case .setupDetails: return "Setup"
        }
    }

    var subtitle: String {
        switch self {
        case .todayDetails:
            return "Keep your routes, saved places, and daily flow close at hand."
        case .scheduleDetails:
            return "Move between your day, week, and month while keeping calendar context together."
        case .toolsDetails:
            return "Open focused tools for timing, notes, visual supports, and session planning."
        case .resourcesDetails:
            return "Jump quickly to the parts of LifeRoute you use throughout the workday."
        case .setupDetails:
            return "Manage your appearance, clients, home location, and saved places."
        }
    }

    var systemImage: String {
        switch self {
        case .todayDetails: return "sun.max.fill"
        case .scheduleDetails: return "calendar.badge.checkmark"
        case .toolsDetails: return "wrench.and.screwdriver.fill"
        case .resourcesDetails: return "books.vertical.fill"
        case .setupDetails: return "gearshape.fill"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedSection: AppSection = .today
    @Published var todayPath = NavigationPath()
    @Published var schedulePath = NavigationPath()
    @Published var toolsPath = NavigationPath()
    @Published var resourcesPath = NavigationPath()
    @Published var setupPath = NavigationPath()
    /// Destination-based NavigationLinks do not populate the shared
    /// NavigationPath, so deep presentation visibility must be tracked
    /// independently and per root. Tokens support nested deep destinations
    /// without allowing one disappearance callback to reveal the root toolbar.
    @Published private(set) var timerHeroNavigationBlocked = false
    var collapseTimerHeroBeforeNavigation: ((@escaping () -> Void) -> Void)?

    func setTimerHeroNavigationBlocked(_ blocked: Bool) {
        if timerHeroNavigationBlocked != blocked { timerHeroNavigationBlocked = blocked }
    }

    @Published private var deepDestinationTokens: [UUID: AppSection] = [:]

    func select(_ section: AppSection) {
        guard selectedSection != section else { return }
        if timerHeroNavigationBlocked {
            collapseTimerHeroBeforeNavigation? { [weak self] in self?.select(section) }
            return
        }
        selectedSection = section
    }

    func open(_ route: AppRoute, in section: AppSection) {
        if timerHeroNavigationBlocked {
            collapseTimerHeroBeforeNavigation? { [weak self] in self?.open(route, in: section) }
            return
        }
        if selectedSection != section {
            selectedSection = section
        }
        switch section {
        case .today:
            todayPath.append(route)
        case .schedule:
            schedulePath.append(route)
        case .tools:
            toolsPath.append(route)
        case .resources:
            resourcesPath.append(route)
        case .setup:
            setupPath.append(route)
        }
    }

    func resetPath(for section: AppSection) {
        if timerHeroNavigationBlocked {
            collapseTimerHeroBeforeNavigation? { [weak self] in self?.resetPath(for: section) }
            return
        }
        switch section {
        case .today:
            todayPath = NavigationPath()
        case .schedule:
            schedulePath = NavigationPath()
        case .tools:
            toolsPath = NavigationPath()
        case .resources:
            resourcesPath = NavigationPath()
        case .setup:
            setupPath = NavigationPath()
        }
    }

    func beginDeepDestination(in section: AppSection) -> UUID {
        let token = UUID()
        deepDestinationTokens[token] = section
        return token
    }

    func endDeepDestination(_ token: UUID) {
        deepDestinationTokens.removeValue(forKey: token)
    }

    var shouldShowBottomToolbar: Bool {
        guard !deepDestinationTokens.values.contains(selectedSection) else { return false }
        switch selectedSection {
        case .today:
            return todayPath.isEmpty
        case .schedule:
            return schedulePath.isEmpty
        case .tools:
            return toolsPath.isEmpty
        case .resources:
            return resourcesPath.isEmpty
        case .setup:
            return setupPath.isEmpty
        }
    }

}

/// Each permanent root supplies this value once. It is destination ownership,
/// not selection: incoming and retained offscreen destinations keep their root.
struct LifeRouteOwningRoot {
    let section: AppSection
}

private struct LifeRouteOwningRootKey: EnvironmentKey {
    static let defaultValue: LifeRouteOwningRoot? = nil
}

extension EnvironmentValues {
    var lifeRouteOwningRoot: LifeRouteOwningRoot? {
        get { self[LifeRouteOwningRootKey.self] }
        set { self[LifeRouteOwningRootKey.self] = newValue }
    }
}

private struct LifeRouteDeepDestinationModifier: ViewModifier {
    func body(content: Content) -> some View {
        navigationContent(content)
            .modifier(LifeRouteScopeModifier(kind: .destination))
    }

    @ViewBuilder
    private func navigationContent(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .containerBackground(Color.clear, for: .navigation)
                .toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}

extension View {
    func lifeRouteDeepDestination() -> some View {
        modifier(LifeRouteDeepDestinationModifier())
    }
}

// BEGIN ROOT VISIBILITY CONTRACT
// Route intent belongs to AppRouter. This owner records exposure and semantic
// leave events; it cannot select a root or mutate a NavigationPath.
enum LifeRouteRootMotion: String { case initial, idle, dragging, decelerating, requested, terminal }
enum LifeRouteScopeKind: String { case root, destination, modal }

struct LifeRouteRootProjection: Equatable {
    let section: AppSection
    let fraction: Double
    let participates: Bool
    let offscreen: Bool
    let interaction: Bool
    let accessibility: Bool
    let departure: UInt64
}

struct LifeRouteScopeProjection: Equatable {
    let id: UUID
    let root: AppSection
    let parent: UUID?
    let kind: LifeRouteScopeKind
    var alive = true
    var mounted = false
    var locallyExposed = false
    var windowed = false
    var modalExposed = false
    var nativeOrder: UInt64 = 0
    var departure: UInt64 = 0
}

struct LifeRouteVisibilitySnapshot: Equatable {
    var snapshotRevision: UInt64 = 0
    var sceneEventRevision: UInt64 = 0
    var backgroundEventRevision: UInt64 = 0
    var scene: ScenePhase = .inactive
    var transitionGeneration: UInt64 = 0
    var layoutRevision: UInt64 = 0
    var requested: AppSection = .today
    var settled: AppSection = .today
    var origin: AppSection?
    var target: AppSection?
    var motion: LifeRouteRootMotion = .initial
    var parentExposed = false
    var windowed = false
    var fractions: [AppSection: Double] = [:]
    var departures: [AppSection: UInt64] = [:]
    var scopes: [UUID: LifeRouteScopeProjection] = [:]
    var terminal = false

    var topModal: UUID? {
        scopes.values.filter { $0.alive && $0.modalExposed && $0.windowed }
            .max { $0.nativeOrder < $1.nativeOrder }?.id
    }

    func root(_ section: AppSection) -> LifeRouteRootProjection {
        let fraction = fractions[section, default: 0]
        let current = !terminal && windowed && parentExposed && section == settled && section == requested && fraction > 0
        return .init(section: section, fraction: fraction, participates: fraction > 0,
                     offscreen: fraction == 0, interaction: current && motion == .idle && scene == .active && topModal == nil,
                     accessibility: current && topModal == nil, departure: departures[section, default: 0])
    }

    func context(_ id: UUID?) -> LifeRouteEffectContext {
        guard let id, let local = scopes[id] else { return .inactive }
        let projection = root(local.root)
        let modal = topModal
        var ancestor: UUID? = id
        var belongsToModal = false
        while let current = ancestor, let value = scopes[current] {
            if current == modal { belongsToModal = true; break }
            ancestor = value.parent
        }
        let exposed: Bool
        if modal != nil {
            exposed = belongsToModal && local.windowed && local.locallyExposed
        } else {
            exposed = projection.participates && local.root == settled && local.root == requested && parentExposed && windowed && local.locallyExposed
        }
        return .init(scope: id, revision: snapshotRevision, alive: local.alive && !terminal,
                     exposed: exposed && local.alive && !terminal, active: exposed && local.alive && !terminal && scene == .active,
                     interaction: exposed && local.alive && !terminal && scene == .active && (belongsToModal || motion == .idle),
                     rootDeparture: local.kind == .modal || belongsToModal ? 0 : projection.departure,
                     localDeparture: local.departure, sceneDeparture: sceneEventRevision,
                     scene: scene, modal: belongsToModal)
    }
}

struct LifeRouteEffectContext: Equatable {
    let scope: UUID?
    let revision: UInt64
    let alive: Bool
    let exposed: Bool
    let active: Bool
    let interaction: Bool
    let rootDeparture: UInt64
    let localDeparture: UInt64
    let sceneDeparture: UInt64
    let scene: ScenePhase
    let modal: Bool
    static let inactive = Self(scope: nil, revision: 0, alive: false, exposed: false, active: false,
                               interaction: false, rootDeparture: 0, localDeparture: 0, sceneDeparture: 0, scene: .inactive, modal: false)
    var leaveIdentity: [UInt64] { [rootDeparture, localDeparture, sceneDeparture, alive ? 0 : 1] }
}

@MainActor
final class LifeRouteRootVisibility {
    let section: AppSection
    unowned let owner: LifeRouteVisibilityOwner
    init(section: AppSection, owner: LifeRouteVisibilityOwner) { self.section = section; self.owner = owner }
    var snapshot: LifeRouteRootProjection { owner.snapshot.root(section) }
}

@MainActor
final class LifeRoutePresentationScope: ObservableObject {
    let id = UUID()
    private(set) weak var owner: LifeRouteVisibilityOwner?
    private(set) var root: AppSection?
    private(set) var parent: UUID?
    private(set) var kind = LifeRouteScopeKind.root
    var context: LifeRouteEffectContext { owner?.snapshot.context(id) ?? .inactive }
    func bind(owner: LifeRouteVisibilityOwner, root: AppSection, parent: UUID?, kind: LifeRouteScopeKind) {
        if self.owner != nil {
            precondition(self.owner === owner && self.root == root && self.parent == parent && self.kind == kind)
            return
        }
        self.owner = owner; self.root = root; self.parent = parent; self.kind = kind
        owner.register(.init(id: id, root: root, parent: parent, kind: kind))
    }
    func feedbackTicket() -> LifeRouteFeedbackTicket? { owner?.ticket(for: id) }
}

@MainActor
struct LifeRouteFeedbackTicket {
    weak var owner: LifeRouteVisibilityOwner?
    let scope: UUID
    let rootEpoch: UInt64
    let localEpoch: UInt64
    let sceneEpoch: UInt64
    var isEligible: Bool { owner?.admits(self) == true }
}

@MainActor
struct LifeRoutePresentationIntent {
    weak var owner: LifeRouteVisibilityOwner?
    let scope: UUID
    let rootEpoch: UInt64
    let localEpoch: UInt64
    let backgroundEpoch: UInt64
    var isValid: Bool { owner?.admitsIntent(self, requireActive: false) == true }
    var isEligible: Bool { owner?.admitsIntent(self, requireActive: true) == true }
}

/// A handle is cleared before invoking an API that may synchronously reenter.
@MainActor
final class LifeRouteOwnedHandle: ObservableObject {
    private(set) var held: UUID?
    func reconcile(_ active: Bool, acquire: () -> UUID, release: (UUID) -> Void) {
        if active && held == nil { held = acquire() }
        else if !active, let old = held { held = nil; release(old) }
    }
}

@MainActor
final class LifeRouteVisibilityOwner: NSObject, @preconcurrency ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let revisions = PassthroughSubject<LifeRouteVisibilitySnapshot, Never>()
    private(set) var snapshot = LifeRouteVisibilitySnapshot()
    private(set) var roots: [AppSection: LifeRouteRootVisibility] = [:]
    private var queue: [(LifeRouteVisibilitySnapshot) -> LifeRouteVisibilitySnapshot] = []
    private var scheduled = false
    private var reconciling = false
    private var terminalAdmission = false
    private var ingressGeneration: UInt64 = 0
    private var ingressLayout: UInt64 = 0
    private var rootEpochs: [AppSection: UInt64] = [:]
    private var localEpochs: [UUID: UInt64] = [:]
    private var localExposure: [UUID: Bool] = [:]
    private var sceneEpoch: UInt64 = 0
    private var backgroundEpoch: UInt64 = 0
    private var ingressScene: ScenePhase = .inactive
    private var terminalScopes = Set<UUID>()
    private var liveScopes = Set<UUID>()
    private var nativeProbes: [UUID: LifeRouteNativeScopeController] = [:]
    private var systemProbes: [LifeRouteSystemModalController] = []
    private var displayLink: CADisplayLink?
    private var nativeOrder: UInt64 = 0
    private var nativeOrders: [UUID: UInt64] = [:]
    private var tokens: [UUID: UUID] = [:]
    private struct Consumer {
        let scope: UUID
        var last: LifeRouteEffectContext?
        var action: (LifeRouteEffectContext) -> Void
    }
    private var consumers: [UUID: Consumer] = [:]
    private var freshConsumers = Set<UUID>()
    private weak var tokenRouter: AppRouter?

    override init() {
        super.init()
        for root in AppSection.allCases { roots[root] = LifeRouteRootVisibility(section: root, owner: self) }
    }

    func register(_ scope: LifeRouteScopeProjection) {
        guard !terminalAdmission else { return }
        liveScopes.insert(scope.id)
        enqueue { previous in
            var next = previous
            if next.scopes[scope.id] == nil { next.scopes[scope.id] = scope }
            return next
        }
    }

    fileprivate func observeSystem(_ probe: LifeRouteSystemModalController) { systemProbes.append(probe) }

    func observe(_ probe: LifeRouteNativeScopeController, router: AppRouter) {
        nativeProbes[probe.scope.id] = probe; tokenRouter = router
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(sampleNative))
            link.add(to: .main, forMode: .common); displayLink = link
        }
    }

    func connect(_ id: UUID, scope: UUID, action: @escaping (LifeRouteEffectContext) -> Void) {
        guard !terminalAdmission else { return }
        // SwiftUI can construct a content probe before its enclosing scope probe.
        // Bind the consumer at the same safe drain as scope registration.
        enqueue { [weak self] previous in
            guard let self, self.liveScopes.contains(scope), !self.terminalAdmission else { return previous }
            let last = self.consumers[id]?.last
            self.consumers[id] = Consumer(scope: scope, last: last, action: action)
            if last == nil { self.freshConsumers.insert(id) }
            return previous
        }
    }

    private func deliverConsumers(force: Bool = false) {
        // Withdraw incompatible presentation ownership before granting its successor.
        let installed = snapshot
        let ordered = consumers.sorted { lhs, rhs in
            func withdraws(_ value: Consumer) -> Bool {
                let next = installed.context(value.scope)
                return (value.last?.active == true && !next.active) ||
                    (value.last?.exposed == true && !next.exposed)
            }
            let left = withdraws(lhs.value), right = withdraws(rhs.value)
            return left != right ? left : lhs.key.uuidString < rhs.key.uuidString
        }
        for (id, consumer) in ordered {
            let context = snapshot.context(consumer.scope)
            let previous = consumer.last
            let changed = previous == nil || previous?.leaveIdentity != context.leaveIdentity ||
                previous?.exposed != context.exposed || previous?.active != context.active ||
                previous?.interaction != context.interaction || previous?.modal != context.modal
            let fresh = freshConsumers.remove(id) != nil
            if force || changed || fresh {
                consumers[id]?.last = context
                consumer.action(context)
            }
            if !context.alive && snapshot.scopes[consumer.scope] != nil { consumers.removeValue(forKey: id) }
        }
    }

    func scene(_ phase: ScenePhase, immediate: Bool = false) {
        guard !terminalAdmission, phase != ingressScene else { return }
        ingressScene = phase
        if phase != .active { sceneEpoch &+= 1 }
        if phase == .background { backgroundEpoch &+= 1 }
        let epoch = sceneEpoch
        let background = backgroundEpoch
        enqueue(immediate: immediate) { previous in
            var next = previous
            next.scene = phase; next.sceneEventRevision = epoch; next.backgroundEventRevision = background
            return next
        }
    }

    func requested(_ section: AppSection, generation: UInt64) {
        guard !terminalAdmission, generation >= ingressGeneration else { return }
        ingressGeneration = generation
        enqueue { previous in
            var next = previous; next.requested = section; next.target = section
            next.transitionGeneration = generation; next.motion = .requested; return next
        }
    }

    func mechanics(requested: AppSection, settled: AppSection, origin: AppSection?, target: AppSection?,
                   motion: LifeRouteRootMotion, generation: UInt64, layout: UInt64,
                   fractions: [AppSection: Double], parent: Bool, window: Bool, committedFrom: AppSection? = nil) {
        guard !terminalAdmission, generation >= ingressGeneration, layout >= ingressLayout else { return }
        ingressGeneration = generation; ingressLayout = layout
        if let old = committedFrom, old != settled { rootEpochs[old, default: 0] &+= 1 }
        let departures = rootEpochs
        enqueue(immediate: committedFrom != nil) { previous in
            var next = previous
            next.requested = requested; next.settled = settled; next.origin = origin; next.target = target
            next.motion = motion; next.transitionGeneration = generation; next.layoutRevision = layout
            next.fractions = fractions.mapValues { $0.isFinite ? min(1, max(0, $0)) : 0 }
            next.parentExposed = parent; next.windowed = window; next.departures = departures
            return next
        }
    }

    func native(_ updates: [LifeRouteScopeProjection], immediate: Bool = false) {
        guard !terminalAdmission else { return }
        let updates = updates.filter { liveScopes.contains($0.id) }
        for update in updates {
            if !update.alive, terminalScopes.insert(update.id).inserted { localEpochs[update.id, default: 0] &+= 1 }
            if localExposure[update.id] == true && !update.locallyExposed {
                localEpochs[update.id, default: 0] &+= 1
            }
            if !update.alive { liveScopes.remove(update.id) }
        }
        for update in updates { localExposure[update.id] = update.locallyExposed }
        let epochs = localEpochs
        enqueue(immediate: immediate) { previous in
            var next = previous
            for var update in updates where next.scopes[update.id]?.alive != false {
                update.departure = epochs[update.id, default: 0]; next.scopes[update.id] = update
            }
            return next
        }
    }

    @objc func sampleNative() {
        guard !terminalAdmission else { return }
        var updates = nativeProbes.values.compactMap { probe -> LifeRouteScopeProjection? in
            guard var fact = probe.sample() else { return nil }
            if fact.modalExposed && nativeOrders[fact.id] == nil { nativeOrder &+= 1; nativeOrders[fact.id] = nativeOrder }
            fact.nativeOrder = nativeOrders[fact.id, default: 0]
            return fact
        }
        for probe in systemProbes {
            for var fact in probe.sample() {
                if fact.modalExposed && nativeOrders[fact.id] == nil { nativeOrder &+= 1; nativeOrders[fact.id] = nativeOrder }
                fact.nativeOrder = nativeOrders[fact.id, default: 0]
                updates.append(fact)
            }
        }
        native(updates, immediate: true)
        let retired = terminalScopes
        terminalScopes.removeAll()
        for id in retired {
            nativeProbes.removeValue(forKey: id); nativeOrders.removeValue(forKey: id)
            localEpochs.removeValue(forKey: id); localExposure.removeValue(forKey: id)
        }
        if !retired.isEmpty {
            enqueue { previous in
                var next = previous
                for id in retired { next.scopes.removeValue(forKey: id) }
                return next
            }
        }
        systemProbes.removeAll { $0.canRetire }
    }

    func ticket(for id: UUID) -> LifeRouteFeedbackTicket? {
        let installed = snapshot
        let context = installed.context(id)
        guard context.active, let scope = installed.scopes[id] else { return nil }
        // A queued revocation can advance ingress while this installed state is
        // still active. Never turn that older visibility into a fresh grant.
        let ticket = LifeRouteFeedbackTicket(owner: self, scope: id,
            rootEpoch: context.modal ? 0 : installed.departures[scope.root, default: 0],
            localEpoch: scope.departure, sceneEpoch: installed.sceneEventRevision)
        return admits(ticket) ? ticket : nil
    }

    func admits(_ ticket: LifeRouteFeedbackTicket) -> Bool {
        guard !terminalAdmission, !terminalScopes.contains(ticket.scope), ingressScene == .active,
              let scope = snapshot.scopes[ticket.scope], snapshot.context(ticket.scope).active else { return false }
        return ticket.rootEpoch == (snapshot.context(ticket.scope).modal ? 0 : rootEpochs[scope.root, default: 0]) &&
            ticket.localEpoch == localEpochs[ticket.scope, default: 0] && ticket.sceneEpoch == sceneEpoch
    }

    func intent(for id: UUID) -> LifeRoutePresentationIntent? {
        let installed = snapshot
        guard let fact = installed.scopes[id], installed.context(id).interaction,
              installed.sceneEventRevision == sceneEpoch else { return nil }
        let intent = LifeRoutePresentationIntent(owner: self, scope: id,
            rootEpoch: installed.departures[fact.root, default: 0],
            localEpoch: fact.departure, backgroundEpoch: installed.backgroundEventRevision)
        return admitsIntent(intent, requireActive: true) ? intent : nil
    }

    func admitsIntent(_ intent: LifeRoutePresentationIntent, requireActive: Bool) -> Bool {
        guard !terminalAdmission, !terminalScopes.contains(intent.scope), let fact = snapshot.scopes[intent.scope], fact.alive,
              intent.rootEpoch == rootEpochs[fact.root, default: 0], intent.localEpoch == localEpochs[intent.scope, default: 0],
              intent.backgroundEpoch == backgroundEpoch else { return false }
        return !requireActive || (ingressScene == .active && snapshot.context(intent.scope).interaction)
    }

    func presentedFeedbackTicket(for id: UUID) -> LifeRouteFeedbackTicket? {
        if let modal = snapshot.topModal, snapshot.scopes[modal]?.parent == id { return ticket(for: modal) }
        return ticket(for: id)
    }

    func timerActive(in scope: LifeRoutePresentationScope?) -> Bool {
        guard let scope else { return false }
        if snapshot.context(scope.id).active { return true }
        return snapshot.scopes.values.contains { $0.kind == .modal && $0.parent == scope.id && snapshot.context($0.id).active }
    }

    func teardown() {
        guard !terminalAdmission else { return }
        terminalAdmission = true; ingressGeneration &+= 1; sceneEpoch &+= 1
        displayLink?.invalidate(); displayLink = nil
        enqueue(immediate: true, allowTerminal: true) { previous in
            var next = previous; next.terminal = true; next.motion = .terminal
            for id in next.scopes.keys { next.scopes[id]?.alive = false }
            return next
        }
        nativeProbes.removeAll(); systemProbes.removeAll()
    }

    private func enqueue(immediate: Bool = false, allowTerminal: Bool = false,
                         _ change: @escaping (LifeRouteVisibilitySnapshot) -> LifeRouteVisibilitySnapshot) {
        guard !terminalAdmission || allowTerminal else { return }
        queue.append(change)
        if immediate && !reconciling { drain(); return }
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in self?.drain() }
    }

    private func drain() {
        guard !reconciling else { return }
        scheduled = false; reconciling = true
        defer { reconciling = false }
        while !queue.isEmpty {
            let change = queue.removeFirst()
            var next = change(snapshot)
            if terminalAdmission { next.terminal = true }
            guard next != snapshot else { deliverConsumers(); continue }
            next.snapshotRevision = snapshot.snapshotRevision &+ 1
            snapshot = next // All five projections read this one installed value.
            for (id, scope) in next.scopes {
                if scope.alive && scope.mounted && !next.terminal && scope.kind == .destination && tokens[id] == nil {
                    tokens[id] = tokenRouter?.beginDeepDestination(in: scope.root)
                } else if (!scope.alive || next.terminal), let token = tokens.removeValue(forKey: id) {
                    tokenRouter?.endDeepDestination(token)
                }
            }
            deliverConsumers(force: true)
            revisions.send(next)
            objectWillChange.send()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-LifeRouteRootOwnershipTrace") {
                let row: [String: Any] = ["revision": next.snapshotRevision, "sceneRevision": next.sceneEventRevision,
                    "generation": next.transitionGeneration, "layout": next.layoutRevision, "scene": String(describing: next.scene),
                    "requested": next.requested.rawValue, "settled": next.settled.rawValue, "motion": next.motion.rawValue,
                    "modal": next.topModal?.uuidString ?? "nil", "tokens": Dictionary(uniqueKeysWithValues: tokens.map { ($0.key.uuidString, $0.value.uuidString) }),
                    "scopes": next.scopes.values.map { ["id": $0.id.uuidString, "root": $0.root.rawValue, "kind": $0.kind.rawValue,
                        "alive": $0.alive, "local": $0.locallyExposed, "modal": $0.modalExposed, "active": next.context($0.id).active] as [String: Any] }]
                if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) {
                    print("LIFEROUTE_VISIBILITY " + text); fflush(stdout)
                }
            }
#endif
        }
    }
}

/// Public containment observation only. No navigation delegate takeover, private
/// controller-class matching, stack mutation, or forwarded feature callbacks.
@MainActor
final class LifeRouteNativeScopeController: UIViewController {
    let scope: LifeRoutePresentationScope
    private weak var navigationOwner: UIViewController?
    private weak var navigation: UINavigationController?
    private var wasMember = false
    private var disposed = false
    private var transition: ObjectIdentifier?
    private var coordinatorReference: AnyObject?
    private var transitioning = false
    init(scope: LifeRoutePresentationScope) { self.scope = scope; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Native scope requires its stable reference") }
    override func loadView() { view = UIView(); view.isUserInteractionEnabled = false; view.backgroundColor = .clear }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); scope.owner?.sampleNative() }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); watchTransition() }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); watchTransition() }
    override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); watchTransition() }
    func dismantle() { disposed = true; watchTransition() }

    private func watchTransition() {
        guard let coordinator = navigation?.transitionCoordinator ?? transitionCoordinator else { return }
        let identity = ObjectIdentifier(coordinator as AnyObject)
        guard transition != identity else { return }
        transition = identity; coordinatorReference = coordinator as AnyObject; transitioning = true
        let registered = coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, self.transition == identity else { return }
            self.transitioning = false; self.scope.owner?.sampleNative()
        }
        if !registered { transitioning = false }
    }

    func sample() -> LifeRouteScopeProjection? {
        guard let root = scope.root else { return nil }
        var cursor: UIViewController? = self
        var modal: UIViewController?
        while let current = cursor {
            if let nav = current.parent as? UINavigationController {
                navigationOwner = current; navigation = nav
            }
            if current.presentingViewController != nil { modal = current }
            cursor = current.parent
        }
        watchTransition()
        var fact = scope.owner?.snapshot.scopes[scope.id] ?? .init(id: scope.id, root: root, parent: scope.parent, kind: scope.kind)
        let windowed = viewIfLoaded?.window != nil
        fact.windowed = windowed
        if let navigation {
            let member = navigation.viewControllers.contains { $0 === navigationOwner }
            if member { wasMember = true }; fact.mounted = wasMember
            if wasMember && !member && !transitioning { fact.alive = false; fact.locallyExposed = false }
            else if !transitioning { fact.locallyExposed = member && navigation.topViewController === navigationOwner }
        } else if scope.kind != .destination {
            fact.locallyExposed = windowed; fact.mounted = windowed || fact.mounted
            if disposed && !windowed { fact.alive = false }
        }
        fact.modalExposed = scope.kind == .modal && modal?.viewIfLoaded?.window != nil
        if scope.kind == .modal && disposed && !fact.modalExposed { fact.alive = false }
        return fact
    }
}

private struct LifeRoutePresentationKey: EnvironmentKey {
    static let defaultValue: LifeRoutePresentationScope? = nil
}
extension EnvironmentValues {
    var lifeRoutePresentation: LifeRoutePresentationScope? {
        get { self[LifeRoutePresentationKey.self] }
        set { self[LifeRoutePresentationKey.self] = newValue }
    }
}

@propertyWrapper
struct LifeRoutePresentation: DynamicProperty {
    @EnvironmentObject private var owner: LifeRouteVisibilityOwner
    @Environment(\.lifeRoutePresentation) private var scope
    var wrappedValue: LifeRouteEffectContext { owner.snapshot.context(scope?.id) }
}

private struct LifeRouteNativeScopeProbe: UIViewControllerRepresentable {
    let scope: LifeRoutePresentationScope
    let owner: LifeRouteVisibilityOwner
    let root: AppSection
    let parent: UUID?
    let kind: LifeRouteScopeKind
    let router: AppRouter
    func makeUIViewController(context: Context) -> LifeRouteNativeScopeController {
        scope.bind(owner: owner, root: root, parent: parent, kind: kind)
        let controller = LifeRouteNativeScopeController(scope: scope)
        owner.observe(controller, router: router)
        return controller
    }
    func updateUIViewController(_ controller: LifeRouteNativeScopeController, context: Context) {}
    static func dismantleUIViewController(_ controller: LifeRouteNativeScopeController, coordinator: ()) { controller.dismantle() }
}

private struct LifeRouteScopeModifier: ViewModifier {
    @EnvironmentObject private var owner: LifeRouteVisibilityOwner
    @EnvironmentObject private var router: AppRouter
    @Environment(\.lifeRouteOwningRoot) private var root
    @Environment(\.lifeRoutePresentation) private var parent
    @StateObject private var scope: LifeRoutePresentationScope
    let kind: LifeRouteScopeKind
    init(kind: LifeRouteScopeKind, scope: LifeRoutePresentationScope? = nil) {
        self.kind = kind; _scope = StateObject(wrappedValue: scope ?? LifeRoutePresentationScope())
    }
    func body(content: Content) -> some View {
        content.environment(\.lifeRoutePresentation, scope)
            .background {
                if let root {
                    LifeRouteNativeScopeProbe(scope: scope, owner: owner, root: root.section,
                        parent: parent?.id, kind: kind, router: router).frame(width: 0, height: 0)
                }
            }
    }
}

private struct LifeRouteReconcileProbe: UIViewRepresentable {
    let id: UUID
    let owner: LifeRouteVisibilityOwner
    let scope: LifeRoutePresentationScope?
    let action: (LifeRouteEffectContext) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView(); view.isUserInteractionEnabled = false
        if let scope { owner.connect(id, scope: scope.id, action: action) }
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        if let scope { owner.connect(id, scope: scope.id, action: action) }
    }
}

private struct LifeRouteReconcileModifier: ViewModifier {
    @EnvironmentObject private var owner: LifeRouteVisibilityOwner
    @Environment(\.lifeRoutePresentation) private var scope
    @State private var id = UUID()
    let action: (LifeRouteEffectContext) -> Void
    func body(content: Content) -> some View {
        content.background(LifeRouteReconcileProbe(id: id, owner: owner, scope: scope, action: action).frame(width: 0, height: 0))
    }
}

extension View {
    func lifeRouteRootScope() -> some View { modifier(LifeRouteScopeModifier(kind: .root)) }
    func lifeRouteModalScope() -> some View { modifier(LifeRouteScopeModifier(kind: .modal)) }
    func lifeRouteReconcile(_ action: @escaping (LifeRouteEffectContext) -> Void) -> some View {
        modifier(LifeRouteReconcileModifier(action: action))
    }
}
struct LifeRoutePresentationClock: TimelineSchedule {
    let interval: TimeInterval
    let active: Bool
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        if active { return AnySequence(PeriodicTimelineSchedule(from: startDate, by: interval).entries(from: startDate, mode: mode)) }
        return AnySequence(CollectionOfOne(startDate))
    }
}

struct LifeRouteModalContent<Content: View>: View {
    @StateObject private var scope = LifeRoutePresentationScope()
    let content: (LifeRoutePresentationScope) -> Content
    init(@ViewBuilder content: @escaping (LifeRoutePresentationScope) -> Content) { self.content = content }
    var body: some View { content(scope).modifier(LifeRouteScopeModifier(kind: .modal, scope: scope)) }
}

/// The public native presentation is the evidence. The binding only admits a
/// new observation attempt; an already shown modal survives a later false intent.
@MainActor
private final class LifeRouteSystemModalController: UIViewController {
    weak var owner: LifeRouteVisibilityOwner?
    var parentScope: LifeRoutePresentationScope?
    var intent = false
    var photoPickerOnly = false
    private weak var presented: UIViewController?
    private var modalID: UUID?
    private var wasWindowed = false
    var disposed = false
    var canRetire: Bool { disposed && modalID == nil }
    init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use the presentation observer") }
    override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
    func sample() -> [LifeRouteScopeProjection] {
        guard let owner, let parentScope, let root = parentScope.root else { return [] }
        func isPhotoPicker(_ controller: UIViewController) -> Bool {
            controller is PHPickerViewController || controller.children.contains(where: isPhotoPicker)
        }
        if modalID == nil && (intent || photoPickerOnly) {
            var ancestor: UIViewController? = self
            while let current = ancestor {
                if let actual = current.presentedViewController, actual.viewIfLoaded?.window != nil,
                   !photoPickerOnly || isPhotoPicker(actual) {
                    presented = actual; modalID = UUID(); wasWindowed = true
                    break
                }
                ancestor = current.parent
            }
        }
        guard let modalID else { return [] }
        let exposed = presented?.viewIfLoaded?.window != nil
        var fact = LifeRouteScopeProjection(id: modalID, root: root, parent: parentScope.id, kind: .modal)
        fact.mounted = wasWindowed; fact.windowed = exposed; fact.locallyExposed = exposed; fact.modalExposed = exposed
        fact.alive = exposed
        if owner.snapshot.scopes[modalID] == nil { owner.register(fact) }
        if !exposed { self.modalID = nil; presented = nil; wasWindowed = false }
        return [fact]
    }
}

private struct LifeRouteSystemModalProbe: UIViewControllerRepresentable {
    @EnvironmentObject private var owner: LifeRouteVisibilityOwner
    @Environment(\.lifeRoutePresentation) private var scope
    let intent: Bool
    var photoPickerOnly = false
    func makeUIViewController(context: Context) -> LifeRouteSystemModalController {
        let controller = LifeRouteSystemModalController()
        controller.owner = owner; controller.parentScope = scope; controller.intent = intent
        controller.photoPickerOnly = photoPickerOnly
        owner.observeSystem(controller)
        return controller
    }
    func updateUIViewController(_ controller: LifeRouteSystemModalController, context: Context) {
        controller.intent = intent
    }
    static func dismantleUIViewController(_ controller: LifeRouteSystemModalController, coordinator: ()) { controller.intent = false; controller.disposed = true }
}

extension View {
    func lifeRoutePhotoPickerScope() -> some View {
        background(LifeRouteSystemModalProbe(intent: false, photoPickerOnly: true).frame(width: 0, height: 0))
    }
    func lifeRouteSystemModal(isPresented: Bool) -> some View {
        background(LifeRouteSystemModalProbe(intent: isPresented).frame(width: 0, height: 0))
    }
}

// END ROOT VISIBILITY CONTRACT

// Checkpoint 06: scene transitions share one bounded persistence-flush task.
// A second inactive/background transition joins the work already in flight
// instead of creating another lifecycle-owned task.
@MainActor
final class AppLifecycleCore: ObservableObject {
    private var persistenceFlushTask: Task<Void, Never>?

    func flushPersistenceForSceneTransition() {
        guard persistenceFlushTask == nil else { return }
        persistenceFlushTask = Task { @MainActor [weak self] in
            await LifeRoutePersistenceStore.shared.flushPendingWrites()
            self?.persistenceFlushTask = nil
        }
    }

    deinit {
        persistenceFlushTask?.cancel()
    }
}

// iOS 16 compatibility shim for the simple empty-state surface used by the
// functional-core rebuild. SwiftUI's system ContentUnavailableView starts at
// iOS 17, while LifeRoute still supports iOS 16 during this rebuild.
struct ContentUnavailableView: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let systemImage: String
    let description: Text

    init(_ title: String, systemImage: String, description: Text) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ScenicRoyalCard(role: .readability) {
            VStack(spacing: 14) {
                ScenicRoyalIconBadge(systemImage: systemImage)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    description
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }
}
