# POST-v0.9 CLEANUP ARCHITECTURE CHECKPOINT

Recorded: 2026-08-31

## Release and branch gate

- TestFlight workflow: GitHub Actions run `33403588020`
- Accepted candidate: LifeRoute `0.9.0` Build `118`
- Exact accepted release SHA: `67b8b4c21df3700a66abb1bb1c4190e2b040cce1`
- Workflow evidence: archive succeeded, export succeeded, and Apple upload succeeded with no upload errors.
- Cleanup branch: `chore/post-v0.9-architecture-cleanup`
- Branch point: the exact accepted release SHA above
- `origin/main` and local `main` matched the accepted release SHA before this branch was created.
- The worktree was clean before the audit and remained clean through all baseline measurements and read-only audits.
- The committed shared `LifeRoute.xcscheme` matched the release baseline.
- `LifeRoute Local.xcscheme` remains under ignored `xcuserdata` and is not shared.
- Build 118 physical QA remains a merge gate. No cleanup work may be merged or released until that QA is accepted.

## Shipping architecture map

| Boundary | Current owner | Cleanup intent |
| --- | --- | --- |
| App entry and appearance | `LifeRoute/LifeRouteApp.swift` | Keep the app entry, root chrome, Debug fixtures, and appearance wiring small and explicit. |
| Theme catalog and Dynamic/scenery rendering | `LifeRoute/LifeRouteTheme.swift`, `LifeRoute/LifeRouteDynamicThemeRenderer.swift`, `LifeRoute/LifeRouteSceneryThemeRenderer.swift` | Preserve catalog identity, composition, and the single shared environment clock. |
| Root paging and five independent navigation stacks | `LifeRoute/V054ContentView.swift`, `LifeRoute/AppNavigation.swift` | Protect; no navigation redesign. |
| Shared Scenic Royal primitives and materials | `LifeRoute/ScenicRoyalComponents.swift`, `LifeRoute/ScenicRoyalMaterials.swift`, `LifeRoute/ScenicRoyalThemeBridge.swift` | Consolidate only exact shared presentation primitives. |
| Feature-bounded Scenic Royal UI | `ScenicRoyalScheduleComponents.swift`, `ScenicRoyalToolsComponents.swift`, `ScenicRoyalResourceComponents.swift`, `ScenicRoyalSetupComponents.swift`, `ScenicRoyalClientComponents.swift`, `ScenicRoyalThemeComponents.swift` | Keep bounded by feature. |
| Today and day routing | `V054TodayView.swift`, `DayRoutePlanningView.swift`, `DayRoutePlanningCore.swift`, `RoutingLocationCore.swift` | Protect persistence, ordering, routing, and continuation semantics. |
| Calendar/provider normalization | `CalendarProviderCore.swift`, `V054ScheduleView.swift` | Protect provider and date behavior; use positional identity only for the static rendered weekday-label row. |
| Visual Timer and session tools | `SessionToolsDomain.swift`, `SessionToolsViews.swift`, `ScenicRoyalVisualTimerView.swift` | Split presentation ownership; protect timer/audio/haptic semantics. |
| Session Note | `AIClinicalToolsViews.swift`, `SessionNoteContracts.swift`, related Foundation Models/evidence owners | Protect all evidence, repair, provenance, OCR, and `SN-DIAG-1` boundaries. |
| Clients, resources, Setup, persistence | Their `V054*`, Scenic Royal component, and core/domain files | Preserve behavior; consolidate only exact presentation duplicates. |
| Live Activity | `LifeRouteLiveActivityWidget/`, `LiveDayActivityAttributes.swift`, current app integration | Protect target membership and compilation. |
| Web and historical compatibility | `LifeRouteWebView.swift`, `ContentView.swift`, bundled web assets, archive trees | Retain and keep outside the shipping Sources phase. |

## Baseline inventory

- Swift sources under `LifeRoute/`: 49
- Widget Swift sources: 1
- App Sources phase: 46 tracked Swift files, plus generated symbols
- Live Activity Sources phase: 2 entries
- Unique tracked Swift files compiled across both targets: 47
- Duplicate compile entries: none
- Missing referenced source files: none
- Baseline unexpected compiler warnings: 0
- Known non-warning App Intents metadata notices: 2

Largest Swift files before cleanup:

