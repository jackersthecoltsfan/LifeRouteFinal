# POST-v0.9.1 SANITATION / VELOCITY CHECKPOINT

Recorded: 2026-09-01

## Gate and isolation

- Exact stable Build 123 baseline:
  `f9c2b13c4c8c7c19c67e3f118176635ea8576808`.
- Branch: `chore/post-v0.9.1-sanitation-v1`.
- Isolated worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-post-v0.9.1-sanitation-v1`.
- The branch and worktree were newly created from the exact baseline. The target
  path and branch did not contain unrelated state and no existing worktree or
  branch was deleted, reset, repurposed, or overwritten.
- Local `main` and `origin/main` resolved to the exact baseline at creation and
  throughout the pass.
- Protected shared-scheme SHA-256 remained
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.
- No Build 124, release repair, TestFlight action, release workflow change,
  signing change, entitlement change, bundle/version change, PR, merge, or
  `main` mutation occurred.

The code-only checkpoint before this evidence document is
`dc2dd8e` (`perf: use active architecture for local Debug`). The final branch
SHA is recorded in the external completion receipt because a commit cannot
truthfully embed its own SHA.

## Scope result

The repository-wide audit was completed, but v1 kept exactly five small,
independently rollbackable slices:

1. use the active architecture for a specific local Debug destination;
2. cache content-addressed Swift contract binaries;
3. compile Debug Swift with `-Onone`;
4. remove historical client presentation from the shipping compile surface;
5. consolidate validation ownership and enforce accepted contract floors.

No production Swift implementation was edited. In particular, ordinary glass,
`ScenicRoyalMaterials`, Visual Timer/audio, navigation/container lifecycle,
environment host/scenery effects, canonical routing, Live Location, Live Day,
Live Activity, Session Note, and Session Plan production behavior remain frozen.

## Audit execution and tool boundaries

- Three read-only sub-agents had non-overlapping ownership: build/dependency
  graph, architecture/source ownership, and validation/test redundancy. They did
  not edit, build, or run timing commands.
- Code Ontology Companion was limited to read-only doctor/preflight checks. Its
  graph/snapshot support covers Java/Spring and Python, not Swift, so no ontology
  workspace, snapshot, network request, or LLM annotation was created. Swift and
  PBX ownership were traced directly instead.
- SwiftUI Expert guidance was used to keep state/view ownership and dependency
  fan-out central to the audit; no SwiftUI production refactor was justified.
- Engineering Guardrails kept each write, benchmark, validation, and commit
  narrow and independently reversible.

## Controlled environment

- Hardware: `Mac17,5`, 8 GiB RAM, 6 logical CPUs.
- macOS: 26.5.1 (`25F80`).
- Xcode: 26.6 (`17F113`).
- iPhone Simulator SDK: 26.5 (`23F81a`).
- Swift compiler: Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`).
- Canonical destination: `generic/platform=iOS Simulator`.
- Local-developer destination: booted iPhone 17 Pro on iOS 26.5,
  `4EFE59CA-415E-4E1F-AEA4-4BA61E71177A`.
- Configuration: Debug or Release as shown below; code signing disabled.
- All builds and timing runs were serialized. Before timing, active
  `xcodebuild` and `swiftc` processes were checked; sub-agents did not build.
- Fresh builds used a new DerivedData directory. Incremental families reused a
  warmed directory and rebuilt the original source variant between measured
  trials.

### Exact commands

Preparation and validation:

```bash
/usr/bin/time -p bash scripts/prepare_build.sh
/usr/bin/time -p bash scripts/validate_fast.sh
/usr/bin/time -p env LIFEROUTE_CONTRACT_CACHE_DIRECTORY="$CACHE" \
  bash scripts/validate_full.sh
```

Canonical Debug:

