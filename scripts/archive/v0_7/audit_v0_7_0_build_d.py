#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

dashboard = (ROOT / "LifeRoute/V054ToolsDashboard.swift").read_text(encoding="utf-8")
clinical = (ROOT / "LifeRoute/AIClinicalToolsViews.swift").read_text(encoding="utf-8")
session = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
intelligence = (ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift").read_text(encoding="utf-8")
shell = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
prepare = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
patch = (ROOT / "scripts/patch_v0_7_0_build_d.py").read_text(encoding="utf-8")

checks = {
    "Build D dashboard marker materialized": "v0.7.0 Build D Tools/ABA" in dashboard,
    "Build D clinical marker materialized": "v0.7.0 Build D clinical presentation" in clinical,
    "Build D timer marker materialized": "v0.7.0 Build D timer presentation" in session,
    "Tools remains the active native tab": "V054ToolsDashboard(" in shell,
    "Five-tab shell remains intact": shell.count("NavigationStack(path: $router.") == 5,
    "Tools has compact top header": 'Text("Tools")' in dashboard and 'Text("ABA workflow, ready when you are.")' in dashboard,
    "Tools uses shared v0.7 section labels": 'LifeRouteSectionLabel(title: "Clinical")' in dashboard and 'LifeRouteSectionLabel(title: "In Session")' in dashboard,
    "Tools gives Session Note primary clinical placement": "AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)" in dashboard and 'title: "Session Note"' in dashboard,
    "Tools gives Session Plan primary clinical placement": "AISessionPlanBuilderView(clientState: clientState)" in dashboard and 'title: "Session Plan"' in dashboard,
    "Tools preserves Visual Timer": "VisualTimerView(timer: toolsState.timer)" in dashboard,
    "Tools preserves Quick Notes": "QuickSessionNotesView(toolsState: toolsState, clientState: clientState)" in dashboard,
    "Tools preserves First Then": "ClientFirstThenVisualView(visualState: visualState, clientState: clientState)" in dashboard,
    "Tools preserves Visual Supports": "VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)" in dashboard,
    "Tools retains Setup client-management handoff": "router.select(.setup)" in dashboard,
    "Tools grid responds to accessibility Dynamic Type": "dynamicTypeSize.isAccessibilitySize" in dashboard and "sessionColumns" in dashboard,
    "Session Note retains optional General mode": 'Text("General / no client").tag("")' in clinical,
    "Session Note retains selected client lookup": "clientState.client(code: selectedClientCode)" in clinical,
    "Session Note retains scratch-note import": "matchingScratchNotes" in clinical and "appendToNarrative" in clinical,
    "Session Note retains optional screenshot input": "PhotosPicker(selection: $selectedPhotoItem, matching: .images)" in clinical,
    "Session Note retains local screenshot transfer task": ".task(id: selectedPhotoItem)" in clinical and "loadTransferable(type: Data.self)" in clinical,
    "Session Note retains AI generation entrypoint": "LifeRouteIntelligenceCore.generateABASessionNote(" in clinical,
    "Session Note remains reviewable": 'Text("Editable draft")' in clinical and "TextEditor(text: $generatedNote)" in clinical,
    "Session Note retains Copy": "UIPasteboard.general.string = generatedNote" in clinical,
    "Session Note retains regenerate action": 'Label("Regenerate from current facts", systemImage: "arrow.clockwise")' in clinical,
    "Session Note retains review warning": "Review every sentence before using a generated draft" in clinical,
    "Session Note visual contract states supplied facts only": "SUPPLIED FACTS ONLY" in clinical,
    "Session Plan retains approved-target requirement": "SessionToolsCore.list(from: targetsText).isEmpty" in clinical,
    "Session Plan retains client context loading": "loadClientContext()" in clinical,
    "Session Plan retains AI generation": "generatedPlan" in clinical and "Build session plan with AI" in clinical,
    "Session Plan retains treatment-boundary copy": "does not create new treatment targets" in clinical,
    "Intelligence context-window hotfix remains present": "context" in intelligence.lower() and "generateABASessionNote" in intelligence,
    "Timer still uses deadline-driven TimelineView": "TimelineView(.periodic(from: .now, by: 1))" in session and "timer.remainingSeconds(at: context.date)" in session,
    "Timer retains start": "timer.start(minutes: minutes)" in session,
    "Timer retains pause": "timer.pause()" in session,
    "Timer retains resume": "timer.resume()" in session,
    "Timer retains add minute": "timer.addMinute()" in session,
    "Timer retains reset": "timer.reset()" in session,
    "Timer engine calls were not moved into Build D patch": "VisualTimerCore" not in patch and "AVAudio" not in patch,
    "Visual Supports retains General library": "ClientVisualSupportCore.generalClientCode" in dashboard,
    "Visual Supports retains AI schedule drafting": "draftSchedule()" in dashboard,
    "Visual Supports retains saved-library wording": "existing local visual library" in dashboard,
    "Build D patch is UI-file scoped": 'DASHBOARD = ROOT / "LifeRoute/V054ToolsDashboard.swift"' in patch and 'CLINICAL = ROOT / "LifeRoute/AIClinicalToolsViews.swift"' in patch and 'SESSION = ROOT / "LifeRoute/SessionToolsViews.swift"' in patch,
    "Build D patch does not target intelligence domain": "LifeRouteIntelligenceCore.swift" not in patch,
    "Build D patch does not target persistence domain": "PersistenceCore.swift" not in patch,
    "Tools files remain native-only": all(token not in dashboard + clinical + session for token in ["WKWebView", "import WebKit", "localStorage", "MutationObserver"]),
    "Preparation materializes C before D": prepare.find("python3 scripts/patch_v0_7_0_build_c_compile_hotfix.py") < prepare.find("python3 scripts/patch_v0_7_0_build_d.py") if "python3 scripts/patch_v0_7_0_build_d.py" in prepare else False,
    "Preparation runs Build D audit": "python3 scripts/audit_v0_7_0_build_d.py" in prepare,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("LifeRoute v0.7.0 Build D audit FAILED:")
    for name in failed:
        print(f"- {name}")
    raise SystemExit(1)

print(
    "LifeRoute v0.7.0 Build D audit passed: Tools uses a clinical-first premium hierarchy; Session Note, Session Plan, Timer, Quick Notes, First/Then, and Visual Supports remain reachable; AI/client/timer/persistence ownership stays intact; and native-only isolation is preserved."
)
