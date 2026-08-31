# LifeRoute current engineering handoff

Updated: 2026-08-31

## Authoritative release baseline

- LifeRoute `0.9.0` Build `118` was accepted by Apple from exact release SHA
  `67b8b4c21df3700a66abb1bb1c4190e2b040cce1` in GitHub Actions run
  `33403588020`. Archive, export, and upload all succeeded with no Apple upload
  error.
- `origin/main` and local `main` both resolved to that SHA when the maintenance
  branch was created. Re-read live Git and GitHub state before relying on this
  recorded checkpoint.
- Build 118 physical QA remains the merge gate for this cleanup. Do not merge
  cleanup work, dispatch another TestFlight build, or claim release readiness
  until the owner accepts that QA.
- If physical QA reports a product defect, preserve the cleanup branch as-is and
  repair the defect from the authoritative release baseline before rebasing or
  resuming cleanup.

## Current maintenance branch

- Branch: `chore/post-v0.9-architecture-cleanup`
- Branch point: exact Build 118 release SHA above
- Purpose: behavior-preserving architecture and development-speed cleanup
- Prohibited on this branch: product redesign, version/build changes, signing
  changes, release-workflow changes, merge, TestFlight, or App Store release

The Stage 1 inventory and baseline measurements are recorded in
`docs/POST_V09_CLEANUP_ARCHITECTURE_CHECKPOINT.md`. Current source ownership is
documented in `docs/APP_ARCHITECTURE.md`.

## Cleanup implementation

- `LifeRouteApp.swift` now owns only the app entry, root chrome/appearance, and
  Debug fixtures. Theme/catalog, compatibility components, Dynamic rendering,
  and scenery rendering have dedicated files without changing their bodies or
  environment ownership.
- The former 3,037-line `SessionToolsViews.swift` is separated into session
  notes/planning, visual-library support, and visual-builder presentation.
- AI Session Plan and Visual AI Studio are independent existing tool views in
  dedicated files; their state and navigation callsites are unchanged.
- One narrow shared Scenic Royal labeled-card primitive replaces the exact Setup
  and Client wrappers. The shared Saved Place symbol mapping has one owner.
- Proven non-shipping presentation declarations were removed. Historical files,
  WebView assets, migration compatibility, dormant Visual Schedule code, and
  persisted identifiers remain retained or deferred.
- `SessionToolsNativeView` and its private card helper remain compiled because
  the retained, excluded historical `ContentView.swift` still references them;
  they did not satisfy the zero-callsite/historical-dependency deletion rule.
- The Schedule weekday row uses positional SwiftUI identity only. The labels,
  order, rendering, selection, persistence, date calculations, and scheduling
  semantics are unchanged; this is structural identity hygiene, not a product
  bug fix.
- Xcode Sources membership is validated by actual build-phase parsing. The
  detached historical `ContentView.swift` build object was removed while its
  file and project reference remain retained outside the shipping phase.

## Validation ownership

- `scripts/prepare_build.sh`: deterministic, validation-only preflight.
- `scripts/validate_fast.sh`: focused current architecture and product-boundary
  checks.
- `scripts/validate_full.sh`: full semantic validation plus all executable
  contracts.
- `scripts/run_contract_tests.sh`: canonical aggregate contract gate.
- `scripts/run_swift_contract_test.sh`: content-addressed per-suite compilation;
  exact source/fixture/runner/compiler changes invalidate only the affected
  cached executable.
- Focused contract runners remain stable public entry points. Machine-enforced
  minimums are Day Route 30, Session Note 162, Visual Timer feedback 47, and
  Runtime feedback 9 assertions.
- Simulator smoke owns runtime launch/capture only and no longer recompiles
  contract suites already owned by full validation.
- `LifeRoute.xcscheme` is the committed shared scheme. `LifeRoute Local.xcscheme`
  stays under ignored `xcuserdata` and must never be shared.

## Protected product boundaries

Preserve the five-root paged navigation shell, five independent navigation
stacks, toolbar synchronization/suppression, iOS 26 navigation-bar ownership,
Scenic Royal Dynamic-plus-scenery composition, 15 fps persistent environment
host, native Liquid Glass and fallbacks, routing/persistence/provider semantics,
Visual Timer audio/haptics/countdown behavior, Session Note evidence and
Foundation Models safeguards, Live Day/Live Activity, and all release metadata.

The process-wide audio-session interaction between theme feedback and Visual
Timer is an evidence-backed ownership risk but has no demonstrated defect. It is
deferred to a separate physical-QA-backed design task. ETTrace and memgraph are
not warranted without a repeatable narrow symptom.

## Local validation checkpoint

Preparation, fast validation, cold and cached full validation, all four contract
suites, Debug/Release Simulator builds, app/extension compilation, the canonical
five-root smoke, representative deep route and theme fixtures, warning review,
runtime-log review, target/scheme/version integrity, and `git diff --check`
passed. Contract totals remain 30 / 162 / 47 / 9 and unexpected compiler
warnings remain zero.

Cold full validation measured 5.37 seconds and cached full validation 1.21
seconds. Preparation and fast validation measured 0.14 and 0.23 seconds. The
single-sample no-change incremental, fresh Debug, and fresh Release builds were
slower than baseline at 5.39, 245.92, and 253.54 seconds; do not claim a build
speed improvement. Canonical smoke measured 59.44 seconds after its capture
settle was raised to a reliable five-second default.

Push only this cleanup branch and open one draft PR against the then-current
`main`. The PR must retain the Build 118 physical-QA merge gate. Do not merge or
release it.
