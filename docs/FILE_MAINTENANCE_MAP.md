# LifeRoute File Maintenance Map

Status: implementation map, documentation only. Baseline inspected: `95c9b7ccba862a80da5c605a01b5c910c8f2de76` on `chore/file-maintenance-map-20260917` (September 17, 2026). This map describes repository authority; it does not authorize deletion, renaming, target-membership changes, workflow changes, or source refactoring.

## 1. Shipping source authority

The shortest source-navigation chain is:

`LifeRoute/LifeRouteApp.swift` (`@main LifeRouteApp` → `appContent`) → `LifeRoute/V054ContentView.swift` (`typealias ContentView = V054ContentView` → `V054ContentView`) → `AppRouter` and the persistent five-root pager → feature owner.

| Concern | Canonical owner | Major supporting files and invariants |
| --- | --- | --- |
| Application root | `LifeRoute/LifeRouteApp.swift` — `LifeRouteApp` | Theme store, scene/window lifetime, activity coordinator, and environment injection live here. |
| Root navigation | `LifeRoute/V054ContentView.swift` — `V054ContentView`, `LifeRouteRootNavigationStack`, persistent pager | `LifeRoute/AppNavigation.swift` — `AppSection` and `AppRouter`; the five roots are `.today`, `.schedule` (Calendar), `.tools`, `.resources`, and `.setup`. `AppRouter` is the discrete selection authority. |
| Today | `LifeRoute/V054TodayView.swift` — `V054TodayView` | `DayRoutePlanningCore.swift`, `DayRoutePlanningView.swift`, `CalendarDomain.swift`; Today consumes the immutable route/day state. |
| Calendar | `LifeRoute/V054ScheduleView.swift` — `V054ScheduleView` | `CalendarDomain.swift` — `CalendarCoreState`; `CalendarProviderCore.swift`; `DayRoutePlanningCore.swift`. Calendar selection and provider identity remain separate from route rendering. |
| Tools | `LifeRoute/V054ToolsDashboard.swift` — `V054ToolsDashboard` | `SessionToolsViews.swift`, `AIClinicalToolsViews.swift`, `BoardEditor.swift`, `BoardArtifact.swift`; current dashboard routes Visual Supports and session tools. |
| Resources | `LifeRoute/V054ContentView.swift` root presentation — `ResourcePortalHubView` | Resource-specific views are reached through the Resources root; do not use the old `ContentView.swift` tab root as a navigation guide. |
| Setup | `LifeRoute/V054ContentView.swift` root presentation — `V054SetupView` | Setup is one of the five current root destinations; its presentation is owned by `V054ContentView`. |
| Session Notes | `LifeRoute/AIClinicalToolsViews.swift` — `AISessionNoteGeneratorView`; `LifeRoute/SessionNoteContracts.swift` — `SessionNoteGenerationPipeline` | `SessionToolsDomain.swift` — `SessionToolsCore`; `PersistenceCore.swift` — `LifeRoutePersistenceStore` for draft/session persistence. |
| Visual Timer | `LifeRoute/ScenicRoyalVisualTimerView.swift` — `VisualTimerView` | `SessionToolsDomain.swift` — `VisualTimerCore`; `VisualTimerHero.swift` — `VisualTimerHeroCoordinator`; Timeline/orb presentation is in the Scenic Royal view. `LegacyVisualTimerView` is retained compatibility material, not the shipping presentation. |
| Visual Supports | `LifeRoute/BoardEditor.swift` — `BoardEditor`/`BoardSavedLibrary`; `LifeRoute/BoardArtifact.swift` — `BoardArtifact`/`BoardCanvas` | `V054ToolsDashboard.swift` routes the current center/library; `VisualSupportImagePrompt.swift` owns the structured image-generation prompt contract. |
| Theme selection | `LifeRoute/LifeRouteApp.swift` — `LifeRouteThemeStore` | `liferoute.selectedTheme` persistence and retired-to-shipping theme normalization are here. |
| Theme rendering | `LifeRoute/ScenicRoyalEnvironment.swift` — `ScenicRoyalEnvironmentHost` | `ScenicRoyalThemeBridge.swift`, `ScenicRoyalDesignSystem.swift`, `ScenicRoyalComponents.swift`, `CinematicThemeViews.swift`; the host selects core glass, live theme, or cinematic fallback presentation. |
| Living Theme/environment | `LifeRoute/LivingThemeScene.swift` — `LivingThemeScene` registry; `LifeRoute/LivingThemeEnvironment.swift` — `LivingThemeEnvironment`/`LivingEnvironmentSurface` | `LifeRouteApp.swift` owns `LifeRouteLiveThemeEnvironment`; `LivingThemeScene.all` is the explicit scene registry. `ScenicRoyalEnvironment.swift` is the routing boundary into the live-theme environment. |
| Persistence | `LifeRoute/PersistenceCore.swift` — `LifeRoutePersistenceStore` | `NativeState` and feature cores use this store; session-note draft save/flush is implemented here. |