| File | Lines |
| --- | ---: |
| `LifeRouteApp.swift` | 3,684 |
| `SessionToolsViews.swift` | 3,037 |
| `SessionNoteContracts.swift` | 2,072 |
| `ContentView.swift` (historical, excluded) | 1,742 |
| `AIClinicalToolsViews.swift` | 1,160 |
| `V054TodayView.swift` | 1,078 |
| `SessionToolsDomain.swift` | 844 |
| `LifeRouteWebView.swift` (historical, excluded) | 827 |
| `RoutingLocationDomain.swift` | 823 |
| `PersistenceCore.swift` | 760 |
| `CalendarProviderCore.swift` | 654 |
| `V054ScheduleView.swift` | 644 |
| `V054ToolsDashboard.swift` | 609 |
| `V054SetupView.swift` | 560 |
| `ClientViews.swift` | 555 |

## Baseline timing and validation metrics

All timings were recorded on the same local Mac from the clean release baseline. They are single-run baselines and will be compared with like-for-like post-cleanup runs.

| Check | Baseline |
| --- | ---: |
| Preparation | 0.12 s |
| Fast validation | 0.05 s |
| Full validation | 5.79 s |
| Day Route contracts | 2.07 s / 30 assertions |
| Session Note contracts | 2.15 s / 162 assertions |
| Visual Timer feedback contracts | 0.59 s / 47 assertions |
| Runtime feedback contracts | 0.52 s / 9 assertions |
| Fresh Debug Simulator build | 110.68 s |
| Incremental Debug Simulator build | 1.97 s |
| Fresh Release Simulator build | 116.38 s |
| Canonical Simulator smoke | 34.57 s |

Debug and Release builds succeeded, including the embedded Live Activity extension. The canonical smoke passed all five roots and its Canyon and Royal Current motion/accessibility fixtures.

## Large-file and ownership findings

### Safe now

- Split `LifeRouteApp.swift` by existing top-level ownership boundaries: theme/catalog and environment values, legacy/shared presentation support, Dynamic rendering, scenery rendering, and the small app-entry/chrome owner.
- Split `SessionToolsViews.swift` into coherent session-tool feature families without adding view models or changing state ownership.
- Extract `AISessionPlanBuilderView` from `AIClinicalToolsViews.swift` and `VisualAIAssistedStudioView` from `V054ToolsDashboard.swift` as independent existing top-level views.
- Keep private/local state local and widen access only where a moved top-level declaration has a proven cross-file dependency.

### Defer

- Broad service-container or root-observation redesign.
- Splitting protected contract/domain files solely to reduce line counts.
- Mass renaming, a universal component system, or new MVVM layers.

## Duplicate-component map

### Safe now

- `ScenicRoyalSetupCard` and `ScenicRoyalClientEditorCard` are exact labeled-card presentation duplicates. Replace them with one narrow shared Scenic Royal labeled-card primitive.
- Today and Setup duplicate the same `LifeRoutePlaceKind` symbol switch. Centralize the presentation mapping while leaving historical copies untouched.
- The Schedule weekday header is a static presentation-only loop. Its offset is now used solely as SwiftUI identity; the exact labels remain `M, T, W, T, F, S, S` in the same order. The identity is not read by a binding, tag, action, selection owner, date calculation, persistence path, or scheduling path. This is therefore structural identity hygiene, not a runtime/product bug fix.

### Keep separate

- Feature-specific Schedule, Tools, Resource, Setup, Client, and Theme components.
- Material roles whose visual differences are intentional.
- Glass grouping and container structure, which affects iOS 26 optical composition.

## Dead-code and Xcode-membership evidence

### Safe now

The following compiled presentation declarations have no shipping or retained-historical callsites and no persistence, migration, bridge, or target-boundary role:

- `LegacyVisualTimerView`
- `LifeRoutePageBackground`
- `LifeRouteSectionLabel`
- `LifeRoutePill`
- `LifeRouteThemeBackdrop`
- `LifeRouteCinematicThemeThumbnail`

`ContentView.swift` has a detached `PBXBuildFile` object but is absent from the app Sources phase. Remove only that orphan project object; retain the historical file reference and file itself.

`SessionToolsNativeView` is not used by shipping navigation, but the excluded
historical `ContentView.swift` still references it. It and its private
`SessionToolCard` dependency are therefore retained unchanged under the
historical-dependency rule.

