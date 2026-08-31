# LifeRoute application architecture

This is the current source-ownership map for the native LifeRoute `0.9.0`
shipping tree after the post-Build-118 maintenance cleanup. It describes where
future changes belong; it does not authorize a product, release, persistence, or
migration change.

## Source and target authority

- `LifeRoute/` contains the native app source and shared Live Activity
  attributes.
- `LifeRouteLiveActivityWidget/` contains the Live Activity extension source.
- `LifeRoute.xcodeproj/` is the authoritative target/build membership source.
- `LifeRoute.xcodeproj/xcshareddata/xcschemes/LifeRoute.xcscheme` is the committed
  shared scheme.
- `LifeRoute Local.xcscheme` is machine-local, ignored under `xcuserdata`, and
  must not be shared.
- `LifeRoute/Web/` is a non-authoritative browser preview. It is not embedded in
  the shipping app.
- `scripts/archive/`, `docs/archive/`, and repository snapshots are archaeology,
  not active build inputs.

The accepted TestFlight baseline for this cleanup is Build 118 at
`67b8b4c21df3700a66abb1bb1c4190e2b040cce1`. Build 118 physical QA remains a
separate merge decision.

## Runtime composition

| Layer | Owner | Responsibility |
| --- | --- | --- |
| App entry and theme injection | `LifeRouteApp.swift` | `@main`, `LifeRouteThemeStore`, Debug launch fixtures, root chrome, and UIKit appearance compatibility |
| Persistent Scenic Royal host | `ScenicRoyalEnvironment.swift` | One root environment owner, active-scene/Reduce Motion gating, shared environmental inputs |
| Root shell | `V054ContentView.swift` | Five paged roots, five independent `NavigationStack`s, root state-object lifetime, toolbar installation, scene transitions |
| Navigation policy | `AppNavigation.swift` | `AppSection`, per-root paths, root selection, and deep-route toolbar suppression |
| Root toolbar | `ScenicRoyalToolbar.swift` | Presentation and root-selection binding only |

`V054ContentView` is the lifetime owner for `AppLifecycleCore`, `AppRouter`,
`CalendarCoreState`, `CalendarProviderCore`, `RoutingLocationCore`,
`ClientProfileCore`, and `SessionToolsCore`. Feature views receive those owners;
they must not create competing root services.

The five protected roots are:

| Root | Screen | Primary feature owners |
| --- | --- | --- |
| Today | `V054TodayView.swift` | calendar, routing, Day Route, Live Day |
| Schedule | `V054ScheduleView.swift` | calendar/provider state, date selection, travel presentation |
| Tools | `V054ToolsDashboard.swift` | Visual Timer, visual supports, quick notes, Session Plan, Session Note |
| Resources | `ResourcePortalViews.swift` | built-in/custom portal presentation and external handoff |
| Setup | `V054SetupView.swift` | profile, navigation/places, To-Dos, clinical links, Clients, Theme Center |

## Scenic Royal and theme ownership

### Theme model and renderers

- `LifeRouteTheme.swift` owns the theme identity, core catalog, palette, theme
  store, and environment values.
- `LifeRouteDynamicThemeRenderer.swift` owns retained Dynamic theme rendering,
  related motion signatures, and retained Dynamic/scenery catalog extensions.
- `LifeRouteSceneryThemeRenderer.swift` owns scenery rendering and the sole
  shared 15 fps `TimelineView` clock used by Dynamic-plus-scenery composition.
- `ScenicRoyalThemeBridge.swift` maps theme identity into Scenic Royal material
  and scenery roles.
- `CinematicThemeViews.swift` retains active bounded cinematic/backdrop support;
  obsolete thumbnail-only presentation has been removed.

Do not introduce a second environment clock, move the tick into a broadly
observed object, alter Dynamic-plus-scenery composition, or change Royal Current
scenery behavior during ordinary cleanup.

### Shared primitives

