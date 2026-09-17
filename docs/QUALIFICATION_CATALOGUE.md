# LifeRoute Qualification Catalogue

Status: Phase 5D catalogue metadata and controlled-deduplication companion
Baseline: `4c2bb0a68ff3c423b8f8f1d790475e34fe259925` (tree `5f02191976fd7e4be060892dd2c74a790a8cc8ea`)
Catalogue version: `1`
Last reviewed: 2026-09-17

This document is the human-readable companion to
[`scripts/qualification_catalogue.json`](../scripts/qualification_catalogue.json).
The JSON file is the machine-readable authority for gate IDs, commands,
dependencies, prerequisites, and evidence classification. The catalogue and
its Phase 5C companion checker do not change which validators run, how builds
are produced, or how release and physical QA are approved; the workflow diff
only schedules the already-defined automatic gates for their declared inputs.

## Qualification semantics

The catalogue separates proof levels. A successful lower-level entry is not a
success for any higher-level entry.

| Proof level | What it proves | What it does not prove |
|---|---|---|
| Wrapper/alias | That an existing command sequence was selected | An additional independent qualification result |
| Static semantic validation | Source, project, resource, and policy invariants | Swift compilation, runtime behavior, visual quality, or owner acceptance |
| Executable Swift fixture | The supplied production declarations and fixtures compile and pass on the host | Shipping-target compilation, Simulator behavior, physical behavior, or owner acceptance |
| Xcode native build | The requested app/extension configuration compiles | Runtime behavior, signed release identity, physical behavior, or approval |
| Simulator runtime | The supplied app launches and produces the requested Simulator observations | Physical-device behavior, final perceptual approval, or release approval |
| Evidence-generation harness | A retained manifest, log, screenshot, video, result bundle, or report was produced | That the evidence is correct, accepted, or physically representative without review |
| Signed release identity | The explicitly authorized SHA produced the checked archive/product identity | TestFlight availability, physical QA, or release approval |
| Physical QA / owner acceptance | The owner-controlled device or visual decision was completed | Any unrelated gate not included in that decision |

In particular:

- Simulator PASS is not physical QA PASS.
- TestFlight upload is not release approval.
- Executable contract PASS is not owner acceptance.
- Artifact existence is not signed identity proof.
- A stored receipt may identify prior evidence but cannot replace a required
  fixture execution, native build, physical check, or owner decision.

## Gate catalogue

The current default path contains the first nine automatic gates below. The
remaining entries are explicit specialized, release, or owner gates so they
are discoverable without being silently promoted into ordinary CI.

