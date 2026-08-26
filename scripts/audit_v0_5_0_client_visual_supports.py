from __future__ import annotations

# Checkpoint 03F exact-head validation trigger: visual support ownership is client-specific.
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / "LifeRoute" / "SessionToolsDomain.swift"
VIEWS = ROOT / "LifeRoute" / "SessionToolsViews.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ios-ci.yml"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


domain = read(DOMAIN)
views = read(VIEWS)
project = read(PROJECT)
prepare = read(PREPARE)
workflow = read(WORKFLOW)

require("final class ClientVisualSupportCore: ObservableObject" in domain, "One native object owns visual-support state")
for model in ["ClientVisualIcon", "ClientChoiceBoard", "ClientVisualSchedule"]:
    require(f"struct {model}" in domain and "clientCode" in domain, f"{model} is client-owned")
require("func icons(for clientCode: String)" in domain, "Icon library is filtered by client code")
require("func choiceBoards(for clientCode: String)" in domain, "Choice boards are filtered by client code")
require("func schedules(for clientCode: String)" in domain, "Visual schedules are filtered by client code")
require("guard !code.isEmpty else { throw ClientVisualSupportError.missingClient }" in domain, "Visual creation requires a client")
require("requested.allSatisfy(allowed.contains)" in domain, "Choice boards reject cross-client icon references")
require("if let iconID = step.iconID, !allowed.contains(iconID)" in domain, "Visual schedules reject cross-client icon references")
require("func icon(id: UUID, for clientCode: String)" in domain, "Icon lookup requires client context")
for forbidden in ["UserDefaults", "localStorage", "WebKit", "WKWebView", "MutationObserver", "setInterval"]:
    require(forbidden not in domain, f"Visual-support domain avoids deferred/legacy dependency: {forbidden}")

require("@StateObject private var visualState = ClientVisualSupportCore()" in views, "Session Tools owns one visual-support state object")
require("Client Visual Supports" in views, "Session Tools exposes client visual supports")
require("ClientVisualSupportCenter" in views, "Native client visual-support center exists")
require("PhotosPicker" in views, "Icon maker can use an on-device selected photo")
require("visualState.addIcon(clientCode: clientCode" in views, "Icon creation writes the selected client code")
require("visualState.icons(for: clientCode)" in views, "Visual builders pull only from the selected client library")
require("visualState.saveChoiceBoard(clientCode: clientCode" in views, "Choice boards save to the selected client")
require("visualState.saveSchedule(clientCode: clientCode" in views, "Visual schedules save to the selected client")
require("ClientFirstThenVisualView" in views and "visualState.icon(id:" in views, "First / Then visual lookup is client-scoped")
require("Visual supports are client-specific and session-only until the persistence checkpoint." in views, "UI states client ownership and deferred persistence truthfully")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")
require("audit_v0_5_0_client_visual_supports.py" in prepare, "Preparation runs the visual-support audit")
require("Audit checkpoint 03F client visual supports" in workflow, "iOS CI exposes the 03F audit")

if errors:
    print("LifeRoute v0.5.0 client-visual-support audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 client-visual-support audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
