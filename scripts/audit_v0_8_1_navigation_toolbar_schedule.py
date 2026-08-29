from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_NAV = (ROOT / "LifeRoute/AppNavigation.swift").read_text(encoding="utf-8")
ACTIVE_CONTENT = (ROOT / "LifeRoute/ContentView.swift").read_text(encoding="utf-8")
LEGACY_CONTENT = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
DASHBOARD = (ROOT / "LifeRoute/V054ToolsDashboard.swift").read_text(encoding="utf-8")
VISUALS = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
TOOLBAR_PATCH = (ROOT / "scripts/patch_v0_7_1_reduced_catalog_toolbar_setup.py").read_text(encoding="utf-8")
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, bool(condition)))


check("bottom-toolbar visibility owner exists", "var shouldShowBottomToolbar: Bool" in APP_NAV)
check("tools icon semantic refinement applied", 'case .tools: return "wrench.and.screwdriver.fill"' in APP_NAV)
check("paged root TabView contract exists", "TabView(selection: $router.selectedSection)" in ACTIVE_CONTENT and ".tabViewStyle(.page(indexDisplayMode: .never))" in ACTIVE_CONTENT)
check("toolbar and paging share the same selected state", "if router.shouldShowBottomToolbar" in ACTIVE_CONTENT and ".toolbar(.hidden, for: .tabBar)" in ACTIVE_CONTENT)
check("five root sections remain", ACTIVE_CONTENT.count(".tag(AppSection.") == 5)
check("legacy wrapper no longer owns root content", "typealias ContentView = V054ContentView" not in LEGACY_CONTENT)
check("toolbar patch is explicit", "v0.8.1 paged root navigation" in TOOLBAR_PATCH)
check("theme root clock remains protected", "minimumInterval: 1.0 / 20.0" in APP and "paused: reduceMotion || !isActive" in APP)

check("visual schedule hidden from visible tools shell", DASHBOARD.count("scheduleAICard") == 1 and 'VisualWorkspaceCard(title: "Visual Schedule"' not in VISUALS)
check("visual schedule routes stay off the active shell", "ClientVisualScheduleBuilderView(" not in ACTIVE_CONTENT and "ClientVisualSchedulePreviewView(" not in ACTIVE_CONTENT and "ClientVisualScheduleBuilderView(" not in DASHBOARD)
check("choice boards remain", 'VisualWorkspaceCard(title: "Choice Boards"' in VISUALS)
check("first-then remains", 'VisualWorkspaceCard(title: "First / Then"' in VISUALS)
check("dormant visual schedule architecture remains available", "struct ClientVisualScheduleBuilderView: View" in VISUALS and "struct ClientVisualSchedulePreviewView: View" in VISUALS)

check("prepare script still owns deterministic prep", "scripts/patch_v0_7_1_reduced_catalog_toolbar_setup.py" in PREPARE and "scripts/patch_v0_8_0_session_note_followup.py" in PREPARE)

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {label}")

print(f"LifeRoute v0.8.1 navigation/toolbar/schedule audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