| ID | Gate | Scope | Command | Runtime class | Automatic/manual | Local/CI owner | Prerequisites | Evidence | Simulator/device | Physical QA | Entry kind |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `Q-PREP` | Canonical preflight | Required canonical files and the fast semantic entrypoint | `bash scripts/prepare_build.sh` | Wrapper over static validation | Automatic | Local; `.github/workflows/ios-ci.yml` current-validation and native-validation | None | stdout only | None | No | Wrapper/alias |
| `Q-SEM-FAST` | Current semantic fast validation | Plists, icon, project/version identity, active build path, navigation, themes, clients, resources, setup, clinical/ABA, release/Web policy | `bash scripts/validate_fast.sh` | Python static semantic validation | Automatic | Local; `.github/workflows/ios-ci.yml` and policy/Pages workflows | None | stdout only | None | No | True gate |
| `Q-SEM-FULL` | Current semantic full validation | Fast validation plus Calendar/Routing/Persistence, Timer/Live Activity semantics, executable contract wrappers, route and thumbnail fixtures | `bash scripts/validate_full.sh` | Python plus executable Swift/Python fixtures | Automatic | Local; `.github/workflows/ios-ci.yml` current-validation and TestFlight | `Q-SEM-FAST` | stdout and scratch-only fixture outputs | None | No | True gate |
| `Q-STORAGE` | Storage scratch/evidence contract | Approved scratch roots, generated-directory policy, checkpoint-copy and closeout boundaries | `PYTHONDONTWRITEBYTECODE=1 python3 scripts/liferoute_storage_contract_tests.py` | Python executable contract | Automatic | Local; `.github/workflows/ios-ci.yml` current-validation | None | stdout only | None | No | True gate |
| `Q-NATIVE-FRAMEWORK` | Apple-framework contracts | macOS-only Visual Activity, Living Themes, and native Timer framework contracts | `bash scripts/run_visual_activity_contract_tests.sh && bash scripts/run_living_theme_tests.sh` | macOS Swift/framework fixture execution | Automatic when the macOS path invokes it | Local; `.github/workflows/ios-ci.yml` native-validation | `Q-SEM-FULL` | stdout and scratch-only fixture outputs | No app runtime required | No | True gate |
| `Q-BUILD-DEBUG` | Debug app/extension build | Debug-equivalent shipping app and Live Activity extension for iOS Simulator | `xcodebuild -project LifeRoute.xcodeproj -scheme LifeRoute -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` | Xcode native build | Automatic | Local; `.github/workflows/ios-ci.yml` native-validation | `Q-SEM-FULL`, `Q-NATIVE-FRAMEWORK` | Build log; CI-retained artifact | Generic Simulator destination; no launch | No | True gate |
| `Q-BUILD-RELEASE` | Release app/extension build | Release-equivalent unsigned Simulator build | `xcodebuild -project LifeRoute.xcodeproj -scheme LifeRoute -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` | Xcode native build | Automatic | Local; `.github/workflows/ios-ci.yml` native-validation | `Q-BUILD-DEBUG` | Build log; CI-retained artifact | Generic Simulator destination; no launch | No | True gate |
| `Q-WARNINGS` | Compiler warning budget | Debug/Release warning comparison and absolute warning policy | `python3 scripts/assess_xcode_warnings.py <debug-log> <release-log>` | Build-log/static analysis | Automatic | Local; `.github/workflows/ios-ci.yml` native-validation | `Q-BUILD-DEBUG`, `Q-BUILD-RELEASE` | Summary plus retained logs in CI | None | No | True gate |
| `Q-SIM-SMOKE` | Native Simulator smoke | Five roots, Timer deep destination, scenery day/night, Living Ocean motion/Reduce Motion, and ordinary glass screenshot | `bash scripts/run_simulator_smoke.sh <debug-app> <external-output>` | Simulator install/launch/screenshot | Automatic in macOS CI; manual-capable locally | `.github/workflows/ios-ci.yml` native-validation | `Q-BUILD-DEBUG`, `Q-WARNINGS` | External screenshots; CI artifact retained 14 days | Yes; Simulator only, currently selected automatically | No | True gate |
| `Q-FOCUSED-NATIVE` | Focused native harnesses | Root ownership/visibility/toolbar geometry, theme readability, board UI/export, and other explicit Simulator harnesses | See specialized validator list below; each requires an explicit app/Simulator/output contract | External native harness | Manual/specialized | Local-only unless a future workflow promotes a specific entry | Usually `Q-BUILD-DEBUG` | External manifest, log, result bundle, screenshot, or report | Yes; Simulator only | No | True gate family; not default CI |
| `Q-FEATURE-EVIDENCE` | Feature renderer/evidence harnesses | Living renderer, motion, ROI, thumbnail capture, BoardArtifact output, and preserved evidence directories | `bash scripts/run_living_theme_render_tests.sh` and applicable capture/export harnesses | Evidence-generation harness | Manual/specialized | Local-only | Applicable semantic and native gates | Durable external evidence when caller supplies a retained directory | Usually Simulator or native renderer; never implicitly physical | No, but owner visual review may follow | True gate family; not default CI |
| `Q-RELEASE-ID` | Exact signed release identity | Authorized SHA, current-main equality, signed archive, app/extension bundle identity, export, and upload | Manual dispatch of `.github/workflows/testflight.yml` with `authorized_sha` | Signed release identity | Manual authorization; CI-executed | GitHub Actions TestFlight workflow | Successful exact-SHA CI validation and explicit release authorization | CI release logs and IPA artifact; upload receipt | No Simulator requirement; physical use is separate | No | True gate |
| `Q-PHYSICAL-OWNER` | Physical and owner acceptance | Real-device behavior, perceptual visual decision, evidence retention, and release decision | Owner-controlled PTH/manual procedure | Physical QA and owner acceptance | Manual | Brandon/owner-controlled | Exact approved artifact and all PTH prerequisites | Owner receipt and retained physical evidence | Physical iPhone when required by the PTH | Yes | True gate |