Tests/validators encoding critical navigation, theme, timer, board, and session-note invariants are concentrated in `scripts/validate_current.py`, `scripts/run_swift_contract_test.sh`, and the targeted validators listed below. Static validation is not physical or owner acceptance.

## 2. Current versus historical/compatibility files

Classification is based on source references and Xcode membership, not names alone. “Current” means part of the current app target or an active caller; “retained” means there is a compatibility, migration, fallback, or evidence reason to preserve it.

| Path or family | Classification | Evidence and future disposition |
| --- | --- | --- |
| `LifeRoute/LifeRouteApp.swift` | CURRENT / SHIPPING | `@main LifeRouteApp`, theme store, and environment injection. Keep active; do not split broadly as a maintenance exercise. |
| `LifeRoute/V054ContentView.swift` | CURRENT / SHIPPING | Defines `V054ContentView`, the current root pager, and root presentations. Keep active. |
| `LifeRoute/V054ContentView.swift` — `typealias ContentView = V054ContentView` | CURRENT / SHIPPING compatibility alias | The alias is the app entry’s current name bridge. Preserve while callers/build assumptions depend on `ContentView`. |
| `LifeRoute/ContentView.swift` | HISTORICAL / NON-SHIPPING | Old `TabView` root and old `SessionToolsNativeView` path. It is present in the project group but excluded from the app Sources build phase. Keep as historical evidence unless an owner approves bounded retirement. |
| `LifeRoute/SessionToolsViews.swift` | CURRENT / SHIPPING, with retained subviews | Current Visual Supports/library and image-generator surfaces coexist with `LegacyVisualTimerView` and older preview/builder material. Keep the file; classify subviews individually before any future retirement. |
| `LifeRoute/LegacyMigrationCore.swift` | COMPATIBILITY-RETAINED | Maps legacy V4 state into the native store and remains in the app target. No current production caller was found beyond validation/project inclusion; migration/reflection risk means owner decision is required before retirement. |
| `LifeRoute/ScenicRoyalThemeBridge.swift` | CURRENT / SHIPPING support | Active style/family mapping, including compatibility normalization for older theme values. Not an obsolete renderer. Keep active. |
| Dynamic-theme symbols in `LifeRoute/LifeRouteApp.swift` (`LifeRouteDynamicGlassFrame`, `LifeRouteDynamicGlassEnvironment`) | COMPATIBILITY-RETAINED | Retired Dynamic catalog values are normalized to current scenery/live-theme values; the symbols remain in the shipping target. Do not remove from a grep-only result. |
| `LifeRoute/CinematicThemeViews.swift` | CURRENT / SHIPPING support | `LifeRouteCinematicBackdrop` is used as the non-live fallback by `ScenicRoyalEnvironmentHost`; other thumbnail/wave helpers require bounded caller review. Keep active pending per-symbol review. |
| `LifeRoute/LivingThemeScene.swift`, `LifeRoute/LivingThemeEnvironment.swift` | CURRENT / SHIPPING | Explicit registry and native environment surface for Living Themes. Keep active. |
| `LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift` plus `LifeRoute/LiveDayActivityAttributes.swift` | CURRENT / SHIPPING | These are the widget target’s current Live Activity implementation and shared app/widget attributes. Follow project target membership. |
| `LifeRouteLiveActivity/LifeRouteLiveActivityWidget.swift`, `LifeRouteShared/LifeRouteActivityAttributes.swift`, and that folder’s `Info.plist` | HISTORICAL / NON-SHIPPING | Older Live Activity paths have no current target references. Keep historical until the owner makes a separate archival decision. |
| `LifeRoute/LifeRouteWebView.swift`, `LifeRoute/Web/**` | HISTORICAL / NON-SHIPPING or preview-only by subpath | The WebView and old embedded runtime are excluded from the current app target/resources. Web preview classification is separately documented in `docs/WEB_PREVIEW_CLASSIFICATION.md`; do not treat web preview as native shipping authority. |
| `LifeRoute_GitHub_Upload_Fresh/**` and root `UPLOAD_MAP.txt` | HISTORICAL / NON-SHIPPING | Snapshot/upload material describes an older project layout and Codemagic path. Preserve as archaeology; it does not override the current project or workflows. |

