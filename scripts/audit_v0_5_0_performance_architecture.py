from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "LifeRoute" / "PersistenceCore.swift"
TOOLS = ROOT / "LifeRoute" / "SessionToolsDomain.swift"
VIEWS = ROOT / "LifeRoute" / "SessionToolsViews.swift"
CALENDAR = ROOT / "LifeRoute" / "CalendarDomain.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
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


store = read(STORE)
tools = read(TOOLS)
views = read(VIEWS)
calendar = read(CALENDAR)
content = read(CONTENT)
project = read(PROJECT)
prepare = read(PREPARE)
workflow = read(WORKFLOW)

# Persistence: mutable state stays main-actor-owned, while serialization and I/O
# execute on one serial actor with explicit revision ordering and atomic writes.
require("@MainActor\nfinal class LifeRoutePersistenceStore" in store, "Persistence state retains one explicit main-actor owner")
writer = section(store, "private actor SnapshotWriter", "private let fileManager: FileManager")
persist = section(store, "private func persist()", "func flushPendingWrites()")
require("let encoder = JSONEncoder()" in writer and "encoder.encode(snapshot)" in writer, "Full snapshot encoding runs inside the serial writer actor")
require("JSONEncoder" not in persist and "data.write" not in persist, "Interaction-thread persist path performs no JSON encoding or disk write")
require("await previousTask?.value" in persist, "Rapid saves preserve request order")
require("latestWrittenRevision" in writer and "revision > latestWrittenRevision" in writer, "Stale write revisions cannot overwrite newer snapshots")
require("data.write(to: fileURL, options: [.atomic])" in writer, "Snapshot replacement remains atomic")
require("flushPendingWrites() async" in store and "phase != .active" in content, "Scene transitions request an ordered persistence flush")

visual_load = section(store, "func loadClientVisualSupports()", "func saveClientVisualSupports(")
routing_load = section(store, "func loadRoutingState()", "func saveRoutingState(")
calendar_load = section(store, "func loadManualCalendarEvents()", "func saveManualCalendarEvents(")
for name, body in [
    ("visual-support", visual_load),
    ("routing", routing_load),
    ("manual-calendar", calendar_load),
]:
    require("Self.sanitized" not in body, f"{name} reads do not rerun full-state sanitization")

icon_encoding = section(store, "private struct PersistedVisualIcon", "private struct PersistedChoiceBoard")
require("encodeIfPresent(resolvedImageFileName" in icon_encoding, "Snapshot JSON stores image references instead of unchanged image bytes")
require("encodeIfPresent(imageData" not in icon_encoding and "encode(imageData" not in icon_encoding, "Snapshot JSON encoder excludes large visual image blobs")
require('appendingPathComponent("VisualImages"' in store, "Visual image blobs use a dedicated protected native-data directory")
require("imageData.write(to: imageURL, options: [.atomic])" in writer, "New visual image blobs are written atomically")
require(writer.count("FileProtectionType.completeUntilFirstUserAuthentication") >= 2, "Snapshot and visual blobs retain sensitive-data file protection")
require("guard !fileManager.fileExists(atPath: imageURL.path)" in writer, "Unchanged immutable image blobs are not rewritten")
require("decodeIfPresent(Data.self, forKey: .imageData)" in icon_encoding, "Existing embedded-image snapshots remain backward compatible")

# Client/visual derived collections: lookups are rebuilt only on mutations and
# render-facing getters do not filter/sort/search the broad arrays.
require("clientIDByNormalizedCode" in store and "clientIndex(for:" in store, "Client-code resolution uses a stable lookup index")
require("iconsByClientID" in tools and "choiceBoardsByClientID" in tools and "schedulesByClientID" in tools, "Per-client visual collections are indexed")
require("iconsByID" in tools and "iconIDsByClientID" in tools, "Visual icon lookup and ownership validation are indexed")
for start, end, name in [
    ("func icons(for clientCode: String)", "func choiceBoards(for clientCode: String)", "icon list"),
    ("func choiceBoards(for clientCode: String)", "func schedules(for clientCode: String)", "choice-board list"),
    ("func schedules(for clientCode: String)", "@discardableResult\n    func addIcon", "schedule list"),
    ("func icon(id: UUID, for clientCode: String)", "func retainClients", "icon-by-ID"),
]:
    body = section(tools, start, end)
    require(".filter" not in body and ".sorted" not in body and ".first" not in body, f"Render-facing {name} lookup avoids broad array scans")
require(tools.count("rebuildVisualIndexes()") >= 9, "Visual indexes have explicit mutation-time invalidation")
require("guard changed else { return }" in tools, "Client reconciliation skips no-op observable writes")
require("func retainClients(_ clients: [LifeRouteClientProfile])" in tools, "Client reconciliation uses durable IDs without persistence timing coupling")

# Thumbnail decode/downsampling is actor-owned and cached; SwiftUI body only
# chooses between an already-decoded image and a deterministic placeholder.
thumbnail = section(views, "private struct ClientVisualIconThumbnail", "private struct VisualSupportPreviewCard")
require("private actor ClientVisualThumbnailCache" in views and "NSCache<NSString, UIImage>" in views, "Decoded thumbnails use a bounded actor-owned cache")
require("CGImageSourceCreateThumbnailAtIndex" in views and "kCGImageSourceThumbnailMaxPixelSize" in views, "Visual photos are downsampled to display scale")
require(".task(id: request)" in thumbnail and "await ClientVisualThumbnailCache.shared.thumbnail" in thumbnail, "Thumbnail work runs outside SwiftUI body evaluation")
require("UIImage(data:" not in thumbnail, "ClientVisualIconThumbnail performs no image decode in body")
require("UIImage(data:" not in views and "ClientVisualDraftPhotoPreview" in views, "Selected-photo previews also avoid synchronous body decoding")

# Calendar rendering consumes one mutation-maintained day index and one derived
# presentation value per parent render, instead of rescanning events per row.
require("eventIndicesByDay" in calendar and "eventCountsBySource" in calendar, "Calendar keeps explicit day/source indexes")
require("private func rebuildEventIndexes()" in calendar and calendar.count("rebuildEventIndexes()") >= 5, "Calendar indexes rebuild at each event mutation boundary")
events_on = section(calendar, "func events(on date: Date)", "func weekDates(")
require(".filter" not in events_on and "eventIndicesByDay" in events_on, "Day event lookup is index-backed")
require("func presentation(for range: LifeRouteCalendarRange)" in calendar, "Day/Week/Month share one derived presentation boundary")
require("let presentation = calendarState.presentation(for: selectedRange)" in content, "Schedule derives range work once per body pass")
calendar_view = section(content, "private struct CalendarEventsView", "private struct CalendarEventRow")
require("@ObservedObject" not in calendar_view and "events(on:" not in calendar_view, "Calendar row rendering consumes narrow immutable inputs without rescanning state")

for forbidden in ["WKWebView", "MutationObserver", "setInterval", "Timer.scheduledTimer", "NotificationCenter.default.addObserver"]:
    require(forbidden not in store + tools + calendar, f"Performance layer adds no quarantined observer/polling/runtime mechanism: {forbidden}")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")
require("audit_v0_5_0_performance_architecture.py" in prepare, "Preparation runs the Checkpoint 05A performance audit")
require("Audit checkpoint 05A performance architecture" in workflow, "iOS CI exposes Checkpoint 05A before Simulator compilation")

if errors:
    print("LifeRoute v0.5.0 performance-architecture audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 performance-architecture audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
