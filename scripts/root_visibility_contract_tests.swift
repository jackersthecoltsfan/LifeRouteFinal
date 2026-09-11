// Exact production declarations precede this file in the runner's translation
// unit. Only model/feedback endpoints and synthetic event transport are doubles.
import UIKit
import SwiftUI
import Combine

struct LifeRouteClientProfile {}
@MainActor enum LifeRouteHaptics {
    static var successes = 0
    static func success() { successes += 1 }
}

extension LifeRouteVisibilityOwner {
    fileprivate func flushFixtureEvents() { drain() }
}
extension AISessionNoteRuntimeModel {
    fileprivate var fixtureRaceFinished: Bool { activeRace?.fixtureFinished == true }
    fileprivate var fixtureRequestID: UUID? { draftLedger.activeRequestID }
}
extension SessionNoteRequestRace {
    fileprivate var fixtureFinished: Bool {
        lock.lock(); defer { lock.unlock() }; return isFinished
    }
}

@MainActor private final class VisibilityFixture {
    var count = 0
    var cases: [String] = []
    func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        count += 1
        guard value() else {
            print("ROOT_VISIBILITY_TEST_FAIL \(count): \(message)")
            fflush(stdout); exit(1)
        }
    }
    func record(_ id: String) { cases.append(id); print("VISIBILITY_CASE \(id)"); fflush(stdout) }
    func facts(_ hub: LifeRouteVisibilityOwner, _ selected: AppSection, from: AppSection? = nil,
               generation: UInt64 = 1, motion: LifeRouteRootMotion = .idle,
               fractions: [AppSection: Double]? = nil, layout: UInt64 = 1) {
        hub.mechanics(requested: selected, settled: selected, origin: motion == .idle ? nil : selected,
                      target: motion == .idle ? nil : .today, motion: motion, generation: generation, layout: layout,
                      fractions: fractions ?? [selected: 1], parent: true, window: true, committedFrom: from)
        hub.flushFixtureEvents()
    }
    func local(_ hub: LifeRouteVisibilityOwner, _ root: AppSection = .setup,
               parent: LifeRoutePresentationScope? = nil, kind: LifeRouteScopeKind = .destination) -> LifeRoutePresentationScope {
        let scope = LifeRoutePresentationScope()
        scope.bind(owner: hub, root: root, parent: parent?.id, kind: kind)
        hub.flushFixtureEvents()
        var fact = hub.snapshot.scopes[scope.id]!
        fact.mounted = true; fact.windowed = true; fact.locallyExposed = true
        fact.modalExposed = kind == .modal; fact.nativeOrder = UInt64(hub.snapshot.scopes.count)
        hub.native([fact], immediate: true)
        return scope
    }
    func fresh() -> (LifeRouteVisibilityOwner, LifeRoutePresentationScope) {
        let hub = LifeRouteVisibilityOwner(); hub.scene(.active, immediate: true)
        let scope = local(hub); facts(hub, .setup)
        return (hub, scope)
    }
    func drainTasks(until condition: () -> Bool) async {
        for _ in 0..<1000 { if condition() { return }; await Task.yield() }
        expect(condition(), "bounded endpoint continuation reached")
    }

    func reducers() {
        record("T01 probe construction order")
        let construction = LifeRouteVisibilityOwner(); let unbound = LifeRoutePresentationScope()
        var constructionActive = false
        construction.connect(UUID(), scope: unbound.id) { constructionActive = $0.active }
        unbound.bind(owner: construction, root: .setup, parent: nil, kind: .destination)
        construction.scene(.active, immediate: true)
        var mounted = construction.snapshot.scopes[unbound.id]!
        mounted.mounted = true; mounted.windowed = true; mounted.locallyExposed = true
        construction.native([mounted], immediate: true); facts(construction, .setup)
        expect(constructionActive, "content probe can precede enclosing scope registration")
        construction.teardown()
        expect(!constructionActive, "terminal effects finish before host removal")
        record("T01/E01 five stable inactive references")
        let hub = LifeRouteVisibilityOwner()
        let ids = hub.roots.mapValues(ObjectIdentifier.init)
        expect(hub.roots.count == 5, "five permanent root references")
        expect(hub.snapshot.motion == .initial, "no manufactured initial settlement")
        for root in AppSection.allCases { expect(hub.roots[root]!.snapshot.offscreen, "inactive before real exposure") }
        hub.scene(.active, immediate: true)
        let scope = local(hub)
        expect(!scope.context.active, "mounted destination alone does not activate")
        facts(hub, .setup)
        expect(scope.context.active, "selected exposed local destination activates")
        expect(AppSection.allCases.filter { hub.snapshot.root($0).interaction } == [.setup], "one root at rest")
        let revision = hub.snapshot.snapshotRevision
        facts(hub, .setup)
        expect(hub.snapshot.snapshotRevision == revision, "identical snapshot no-op")
        expect(hub.roots.mapValues(ObjectIdentifier.init) == ids, "reference identities unchanged")
        let ticket = scope.feedbackTicket()!
        var observed: [[UInt64]] = []
        let connection = hub.revisions.sink { snapshot in
            observed.append(AppSection.allCases.map { hub.roots[$0]!.owner.snapshot.snapshotRevision })
            self.expect(hub.snapshot.snapshotRevision == snapshot.snapshotRevision, "notification follows aggregate installation")
        }
        var leaves = 0
        var previous = scope.context.rootDeparture
        hub.connect(UUID(), scope: scope.id) { context in
            if context.rootDeparture != previous { previous = context.rootDeparture; leaves += 1 }
        }
        record("T03/E02-E08 partial zero cancelled reversed deceleration")
        for fractions: [AppSection: Double] in [[.setup:0.7,.resources:0.3],[.setup:0,.resources:1],[.setup:0.4,.resources:0.6],[.setup:1]] {
            facts(hub, .setup, generation:2, motion:.dragging, fractions:fractions)
            expect(leaves == 0, "provisional geometry never commits departure")
            expect(!hub.snapshot.root(.resources).interaction, "incoming root cannot interact")
        }
        facts(hub,.setup,generation:2,motion:.decelerating)
        expect(leaves == 0, "deceleration remains provisional")
        facts(hub,.setup,generation:2)
        expect(leaves == 0 && ticket.isEligible, "cancel keeps request episode")
        record("X16 committed ABA")
        facts(hub,.today,from:.setup,generation:3)
        facts(hub,.setup,from:.today,generation:4)
        expect(leaves == 1, "setup leave preserved across ABA")
        expect(hub.snapshot.departures[.today] == 1, "second actual departure retained")
        expect(!ticket.isEligible, "old feedback never reactivates after return")
        record("X12/T04/E09-E11 delivered request and stale completion")
        hub.requested(.tools,generation:6)
        facts(hub,.resources,from:.setup,generation:5)
        expect(hub.snapshot.requested == .tools && hub.snapshot.settled == .setup, "stale gesture rejected; intent distinct from settlement")
        facts(hub,.tools,from:.setup,generation:6)
        expect(hub.snapshot.settled == .tools, "programmatic final settlement")
        let settledRevision=hub.snapshot.snapshotRevision
        facts(hub,.today,from:.tools,generation:5)
        expect(hub.snapshot.snapshotRevision == settledRevision, "old generation no state publication")
        record("X13/X14 background rotation partial")
        facts(hub,.tools,generation:7,motion:.dragging,fractions:[.tools:0.4,.resources:0.6],layout:2)
        let departures=hub.snapshot.departures
        facts(hub,.tools,generation:7,motion:.dragging,fractions:[.tools:0.4,.resources:0.6],layout:3)
        facts(hub,.today,from:.tools,generation:7,layout:2)
        expect(hub.snapshot.departures == departures && hub.snapshot.layoutRevision == 3, "old layout rejected; rotation is not departure")
        hub.scene(.inactive,immediate:true); hub.scene(.background,immediate:true); hub.scene(.active,immediate:true)
        expect(hub.snapshot.sceneEventRevision == 2, "both real nonactive facts survive active return")
        expect(!scope.context.active, "root hidden while actual scene remains active")
        expect(observed.allSatisfy { Set($0).count == 1 }, "one coherent revision for all five projections")
        connection.cancel()
        record("E22 terminal queued geometry")
        hub.mechanics(requested:.setup,settled:.setup,origin:nil,target:nil,motion:.idle,generation:8,layout:3,
                      fractions:[.setup:1],parent:true,window:true)
        hub.teardown(); hub.flushFixtureEvents()
        expect(hub.snapshot.terminal && !scope.context.active, "terminal wins over queued grants")
        let finalRevision=hub.snapshot.snapshotRevision
        facts(hub,.setup,from:.tools,generation:9,layout:4); hub.teardown(); hub.flushFixtureEvents()
        expect(hub.snapshot.snapshotRevision == finalRevision, "terminal callbacks and duplicate teardown ignored")
    }

    func localModalTheme() {
        record("L01-L06 independent Add/Edit local lifetimes")
        let (hub,list)=fresh()
        let add=local(hub,parent:list);let edit=local(hub,parent:list)
        expect(Set([list.id,add.id,edit.id]).count == 3, "independent complete list/Add/Edit scopes")
        var listFact=hub.snapshot.scopes[list.id]!;listFact.locallyExposed=false
        hub.native([listFact],immediate:true)
        expect(add.context.active && edit.context.alive && !list.context.exposed, "covered parent does not gate its independent child")
        let addIdentity=add.id
        facts(hub,.today,from:.setup,generation:2)
        expect(add.context.alive && !add.context.exposed && add.id == addIdentity, "editor alive while root hidden")
        facts(hub,.setup,from:.today,generation:3)
        expect(add.context.active && add.id == addIdentity, "editor return retains identity")
        var editFact=hub.snapshot.scopes[edit.id]!;editFact.alive=false;editFact.locallyExposed=false
        hub.native([editFact],immediate:true)
        editFact.alive=true;editFact.locallyExposed=true;hub.native([editFact],immediate:true)
        expect(!edit.context.alive, "terminal local scope rejects old true callback")
        record("X03-X05/L07-L10 modal native facts outrank root")
        let modal=local(hub,parent:add,kind:.modal)
        expect(modal.context.active && !add.context.active, "native modal owns exposed effects")
        expect(AppSection.allCases.allSatisfy { !hub.snapshot.root($0).interaction }, "modal excludes every underlying root")
        let modalTicket=modal.feedbackTicket()!
        facts(hub,.today,from:.setup,generation:4)
        expect(modal.context.active && modalTicket.isEligible, "visible cover survives underlying root change")
        var modalFact=hub.snapshot.scopes[modal.id]!;modalFact.alive=false;modalFact.modalExposed=false
        hub.native([modalFact],immediate:true)
        expect(hub.snapshot.settled == .today && hub.snapshot.topModal == nil, "dismissal reveals current selection")
        expect(!modalTicket.isEligible && !add.context.active, "no ghost modal or presenter feedback")
        record("T08/X08 Theme lease 1-0-1-0 and category")
        let theme=LifeRouteThemeVisibilityEpisode();let handle=LifeRouteOwnedHandle()
        let ambient=LifeRouteVisualActivityCoordinator();var category="initial";var initialization=0;var acquisitions=0;var releases=0
        hub.connect(UUID(),scope:add.id) { context in
            theme.reconcile(context,initialize:{initialization += 1;category="selected"},visibilityChanged:{ active in
                handle.reconcile(active,acquire:{acquisitions += 1;return ambient.acquireAmbientSuspension()},release:{ id in
                    releases += 1;ambient.releaseAmbientSuspension(id)
                })
            })
        }
        facts(hub,.setup,from:.today,generation:5)
        expect(ambient.ambientSuspensionCount == 1, "Theme one owner")
        let first=handle.held;category="browsed"
        facts(hub,.today,from:.setup,generation:6)
        expect(ambient.ambientSuspensionCount == 0 && handle.held == nil, "Theme exact release")
        facts(hub,.setup,from:.today,generation:7)
        expect(ambient.ambientSuspensionCount == 1 && handle.held != first, "Theme fresh lease")
        expect(category == "browsed" && initialization == 1, "category initialization never replays on root return")
        var addFact=hub.snapshot.scopes[add.id]!;addFact.alive=false;addFact.locallyExposed=false
        hub.native([addFact],immediate:true);hub.native([addFact],immediate:true)
        expect(ambient.ambientSuspensionCount == 0 && acquisitions == 2 && releases == 2, "Back and duplicate native cleanup release once")
        record("X09/X17 logical timer transfer")
        let timer=local(hub,.setup)
        expect(hub.timerActive(in:timer), "embedded logical presentation active")
        let cover=local(hub,parent:timer,kind:.modal)
        expect(hub.timerActive(in:timer), "same logical owner during cover transfer")
        facts(hub,.today,from:.setup,generation:8)
        expect(hub.timerActive(in:timer) && cover.context.active, "cover owns same timer across root change")
        var coverFact=hub.snapshot.scopes[cover.id]!;coverFact.alive=false;coverFact.modalExposed=false
        hub.native([coverFact],immediate:true)
        expect(!hub.timerActive(in:timer), "Close under another root leaves no hidden timer presentation")
        facts(hub,.setup,from:.today,generation:9)
        expect(hub.timerActive(in:timer), "return reactivates presentation only")
        hub.teardown();hub.flushFixtureEvents()
    }

    func media() {
        record("M01-M05/M08-M11 data identity separate from presentation")
        let data=LifeRouteMediaAdmission();let signature=["synthetic-client","icon label"]
        let request=data.begin(signature);let accepted=data.accept(request,signature:signature)!
        data.revokePresentation()
        expect(data.publish(accepted,signature:signature), "accepted result retained across visibility epoch")
        expect(!data.publish(accepted,signature:signature), "same accepted result committed once")
        let next=data.begin(signature);let result=data.accept(next,signature:signature)!
        data.update(["new-client","edited input"])
        expect(!data.publish(result,signature:["new-client","edited input"]), "stale client/input cannot replace newer artwork")
        let newer=data.begin(["new-client","edited input"])
        expect(!data.accepts(next,signature:["new-client","edited input"]), "old callback cannot own current request")
        expect(data.accepts(newer,signature:["new-client","edited input"]), "current request remains reusable")
        record("M06/M07/X10 permission intent and real scene distinction")
        let (hub,scope)=fresh();let intent=hub.intent(for:scope.id)!
        hub.scene(.inactive,immediate:true)
        expect(intent.isValid && !intent.isEligible, "system alert inactivity retains intent without showing hidden UI")
        hub.scene(.active,immediate:true)
        expect(intent.isEligible, "same eligible origin may finish permission flow")
        facts(hub,.today,from:.setup,generation:2);facts(hub,.setup,from:.today,generation:3)
        expect(!intent.isValid && !intent.isEligible, "committed departure permanently revokes permission intent")
        let backgroundIntent=hub.intent(for:scope.id)!
        hub.scene(.background,immediate:true);hub.scene(.active,immediate:true)
        expect(!backgroundIntent.isValid, "actual background invalidates pending permission")
        hub.teardown();hub.flushFixtureEvents()
    }

    func collisions() {
        record("X01/X02/X08 root scene pop collision and handle release")
        for sceneFirst in [false, true] {
            let (hub, scope) = fresh(); let handle = LifeRouteOwnedHandle()
            var count = 0; var releases = 0
            hub.connect(UUID(), scope: scope.id) { context in
                handle.reconcile(context.active, acquire: { count += 1; return UUID() }, release: { _ in
                    self.expect(handle.held == nil, "owned handle cleared before external release")
                    count -= 1; releases += 1
                })
            }
            hub.flushFixtureEvents(); expect(count == 1, "collision starts with one lease")
            if sceneFirst { hub.scene(.background, immediate: true) }
            facts(hub, .today, from: .setup, generation: 2)
            if !sceneFirst { hub.scene(.background, immediate: true) }
            var removed = hub.snapshot.scopes[scope.id]!; removed.alive = false; removed.locallyExposed = false
            hub.native([removed], immediate: true); hub.native([removed], immediate: true)
            hub.teardown()
            expect(count == 0 && releases == 1, "root scene pop and teardown release the held UUID once")
        }
        record("X03 pending modal versus actual presentation during partial motion")
        let (hub, origin) = fresh()
        facts(hub, .setup, generation: 2, motion: .dragging, fractions: [.setup:0.4, .resources:0.6])
        let pending = LifeRoutePresentationScope()
        pending.bind(owner: hub, root: .setup, parent: origin.id, kind: .modal); hub.flushFixtureEvents()
        expect(!pending.context.active && hub.snapshot.topModal == nil, "pending modal lifetime is not native exposure")
        var shown = hub.snapshot.scopes[pending.id]!
        shown.mounted = true; shown.windowed = true; shown.locallyExposed = true; shown.modalExposed = true; shown.nativeOrder = 1
        hub.native([shown], immediate: true)
        expect(pending.context.active && !origin.context.active, "actually accepted modal outranks partial root geometry")
        expect(AppSection.allCases.allSatisfy { !hub.snapshot.root($0).accessibility }, "actual modal excludes underlying root accessibility")
        facts(hub, .today, from: .setup, generation: 3)
        expect(pending.context.active, "same accepted modal survives committed departure")
        shown.alive = false; shown.modalExposed = false; shown.locallyExposed = false
        hub.native([shown], immediate: true)
        expect(hub.snapshot.root(.today).accessibility, "modal dismissal exposes latest selected root")
        hub.teardown()

        record("X12/X16 never-settled requests do not fabricate visits")
        let (requests, requestScope) = fresh()
        requests.requested(.resources, generation: 2); requests.requested(.tools, generation: 3)
        facts(requests, .tools, from: .setup, generation: 3)
        expect(requests.snapshot.departures[.setup] == 1, "one committed leave from delivered sequence")
        expect(requests.snapshot.departures[.resources, default: 0] == 0, "unsettled request is not a visit")
        expect(requestScope.context.alive, "requested sequence retains local lifetime")
        requests.teardown()

        record("X15 reentrant release queues new ingress without nested publication")
        let (reentrant, retained) = fresh(); let handle = LifeRouteOwnedHandle()
        var callbackDepth = 0; var maximumDepth = 0; var acquisitions = 0; var releases = 0; var returned = false
        reentrant.connect(UUID(), scope: retained.id) { context in
            callbackDepth += 1; maximumDepth = max(maximumDepth, callbackDepth)
            defer { callbackDepth -= 1 }
            handle.reconcile(context.active, acquire: { acquisitions += 1; return UUID() }, release: { _ in
                releases += 1
                self.expect(handle.held == nil, "reentrant release sees cleared old owner")
                if !returned {
                    returned = true
                    self.facts(reentrant, .setup, from: .today, generation: 3)
                }
            })
        }
        reentrant.flushFixtureEvents()
        let oldTicket = retained.feedbackTicket()!
        facts(reentrant, .today, from: .setup, generation: 2)
        expect(maximumDepth == 1, "external callback cannot recursively publish effects")
        expect(reentrant.snapshot.settled == .setup && acquisitions == 2 && releases == 1, "reentrant return reconciles in next transaction")
        expect(!oldTicket.isEligible && handle.held != nil, "old callback cannot reactivate or release fresh owner")
        reentrant.teardown()
        expect(releases == 2 && handle.held == nil, "terminal releases renewed owner once")
    }

    func reentrantAdmission() {
        for transport in ["consumer", "revision"] {
            for edge in ["root", "local", "inactive", "background", "terminal"] {
                record("S02 fresh grant during pending \(edge) revocation via \(transport)")
                let (hub, scope) = fresh()
                let oldTicket = scope.feedbackTicket()!
                let oldIntent = hub.intent(for: scope.id)!
                var entered = false; var depth = 0; var maximumDepth = 0
                var observedInactive = false; var observedReturn = false
                func callback() {
                    depth += 1; maximumDepth = max(maximumDepth, depth)
                    defer { depth -= 1 }
                    let context = hub.snapshot.context(scope.id)
                    if entered {
                        if !context.active { observedInactive = true }
                        if observedInactive && context.active { observedReturn = true }
                        return
                    }
                    entered = true
                    let revision = hub.snapshot.snapshotRevision
                    self.expect(context.active && hub.intent(for: scope.id) != nil, "callback starts in coherent active state")
                    switch edge {
                    case "root": self.facts(hub, .today, from: .setup, generation: 2, layout: 2)
                    case "local":
                        var hidden = hub.snapshot.scopes[scope.id]!
                        hidden.locallyExposed = false; hub.native([hidden], immediate: true)
                    case "inactive": hub.scene(.inactive, immediate: true)
                    case "background": hub.scene(.background, immediate: true)
                    default: hub.teardown()
                    }
                    self.expect(hub.snapshot.snapshotRevision == revision && hub.snapshot.context(scope.id).active,
                                "negative oracle runs before queued revocation is installed")
                    self.expect(scope.feedbackTicket() == nil && hub.intent(for: scope.id) == nil,
                                "pending revocation denies fresh ticket and intent")
                    self.expect(!oldTicket.isEligible, "ingress immediately invalidates the old feedback ticket")
                    if edge == "inactive" {
                        self.expect(oldIntent.isValid && !oldIntent.isEligible, "temporary system inactivity retains existing intent only")
                    } else {
                        self.expect(!oldIntent.isValid, "committed semantic departure invalidates existing intent")
                    }
                    switch edge {
                    case "root": self.facts(hub, .setup, from: .today, generation: 3, layout: 2)
                    case "local":
                        var visible = hub.snapshot.scopes[scope.id]!
                        visible.locallyExposed = true; hub.native([visible], immediate: true)
                    case "inactive", "background": hub.scene(.active, immediate: true)
                    default: break
                    }
                    self.expect(hub.snapshot.snapshotRevision == revision, "reentrant return remains queued")
                    self.expect(scope.feedbackTicket() == nil && hub.intent(for: scope.id) == nil,
                                "queued return cannot mint mixed-epoch grants from old active visibility")
                }
                var subscription: AnyCancellable?
                if transport == "consumer" {
                    hub.connect(UUID(), scope: scope.id) { _ in callback() }
                    hub.flushFixtureEvents()
                } else {
                    subscription = hub.revisions.sink { _ in callback() }
                    facts(hub, .setup, layout: 2)
                }
                expect(entered && maximumDepth == 1, "callback ingress is exercised without nested publication")
                expect(observedInactive, "queued inactive or terminal edge is delivered losslessly")
                expect(!oldTicket.isEligible, "old ticket never revives after coherent return")
                if edge != "terminal" {
                    expect(observedReturn && scope.context.active, "coherent return follows delivered revocation")
                    expect(scope.feedbackTicket()?.isEligible == true && hub.intent(for: scope.id)?.isEligible == true,
                           "fresh grants resume only from coherent active installed state")
                    expect(oldIntent.isValid == (edge == "inactive"), "existing permission inactivity policy is unchanged")
                } else {
                    expect(scope.feedbackTicket() == nil && hub.intent(for: scope.id) == nil, "terminal owner cannot grant again")
                }
                subscription?.cancel(); hub.teardown(); hub.flushFixtureEvents()
            }
        }
    }

    func notes() async {
        for sceneDeparture in [false,true] {
            record(sceneDeparture ? "N2-B/X07 inactive after race win" : "N2-B/X06 root departure after race win")
            let (hub,scope)=fresh();let generator=NoteEndpoint();let runtime=AISessionNoteRuntimeModel(generator:generator)
            runtime.presentationScope=scope;runtime.generatedNote="previous edited draft"
            hub.connect(UUID(),scope:scope.id) { runtime.reconcilePresentation($0) };hub.flushFixtureEvents()
            var observedWin=false
            let before=LifeRouteHaptics.successes
            let subscription=runtime.$diagnosticReceipt.sink { delivered in
                if delivered == "SN-DIAG-1 | no-events" {
                    observedWin=runtime.fixtureRaceFinished
                    self.expect(runtime.generatedNote == "previous edited draft", "race won before draft publication")
                    if sceneDeparture { hub.scene(.inactive,immediate:true);hub.scene(.active,immediate:true) }
                    else { self.facts(hub,.today,from:.setup,generation:2);self.facts(hub,.setup,from:.today,generation:3) }
                }
            }
            runtime.start(narrative:"Synthetic session facts.",writerCredential:"RBT",client:nil)
            await drainTasks { generator.waitingForResult }
            generator.resolve()
            await drainTasks { !runtime.isGenerating }
            expect(observedWin, "read-only race observation proves success-won ordering")
            expect(runtime.generatedNote == NoteEndpoint.result.draft, "N2 retains valid won result after leave")
            expect(runtime.completeness == .reviewRequired, "reviewRequired retained")
            expect(LifeRouteHaptics.successes == before, "hidden/obsolete success feedback suppressed without replay")
            expect(runtime.fixtureRequestID == nil && generator.requests == 1, "terminal reusable state and no return regeneration")
            subscription.cancel();hub.teardown();hub.flushFixtureEvents()
        }
        record("N2-A/N2-D cancellation before resolution preserves latest edit")
        let (hub,scope)=fresh();let generator=NoteEndpoint();let runtime=AISessionNoteRuntimeModel(generator:generator)
        runtime.presentationScope=scope;runtime.generatedNote="first edit"
        hub.connect(UUID(),scope:scope.id) { runtime.reconcilePresentation($0) };hub.flushFixtureEvents()
        runtime.start(narrative:"Synthetic facts.",writerCredential:"RBT",client:nil)
        await drainTasks { generator.waitingForResult }
        let request=runtime.fixtureRequestID
        facts(hub,.setup,generation:2,motion:.dragging,fractions:[.setup:0,.resources:1])
        facts(hub,.setup,generation:2)
        expect(runtime.isGenerating && runtime.fixtureRequestID == request, "partial zero cancelled drag does not cancel Note")
        runtime.generatedNote="later edited draft"
        facts(hub,.today,from:.setup,generation:3);hub.scene(.inactive,immediate:true)
        await drainTasks { !runtime.isGenerating }
        generator.resolve();await Task.yield()
        expect(runtime.generatedNote == "later edited draft", "cancel before result preserves latest bound draft")
        expect(runtime.state == .cancelled, "cancel reaches terminal state")
        hub.teardown();hub.flushFixtureEvents()
        record("N2-E availability cancellation readiness")
        let (availabilityHub,availabilityScope)=fresh();let delayed=NoteEndpoint();delayed.blockAvailability=true
        let availability=AISessionNoteRuntimeModel(generator:delayed);availability.presentationScope=availabilityScope
        availability.generatedNote="retained edit";availability.start(narrative:"Synthetic facts.",writerCredential:"RBT",client:nil)
        await drainTasks { delayed.waitingForAvailability }
        availability.cancel();availability.cancel()
        expect(availability.state == .cancelled && !availability.isGenerating && availability.fixtureRequestID == nil, "availability cancellation clears loading and request once")
        expect(availability.generatedNote == "retained edit", "availability cancel preserves draft")
        delayed.resolveAvailability();await Task.yield();delayed.blockAvailability=false
        availability.start(narrative:"Later synthetic request.",writerCredential:"RBT",client:nil)
        await drainTasks { delayed.waitingForResult };delayed.resolve()
        await drainTasks { !availability.isGenerating }
        expect(availability.generatedNote == NoteEndpoint.result.draft, "later user request succeeds")
        record("N2-C/N2-F published result and return")
        let published=availability.generatedNote;let feedback=LifeRouteHaptics.successes
        facts(availabilityHub,.today,from:.setup,generation:2);facts(availabilityHub,.setup,from:.today,generation:3)
        expect(availability.generatedNote == published && LifeRouteHaptics.successes == feedback, "published result retained; no replay on return")
        availabilityHub.teardown();availabilityHub.flushFixtureEvents()
    }

    func photoRetry() async {
        record("S04/S06 production selected-photo task and publication adapter")
        let (hub, scope) = fresh()
        let view = PhotoAdapterFixture(scope: scope)
        let photo = PhotosPickerItem(id: "synthetic-selected-photo")
        view.selectedPhotoItem = photo
        view.photoData = Data([9]); view.publications = 0
        let first = Task { await view.start() }
        await drainTasks { PhotoLoadEndpoint.shared.pending != nil }
        expect(view.loadedPhotoSelection == nil, "loading does not mark the item completed")
        PhotoLoadEndpoint.shared.finish(Data([1, 2, 3]))
        await first.value
        await drainTasks { ClientVisualThumbnailCache.shared.pending != nil }
        expect(view.loadedPhotoSelection == nil && view.photoData == Data([9]), "normalization keeps existing artwork and incomplete selection")
        let oldInput = view.media.inputRevision
        view.label = "Changed exact label"; view.clientCode = "synthetic-client-b"
        view.inputChanged()
        expect(view.media.inputRevision > oldInput, "client and label change advances semantic request identity")
        ClientVisualThumbnailCache.shared.finish()
        await drainTasks { ClientVisualThumbnailCache.shared.finished == 1 }
        // The continuation must finish the extracted publication adapter too.
        for _ in 0..<20 { await Task.yield() }
        expect(view.loadedPhotoSelection == nil && view.photoData == Data([9]) && view.publications == 0,
               "stale normalization cannot publish or strand the selected item")
        expect(view.selectedPhotoItem == photo, "retry retains the same current picker selection")
        let retry = Task { await view.start() }
        await drainTasks { PhotoLoadEndpoint.shared.pending != nil }
        expect(PhotoLoadEndpoint.shared.loads == 2, "same selected item remains eligible after rejection")
        PhotoLoadEndpoint.shared.finish(Data([4, 5, 6]))
        await retry.value
        await drainTasks { ClientVisualThumbnailCache.shared.pending != nil }
        // Accepted finite work may publish data while hidden; feedback cannot replay.
        facts(hub, .today, from: .setup, generation: 2)
        ClientVisualThumbnailCache.shared.finish()
        await drainTasks { view.loadedPhotoSelection != nil }
        expect(view.photoData == Data([4, 5, 6]) && view.publications == 1, "new identified normalization publishes exactly once")
        expect(view.loadedPhotoSelection == LifeRoutePhotoSelection(item: photo, client: "synthetic-client-b"),
               "only published result completes the correct item and client")
        expect(view.message == nil, "hidden accepted normalization emits no success presentation")
        facts(hub, .setup, from: .today, generation: 3)
        await view.start()
        expect(PhotoLoadEndpoint.shared.loads == 2 && view.publications == 1, "root return neither clears artwork nor reloads completed item")
        view.isGeneratedArtwork = true; view.label = "Later label edit"; view.inputChanged()
        await view.start()
        expect(view.isGeneratedArtwork && PhotoLoadEndpoint.shared.loads == 2, "later label editing preserves generated artwork")
        view.selectedPhotoItem = nil
        await view.start()
        expect(view.photoData == Data([4, 5, 6]) && view.publications == 1, "picker cancellation leaves accepted artwork intact")
        hub.teardown()
    }

    func run() async {
        reducers();localModalTheme();media();collisions();reentrantAdmission();await photoRetry();await notes()
        print("ROOT_VISIBILITY_TEST_PASS \(count) assertions; \(cases.count) scenario groups; actual production reducers/runtime/race; model and event transport are fixtures")
        fflush(stdout);exit(0)
    }
}