No current shipping owner is classified `UNKNOWN` from the inspected source. The explicit follow-up items are mixed-content `SessionToolsViews.swift`, per-symbol `CinematicThemeViews.swift`, and migration-caller confirmation for `LegacyMigrationCore.swift`.

## 3. Target membership and build authority

`LifeRoute.xcodeproj/project.pbxproj` is the build-authority index. Its `PBXSourcesBuildPhase` and `PBXResourcesBuildPhase` entries, plus the app/widget target sections, determine what Xcode compiles and packages. The project group alone is not evidence of shipping membership.

Current evidence includes `V054ContentView.swift`, the current domain/UI files, `CinematicThemeViews.swift`, and `LegacyMigrationCore.swift` in the app Sources phase. `ContentView.swift`, `ClientViews.swift`, and `LifeRouteWebView.swift` remain project references but are excluded from app Sources; `Web` is not an app resource. The widget target owns `LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift` and its current attributes path.

`scripts/validate_current.py` independently checks the expected current target membership and explicitly guards against re-adding the old ContentView/WebView/ClientViews/Web resource path. Any future source-retirement decision must inspect both the project file and dynamic/runtime references before changing membership.

## 4. Script and validator disposition

### Canonical automatic

These are the normal validation/build-authority chain: `scripts/prepare_build.sh`, `scripts/validate_fast.sh`, `scripts/validate_full.sh`, `scripts/validate_current.py`, `scripts/run_swift_contract_test.sh`, `scripts/assess_build_warnings.sh`, and the current CI workflows. The storage boundary is canonical too: `scripts/liferoute_storage.py` provides scratch-root/checkpoint-copy/closeout policy, and `scripts/liferoute_storage_contract_tests.py` validates that policy. `.github/workflows/ios-ci.yml` invokes current validation and the storage contract checks; CI/TestFlight use the storage scratch root.

### Targeted/manual

Feature and evidence scripts such as `scripts/route_timeline_separator_contract_test.py`, `scripts/board_production_ui_tests.swift`, `scripts/run_board_production_ui_tests.py`, `scripts/run_board_artifact_render_review.py`, the root-navigation/visibility checks, Timer A–D checks, Living Theme native/render/UI/QA checks, route/calendar checks, and R2/visual evidence capture scripts are targeted or manual unless a workflow explicitly calls them. They are useful contract/evidence tools, not automatically shipping authority.

### Compatibility and historical

`scripts/archive/**` is archaeology and is not part of the current validation chain. Scripts that reference legacy paths, prior artifacts, or handoff-era evidence remain retained until their assumptions and evidence value are reviewed. Retention does not imply current automation.

### Orphan / needs review

`scripts/route_timeline_separator_contract_test.py` was explicitly inspected. It reads current Today source and checks the separator contract, but no current wrapper, workflow, or documentation caller was found. Its current status is **APPARENTLY ORPHANED — NEEDS REVIEW**, not deleted: keep as a targeted validator while an owner decides whether to wire it into validation or formally mark it manual.

The root `codemagic.yaml` is similarly retained non-authoritative tooling and is not a current script/release owner. No retirement is authorized by this map.

## 5. CI and release authority

