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
    require(forbidden not in combined, f"Session Tools avoid legacy/polling/modal dependency: {forbidden}")

require("final class VisualTimerCore: ObservableObject" in domain, "Visual timer has one explicit native state owner")
require("@Published private(set) var deadline: Date?" in domain, "Visual timer uses an absolute deadline")
require("func remainingSeconds(at now: Date = Date())" in domain, "Timer derives remaining time from the deadline")
require("TimelineView(.periodic(from: .now, by: 1))" in views, "Timer rendering uses system-driven one-second TimelineView ticks")
require("ProgressView(value: timer.progress" in views, "Visual timer exposes deterministic progress")
require("Alerts and haptics are intentionally deferred" in views, "Timer still defers notification and haptic delivery")

# v0.5.2 native audible timer feedback: audio follows the deadline-driven timer
# but never owns countdown accuracy or introduces a repeating Foundation timer.
require("import AVFoundation" in domain, "Timer audio uses native AVFoundation")
require("private final class VisualTimerToneEngine" in domain, "Timer audio has one explicit native engine owner")
require("AVAudioEngine()" in domain and "AVAudioPlayerNode()" in domain, "Timer pulses are synthesized locally without bundled/network audio")
require("audioPulseNanoseconds: UInt64 = 250_000_000" in domain, "Audible pulse cadence is exactly 0.25 seconds")
require("startFrequency = 220.0" in domain and "endFrequency = 1_320.0" in domain, "Rising timer tone spans 220 Hz to 1320 Hz")
require("pow(elapsedFraction, 1.18)" in domain and "pow(Self.endFrequency / Self.startFrequency, eased)" in domain, "Timer pitch rises smoothly and exponentially with elapsed progress")
require("completionBuffer()" in domain and "(0.25, 1_430)" in domain, "Timer has a distinct synthesized three-tone completion chime")
require("private var audioTask: Task<Void, Never>?" in domain and "audioTask?.cancel()" in domain, "Quarter-second audio work has an explicit cancellable owner")
require("stopAudioLoop()" in domain and "toneEngine.stop()" in domain, "Pause/reset paths can stop timer audio promptly")
require("setCategory(.ambient" in domain and ".mixWithOthers" in domain, "Timer audio respects iOS ambient-audio behavior and mixes with other audio")

require("struct QuickSessionNote: Identifiable, Hashable" in domain, "Quick notes use a plain native value model")
require("func addNote(text: String, clientCode: String?)" in domain, "Quick-note mutation has one owner")
require("QuickSessionNotesView" in views and "Picker(\"Client\"" in views, "Quick notes can link to an ABA client code")
require("Button(\"Delete note\", role: .destructive)" in views, "Quick note deletion uses a semantic native action")

require("ClientFirstThenVisualView" in views, "First/Then tool remains native after client-visual upgrade")
require("TextField(\"First activity\"" in views and "TextField(\"Then activity\"" in views, "First/Then preserves native text input")
require("Button(\"Swap First / Then\")" in views, "First/Then swap remains a semantic native button")
require("visualState.icons(for: selectedClientCode)" in views, "First/Then visual choices are client-scoped")

require("SessionPlanSnapshot" in domain and "func buildPlan(" in domain, "Session plan organizer has deterministic owned state")
require("supervisor-approved target" in domain.lower() or "supervisor-approved target" in views.lower(), "Session plan is constrained to supervisor-approved targets")
require("only organizes information you enter or load from the client profile" in views, "Session plan does not invent clinical procedures")
require("Load saved client profile" in views and "client.currentTargets" in views and "client.preferredActivities" in views, "Session plan can reuse reviewed client context")
require("AI" not in domain, "Session Tools domain has no AI dependency")

require("@StateObject private var toolsState = SessionToolsCore()" in content, "Root app owns one SessionToolsCore")
require("SessionToolsNativeView(router: router, toolsState: toolsState, clientState: clientState)" in content, "Tools receive owned tool/client state explicitly")
require("NavigationLink(value: SessionToolRoute." in views and ".navigationDestination(for: SessionToolRoute.self)" in views, "Tools use typed native navigation inside the existing Tools stack")
require("NavigationStack" not in views, "Tools do not create a competing NavigationStack")
require("Scratch note saved for this app session." in views, "Scratch-note UI remains truthful about its intentionally ephemeral state")
require("Visual supports are client-specific and saved locally on this iPhone." in views, "Visual-support UI reflects the native persistence upgrade")
require("SessionToolsDomain.swift in Sources" in project and "SessionToolsViews.swift in Sources" in project, "Session Tools files compile in the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 Session Tools core audit FAILED")
    for error in errors: print(f"- FAIL: {error}")
    raise SystemExit(1)
print(f"LifeRoute v0.5.0 Session Tools core audit passed ({len(checks)} checks).")
for check in checks: print(f"- OK: {check}")
