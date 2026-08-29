from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / "LifeRoute" / "ClientProfileDomain.swift"
VIEWS = ROOT / "LifeRoute" / "ClientViews.swift"
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

for forbidden in ["WebKit", "WKWebView", "JavaScript", "localStorage", "UserDefaults", "@AppStorage", "NotificationCenter", "Timer("]:
    require(forbidden not in domain + views, f"Client core avoids legacy/runtime dependency: {forbidden}")
require("struct LifeRouteClientProfile: Identifiable, Codable, Hashable" in domain, "Client profile is a plain value model")
require("var code: String { first2 + last2 }" in domain, "Client code derives from two first + two last initials")
require("final class ClientProfileCore: ObservableObject" in domain, "One native owner manages client profiles")
require("@Published private(set) var clients" in domain, "Client mutations remain owned by ClientProfileCore")
require("static func normalizedPair" in domain and "prefix(2)" in domain, "Initial pairs are normalized to two letters")
require("case .invalidInitials" in domain and "duplicateCode" in domain, "Invalid/duplicate client codes are rejected")
for field in ["preferredActivities", "currentTargets", "behaviorsOfConcern", "communicationNotes", "promptingNotes", "caregiverNotes", "clinicalNotes", "address"]:
    require(field in domain, f"Useful client field retained: {field}")
require("func saveProfile(" in domain and "func removeClient" in domain, "Client add/edit/remove ownership is explicit")
require("@StateObject private var clientState = ClientProfileCore()" in content, "Root app owns one client state")
require("ClientProfilesView(clientState: clientState)" in content, "Setup opens native client management")
require("Full names are not required." in views, "Client UI preserves ABA-style privacy-first initials workflow")
require("NavigationLink" in views and "ClientEditorView" in views, "Client add/edit uses native navigation")
require("Button(\"Remove\", role: .destructive)" in views, "Client removal uses a semantic native button")
require("TextEditor(text: $preferredActivities)" in views and "TextEditor(text: $currentTargets)" in views, "Long-form session fields accept native text input")
require("Client profiles are saved locally in protected LifeRoute app data on this iPhone." in views, "Client UI states the current native persistence behavior truthfully")
require("ClientProfileDomain.swift in Sources" in project and "ClientViews.swift in Sources" in project, "Client core files compile in the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 clients-core audit FAILED")
    for error in errors: print(f"- FAIL: {error}")
    raise SystemExit(1)
print(f"LifeRoute v0.5.0 clients-core audit passed ({len(checks)} checks).")
for check in checks: print(f"- OK: {check}")