- `ScenicRoyalDesignSystem.swift`: spacing, sizing, typography, touch, and
  layout tokens.
- `ScenicRoyalMaterials.swift`: native iOS 26 Liquid Glass, grouped glass, and
  iOS 16-25/accessibility material fallbacks.
- `ScenicRoyalComponents.swift`: truly shared cards, labeled cards, headers,
  badges, rows, buttons, fields, and selected-state primitives.
- `LifeRouteLegacyComponents.swift`: still-active compatibility palette,
  readability, button, haptic, and theme-feedback owners used across files that
  have not migrated to a narrower Scenic Royal primitive.

Feature presentation remains bounded in:

- `ScenicRoyalScheduleComponents.swift`
- `ScenicRoyalToolsComponents.swift`
- `ScenicRoyalResourceComponents.swift`
- `ScenicRoyalSetupComponents.swift`
- `ScenicRoyalClientComponents.swift`
- `ScenicRoyalThemeComponents.swift`

Centralize a component only when inputs, material role, interaction, and
accessibility behavior are genuinely identical. Do not create a universal card
or flatten feature-specific glass grouping.

## Feature and domain ownership

| Domain | Domain/core owners | Presentation owners |
| --- | --- | --- |
| Calendar and providers | `CalendarDomain.swift`, `CalendarProviderCore.swift` | `V054ScheduleView.swift`, `ScenicRoyalScheduleComponents.swift` |
| Routing and saved places | `RoutingLocationDomain.swift` | Today, Setup, shared address field, Day Route |
| Day Route ordering/handoff | `DayRouteContracts.swift`, `FullRouteHandoffContracts.swift`, `DayRoutePlanningCore.swift` | `DayRoutePlanningView.swift` |
| Clients | `ClientProfileDomain.swift` | `V054ClientViews.swift`, `ScenicRoyalClientComponents.swift`; compiled `ClientViews.swift` remains a compatibility companion |
| Visual Timer and tool state | `SessionToolsDomain.swift`, `VisualTimerFeedbackContracts.swift` | `ScenicRoyalVisualTimerView.swift`, Tools dashboard |
| Session notes/plans | `LifeRouteIntelligenceCore.swift`, `SessionNoteContracts.swift` | `AIClinicalToolsViews.swift`, `AISessionPlanBuilderView.swift`, `SessionToolsViews.swift` |
| Visual-support library | `ClientVisualSupportCore` in `SessionToolsDomain.swift` | `ClientVisualSupportViews.swift`, `ClientVisualBuilderViews.swift`, `VisualAIAssistedStudioView.swift` |
| Resources | `ResourcePortalDomain.swift` | `ResourcePortalViews.swift`, `ScenicRoyalResourceComponents.swift` |
| Persistence/migration | `PersistenceCore.swift`, `LegacyMigrationCore.swift` | No presentation ownership |
| Live Day/Live Activity | `LiveDayActivityCore.swift`, `LiveDayActivityAttributes.swift` | Today and `LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift` |

Shipping callsites in `SessionToolsViews.swift` use Quick Session Notes and
Session Plan Organizer presentation. The file also retains the excluded
historical shell's `SessionToolsNativeView` and private card dependency.
Visual-support library and builder families have their own files so future
changes can compile and review against the relevant feature without reopening
the entire former 3,037-line surface.

## Protected behavioral contracts

- Navigation: five roots, horizontal paging, five independent stacks, toolbar
  synchronization/suppression, iOS 26 native navigation ownership, and the
  iOS 16-25 fallback.
- Routing: saved-stop persistence, deterministic before/event/after order,
  MapKit leg generation, bounded provider handoff, sequential continuation,
  Return Home, and stop-only days.
- Visual Timer: deadline/countdown semantics, urgency curve, Warm/Soft/Clear
  profiles, independent Sound and persisted volume, Ring/Silent behavior,
  completion haptic preference, and audio-session lifecycle.