### Defer or retain

- `ContentView.swift`, `ClientViews.swift`, `LifeRouteWebView.swift`, bundled web assets, `LiveActivityManager.swift`, shared/historical Live Activity trees, and repository snapshots.
- Dormant Visual Schedule presentation and architecture while it remains intentionally hidden and validation-protected.
- Persisted identifiers, `LegacyMigrationCore.swift`, theme migration and renderer fallbacks.
- `codemagic.yaml`, `LifeRoute_GitHub_Upload_Fresh/`, and remote historical branches.

No file will be deleted based only on its name, age, or appearance.

## Validation and build-speed findings

- Current membership validation searches raw project text; the detached `ContentView.swift` build object proves this does not establish real target membership.
- Full validation reloads the Swift source inventory after fast validation and Simulator smoke repeats three contract suites already owned by full validation.
- Each focused contract runner independently compiles. The measured 5.33 seconds across four runners dominates the 5.79-second full validation baseline. A first parallel orchestration measurement took 5.48 seconds, so compiler-process contention did not improve the cold path on this Mac.
- Full validation can report success after focused runners skip for a missing `swiftc`; canonical full validation should require Swift.
- Contract minima are documented but not directly machine-enforced.
- Active script modes are already correct; no executable-bit repair is needed.
- The Xcode project is small and has no package or custom build-phase overhead. Persistent caches, shared Debug/Release DerivedData, and project-format changes are not justified.

Planned safe changes:

- Parse actual `PBXSourcesBuildPhase` membership and cardinality, including detached/duplicate build-file detection.
- Add one deterministic aggregate contract runner that preserves each focused entry point and emits suites in stable order.
- Centralize Swift compilation behind a content-addressed per-suite cache. Exact source, fixture, runner, and compiler identity determine reuse; changed contracts recompile, while UI-only iterations reuse the exact compiled fixture binary.
- Require `swiftc` for canonical full validation.
- Reuse one source snapshot between fast and full semantic validation.
- Remove duplicate contract execution from Simulator smoke while retaining full validation as the canonical contract gate.
- Machine-enforce minimum passing totals: Day Route 30, Session Note 162, Visual Timer feedback 47, Runtime feedback 9.
- Keep preparation, fast validation, full validation, and every focused runner as stable public entry points.

Workflow-file changes that touch release behavior are outside this cleanup. Narrow validation-CI path coverage may be updated only if it does not change release or TestFlight ownership.

## Performance and ownership findings

### Pass and protect

- Exactly one persistent Scenic Royal environment host is installed at the production root.
- Exactly one shared environment timeline drives Dynamic and scenery phases at 15 fps, pausing for Reduce Motion or inactive scenes.
- The high-frequency tick is bounded to the backdrop subtree rather than published through broad environment observation.
- Dynamic-plus-scenery composition no longer has the former redundant outer compositing group. Remaining renderer-local groups are appearance-sensitive.
- iOS 26 native Liquid Glass, accessibility opaque treatment, and iOS 16-25 material fallbacks are centralized and structurally sound.
- The retained haptic-generator pool is bounded and reused.
- Five independent navigation stacks and the iOS 26 native navigation-bar ownership repair remain intact.
- No evidence of monotonic retained-object or memory growth was found.

### Defer

- Visual Timer and theme-feedback code both mutate the process-wide audio session. This is an evidence-backed ownership risk, but no failure was demonstrated and a naïve repair could break protected Ring/Silent behavior. It requires a separate coordinated ownership design and narrow physical QA.
- Root observable fan-out is plausible but not demonstrated as a performance problem.
- Royal Current compositing and nested glass density remain watchpoints, not proven defects.
- ETTrace is not warranted without a repeatable narrow CPU/jank symptom.
- Memgraph is not warranted without repeatable retained-growth evidence.

## Documentation findings

- The root handoff still describes Build 117 work and forbids the now-completed Build 118 dispatch; archive that narrative and replace it with a compact current checkpoint.
- Add a durable application architecture and ownership map and link it from the README.
- Make native SwiftUI shipping authority, quarantined WebView history, current validation ownership, local Mac scheme handling, exact Build 118 baseline, and deferred legacy decisions unambiguous.
- Harmonize stale release-authorization prose with current repository policy without changing workflows or authorizing this cleanup to release.
- Mark obsolete reconstruction guidance as historical; do not delete ambiguous historical material.

