#!/usr/bin/env python3
"""Check fixed root ownership, router synchronization and ambient boundaries."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = (ROOT / "LifeRoute/V054ContentView.swift").read_text()
COORDINATOR = (ROOT / "LifeRoute/LifeRouteVisualActivityCoordinator.swift").read_text()
TIMER = (ROOT / "LifeRoute/ScenicRoyalVisualTimerView.swift").read_text()
NAVIGATION = (ROOT / "LifeRoute/AppNavigation.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Root-paging ambient suspension contract failed: {message}")


# These structural checks complement the executable production-controller harness.
# They do not claim native gesture, SwiftUI lifecycle, or physical acceptance.
pager = CONTENT.split("// BEGIN PERMANENT ROOT PAGER", 1)[1].split("// END PERMANENT ROOT PAGER", 1)[0]
require(CONTENT.count(".init(section: .") == 5, "five permanent root hosts")
require(r'roots.map(\.section) == AppSection.allCases' in pager, "fixed identity and order are checked")
require(pager.count("UIHostingController(rootView:") == 1, "only the constructor allocates hosts, once per fixed registration")
constructor = pager.split("    init(roots:", 1)[1].split("    required init?", 1)[0]
require("for root in roots" in constructor and "allocationCount += 1" in constructor, "five allocations occur in the fixed constructor loop")
require("addChild(host)" in constructor and "host.didMove(toParent: self)" in constructor, "permanent UIKit containment is balanced at installation")
require(pager.count("addChild(host)") == 1 and pager.count("removeFromParent()") == 1, "only installation and whole-pager teardown change parenthood")
require("func tearDown()" in pager and "host.willMove(toParent: nil)" in pager, "whole-pager teardown releases containment")
require(all(x not in pager for x in ["UICollectionView", "UITableView", "UIPageViewController", "UINavigationController(", ".rootView =", ".setItems("]), "no root recycling or navigation wrapping")
require("TabView(selection:" not in CONTENT and ".tabViewStyle(.page" not in CONTENT, "root page-cell ownership is removed")
require("scrollView.isPagingEnabled = true" in pager, "UIKit owns true touch-following movement")
require("scrollView.contentInsetAdjustmentBehavior = .never" in pager, "pager adds no second inset")
require("width: size.width * 5" in pager and "view.clipsToBounds = true" in pager, "the five-page strip stays inside one viewport")
update = pager.split("    func updateUIViewController",1)[1].split("    func sizeThatFits",1)[0]
require("UIHostingController(" not in update and "receiveEnvironment" in update, "environment updates do not replace hosts")
require("id == generation" in pager and "request.generation == requestGeneration" in pager, "obsolete transitions cannot overwrite a newer router request")
scroll = pager.split("    func scrollViewDidScroll",1)[1].split("    func scrollViewDidEndDragging",1)[0]
require("router.select" not in scroll and "@Published" not in scroll, "per-pixel progress remains in UIKit")
require("completeGesture(id)" in pager and "router.select(section)" in pager, "selection commits once at settling")
require("visualActivity.acquireForegroundInteraction()" in pager and "visualActivity.releaseAmbientSuspension(request)" in pager, "same coordinator and exact paging request")
require("environment.scenePhase != .active" in pager and "cancelInteraction()" in pager, "background interruption releases transient ownership")
require("settleDelayNanoseconds" not in CONTENT, "actual UIKit settling replaces the former time estimate")
require("host.view.accessibilityElementsHidden = !(settledInput && current.accessibility)" in pager, "root accessibility closes synchronously during motion")
require("override func hitTest" in pager and "hit.isDescendant(of: root)" in pager, "viewport admits new contacts only to the current root")
require("host.view.isUserInteractionEnabled =" not in pager, "input withdrawal cannot suspend and restore a retained responder")
require("if old != section { hosts[old]?.view.endEditing(true) }" in pager, "only committed departing roots end editing")
require("LifeRouteRootPagingToolbar(selection: $router.selectedSection)" in CONTENT, "existing modern toolbar remains router-owned")
require("ScenicRoyalToolbar(selection: $router.selectedSection)" in CONTENT, "existing legacy toolbar remains router-owned")
require(CONTENT.count(".safeAreaInset(edge: .bottom, spacing: 0)") == 2, "one reservation in each mutually exclusive OS shell")
require("private var rootToolbarBottomClearance: CGFloat" in CONTENT, "toolbar visual clearance is a dedicated root token")
require("ScenicRoyalDesignSystem.Layout.bottomToolbarClearance" in CONTENT, "the established toolbar visual-clearance token remains in use")
require("geometry.safeAreaInsets.bottom" not in CONTENT and "bottomSafeArea +" not in CONTENT, "physical bottom inset is not counted twice")
require(CONTENT.count("@StateObject private var router = AppRouter()") == 1, "AppRouter has one StateObject owner")
require(CONTENT.count("LifeRouteRootNavigationStack(path: $router.") == 5, "five original root stack builders remain")
require("let owner: LifeRouteOwningRoot" in pager and "values.lifeRouteOwningRoot = owner" in pager, "each root injects immutable destination ownership")
require("values.scenePhase = parent.scenePhase" in pager, "offscreen roots receive the real scene phase")
require("values.openURL = parent.openURL" in pager and "values.dismiss =" not in pager, "external actions relay while dismiss remains child-owned")

require("private var activeRequests = Set<UUID>()" in COORDINATOR, "shared coordinator remains reference counted")
require("func setThemeCenterVisible(_ isVisible: Bool)" in COORDINATOR, "Theme Center keeps the same suspension owner")
require("private var deepDestinationTokens: [UUID: AppSection] = [:]" in NAVIGATION, "deep destination visibility is tracked per root")
require("func beginDeepDestination(in section: AppSection) -> UUID" in NAVIGATION, "a deep destination acquires a unique presentation token")
require("func endDeepDestination(_ token: UUID)" in NAVIGATION, "a deep destination releases its exact presentation token")
require("deepDestinationTokens.values.contains(selectedSection)" in NAVIGATION, "the active root toolbar remains hidden while that root has a deep destination")
require("tokenRouter?.beginDeepDestination(in: scope.root)" in NAVIGATION, "deep tokens use the immutable presenting root even when a different root is selected")
require("router.setBottomToolbarSuppressed" not in CONTENT + NAVIGATION, "root selection cannot clear deep-page toolbar suppression")

require(".safeAreaInset(edge: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard)" in TIMER, "Visual Timer reserves navigation-safe top breathing room")
require("Color.clear.frame(height: 0)" in TIMER, "Visual Timer adds top safe-area reservation without a hard-coded navigation-bar height")
require(".toolbarBackground(.visible, for: .navigationBar)" in TIMER, "Visual Timer keeps system navigation material over scrolled deep-page content")

print("PASS: permanent-root structural contracts; native behavior requires production-controller and app qualification")

require("final class LifeRouteVisibilityOwner" in NAVIGATION and "snapshotRevision" in NAVIGATION, "one coherent revision owner")
require("localEpochs" in NAVIGATION and "sceneEpoch" in NAVIGATION and "terminalAdmission" in NAVIGATION, "semantic admission survives deferred notification")
require(".lifeRouteRootScope()" in CONTENT and "LifeRouteScopeModifier(kind: .destination)" in NAVIGATION, "root content and complete destinations have independent scopes")
require("navigation.viewControllers.contains" in NAVIGATION and "transitioning" in NAVIGATION, "actual native removal is distinct from appearance")
require("visibility.teardown()" in pager and pager.index("tornDown = true") < pager.index("host.willMove(toParent: nil)"), "terminal admission precedes host removal")
