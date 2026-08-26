from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "LifeRoute" / "PersistenceCore.swift"
CLIENT = ROOT / "LifeRoute" / "ClientProfileDomain.swift"
TOOLS = ROOT / "LifeRoute" / "SessionToolsDomain.swift"
VIEWS = ROOT / "LifeRoute" / "SessionToolsViews.swift"
CLIENT_VIEWS = ROOT / "LifeRoute" / "ClientViews.swift"
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


store = read(STORE)
client = read(CLIENT)
tools = read(TOOLS)
views = read(VIEWS)
client_views = read(CLIENT_VIEWS)
project = read(PROJECT)
prepare = read(PREPARE)
workflow = read(WORKFLOW)

require("final class LifeRoutePersistenceStore" in store and "static let shared" in store, "Native persistence has one explicit store owner")
require(".applicationSupportDirectory" in store and "native-state-v1.json" in store, "Persistent state uses a versioned Application Support file")
require("schemaVersion" in store and "decodeIfPresent" in store, "Persistence format is versioned and tolerant of missing fields")
require("FileProtectionType.completeUntilFirstUserAuthentication" in store, "Native client data uses iOS file protection")
require("data.write(to: fileURL, options: [.atomic])" in store, "Native state writes atomically")
require("native-state-v1-corrupt-" in store and "moveItem(at: url, to: backupURL)" in store, "Malformed state is preserved before safe-default recovery")
for forbidden in ["WebKit", "WKWebView", "localStorage", "UserDefaults", "@AppStorage"]:
    require(forbidden not in store, f"Persistence does not reactivate legacy/browser storage: {forbidden}")
require("CalendarProviderCore" not in store and "providerState" not in store, "Provider connection/cache objects remain excluded from native user-data persistence")

require("clients: [LifeRouteClientProfile]" in store, "Client profiles are part of the native snapshot")
require("imageData: Data?" in store, "Client visual photo data is included in the protected native snapshot")
require(store.count("var clientID: UUID") >= 3, "Persisted icons, boards, and schedules use durable client UUID ownership")
require("func clientID(forCode code: String) -> UUID?" in store, "Displayed ABA client code resolves to durable client identity")
require("let codeByClientID = Dictionary" in store and "codeByClientID[icon.clientID]" in store, "Persisted visual records survive client-code edits by reconciling through client UUID")
require("iconOwner[$0] == board.clientID" in store, "Persisted choice-board references are revalidated against same-client UUID ownership")
require("iconOwner[iconID] == schedule.clientID" in store, "Persisted schedule icon references are revalidated against same-client UUID ownership")
require("guard let currentCode = codeByClientID[icon.clientID]" in store, "Deleting a client automatically prunes that client’s persisted icons")
require("guard let currentCode = codeByClientID[board.clientID]" in store, "Deleting a client automatically prunes that client’s persisted choice boards")
require("guard let currentCode = codeByClientID[schedule.clientID]" in store, "Deleting a client automatically prunes that client’s persisted schedules")

require("LifeRoutePersistenceStore.shared.loadClients()" in client, "Client core restores native client profiles at initialization")
require(client.count("LifeRoutePersistenceStore.shared.saveClients(clients)") >= 2, "Client save and removal both update native persistence")
require("let clientID: UUID" in tools and "var clientCode: String" in tools, "In-memory visual models separate durable client identity from editable display code")
require("LifeRoutePersistenceStore.shared.loadClientVisualSupports()" in tools, "Visual-support core restores persisted client libraries")
require("persistVisualSupports()" in tools and "saveClientVisualSupports(" in tools, "Visual-support mutations write through the native persistence store")
require("func retainClientCodes(_ clientCodes: Set<String>)" in tools, "Visual-support core can reconcile client edits and purge orphaned client libraries")
require(".onReceive(clientState.$clients)" in views and "retainClientCodes" in views, "Client-list changes actively reconcile visual ownership")

require("Client profiles are saved locally in protected LifeRoute app data on this iPhone." in client_views, "Client UI states durable protected storage truthfully")
require("Visual supports are client-specific and saved locally on this iPhone." in views, "Session Tools states durable client-specific visual storage truthfully")
require("session-only until the persistence checkpoint" not in views + client_views, "Superseded session-only persistence copy is removed")
require("PersistenceCore.swift in Sources" in project, "Native persistence store compiles in the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")
require("audit_v0_5_0_client_visual_persistence.py" in prepare, "Preparation runs the 04A persistence audit")
require("Audit checkpoint 04A client visual persistence" in workflow, "iOS CI exposes the 04A persistence audit")

if errors:
    print("LifeRoute v0.5.0 client/visual persistence audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 client/visual persistence audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