## Planned files and commit breakdown

Planned change groups:

1. **SwiftUI/component structure**
   - Split the oversized active view/renderer files along existing ownership boundaries.
   - Consolidate the exact labeled-card and place-symbol duplicates.
   - Correct Schedule weekday identity.
2. **Proven dead code, project membership, and validation architecture**
   - Remove only proven zero-callsite declarations and the detached project object.
   - Add robust Sources-phase validation and deterministic contract orchestration.
3. **Documentation**
   - Archive the old handoff, publish current architecture/validation ownership, and record deferrals.

Protected files and boundaries include release/TestFlight workflows, signing/version metadata, persisted identifiers and migrations, WebView/history, protected domain contracts, navigation ownership, Dynamic/scenery cadence and composition, glass behavior, timer/audio/haptic semantics, and physical-QA status.

## Risks and automatic-continuation decision

Primary risks are accidental access-control breakage during mechanical file moves, Xcode membership drift, source-marker assumptions tied to old filenames, and optical changes from over-consolidating Scenic Royal components. The implementation will use existing top-level boundaries, preserve declaration bodies, update explicit project membership, and validate after each bounded slice.

The safe-now scope is behavior-neutral, Build 118 physical QA has reported no blocker, the cleanup branch is isolated from the release baseline, and the planned diff remains reviewable. Stage 2 may therefore continue automatically. Merge, TestFlight, and public release remain prohibited.

## Stage 2 implementation outcome

The approved safe-now cleanup was implemented without changing product-domain
owners or release configuration:

- `LifeRouteApp.swift` now contains the app entry, root chrome/appearance, and
  Debug fixtures. Theme identity, compatibility presentation, Dynamic rendering,
  and scenery rendering are owned by four dedicated files.
- The former session-tools presentation surface is split into its shipping
  notes/planning owner, visual-support library owner, and visual-builder owner.
  AI Session Plan and Visual AI Studio also have dedicated files.
- One shared `ScenicRoyalLabeledCard` replaces the two exact Setup/Client
  wrappers, and `LifeRoutePlaceKind.scenicRoyalSystemImage` owns the duplicated
  Today/Setup presentation mapping.
- Six zero-callsite presentation declarations were removed. No source or asset
  file was deleted. `SessionToolsNativeView` remains because the retained
  historical `ContentView.swift` references it.
- The detached `ContentView.swift` `PBXBuildFile` object was removed. Its file
  reference and historical source remain outside the shipping Sources phase.
- The weekday row uses positional identity only. Its `M, T, W, T, F, S, S`
  order and every persistence, selection, date, scheduling, and rendered-content
  behavior remain unchanged.

## After-cleanup inventory and large-file map

- Swift sources under `LifeRoute/`: 57 (49 before)
- Widget Swift sources: 1 (unchanged)
- App Sources phase: 54 tracked Swift files (46 before)
- Live Activity Sources phase: 2 entries (unchanged)
- Unique tracked Swift files compiled across both targets: 55 (47 before)
- Duplicate, missing, extra, or detached Sources build entries: none

| Former owner | Before | Current owner(s) | After |
| --- | ---: | --- | ---: |
| `LifeRouteApp.swift` | 3,684 | `LifeRouteApp.swift` | 267 |
|  |  | `LifeRouteTheme.swift` | 556 |
|  |  | `LifeRouteLegacyComponents.swift` | 484 |
|  |  | `LifeRouteDynamicThemeRenderer.swift` | 1,363 |
|  |  | `LifeRouteSceneryThemeRenderer.swift` | 849 |
| `SessionToolsViews.swift` | 3,037 | `SessionToolsViews.swift` | 569 |
|  |  | `ClientVisualSupportViews.swift` | 989 |
|  |  | `ClientVisualBuilderViews.swift` | 1,266 |
| `AIClinicalToolsViews.swift` | 1,160 | `AIClinicalToolsViews.swift` | 972 |
|  |  | `AISessionPlanBuilderView.swift` | 189 |
| `V054ToolsDashboard.swift` | 609 | `V054ToolsDashboard.swift` | 220 |
|  |  | `VisualAIAssistedStudioView.swift` | 391 |

