#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

resources = (ROOT / "LifeRoute/ResourcePortalViews.swift").read_text(encoding="utf-8")
resource_domain = (ROOT / "LifeRoute/ResourcePortalDomain.swift").read_text(encoding="utf-8")
clients = (ROOT / "LifeRoute/V054ClientViews.swift").read_text(encoding="utf-8")
client_domain = (ROOT / "LifeRoute/ClientProfileDomain.swift").read_text(encoding="utf-8")
setup = (ROOT / "LifeRoute/V054SetupView.swift").read_text(encoding="utf-8")
routing = (ROOT / "LifeRoute/RoutingLocationDomain.swift").read_text(encoding="utf-8")
persistence = (ROOT / "LifeRoute/PersistenceCore.swift").read_text(encoding="utf-8")
themes = (ROOT / "LifeRoute/V054ThemeCenterView.swift").read_text(encoding="utf-8")
theme_owner = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text(encoding="utf-8")
session = (ROOT / "LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
shell = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
prepare = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
patch = (ROOT / "scripts/patch_v0_7_0_build_e.py").read_text(encoding="utf-8")

checks = {
    "Build E Resources marker materialized": "v0.7.0 Build E Resources" in resources,
    "Resources keeps ResourcePortalCore ownership": "@StateObject private var portalState = ResourcePortalCore()" in resources,
    "Resources keeps built-in portal catalog": "CentralReach" in resource_domain and "Motivity" in resource_domain and "BACB Portal" in resource_domain,
    "Resources keeps category grouping": "LifeRoutePortalCategory.allCases" in resources and "portalState.portals(in: category)" in resources,
    "Resources keeps external URL launch": "openURL(url)" in resources,
    "Resources keeps custom portal creation": "portalState.addCustomPortal(" in resources,
    "Resources keeps custom portal removal": "portalState.removeCustomPortal(id: portal.id)" in resources,
    "Resources preserves privacy boundary": "Credentials, sign-in, and data entered there remain with the destination service" in resources,
    "Resources does not embed third-party portals": all(token not in resources for token in ["WKWebView", "import WebKit", "localStorage"]),

    "Build E Client Hub marker materialized": "v0.7.0 Build E Client Hub" in clients,
    "Clients retain ABA four-letter code normalization": "ClientProfileCore.normalizedPair" in clients and "normalizedPair" in client_domain,
    "Clients retain service address field": "V054AddressField" in clients,
    "Clients retain preferred activities": "preferredActivities" in clients,
    "Clients retain targets": "currentTargets" in clients,
    "Clients retain behaviors of concern": "behaviorsOfConcern" in clients,
    "Clients retain communication/FCT context": "communicationNotes" in clients,
    "Clients retain prompting/reinforcement context": "promptingNotes" in clients,
    "Clients retain caregiver/setting context": "caregiverNotes" in clients,
    "Clients retain other clinical notes": "clinicalNotes" in clients,
    "Clients retain save": "clientState.saveProfile(" in clients,
    "Clients retain edit workflow": "V054ClientEditorView(clientState: clientState, profile: profile)" in clients,
    "Clients retain remove": "clientState.removeClient(id: profile.id)" in clients,
    "Client editor has strong bottom Save affordance": ".safeAreaInset(edge: .bottom" in clients and '"Save Client"' in clients,
    "Client Hub avoids iOS-17-only ContentUnavailableView": "ContentUnavailableView" not in clients,

    "Build E Setup marker materialized": "v0.7.0 Build E Setup Control Center" in setup,
    "Setup groups profile/work identity": 'LifeRouteSectionLabel(title: "Profile / Work Identity")' in setup,
    "Setup groups navigation and places": 'LifeRouteSectionLabel(title: "Navigation & Places")' in setup,
    "Setup keeps Weekly To-Dos visible": 'LifeRouteSectionLabel(title: "Weekly To-Dos")' in setup and "weeklyTodosCard" in setup,
    "Setup keeps Clients visible": 'LifeRouteSectionLabel(title: "Clinical")' in setup and "V054ClientProfilesView(clientState: clientState)" in setup,
    "Setup keeps Theme Center visible": 'LifeRouteSectionLabel(title: "Appearance")' in setup and "V054ThemeCenterView()" in setup,
    "Setup keeps privacy visible": 'LifeRouteSectionLabel(title: "Privacy")' in setup and "privacyCard" in setup,
    "Setup retains RBT profile": "liferoute.rbtProfile.name" in setup and "rbtProfileCard" in setup,
    "Setup retains preferred navigation app": "liferoute.preferredNavigationApp" in setup and "preferredNavigationAppRaw" in setup,
    "Setup retains home address save": "routingState.setHomeAddress(homeDraft)" in setup,
    "Saved Places retain add": "routingState.addSavedPlace(" in setup,
    "Saved Places retain remove": "routingState.removeSavedPlace(id: place.id)" in setup,
    "Saved Places retain minimum visit": "minimumVisitMinutes" in setup,
    "Saved Places retain gap eligibility": "useInGapSuggestions: gapSuggestion" in setup,
    "Weekly To-Dos retain add": "routingState.addTodo(" in setup,
    "Weekly To-Dos retain completion": "routingState.setTodoCompleted" in setup,
    "Weekly To-Dos retain removal": "routingState.removeTodo" in setup,
    "Weekly To-Dos retain category": "todoCategory" in setup,
    "Weekly To-Dos retain duration": "todoDurationMinutes" in setup,
    "Weekly To-Dos retain optional Saved Place": "todoSavedPlaceID" in setup,
    "Weekly To-Dos retain priority": "todoPriority" in setup,
    "Weekly To-Dos retain due date": "todoDueDate" in setup,
    "Weekly To-Dos retain notes": "todoNotes" in setup,
    "Routing domain still owns Saved Places and To-Dos": "@Published private(set) var savedPlaces" in routing and "@Published private(set) var todos" in routing,
    "Protected persistence still owns routing snapshot": "saveRoutingState" in persistence and "todos" in persistence and "savedPlaces" in persistence,

    "Build E Theme Center marker materialized": "v0.7.0 Build E Theme Center" in themes,
    "Theme Center consumes existing LifeRouteThemeStore": "@EnvironmentObject private var themeStore: LifeRouteThemeStore" in themes,
    "Theme Center does not create second theme store": "LifeRouteThemeStore()" not in themes,
    "Theme selection still writes existing owner": "themeStore.selectedTheme = theme" in themes,
    "Theme browser covers all existing themes": "LifeRouteTheme.allCases" in themes,
    "Theme browser has compact category controls": "LifeRoutePill" in themes and "ThemeFilter.allCases" in themes,
    "Theme cards use color/material swatches": "theme.palette.backgroundGradient" in themes and "theme.palette.accent" in themes,
    "Theme Center does not add scenery owner": "LifeRouteCinematicBackdrop" not in themes,
    "Core theme architecture remains owned centrally": "final class LifeRouteThemeStore" in theme_owner and "var category: LifeRouteThemeCategory" in theme_owner,

    "Five-tab shell remains exact": shell.count("NavigationStack(path: $router.") == 5,
    "Today root remains": "Label(AppSection.today.title, systemImage: AppSection.today.systemImage)" in shell and ".tag(AppSection.today)" in shell,
    "Schedule root remains": "Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage)" in shell and ".tag(AppSection.schedule)" in shell,
    "Tools root remains": "Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage)" in shell and ".tag(AppSection.tools)" in shell,
    "Resources root remains": "Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage)" in shell and ".tag(AppSection.resources)" in shell,
    "Setup root remains": "Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage)" in shell and ".tag(AppSection.setup)" in shell,
    "Build D final timer cadence remains 0.10 seconds": "TimelineView(.periodic(from: .now, by: 0.10))" in session,
    "Build D timer compatibility anchor remains": "v0.7.0 Build D audit compatibility anchor" in session,

    "Build E patch is presentation-file scoped": all(path in patch for path in [
        'LifeRoute/ResourcePortalViews.swift',
        'LifeRoute/V054ClientViews.swift',
        'LifeRoute/V054SetupView.swift',
        'LifeRoute/V054ThemeCenterView.swift',
    ]),
    "Build E patch does not target routing domain": "RoutingLocationDomain.swift" not in patch,
    "Build E patch does not target persistence domain": "PersistenceCore.swift" not in patch,
    "Build E patch does not target client domain": "ClientProfileDomain.swift" not in patch,
    "Build E patch does not target resource domain": "ResourcePortalDomain.swift" not in patch,
    "Build E patch does not target timer domain": "SessionToolsDomain.swift" not in patch,
    "Build E patch does not target AppRouter": "AppNavigation.swift" not in patch,
    "Build E runs after Build D compatibility": prepare.find("python3 scripts/patch_v0_7_0_build_d_compat.py") < prepare.find("python3 scripts/patch_v0_7_0_build_e.py") if "python3 scripts/patch_v0_7_0_build_e.py" in prepare else False,
    "Preparation runs Build E audit": "python3 scripts/audit_v0_7_0_build_e.py" in prepare,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("LifeRoute v0.7.0 Build E audit FAILED:")
    for name in failed:
        print(f"- {name}")
    raise SystemExit(1)

print(
    "LifeRoute v0.7.0 Build E audit passed: Resources, Clients, Setup, Saved Places, Weekly To-Dos, and Theme Center use the compact v0.7 supporting-surface hierarchy while domain ownership, local persistence, five-tab routing, privacy boundaries, and the validated Build D timer cadence remain intact."
)