## Current specialized/manual validators

These entries are intentionally discoverable but are not represented as
automatic default gates merely because they exist. They are not deletion
candidates, and absence from `validate_full.sh` is not proof of redundancy.

| Validator | Domain | Current role | Runtime/evidence class | Current owner |
|---|---|---|---|---|
| `scripts/run_root_navigation_ownership_tests.py` | Root/navigation | Compiles exact production declarations into a test app and launches it | Simulator harness with external output | Local/manual |
| `scripts/run_root_visibility_contract_tests.py` | Root/visibility | Compiles visibility/effect/Session Note declarations and launches a harness | Simulator harness with external output | Local/manual |
| `scripts/run_root_toolbar_geometry_tests.py` | Root/toolbar | Checks measured production root/toolbar frames or an existing probe | Static or Simulator measurement | Local/manual |
| `scripts/run_theme_readability_contract_tests.py` | Themes/readability | Extracts production theme/migration declarations and executes resolved-color contracts | macOS Swift fixture | Local/manual |
| `scripts/run_glass_lab_smoke.sh` | Themes/glass | Captures bright/dark Glass Lab comparisons | Simulator screenshots | Local/manual |
| `scripts/run_living_theme_native_tests.py` | Living Themes | Runs the production Metal surface on an explicit Simulator | Simulator harness with manifest/log | Local/manual |
| `scripts/run_living_theme_ui_tests.py` | Living Themes | Runs foreground Living/Timer integration UI tests | Xcode UI test and result bundle | Local/manual |
| `scripts/run_living_theme_qa_ui_tests.py` | Living Themes | Runs the actual DEBUG viewer through native UI | Xcode UI test and result bundle | Local/manual |
| `scripts/run_living_theme_render_tests.sh` | Living Themes | Compiles/runs renderer and motion contracts, retaining render output | Metal/native renderer evidence | Local/manual |
| `scripts/capture_living_scene.py` | Living Themes | Captures explicit scene evidence with source/resource/video hashes | Simulator capture and durable evidence | Local/manual |
| `scripts/run_living_event_tests.sh` | Living Themes | Compiles Living event Metal/Swift fixtures | macOS Metal/Swift fixture | Local/manual |
| `scripts/run_board_production_ui_tests.py` | Visual Supports | Exercises shipping board routes with synthetic data and restores Simulator state | Simulator UI test with preservation/result evidence | Local/manual |
| `scripts/run_board_artifact_render_review.py` | Visual Supports | Exercises BoardArtifact export fixtures in a separate Simulator app | Simulator harness with manifest/report | Local/manual |
| `scripts/run_clean_baseline_regression_tests.py` | Calendar/planner | Runs anonymous Calendar → Today → Planner and route-context regressions | Swift fixture; optional Simulator harness | Local/manual |
| `scripts/run_core_product_repair_tests.py` | Planner/routing | Executes the production gap-recommendation seam | macOS Swift fixture | Local/manual |
| `scripts/run_regenerate_route_presentation_tests.py` | Planner/routing | Exercises route-regeneration state lifecycle | macOS Swift fixture | Local/manual |
| `scripts/run_session_note_narrative_evaluation.sh` | Session Notes | Evaluates narrative output using extracted production instructions | macOS Swift evaluation | Local/manual |
| `scripts/run_timer_abc_tests.py` | Timer | Exercises extracted unchanged Timer ABC authorities | Swift fixture | Local/manual |
| `scripts/run_timer_d_hero_tests.py` | Timer | Exercises production Timer D mechanics and Hero integration | Swift fixture | Local/manual |
| `scripts/capture_theme_thumbnail_assets.sh` | Theme evidence | Captures fixed-phase Theme Center previews | Simulator screenshots/assets | Local/manual |
| `scripts/route_timeline_separator_contract_test.py` | Today presentation | Historical/specialized separator check; not called by current default wrappers | Python static contract | Apparently orphaned; review required |
| `scripts/run_swift_contract_cache_tests.sh` | Qualification tooling | Tests path-independent/cache execution semantics for the shared Swift runner | Tooling contract | Local/manual; not default current gate |