Protected domain/contract files were not split merely to reduce their line
counts. `SessionNoteContracts.swift` remains the largest active source at 2,072
lines; historical `ContentView.swift` remains 1,742 lines outside the app target.

## Validation architecture outcome

- `prepare_build.sh`, fast validation, full validation, and every focused
  contract runner remain stable public entry points.
- `run_contract_tests.sh` runs all four suites in parallel while preserving
  deterministic captured output.
- `run_swift_contract_test.sh` provides content-addressed per-suite compilation.
  Cached binaries still execute every assertion.
- Full validation no longer repeats its source snapshot and Simulator smoke no
  longer recompiles contracts already owned by the full gate.
- Actual `PBXSourcesBuildPhase` parsing now rejects missing, extra, duplicate,
  and detached source objects.
- Contract floors are machine-enforced: Day Route 30, Session Note 162, Visual
  Timer feedback 47, and Runtime feedback 9.
- Simulator smoke now waits five seconds by default before each capture. The
  previous two-second window produced background-only evidence on this Mac even
  though the foreground rendered later. The settle interval is configurable via
  `LIFEROUTE_SMOKE_SETTLE_SECONDS` for controlled measurements.

## Final local validation snapshot

| Check | Baseline | After | Honest result |
| --- | ---: | ---: | --- |
| Preparation | 0.12 s | 0.14 s | 0.02 s slower |
| Fast validation | 0.05 s | 0.23 s | 0.18 s slower; membership checks are stronger |
| Cold full validation | 5.79 s | 5.37 s | 0.42 s faster |
| Cached full validation | not available | 1.21 s | new focused-iteration path |
| No-change incremental Debug build | 1.97 s | 5.39 s | 3.42 s slower |
| Fresh Debug Simulator build | 110.68 s | 245.92 s | 135.24 s slower |
| Fresh Release Simulator build | 116.38 s | 253.54 s | 137.16 s slower |
| Canonical Simulator smoke | 34.57 s | 59.44 s | 24.87 s slower; capture settle changed |

The build results are single samples from the same Mac. They establish no clean
or incremental build-speed improvement; the measured build regressions remain a
review risk and must not be explained away. The validation-cache improvement is
real for unchanged focused contract work, while preparation/fast entry points
remain effectively sub-second despite their small regressions.

Validation results:

- Preparation, fast validation, cold full validation, and cached full
  validation passed.
- Day Route passed 30 assertions; Session Note passed 162; Visual Timer feedback
  passed 47; Runtime feedback passed 9. No contract floor was reduced.
- Fresh Debug and Release Simulator builds passed. The main app and embedded
  Live Activity extension compiled in both configurations.
- Unexpected compiler warnings: 0. Two exact no-AppIntents metadata notices were
  classified as known Xcode 26.6 toolchain output.
- Canonical Today, Schedule, Tools, Resources, and Setup launches passed. A
  representative Visual Timer deep route rendered with root-toolbar suppression.
- Canyon Day, Royal Current Reduce Motion, Arctic Day, and Rainforest Day
  fixtures rendered and were visually inspected.
- Runtime review found no app crash, fault, assertion, or hang. The only app-log
  diagnostic was the previously observed Simulator CoreAudio factory-registration
  message during the audible Visual Timer fixture.
- `git diff --check`, shared-scheme integrity, local-scheme ignore state, target
  membership, and release/version metadata integrity passed.

No ETTrace or memgraph capture was warranted because the code-first audit and
runtime pass did not demonstrate a repeatable CPU/jank or retained-growth
symptom.

## Protected-boundary and deferral outcome

Routing, persistence, migration, calendar/provider, Visual Timer domain/audio,
Session Note contracts, navigation ownership, environment cadence/composition,
Live Activity behavior, signing, bundle identifiers, marketing/build versions,
and the TestFlight workflow were not changed. The shared scheme is byte-for-byte
unchanged; the local scheme remains ignored under `xcuserdata`.

Ambiguous WebView/history, dormant Visual Schedule architecture, persisted
identifiers, renderer/migration fallbacks, historical snapshots, and the
process-wide audio-session ownership risk remain explicitly deferred. Build 118
physical QA remains mandatory before any cleanup merge. Nothing in this branch
authorizes another TestFlight upload or an App Store release.