@MainActor private final class NoteEndpoint: SessionNoteGenerating {
    static let result=SessionNoteGenerationResult(draft:"A synthetic accepted note.",outcome:.generated,issueCodes:[])
    var blockAvailability=false
    var requests=0
    private var availabilityContinuation: CheckedContinuation<SessionNoteModelAvailability,Never>?
    private var resultContinuation: CheckedContinuation<SessionNoteGenerationResult,Error>?
    var waitingForAvailability: Bool { availabilityContinuation != nil }
    var waitingForResult: Bool { resultContinuation != nil }
    func availability() async -> SessionNoteModelAvailability {
        if blockAvailability { return await withCheckedContinuation { availabilityContinuation=$0 } }
        return .available
    }
    func resolveAvailability() { let continuation=availabilityContinuation;availabilityContinuation=nil;continuation?.resume(returning:.available) }
    func generateNote(narrative:String,writerRole:SessionNoteWriterRole,client:LifeRouteClientProfile?,progress:@escaping(SessionNoteGenerationProgress) async -> Void) async throws -> SessionNoteGenerationResult {
        requests += 1
        return try await withCheckedThrowingContinuation { resultContinuation=$0 }
    }
    func resolve() { let continuation=resultContinuation;resultContinuation=nil;continuation?.resume(returning:Self.result) }
}

