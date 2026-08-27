from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_NAVIGATION = ROOT / "LifeRoute" / "AppNavigation.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PERSISTENCE = ROOT / "LifeRoute" / "PersistenceCore.swift"
CALENDAR = ROOT / "LifeRoute" / "CalendarDomain.swift"
PROVIDERS = ROOT / "LifeRoute" / "CalendarProviderCore.swift"
ROUTING = ROOT / "LifeRoute" / "RoutingLocationDomain.swift"
SESSION_VIEWS = ROOT / "LifeRoute" / "SessionToolsViews.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ios-ci.yml"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


def section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        errors.append(f"Could not find source section start: {start}")
        return ""
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        errors.append(f"Could not find source section end after {start}: {end}")
        return ""
    return text[start_index:end_index]


navigation = read(APP_NAVIGATION)
content = read(CONTENT)
persistence = read(PERSISTENCE)
calendar = read(CALENDAR)
providers = read(PROVIDERS)
routing = read(ROUTING)
session_views = read(SESSION_VIEWS)
project = read(PROJECT)
prepare = read(PREPARE)
workflow = read(WORKFLOW)

# Root ownership and lifecycle work remain explicit and bounded. ContentView
# delegates to domain-owned operations instead of creating fire-and-forget tasks.
require(navigation.count("final class AppRouter: ObservableObject") == 1, "Exactly one native navigation owner type is defined")
require(content.count("@StateObject private var router = AppRouter()") == 1, "The root owns exactly one AppRouter instance")
require("final class AppLifecycleCore: ObservableObject" in navigation, "Scene-transition work has an explicit lifecycle owner")
require("private var persistenceFlushTask: Task<Void, Never>?" in navigation, "Lifecycle persistence flush has one retained task handle")
require("guard persistenceFlushTask == nil else { return }" in navigation, "Repeated scene transitions cannot duplicate persistence flush tasks")
require("Task {" not in content, "ContentView creates no unowned fire-and-forget Task")

scene_change = section(content, ".onChange(of: scenePhase)", "private struct CoreHeader")
for call, label in [
    ("lifecycleState.flushPersistenceForSceneTransition()", "ordered persistence flush"),
    ("routingState.cancelPendingOperations()", "routing/location cancellation"),
]:
    require(call in scene_change, f"Inactive/background transitions request {label}")
require("if phase == .background" in scene_change, "Cancellable routing work stops only on a true background transition")
require("providerState.cancelPendingOperations()" not in scene_change, "System calendar permission/auth flows survive transient inactive scene phases")

flush = section(persistence, "func flushPendingWrites() async", "private static func sanitized(")
require("while true" in flush and "let revisionAtStart = persistenceRevision" in flush, "Persistence flush tracks the revision it started with")
require("await persistenceTask?.value" in flush and "revisionAtStart != persistenceRevision" in flush, "Persistence flush also awaits writes queued during the first await")

# Provider refreshes are single-flight, cancellation-aware, and generation
# checked. Cached provider events are published only after a successful current
# operation; failure and disconnect paths do not replace the calendar cache.
require("private var appleRefreshTask: Task<Void, Never>?" in providers, "Apple refresh has one retained task owner")
require("private var googleRefreshTask: Task<Void, Never>?" in providers, "Google refresh has one retained task owner")
require("guard appleRefreshTask == nil else { return }" in providers, "Apple refresh is single-flight")
require("guard googleRefreshTask == nil else { return }" in providers, "Google refresh is single-flight")
require(providers.count("validateGoogleOperation(generation)") >= 7, "Google async boundaries validate cancellation/generation before mutation")
require("withTaskCancellationHandler" in providers and "googleAuthSession?.cancel()" in providers, "Google web authentication has an explicit cancellation path")

disconnect = section(providers, "func disconnectGoogle()", "func presentationAnchor")
for token, label in [
    ("googleOperationGeneration &+= 1", "invalidates stale completions"),
    ("googleRefreshTask?.cancel()", "cancels refresh work"),
    ("googleAuthSession?.cancel()", "cancels interactive authentication"),
    ("deleteGoogleRefreshToken()", "removes the persisted credential"),
]:
    require(token in disconnect, f"Google disconnect {label}")

google_entry = section(providers, "func connectOrRefreshGoogle(", "private func performGoogleRefresh")
google_operation = section(providers, "private func performGoogleRefresh", "func disconnectGoogle()")
require("if let events { onEvents(events) }" in google_entry, "Only a successful current provider result is published")
require("onEvents" not in google_operation, "Provider error/cancellation paths cannot replace cached events")
require(providers.count("request.timeoutInterval = 30") >= 2, "Google token and API requests have finite network timeouts")
require("seenPageTokens" in providers and "pageCount <= 100" in providers, "Google pagination rejects cycles and excessive page counts")

