from __future__ import annotations

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
    require(f"struct {model}" in domain, f"{model} exists as a native value model")
require(domain.count("let clientID: UUID") >= 3, "Icons, boards, and schedules carry durable library UUID ownership")
require(domain.count("var clientCode: String") >= 3, "Visual models retain the editable ABA/general library code for display/context")
require("func icons(for clientCode: String)" in domain, "Icon library is requested in visual-library context")
require("func choiceBoards(for clientCode: String)" in domain, "Choice boards are requested in visual-library context")
require("func schedules(for clientCode: String)" in domain, "Visual schedules are requested in visual-library context")
require('static let generalClientCode = "GENERAL"' in domain, "A stable General visual library exists without a saved client")
require("clientID(forCode: code)" in domain, "Client-specific visual creation resolves ABA code to durable client identity")
require("visualOwner(for:" in domain, "Visual creation resolves either General or a saved client through one ownership boundary")
require("throw ClientVisualSupportError.missingClient" in domain, "Unknown non-General visual owners are rejected")
require("requested.allSatisfy(allowed.contains)" in domain, "Choice boards reject cross-library icon references")
require("if let iconID = step.iconID, !allowed.contains(iconID)" in domain, "Visual schedules reject cross-library icon references")
require("func icon(id: UUID, for clientCode: String)" in domain, "Icon lookup requires visual-library context")
require("guard let icon = iconsByID[id], icon.clientID == owner.id" in domain, "Icon lookup enforces same-library UUID ownership")
require("union([Self.generalClientID])" in domain, "Client cleanup preserves General visual data")
for forbidden in ["UserDefaults", "localStorage", "WebKit", "WKWebView", "MutationObserver", "setInterval"]:
    require(forbidden not in domain, f"Visual-support domain avoids legacy storage/runtime dependency: {forbidden}")

require("@StateObject private var visualState = ClientVisualSupportCore()" in views, "Session Tools owns one visual-support state object")
require(
    'title: "Visual Supports"' in views and "ClientVisualSupportCenter(visualState: visualState, clientState: clientState)" in views,
    "Session Tools exposes visual supports through the restored tool card",
)
require("ClientVisualSupportCenter" in views, "Native visual-support center exists")
require("ClientVisualSupportCore.generalDisplayName" in views, "Visual-support center exposes General even with zero client profiles")
require("PhotosPicker" in views, "Icon maker can use an on-device selected photo")
require("visualState.addIcon(clientCode: clientCode" in views, "Icon creation writes in the selected visual-library context")
require("visualState.icons(for: clientCode)" in views, "Visual builders pull only from the selected library")
require("visualState.saveChoiceBoard(clientCode: clientCode" in views, "Choice boards save to the selected library")
require("visualState.saveSchedule(clientCode: clientCode" in views, "Visual schedules save to the selected library")
require("ClientFirstThenVisualView" in views and "visualState.icon(id:" in views, "First / Then visual lookup is visual-library scoped")
require("General library or scoped to a specific client profile" in views, "UI states General and client-specific ownership truthfully")
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