| Function | Canonical authority | Boundary |
| --- | --- | --- |
| GitHub iOS CI | `.github/workflows/ios-ci.yml` | Current validation, native build/Simulator qualification, warning assessment, and scratch build outputs. |
| TestFlight | `.github/workflows/testflight.yml` | The sole current workflow with Apple signing, IPA export, and TestFlight upload machinery. |
| Web preview | `.github/workflows/pages.yml` plus `scripts/build_web_preview.py` | Preview-only; it does not establish native shipping authority. |
| Reusable workflow templates | `ReusableAppWorkflow/ios-ci.template.yml` and `ReusableAppWorkflow/testflight.template.yml` | Templates for the corresponding GitHub workflows; the live `.github/workflows` files remain the executed authority. |
| Codemagic | `codemagic.yaml` | Current file, but **UNKNOWN — NEEDS FOLLOW-UP / NON-AUTHORITATIVE**: source and current release docs identify GitHub Actions TestFlight as the owner, and no current workflow reference to Codemagic was found. Keep until an owner decides whether it is historical or separately supported. |

Supporting operational authority is documented in `docs/BUILD_ARCHITECTURE.md`, `TESTFLIGHT_SETUP.md`, and `GITHUB_ACTIONS_RUNBOOK.md`; these do not replace the workflow files.

## 6. Generated scratch versus durable evidence

`~/Library/Developer/LifeRouteBuilds` is generated build scratch. Derived data, archives, exports, fixture caches, and similar generated material belong below that scratch root and are reproducible or replaceable.

Durable checkpoint/evidence roots are separate: `~/Documents/LifeRouteCheckpoints` and `~/Documents/LifeRouteEvidence` (with the repository’s committed `docs/evidence/**` used where applicable). Receipts, manifests, screenshots, video, and explicitly final artifacts belong in durable roots only when deliberately copied or staged. `scripts/liferoute_storage.py checkpoint-copy` excludes generated directories and copies explicitly named artifacts; `closeout` is guarded and dry-run by default. A scratch path in a handoff or log is not durable evidence merely because it is named there.

## 7. Known maintenance items

- The required prevention helper `/Users/brand/Documents/LifeRouteCheckpoints/consolidated-one-checkout-cleanup-20260913-20260913T170527Z-terra/prevention/liferoute-worktree-count-check.sh` is absent. Direct `git worktree list --porcelain` is the current fallback; do not recreate or silently replace the helper in this documentation task.
- `AGENTS.md` still describes the checked-in source as v0.9.0 while current README/validator/build documentation identify v0.9.1. This is a documentation-alignment item, not evidence that the source is stale.
- `LIFEROUTE_HANDOFF.md` is a time-bound handoff ledger and its current top material is Crystal/follow-up-specific; use current Git/project/workflow files for authority. Keep the ledger as evidence unless its owner revises it.
- The Today separator validator has no discovered caller; preserve it pending an owner decision on automatic wiring versus manual-specialized status.
- `LifeRouteApp.swift` is large, but current ownership is coherent enough that broad splitting is not a safe first maintenance action.

## 8. Recommended future sequence

### Phase A — navigation-only, low risk

Keep this map and a small pointer in the repository’s worker-facing read order (`README.md`/`AGENTS.md`) aligned with the current source and project authority. Correct only demonstrably stale authority labels, such as the v0.9.0/v0.9.1 wording, in a separately authorized documentation change.

### Phase B — script decisions

For each apparently orphaned or manual script, record callers, documentation references, source assumptions, original purpose, and evidence value. Decide whether to wire, retain as manual, or retire; do not infer retirement from no grep caller.

### Phase C — bounded source retirement

Only after owner review and multi-signal evidence, consider one bounded candidate at a time: old target-excluded source, a compatibility symbol with no migration/runtime risk, or a proven unused private view. Recheck project membership, reflection/serialization/deep-link/preview risks, and validation after each decision.

### Phase D — optional structural reorganization

Avoid directory moves unless a concrete build, ownership, or discoverability payoff is demonstrated. Preserve history and target membership explicitly if a move is ever approved.

High-risk items to leave alone for now: `LifeRouteApp.swift`, the `ContentView` alias, migration and Dynamic Theme compatibility paths, Live Activity compatibility snapshots, mixed `SessionToolsViews.swift`, historical Web/upload material, and all workflow/project membership entries.
