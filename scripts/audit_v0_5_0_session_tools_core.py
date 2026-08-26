from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / "LifeRoute" / "SessionToolsDomain.swift"
VIEWS = ROOT / "LifeRoute" / "SessionToolsViews.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

errors: list[str] = []
checks: list[str] = []

def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)

def read(path: Path) -> str:
    try: return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""

domain = read(DOMAIN)
views = read(VIEWS)
content = read(CONTENT)
project = read(PROJECT)
combined = domain + "\n" + views

for forbidden in ["WebKit", "WKWebView", "JavaScript", "MutationObserver", "localStorage", "UserDefaults", "@AppStorage", "Timer.scheduledTimer", "DispatchSourceTimer", "setInterval", ".sheet("]:
    require(forbidden not in combined, f"Session Tools avoid legacy/persistence/polling/modal dependency: {forbidden}")

require("final class VisualTimerCore: ObservableObject" in domain, "Visual timer has one explicit native state owner")
require("@Published private(set) var deadline: Date?" in domain, "Visual timer uses an absolute deadline")
require("func remainingSeconds(at now: Date = Date())" in domain, "Timer derives remaining time from the deadline")
require("TimelineView(.periodic(from: .now, by: 1))" in views, "Timer rendering uses system-driven one-second TimelineView ticks")
require("ProgressView(value: timer.progress" in views, "Visual timer exposes deterministic progress")
require("Alerts and haptics are intentionally deferred" in views, "Timer core does not smuggle cosmetic feedback into interaction delivery")

require("struct QuickSessionNote: Identifiable, Hashable" in domain, "Quick notes use a plain native value model")
require("func addNote(text: String, clientCode: String?)" in domain, "Quick-note mutation has one owner")
require("QuickSessionNotesView" in views and "Picker(\"Client\"" in views, "Quick notes can link to an ABA client code")
require("Button(\"Delete note\", role: .destructive)" in views, "Quick note deletion uses a semantic native action")

require("FirstThenNativeView" in views, "Text First/Then tool exists natively")
require("TextField(\"First activity\"" in views and "TextField(\"Then activity\"" in views, "First/Then uses native text input")
require("Button(\"Swap\")" in views, "First/Then swap is a semantic native button")

require("SessionPlanSnapshot" in domain and "func buildPlan(" in domain, "Session plan organizer has deterministic owned state")
require("supervisor-approved target" in domain.lower() or "supervisor-approved target" in views.lower(), "Session plan is constrained to supervisor-approved targets")
require("only organizes information you enter or load from the client profile" in views, "Session plan does not invent clinical procedures")
require("Load saved client profile" in views and "client.currentTargets" in views and "client.preferredActivities" in views, "Session plan can reuse reviewed client context")
require("AI" not in domain, "Session Tools domain has no AI dependency")

require("@StateObject private var toolsState = SessionToolsCore()" in content, "Root app owns one SessionToolsCore")
require("SessionToolsNativeView(router: router, toolsState: toolsState, clientState: clientState)" in content, "Tools receive owned tool/client state explicitly")
require("NavigationLink(value: SessionToolRoute." in views and ".navigationDestination(for: SessionToolRoute.self)" in views, "Tools use typed native navigation inside the existing Tools stack")
require("NavigationStack" not in views, "Tools do not create a competing NavigationStack")
require("Scratch notes and plans are session-only until the persistence checkpoint." in views, "Tools UI is truthful about in-memory state")
require("SessionToolsDomain.swift in Sources" in project and "SessionToolsViews.swift in Sources" in project, "Session Tools files compile in the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 Session Tools core audit FAILED")
    for error in errors: print(f"- FAIL: {error}")
    raise SystemExit(1)
print(f"LifeRoute v0.5.0 Session Tools core audit passed ({len(checks)} checks).")
for check in checks: print(f"- OK: {check}")