The catalogue therefore contains **13 gates** and **22 specialized/manual
validator entries**. The specialized count is a discoverability count, not a
claim that every entry must run for every source change.

## Current invocation ownership

The current default graph is deliberately preserved:

```text
prepare_build.sh
  -> validate_fast.sh
     -> validate_current.py fast

validate_full.sh
  -> validate_current.py full
     -> run_fast()
     -> Calendar/Routing/Persistence semantic checks
     -> Timer/Live Activity semantic checks
  -> executable feature contracts
  -> root paging / full-route / thumbnail fixtures

ios-ci.yml / current-validation
  -> prepare_build.sh -> Q-SEM-FAST
  -> storage contract
  -> validate_full.sh -> guarded reuse of Q-PREP fast result

ios-ci.yml / native-validation
  -> prepare_build.sh -> guarded reuse of Q-SEM-FULL fast result
  -> macOS framework contracts
  -> Visual Timer native-only contracts after Q-SEM-FULL
  -> Debug build
  -> Release build
  -> Simulator smoke runtime-only mode after Q-SEM-FULL
  -> warning assessment
  -> native evidence artifact
```

The Phase 5D modes remove only same-event work proven by an explicit
prerequisite and exact source identity. Direct/local invocations retain their
self-contained defaults. `validate_current.py` performs structural checks on
wrappers and fixtures but does not execute them, so that inspection is not
treated as a duplicate of executable fixture runs.

For one normal iOS CI event, the catalogue records the modeled count change:

| Affected work | Before | After | Avoided (category) |
|---|---:|---:|---:|
| Fast semantic execution (`Q-SEM-FAST`) | 4 | 1 | 3 |
| Simulator smoke contract prelude | 9 | 0 | 9 |
| Host-independent Visual Timer fixture | 3 | 1 | 2 |

The Simulator runtime launches/screenshots, macOS framework contracts, Debug
build, Release build, warning assessment, full semantic gate, and native-only
Visual Timer checks remain in their original proof boundaries.

The modeled total is **13 unique avoided script/fixture invocations** per
normal event: 3 fast-semantic executions, 9 Simulator-smoke contract
invocations, and 1 additional native-only Timer base-fixture execution. The
third Timer occurrence is already included in the 9-item Simulator prelude and
is not counted twice.

## Trigger and dependency interpretation

The JSON `triggerPaths` entries describe the intended source-changing scope;
`dependencies` list exact repository paths used by the command. The Phase 5C
repair adds the previously uncovered full-validation wrappers and fixtures,
the Visual Timer support validators conditionally executed on macOS, the
direct Python route/thumbnail contracts, and the two `ReusableAppWorkflow`
templates read by current semantic validation to both the iOS CI trigger and
the release-policy trigger. This changes when existing validation is scheduled,
not what any validator executes.

The automatic dependency set is intentionally separate from
`specializedManualValidators`. A specialized entry may remain discoverable and
important without becoming an automatic CI gate merely because its script is
present in the repository.

The historical `LifeRouteLiveActivity/**`, `LifeRouteShared/**`, old WebView
files, and archive scripts are not silently promoted to shipping dependencies.
Current Xcode target membership and the validator’s compatibility guards remain
the authority for those boundaries.

## Limitations and non-claims

- No validator was run as part of catalogue creation until the final requested
  read-only checks below; this change does not claim product qualification.
- No Simulator, physical device, TestFlight, release, or hosted CI action was
  started.
- Evidence retention is caller/workflow-dependent. A local output directory is
  not automatically a durable receipt.
- `Q-RELEASE-ID` is not a release approval. It is the exact-SHA signed-product
  identity gate that precedes separate physical and owner decisions.
- `Q-PHYSICAL-OWNER` cannot be satisfied by any automatic lower-level gate.
- The missing lifecycle helper at the repository-prescribed path remains an
  environment limitation; direct Git worktree inspection is the fallback.