```bash
/usr/bin/time -p xcodebuild \
  -project LifeRoute.xcodeproj \
  -scheme LifeRoute \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DEBUG_DERIVED_DATA" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG \
  CODE_SIGNING_ALLOWED=NO \
  -showBuildTimingSummary \
  build
```

Canonical Release used the same form with `-configuration Release`, a fresh
Release DerivedData directory, and without the explicit Debug compilation
condition.

Specific local Debug architecture isolation:

```bash
/usr/bin/time -p xcodebuild \
  -project LifeRoute.xcodeproj \
  -scheme LifeRoute \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=4EFE59CA-415E-4E1F-AEA4-4BA61E71177A' \
  -derivedDataPath "$LOCAL_DERIVED_DATA" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG \
  CODE_SIGNING_ALLOWED=NO \
  -showBuildTimingSummary \
  build
```

For the isolated donor-setting comparison only, the active case added
`ONLY_ACTIVE_ARCH=YES` on the command line. The kept project setting now makes
that explicit only where Xcode has a concrete destination architecture.

### DerivedData strategy used

- Exact Build 123 generic Debug baseline and incrementals:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/debug-dd`.
- Kept Debug/pruned-surface generic incrementals:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/debug-client-pruned-dd`.
- Exact Build 123 Release:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/release-dd`.
- Final fresh Release:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/release-final-dd`.
- Specific local dual-architecture Debug:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/local-dual-dd`.
- Specific local active-architecture Debug:
  `/tmp/liferoute-post-v091-sanitation-v1.HRuqdp/local-active-dd`.

No benchmark runner was added to the repository; the exact commands, edits,
raw trial values, medians, and task summaries below are sufficient to reproduce
the comparison without adding maintenance surface.

## Canonical timing matrix

Three-run entries show raw wall times followed by the median. Fresh builds and
cold cache checks are single runs as authorized.

| Workflow | Exact Build 123 | Sanitation v1 | Change |
| --- | ---: | ---: | ---: |
| Preparation | `0.39, 0.07, 0.06`; median `0.07 s` | `0.13, 0.05, 0.05`; median `0.05 s` | `-0.02 s` / `-28.6%` |
| Fast validation | `0.06, 0.06, 0.06`; median `0.06 s` | `0.05, 0.05, 0.05`; median `0.05 s` | `-0.01 s` / `-16.7%` |
| Full validation | `11.64, 11.12, 11.84`; median `11.64 s` | cold `10.10 s`; warm `3.78, 3.64, 3.76`; median `3.76 s` | cold `-13.2%`; warm `-67.7%` |
| Fresh generic Debug | `201.11 s` | `101.70 s` | `-99.41 s` / `-49.4%` |
| Fresh generic Release | `223.99 s` | `188.37 s` | `-35.62 s` / `-15.9%` |
| No-change generic Debug | `4.29, 1.24, 1.05`; median `1.24 s` | `1.40, 1.20, 1.21`; median `1.21 s` | `-0.03 s` / `-2.4%` |

The final Debug clean value was measured after `-Onone` and compile-surface
pruning. Later changes touched validation scripts plus `ONLY_ACTIVE_ARCH`; Xcode
resolves that setting to `NO` for the generic destination, so the canonical
generic build configuration and architecture coverage remain the measured
dual-architecture path.

## Timestamp / input-invalidation lower-bound results

These timestamp-only runs measure the minimum build-system cost of invalidating
the named file. They are not representative source-edit results.

| Input | Exact Build 123 raw / median | `-Onone` raw / median | Change |
| --- | ---: | ---: | ---: |
| Leaf: `ResourcePortalViews.swift` | `5.39, 5.80, 5.51`; `5.51 s` | `4.99, 4.44, 4.09`; `4.44 s` | `-19.4%` |
| Shared style: `ScenicRoyalDesignSystem.swift` | `6.10, 4.97, 5.60`; `5.60 s` | `4.45, 4.17, 4.03`; `4.17 s` | `-25.5%` |
| Planning/core: `RoutingLocationDomain.swift` | `7.99, 7.91, 8.12`; `7.99 s` | `5.05, 4.65, 5.15`; `5.05 s` | `-36.8%` |

The first shared-style timestamp run (`7.06 s`) was discarded because restoring
the prior file timestamp contaminated it. The three listed runs are the clean,
comparable family. Each listed timestamp family compiled only the named primary
file for `arm64` and `x86_64`.

## Real reversible source-byte edits

The following exact temporary changes were applied with patch-based editing,
never committed, never physically run, and restored after every measured trial:

```diff
-            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
+            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact + 0)

