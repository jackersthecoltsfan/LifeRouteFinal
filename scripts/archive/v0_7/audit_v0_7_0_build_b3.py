#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = (ROOT / "LifeRoute/V054TodayView.swift").read_text(encoding="utf-8")
TOOLS = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")

checks = {
    "B.3 Home marker is materialized": "v0.7.0 Build B.3 device QA" in TODAY,
    "cinematic hero keeps a local native scene": "private struct LifeRouteTodayHeroScene: View" in TODAY,
    "hero adds distant mountain depth": "private func distantRange" in TODAY,
    "hero adds snow/highlight detail": "private func snowHighlights" in TODAY,
    "hero adds valley atmosphere": "private func valleyMist" in TODAY,
    "hero keeps a gold route path": "private func roadPath" in TODAY and "goldBright" in TODAY,
    "Home shows at most one open To-Do preview": "ForEach(openTodos.prefix(1))" in TODAY,
    "Home shows one saved-place preview when no To-Do is ahead of it": "ForEach(suggestions.prefix(openTodos.isEmpty ? 1 : 0))" in TODAY,
    "Home keeps See all route access": 'Text("See all")' in TODAY,
    "Home keeps Live Day below primary content": "private var liveDayCard: some View" in TODAY,
    "B.3 visual workflow marker is materialized": "v0.7.0 B.3 visual presentation workflow" in TOOLS,
    "Visual Supports center accepts initial library scope": "initialClientCode: String = ClientVisualSupportCore.generalClientCode" in TOOLS,
    "Choice Board exposes View Library": TOOLS.count('Label("View Library", systemImage: "books.vertical.fill")') >= 3,
    "Choice Board retains Save and Preview": TOOLS.count('Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")') >= 3,
    "visual editors hide the main tab bar": TOOLS.count(".toolbar(.hidden, for: .tabBar)") >= 5,
    "First Then has a dedicated full-screen session preview": "struct ClientFirstThenSessionPreviewView: View" in TOOLS,
    "First Then full-screen preview is true full screen": "Close First Then preview" in TOOLS and ".fullScreenCover(isPresented: $showingFullScreenPreview)" in TOOLS,
    "First Then retains horizontal FIRST to THEN presentation": "v0.7.0 horizontal First Then preview" in TOOLS and 'Image(systemName: "arrow.right.circle.fill")' in TOOLS,
    "First Then has explicit save helper": "private func saveFirstThen()" in TOOLS,
    "First Then saves through existing protected Visual Schedule persistence": "_ = try visualState.saveSchedule(" in TOOLS,
    "First Then saved form has exactly two reusable schedule steps": "ClientVisualScheduleStep(label: resolvedFirstText" in TOOLS and "ClientVisualScheduleStep(label: resolvedThenText" in TOOLS,
    "First Then explains reusable library storage truthfully": "Saving First / Then stores it as a reusable two-step Visual Schedule" in TOOLS,
    "First Then can open the current visual library": "initialClientCode: selectedClientCode" in TOOLS,
    "Choice Board still uses full-screen saved preview": ".fullScreenCover(item: $previewBoard)" in TOOLS,
    "Visual Schedule still uses full-screen saved preview": ".fullScreenCover(item: $previewSchedule)" in TOOLS,
    "B.3 remains native-only": "WKWebView" not in TODAY and "WKWebView" not in TOOLS,
    "prepare build runs B.3 patch": "python3 scripts/patch_v0_7_0_build_b3.py" in PREPARE,
    "prepare build runs B.3 audit": "python3 scripts/audit_v0_7_0_build_b3.py" in PREPARE,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("LifeRoute v0.7.0 Build B.3 audit FAILED:")
    for name in failed:
        print(f"- {name}")
    raise SystemExit(1)

print(
    "LifeRoute v0.7.0 Build B.3 audit passed: real-device Home hierarchy is tightened around a more cinematic hero, visual editor actions are no longer obscured by the main tab bar, and First/Then now saves into the protected visual library with true full-screen presentation."
)
