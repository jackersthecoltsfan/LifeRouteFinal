from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPPER = ROOT / "LifeRoute" / "LegacyMigrationCore.swift"
STORE = ROOT / "LifeRoute" / "PersistenceCore.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
POLICY = ROOT / "LIFEROUTE_V0_5_0_CHECKPOINT_04C_MIGRATION_POLICY.md"
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


mapper = read(MAPPER)
store = read(STORE)
project = read(PROJECT)
policy = read(POLICY)
prepare = read(PREPARE)
workflow = read(WORKFLOW)

require("import Foundation" in mapper, "Legacy mapper uses native Foundation")
for forbidden in [
    "import WebKit",
    "WKWebView",
    "WKWebsiteDataStore",
    "localStorage",
    "MutationObserver",
    "setInterval",
    "LifeRouteWebView",
]:
    require(forbidden not in mapper, f"Legacy mapper does not reactivate runtime/storage reader: {forbidden}")

require("struct LegacyMigrationPayload" in mapper, "Legacy mapping produces an explicit native payload")
require("JSONSerialization.jsonObject(with: data)" in mapper and "return .empty" in mapper, "Malformed legacy JSON fails closed to an empty payload")
require('state["prefs"]' in mapper and 'state["events"]' in mapper and 'state["places"]' in mapper, "Mapper reads only the reviewed liferoute_v3 product buckets")
require("dedicatedHomeAddress" in mapper and "resolveHomeAddress" in mapper, "Dedicated legacy home key can be supplied without browser ownership")
require("source.isEmpty || source == \"manual\"" in mapper, "Only legacy manual calendar events map forward")
require("resolvedEnd > resolvedStart" in mapper, "Malformed timed appointments are rejected")
require('calendarTitle: legacyCalendarTitle' in mapper and 'source: .manual' in mapper, "Imported appointments are explicitly namespaced as manual legacy data")

for alias in [
    'raw["preferredActivities"] ?? raw["reinforcers"]',
    'raw["currentTargets"] ?? raw["targets"]',
    'raw["behaviorsOfConcern"] ?? raw["behaviors"]',
    'raw["communicationNotes"] ?? raw["fctNotes"]',
    'raw["promptingNotes"] ?? raw["reinforcementNotes"]',
    'raw["caregiverNotes"] ?? raw["settingNotes"]',
    'raw["clinicalNotes"] ?? raw["notes"]',
]:
    require(alias in mapper, f"Reviewed legacy client alias is supported: {alias}")

require("private static func normalizedPair" in mapper, "Legacy client-code normalization is pure and mapper-owned")
require("ClientProfileCore.normalizedPair" not in mapper, "Legacy parsing does not cross into main-actor client state")
require('deterministicUUID(namespace: "legacy-client"' in mapper, "Imported client IDs are deterministic")
require('deterministicUUID(namespace: "legacy-place"' in mapper, "Imported place IDs are deterministic")
require('let id = "legacy-v4-\\(stableSourceID)"' in mapper, "Imported manual event IDs are migration-namespaced and stable")
require("private static func placeIdentity" in mapper, "Saved-place dedupe uses normalized logical identity")
require("case \"gym\"" in mapper and "default: return .other" in mapper, "Legacy place types map through an explicit allow-list")
require("let part1 = String(hex.prefix(8))" in mapper and "let part5 = String(hex.dropFirst(20).prefix(12))" in mapper, "Deterministic UUID construction is split into compiler-safe subexpressions")
require("preconditionFailure(\"Deterministic legacy UUID construction failed\")" in mapper, "Deterministic UUID construction cannot silently fall back to a random ID")
require("?? UUID()" not in mapper, "Migration IDs have no random fallback")

require("static func mergeIntoNativeStore" in mapper, "Mapper has an explicit native merge entrypoint")
require("mergeIntoNativeStore(payload, store: .shared)" in mapper, "Main-actor shared-store lookup occurs inside the merge function body")
require("store: LifeRoutePersistenceStore = .shared" not in mapper, "Main-actor persistence singleton is not captured in a default argument")
require("guard !payload.isEmpty else { return }" in mapper, "Empty migration is a no-op")
require("existingCodes.insert(code).inserted" in mapper, "Existing native clients win on duplicate code")
require("identities.insert(identity).inserted" in mapper, "Existing native saved places win on duplicate logical identity")
require("let nativeHome" in mapper and "nativeHome.isEmpty ? payload.homeAddress : nativeHome" in mapper, "Existing native home wins over legacy home")
require("var ids = Set(events.map(\\.id))" in mapper and "ids.insert(event.id).inserted" in mapper, "Existing native manual events win on duplicate ID")
require("store.saveClients(existing)" in mapper, "Client merge writes through existing client persistence owner")
require("store.saveRoutingState" in mapper, "Routing merge writes through existing routing persistence owner")
require("store.saveManualCalendarEvents(events)" in mapper, "Calendar merge writes through existing manual-calendar persistence owner")

for quarantined in [
    "liferoute_visual_tools_v2",
    "firstIconId",
    "thenIconId",
    "boardSelection",
    "theme",
    "auth-gate",
    "googleAccessToken",
]:
    require(quarantined not in mapper, f"Quarantined legacy state is not mapped: {quarantined}")

require("LegacyMigrationCore.swift in Sources" in project, "Pure legacy mapper compiles in the active native target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView/runtime remains quarantined")
require("WKWebView" not in store and "WebKit" not in store, "Persistence owner remains WebKit-free")
require("never auto-import or auto-assign" in policy.lower(), "Policy explicitly forbids guessing client ownership for the old global visual library")
require("does not require the reader to run automatically at startup" in policy, "Policy keeps migration reader off startup-critical path")
require("audit_v0_5_0_legacy_migration.py" in prepare, "Preparation runs the 04C migration audit")
require("Audit checkpoint 04C legacy migration" in workflow, "iOS CI exposes the 04C migration audit")

if errors:
    print("LifeRoute v0.5.0 legacy migration audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 legacy migration audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