-        static let standard: CGFloat = 12
+        static let standard: CGFloat = 12.0

-        self.minimumVisitMinutes = max(5, minimumVisitMinutes)
+        self.minimumVisitMinutes = max(minimumVisitMinutes, 5)
```

Original SHA-256 values were verified after every family:

- `ResourcePortalViews.swift`:
  `99593ae4cda81731a236a81fffc21f092bb7f85b7886295c651f3b8d12e8842a`.
- `ScenicRoyalDesignSystem.swift`:
  `7518e8c04a4f9aec28bbef986996fed31e6a2136015458d9b2f518ffdeb8770d`.
- `RoutingLocationDomain.swift`:
  `6bb2d38b8fca6bca3b1302aa1f6582080f3f57b8a2fa18515e3cfc5697dd032c`.

For an exact baseline comparison in the same worktree and paths, the project
file was temporarily restored by patch to its exact Build 123 bytes
(`74103165292e59960b822e89566fc998e4d5d35d631844a692a251f4ab25f485`),
then patched back to the sanitation configuration. No checkout, reset, branch
move, or commit rewrite was used. The final project-file hash before checkpoint
documentation was
`f31df2942d3bbde3d8c00c992433bd0a4fee07fa2f6d17a31fd254416676425b`.

### Generic Simulator source-edit results

| Source edit | Exact Build 123 raw / median | Sanitation raw / median | Change |
| --- | ---: | ---: | ---: |
| Leaf SwiftUI | `7.98, 6.37, 10.99`; `7.98 s` | `7.28, 15.13, 10.12`; `10.12 s` | `+2.14 s` / `+26.8%` |
| Shared style/theme | `26.41, 29.03, 22.52`; `26.41 s` | `22.28, 25.82, 22.19`; `22.28 s` | `-4.13 s` / `-15.6%` |
| Planning/core | `11.47, 11.58, 19.84`; `11.58 s` | `9.53, 10.37, 11.25`; `10.37 s` | `-1.21 s` / `-10.4%` |

The generic leaf wall-time family is noisy and regressed. It is retained as a
real measured regression, not explained away. Its compiler graph stayed at one
unique primary file and two SwiftCompile tasks. The kept unoptimized Debug path
uses Xcode's Debug dylib/stub topology, so the app performed four link tasks
instead of the optimized baseline's two. The extension, assets, and scripts did
not rebuild. This tradeoff is accepted because the ordinary local path below is
materially faster, generic clean Debug is 49.4% faster, generic shared/core
edits improve, and CI uses clean rather than incremental generic builds.

### Ordinary local-developer path

This comparison isolates only active-architecture behavior on the booted iPhone
17 Pro destination. Both sides already include `-Onone` and the pruned compile
surface.

| Workflow | Local dual architecture | Local active architecture | Change |
| --- | ---: | ---: | ---: |
| Fresh Debug | `121.28 s`, `x86_64 arm64` | `62.53 s`, `arm64` | `-58.75 s` / `-48.4%` |
| Real leaf edit | `8.71, 7.82, 8.88`; median `8.71 s` | `5.33, 6.15, 4.78`; median `5.33 s` | `-3.38 s` / `-38.8%` |

Effective settings prove the local/CI separation:

| Destination | `ARCHS` | `ONLY_ACTIVE_ARCH` | Optimization |
| --- | --- | --- | --- |
| Booted iPhone 17 Pro | `arm64` | `YES` | `-Onone` |
| Generic Simulator / canonical CI | `arm64 x86_64` | `NO` | `-Onone` |

The local leaf family ran one SwiftCompile task and two app link tasks. The dual
family ran two SwiftCompile tasks and four app link tasks. Both compiled only
`ResourcePortalViews.swift`; neither rebuilt/relinked the Live Activity
extension, ran asset-catalog work, or ran build scripts.

## Task-level rebuild fan-out

| Generic edit | Swift work | App link | Extension | Assets | Scripts |
| --- | --- | ---: | --- | --- | --- |
| No change | no SwiftCompile | none | no compile/link | none | none |
| Leaf byte edit | 2 tasks; 1 unique primary, `ResourcePortalViews.swift` | baseline 2; sanitation 4 | no compile/link | none | none |
| Planning/core byte edit | 2 tasks; 1 unique primary, `RoutingLocationDomain.swift` | baseline 2; sanitation 4 | no compile/link | none | none |
| Shared-style byte edit | 14 tasks; 19 unique primary files | baseline 2; sanitation 4 | no compile/link | none | none |

The shared-style primary set was identical before and after:
`ScenicRoyalDesignSystem`, `ScenicRoyalMaterials`, `ScenicRoyalComponents`,
six feature Scenic Royal component/view owners, the Today/Schedule/Tools/Setup/
Theme/Address/Client screens, Day Route planning view, and Resource Portal view.
This is a real 19-file dependency-fan-out hotspot. V1 deliberately does not
split or wrap it without a design that reduces those edges and proves a faster
source-edit family.

Fresh builds appropriately compiled both app and Live Activity targets and ran
one asset-catalog task. Final Release produced dual-architecture app and
extension products. No incremental representative edit unexpectedly rebuilt
the extension, assets, or scripts.

## Ranked sanitation findings

Ranking weights recurring frequency and seconds saved, then confidence,
reduced ownership/steps, rollback ease, and regression risk.

### 1. Active architecture for the specific local Debug destination — kept

- Friction: local Simulator builds defaulted to both simulator architectures
  even when a concrete arm64 device was selected.
- Change: add one project Debug `ONLY_ACTIVE_ARCH = YES` setting. Xcode forces
  it back to `NO` for the generic destination.
- Practical benefit: local clean Debug `-48.4%`; real local leaf edit `-38.8%`.
- Files: `LifeRoute.xcodeproj/project.pbxproj`,
  `scripts/validate_current.py`.
- Risk: low; Debug-only and effective-setting coverage proves canonical generic
  builds remain dual architecture.
- Rollback: one independent commit and one validator assertion.

### 2. Content-addressed Swift contract binaries — kept

- Friction: five full-validation runners recompiled unchanged contract binaries
  on every run.
- Change: one shared runner owns compiler discovery, exact cache identity,
  private permissions, atomic publication, and execution; focused entry points
  remain stable and sequential.
- Practical benefit: cold full `-13.2%`; warm full `-67.7%`, saving `7.88 s`
  per repeated full validation.
- Files: new `scripts/run_swift_contract_test.sh`, five focused runner scripts,
  and `scripts/validate_current.py`.
- Risk: low-to-moderate stale-cache risk, bounded by a key containing the
  compiler path/version, OS/architecture, helper bytes, and every input-source
  hash. A temporary runtime-fixture edit created a distinct cache entry and the
  original hash was restored.
- Rollback: one independent commit; public runner names are unchanged.

### 3. Disable Swift optimization for Debug — kept

- Friction: the baseline project inherited `-O` for Debug, making clean and
  substantive source edits unnecessarily expensive.
- Change: explicit project Debug `SWIFT_OPTIMIZATION_LEVEL = -Onone` plus a
  semantic validator assertion.
- Practical benefit: generic clean Debug `-49.4%`; real shared-style edit
  `-15.6%`; real planning/core edit `-10.4%`; timestamp lower bounds improved
  `19.4%` to `36.8%`.
- Files: `LifeRoute.xcodeproj/project.pbxproj`,
  `scripts/validate_current.py`.
- Risk: low-to-moderate because Debug link topology changes; the noisy generic
  leaf regression is documented above. Release optimization and output are
  unchanged.
- Rollback: one independent commit.

### 4. Remove historical client presentation from shipping compilation — kept

- Friction: `ClientViews.swift` added 555 lines to every app compilation even
  though its only live typed callsite was in excluded historical
  `ContentView.swift`.
- Change: remove only its `PBXBuildFile`/Sources membership and the already
  detached `ContentView.swift` build-file object; retain both source files and
  file references.
- Practical benefit: app Sources entries `50 -> 49`; unique compiled Swift files
  across app/extension `51 -> 50`; 555 historical source lines no longer enter
  shipping builds. Fresh Debug remained within noise at the slice boundary;
  final Release improved without a behavior change.
- Files: `LifeRoute.xcodeproj/project.pbxproj`,
  `scripts/validate_current.py`.
- Risk: low after typed/dynamic/build-script/extension/preview/serialization
  tracing. `ClientProfilesView` is referenced only by excluded
  `ContentView.swift`; `ClientEditorView` is internal to `ClientViews.swift`.
- Rollback: one independent project-membership commit; no source deletion.

### 5. Validation ownership, floors, and CI path coverage — kept

- Friction: full validation loaded production Swift twice; workflow files were
  read twice; release-policy checks were full-only; contract-only changes could
  miss native CI; accepted assertion counts were report-only.
- Change: reuse one source snapshot, read one workflow map, run policy checks in
  fast validation, add contract helper/runner/fixture path globs to both native
  CI triggers, and enforce five executable minimum floors.
- Practical benefit: preparation/fast remain effectively instantaneous; common
  policy failures surface earlier; contract changes cannot silently bypass the
  native workflow; floor regressions stop immediately.
- Files: `.github/workflows/ios-ci.yml`, `scripts/validate_current.py`, and five
  executable fixture files.
- Risk: low; this can trigger validation more correctly, but does not change
  release or TestFlight ownership.
- Proof: temporarily raising Runtime Feedback to 26 failed with exit 133 and
  `found 25`; the exact source hash was restored and the accepted 25 passed.
- Rollback: one independent commit.

## Dead and duplicated code result

- No Swift declaration or source file was deleted.
- One genuinely obsolete compile dependency was removed:
  `ClientViews.swift` remains available for archaeology but is no longer part of
  the shipping app Sources phase.
- One detached `ContentView.swift in Sources` `PBXBuildFile` object was removed;
  it was never in the active Sources phase.
- Five runners no longer duplicate compiler discovery, temporary binary
  creation, cleanup, and invocation. Their stable focused entry points now
  delegate to one 48-line owner.
- No dynamic lookup, Objective-C selector, notification/deep-link name, App
  Intent, Live Activity extension, preview/fixture, protocol, asset-name,
  serialization, reflection, build-script, or active validation dependency was
  found for the removed compile membership.

## Validation result

- Day Route: `163` assertions.
- Session Note: `162` assertions.
- Visual Timer feedback: `119` assertions.
- Runtime Feedback: `25` assertions.
- Scenery Effects: `54` assertions.
- Preparation: pass.
- Fast validation: pass.
- Cold and warm full validation: pass.
- Fresh generic Debug at the final native compile surface: pass, app plus
  extension, dual architecture, zero unexpected warnings. The final branch also
  passed three no-change generic Debug builds; its later setting resolves
  identically for the generic destination and its other later changes are
  validation-only.
- Final generic Release: pass, app plus extension, dual architecture, zero
  unexpected warnings.
- Known Xcode no-AppIntents notices: 2; classified by the existing assessor.
- Contract-cache invalidation test: pass.
- Negative assertion-floor test: expected failure, then restored positive pass.

## Rejected or deferred findings

- PR #127-style broad ownership extraction: rejected. Its recorded before/after
  checkpoint increased compiled Swift files `47 -> 55`, no-change Debug
  `1.97 -> 5.39 s`, fresh Debug `110.68 -> 245.92 s`, and fresh Release
  `116.38 -> 253.54 s`. Organization did not justify those regressions.
- Wholesale transplant or cherry-pick from `4ad63319` or `f1ceab7`: rejected.
  Only the contract-cache and Debug-setting ideas were selectively
  reimplemented and retested against Build 123.
- Parallel contract compilation: rejected. It adds contention on this 8 GiB Mac
  and donor evidence did not improve the cold path; focused runners remain
  sequential and deterministic.
- Repository-wide view/file splits, folder redesign, mass renames, universal
  component layers, protocol/service containers, and MVVM expansion: rejected
  for v1.
- Broader removal of apparently dead presentation declarations: deferred. A
  simple text search is insufficient for the required dynamic/intent/extension/
  serialization safety proof, and the compile-surface win already came from the
  one fully traced historical file.
- `ScenicRoyalDesignSystem` decomposition: deferred. A real token edit fans out
  to 19 primary files, but adding files/wrappers without reducing that graph
  risks repeating PR #127.
- Exact labeled-card and place-symbol presentation duplicates: deferred. The
  additional shared abstraction did not yet prove fewer edits or lower compile
  fan-out.
- Removing repeated contract execution from Simulator smoke: deferred. The
  runtime-smoke ownership boundary is behavior-sensitive and outside the five
  best low-risk slices.
- Ordinary-glass opacity and Visual Timer physical loudness: explicitly
  deferred product limitations; untouched.
- Additional benchmark tooling: rejected as unnecessary repository complexity.

## Commits and changed files

Implementation commits, in order:

1. `93e6d8422ffd5125dc3133ada63656aa181f1ab6` —
   `perf: disable Swift optimization for Debug`
2. `711e385b91481c60c999c59d02c9289c6b3109ea` —
   `chore: exclude historical client UI from builds`
3. `4e4887a7e763ef0d3901293cbe2d9cb2c751dfcb` —
   `perf: cache Swift contract binaries`
4. `32f09ec` — `chore: tighten validation ownership and floors`
5. `dc2dd8e` — `perf: use active architecture for local Debug`

Changed implementation/validation files:

- `.github/workflows/ios-ci.yml`
- `LifeRoute.xcodeproj/project.pbxproj`
- `scripts/run_swift_contract_test.sh`
- `scripts/run_day_route_contract_tests.sh`
- `scripts/run_session_note_contract_tests.sh`
- `scripts/run_visual_timer_feedback_contract_tests.sh`
- `scripts/run_runtime_feedback_contract_tests.sh`
- `scripts/run_scenery_effect_contract_tests.sh`
- `scripts/day_route_contract_tests.swift`
- `scripts/session_note_contract_tests.swift`
- `scripts/visual_timer_feedback_contract_tests.swift`
- `scripts/runtime_feedback_contract_tests.swift`
- `scripts/scenery_effect_contract_tests.swift`
- `scripts/validate_current.py`

Checkpoint documentation adds this report and refreshes
`LIFEROUTE_HANDOFF.md`. No release workflow file was changed.

## Recommendation

All five slices are safe to keep together, and each can also be reverted
independently. Preserve the local/generic architecture distinction, the exact
cache key inputs, and the executable assertion floors. Do not pursue further
Scenic Royal or mega-file extraction until a proposed edge reduction beats the
real source-byte shared-style benchmark and does not regress the local recurring
loop by more than the accepted threshold.

Stop at `POST-v0.9.1 SANITATION / VELOCITY CHECKPOINT`. Do not merge.