provider_replace = section(calendar, "func replaceProviderEvents", "func removeProviderEvents")
provider_remove = section(calendar, "func removeProviderEvents", "func eventCount")
for body, label in [(provider_replace, "replacement"), (provider_remove, "removal")]:
    require("guard nextEvents != events else { return }" in body, f"Provider {label} skips no-op observable writes")
    require(body.count("events = nextEvents") == 1, f"Provider {label} publishes one coherent event-array mutation")

# Routing, Maps, and Core Location reject duplicate work and stale completions.
require("private var routeTasks: [UUID: Task<Void, Never>]" in routing, "Each saved-place route has one retained task owner")
require("private var mapsOpenTask: Task<Void, Never>?" in routing, "Apple Maps resolution has one retained task owner")
require("guard routeTasks[place.id] == nil" in routing, "Duplicate route requests for one place are rejected")
require("guard mapsOpenTask == nil" in routing, "Duplicate Apple Maps opens are rejected")
require(routing.count("try validateRouteOperation") >= 3, "Route mutations validate current ownership after every async boundary")
require("try validateMapsOpen(placeID: place.id, generation: generation)" in routing, "Apple Maps validates ownership after destination lookup")
require("cancelRouteOperation(for: id)" in routing, "Deleting a place cancels its route operation before removal")

routing_cancel = section(routing, "func cancelPendingOperations()", "private func performRouteCalculation")
for token, label in [
    ("for task in routeTasks.values { task.cancel() }", "all route tasks"),
    ("mapsOpenTask?.cancel()", "Maps lookup"),
    ("locationRequestPendingAuthorization = false", "pending permission continuation"),
    ("locationRequestInFlight = false", "location request state"),
]:
    require(token in routing_cancel, f"Lifecycle cancellation clears {label}")

authorization = section(routing, "func locationManagerDidChangeAuthorization", "func locationManager(_ manager: CLLocationManager, didUpdateLocations")
require("let shouldRequestLocation = locationRequestPendingAuthorization" in authorization, "Authorization callbacks request a location only after an explicit user request")
require("if shouldRequestLocation" in authorization, "Authorization changes cannot trigger startup location work")
require(routing.count("guard locationRequestInFlight else { return }") >= 2, "Stale Core Location success/failure callbacks are ignored")

require("routingState.calculateRoute(to: place, mode: routeMode)" in content and "Task { await routingState.calculateRoute" not in content, "Route buttons call the domain-owned operation directly")
require("routingState.openInAppleMaps(place, mode: routeMode)" in content and "Task { await routingState.openInAppleMaps" not in content, "Maps buttons call the domain-owned operation directly")
require(
    "routeBusy: routingState.routeRequestsInFlight.contains(place.id)" in content and ".disabled(routeBusy)" in content,
    "Route controls expose single-flight state",
)
require(
    "mapsBusy: routingState.mapsOpenInFlight" in content and ".disabled(mapsBusy)" in content,
    "Maps controls expose single-flight state",
)
require(content.count(".disabled(routingState.locationRequestInFlight)") >= 2, "Location controls expose single-flight state")

# Photo selection uses SwiftUI task identity for automatic cancellation and
# checks identity again before publishing decoded input data.
photo_loading = section(session_views, ".task(id: selectedPhotoItem)", "private func saveIcon")
require("loadTransferable(type: Data.self)" in photo_loading, "Selected-photo loading runs in an identity-owned SwiftUI task")
require("guard !Task.isCancelled" in photo_loading and "selectedPhotoItem == self.selectedPhotoItem" in photo_loading, "Stale photo-load completions cannot replace newer selection state")
require(".onChange(of: selectedPhotoItem)" not in session_views, "Photo selection no longer launches unowned onChange tasks")

# The active target stays native and avoids the known classes of global input,
# observer, polling, and legacy-runtime regressions.
active_sources = navigation + content + persistence + calendar + providers + routing + session_views
for forbidden in [
    "WKWebView",
    "WKScriptMessage",
    "MutationObserver",
    "setInterval",
    "Timer.scheduledTimer",
    "NotificationCenter.default.addObserver",
    "touchesBegan(",
    "sendEvent(",
]:
    require(forbidden not in active_sources, f"Stability layer avoids quarantined/global runtime mechanism: {forbidden}")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView and JavaScript resources remain outside the active target")
require("audit_v0_5_0_stability_architecture.py" in prepare, "Preparation runs the Checkpoint 06 stability audit")
require("Audit checkpoint 06 stability architecture" in workflow, "iOS CI exposes Checkpoint 06 before Simulator compilation")

if errors:
    print("LifeRoute v0.5.0 stability-architecture audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 stability-architecture audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