@MainActor private final class VisibilityTestAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Visibility Fixture", sessionRole: session.role)
        configuration.delegateClass = VisibilityTestSceneDelegate.self
        return configuration
    }
}
@MainActor private final class VisibilityTestSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { preconditionFailure("Expected window scene") }
        let fixtureWindow = UIWindow(windowScene: windowScene)
        fixtureWindow.rootViewController = UIViewController()
        fixtureWindow.makeKeyAndVisible()
        window = fixtureWindow
        Task { @MainActor in await VisibilityFixture().run() }
    }
}
_ = UIApplicationMain(CommandLine.argc,CommandLine.unsafeArgv,nil,NSStringFromClass(VisibilityTestAppDelegate.self))


// State transport and asynchronous endpoints only. The selected-photo task,
// semantic checks and normalization publication below are source-extracted.
private struct PhotosPickerItem: Hashable {
    let id: String
    @MainActor func loadTransferable(type: Data.Type) async throws -> Data? {
        await PhotoLoadEndpoint.shared.load()
    }
}
@MainActor private final class PhotoLoadEndpoint {
    static let shared = PhotoLoadEndpoint()
    var loads = 0
    var pending: CheckedContinuation<Data?, Never>?
    func load() async -> Data? {
        loads += 1
        return await withCheckedContinuation { pending = $0 }
    }
    func finish(_ data: Data) { let next = pending; pending = nil; next?.resume(returning: data) }
}
private struct ClientVisualThumbnailRequest {
    let assetID: UUID
    let maximumPixelDimension: Int
}
@MainActor private final class ClientVisualThumbnailCache {
    static let shared = ClientVisualThumbnailCache()
    var pending: CheckedContinuation<UIImage?, Never>?
    var finished = 0
    func thumbnail(for request: ClientVisualThumbnailRequest, imageData: Data) async -> UIImage? {
        let image: UIImage? = await withCheckedContinuation { pending = $0 }
        finished += 1
        return image
    }
    func finish() { let next = pending; pending = nil; next?.resume(returning: nil) }
}
@MainActor private class PhotoAdapterState {
    enum InputMethod: String { case textOnly, photoLibrary }
    var inputMethod = InputMethod.textOnly
    let media = LifeRouteMediaAdmission()
    var loadedPhotoSelection: LifeRoutePhotoSelection?
    var visibilityScope: LifeRoutePresentationScope?
    var visibility: LifeRouteEffectContext { visibilityScope?.context ?? .inactive }
    var selectedPhotoItem: PhotosPickerItem?
    var clientCode = "synthetic-client-a"
    var label = "Initial exact label"
    var visualDescription = "Synthetic reference"
    var message: String?
    var referencePhotoData: Data?
    var referenceSourceImage: Image?
    var photoData: Data? { didSet { publications += 1 } }
    var publications = 0
    var isGeneratedArtwork = false
    var referencePreviewID = UUID()
    var photoPreviewID = UUID()
    init(scope: LifeRoutePresentationScope) { visibilityScope = scope }
}