- Session Note: experimental warning, Foundation Models boundary, evidence and
  identity validation, bounded repair/fallback, provenance, `SN-DIAG-1`, OCR,
  and measurement protection.
- Scenic Royal: continuous scenery, native Liquid Glass, ordinary/accessibility
  material modes, living motion, 15 fps cadence, one persistent host, and all
  accepted theme identities/catalogs.
- Persistence and compatibility: stored identifiers, schema decoding, legacy
  migration, provider credentials, saved places, clients, custom portals,
  Weekly To-Dos, theme selection, Live Day, and Live Activity.

## Validation architecture

| Entry point | Intended use |
| --- | --- |
| `bash scripts/prepare_build.sh` | Idempotent canonical-source preflight; includes fast validation |
| `bash scripts/validate_fast.sh` | Focused development architecture and semantic checks |
| `bash scripts/validate_full.sh` | Merge-grade semantic checks plus all executable contracts |
| `bash scripts/run_contract_tests.sh` | All four executable contract subsystems |
| `bash scripts/run_day_route_contract_tests.sh` | Day Route only; minimum 30 assertions |
| `bash scripts/run_session_note_contract_tests.sh` | Session Note only; minimum 162 assertions |
| `bash scripts/run_visual_timer_feedback_contract_tests.sh` | Visual Timer feedback only; minimum 47 assertions |
| `bash scripts/run_runtime_feedback_contract_tests.sh` | Runtime navigation/haptic policy only; minimum 9 assertions |
| `bash scripts/run_simulator_smoke.sh APP_PATH OUTPUT_DIR` | Five-root and theme-fixture runtime launch/capture only; five-second capture settle by default |

The focused Swift runners use a content-addressed cache through
`run_swift_contract_test.sh`. The cache key includes the compiler, common runner,
and exact source/fixture contents. A changed subsystem recompiles; unrelated UI
work reuses the exact binary but still executes every assertion. Set
`LIFEROUTE_CONTRACT_CACHE_DIRECTORY` to a fresh temporary directory for a cold
measurement.

Simulator capture settling is controlled by
`LIFEROUTE_SMOKE_SETTLE_SECONDS` and defaults to five seconds. Keep the default
for canonical evidence; use an override only for a deliberate timing experiment.

`validate_current.py` parses actual app and extension `PBXSourcesBuildPhase`
entries. Every active Swift file must be in the correct target exactly once;
every Sources build object must be referenced. This prevents detached project
objects from masquerading as shipping membership.

## Local Mac workflow

1. Close Xcode before broad project-file or shared-scheme inspection.
2. Confirm the intended branch, HEAD, expected dirty files, and exact baseline.
3. Use the shared `LifeRoute` scheme for canonical builds. Use `LifeRoute Local`
   only for machine-specific Run configuration and never share it.
4. Prefer focused validation and an incremental Debug build while iterating.
5. Before handoff, run cold full validation, Debug and Release Simulator builds,
   warning assessment, canonical smoke, runtime-log review, and integrity checks.
6. If the shared scheme drifts unexpectedly, stop, quit Xcode, restore only the
   tracked scheme from the current branch, and verify no other file changed.

## Retained and deferred history

The following are deliberately not cleanup deletion targets:

- `ContentView.swift`: historical native shell, outside app Sources.
- `LifeRouteWebView.swift` and bundled web assets: quarantined historical
  runtime/bridge, outside app Sources.
- `LiveActivityManager.swift`: non-shipping compatibility/history pending a
  separate ownership decision.
- `ClientViews.swift`: still compiled; do not delete based on its legacy name.
- dormant Visual Schedule architecture while intentionally hidden.
- persisted identifiers, theme renderer fallbacks, `LegacyMigrationCore.swift`,
  archive trees, and repository snapshots.

Deletion requires zero shipping dependency, correct target-membership evidence,
and proof that migration, persistence, bridge, and historical needs are absent.
