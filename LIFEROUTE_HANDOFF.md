# LifeRoute current engineering handoff

## Current authority

- Build 123 / `f9c2b13c4c8c7c19c67e3f118176635ea8576808` remains the last fully accepted physical TestFlight baseline.
- Build 124 functional continuation baseline: `3ccbcc275c72297650fd4140664498fe95957149`.
- Build 125 candidate branch: `fix/build125-visual-foundation-performance`.
- Isolated worktree: `/Users/brand/Documents/GitHub/LifeRouteFinal-build125-visual-foundation-performance`.
- Stop point: `BUILD 125 VISUAL FOUNDATION + PERFORMANCE IMPLEMENTATION CHECKPOINT`.

Do not merge this branch, dispatch TestFlight, change signing/version/build
numbers, or create a shipping archive without separate owner authorization.

## Build 126 day-glass readability repair

- Isolated repair branch: `fix/build126-day-glass-readability`.
- Exact baseline: `c5d676c85058396cdf674f0cced2109e19b3ec8d`.
- Shared major-group glass remains `Glass.clear`; dark/night scenery keeps the
  calibrated `0.044` neutral underlay, while classified bright/day scenery uses
  a bounded `0.16` readability underlay.
- Focused contracts, preparation, fast/full validation, Debug/Release
  Simulator builds, canonical Simulator smoke, and Glass Lab bright/dark
  capture passed. Physical iPhone A/B readability acceptance remains open.

## Build 126 Terra candidate

- Branch: `exp/build126-terra-shell-performance`, based on
  `0aa161c3b8edcb15dc69c0da9dc03f7c6e4f33fd`.
- iOS 26+ now uses a native five-root `TabView` (`Today`, `Calendar`,
  `Tools`, `Resources`, `Setup`) with system safe-area and Liquid Glass tab-bar
  ownership. The pre-iOS-26 page shell and `ScenicRoyalToolbar` are retained as
  an availability-gated fallback; the native path does not use page style, the
  custom root toolbar inset, stock-tab hiding, or custom tab-bar appearance.
- `LifeRouteVisualActivityCoordinator` owns reference-counted ambient
  suspension. A foreground screen acquires a UUID in `onAppear` and releases
  it in `onDisappear`; the root environment becomes deterministic static while
  any request remains. Build 126's Theme Center work should use that API rather
  than add another global flag.
- DEBUG-only `-LifeRouteVisualActivityMode` supports `full`, `frozen`,
  `sceneryOnly`, `dynamicOnly`, and `noEffects` for same-device capture.
  DEBUG signposts cover root selection, post-selection settling, and suspension
  changes. Release omits the launch argument and signpost labels.
- Runtime verification booted iPhone 17 Pro / iOS 26.5. The five native roots
  completed five full Today → Calendar → Tools → Resources → Setup → Today
  cycles without a page-style sideways root movement, neighboring-root
  exposure, duplicate tab bar, or black root. A deep Visual Timer navigation
  path survived a URL-driven switch to Today and a return to Tools; native root
  tab bars are visible, while the deep destination deliberately hides its tab
  bar. DEBUG Royal Current modes (`full`, `frozen`, `sceneryOnly`,
  `dynamicOnly`, and `noEffects`) completed the same root/scroll sequence;
  Simulator observation did not establish a material smoothness difference.
- Native iOS 26 UIKit container host backgrounds were initially opaque black
  over the shared Royal Current environment. The Terra-local fix clears only
  those host fills after creation; it does not alter native tab/nav layout or
  appearance. Focused revalidation and a fresh candidate commit are required.
  No physical iPhone was connected.

## Build 125 checkpoint

- `V054ContentView` remains the sole bottom-toolbar layout owner. Its existing
  bottom safe-area inset now uses one canonical 10-point visual-clearance token
  instead of the previous 2-point bottom padding; no offsets or device-specific
  exceptions were introduced.
- `LifeRouteOrdinaryGlassPolicy` remains the canonical ordinary-surface owner
  for ambient, card, readability, and toolbar roles. The material modifier now
  distinguishes one ordinary container from nested ordinary content: the
  container owns the thin fill, highlight, outline, and shadow, while nested
  rows retain only a subtle outline and do not add another fill or shadow.
- Selected and intentional focal controls retain native Regular glass.
  Unselected Calendar date chips now use the ordinary ambient recipe; the
  selected chip keeps native selected-control emphasis.
- The scenery base remains fixed-camera and existing localized effects remain
  unchanged. No navigation, state, caching, animation, or scenery performance
  refactor was retained because a controlled warmed same-device process-sample
  A/B showed no meaningful CPU-side delta.

## Validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: `177` assertions.
- Calendar Edit: `29` assertions.
- Session Note: `162` assertions.
- Visual Timer feedback: `119` assertions.
- Runtime Feedback: `32` assertions.
- Scenery Effects: `54` assertions.
- Fresh Debug and Release Simulator builds passed for the app plus embedded
  Live Activity extension.
- Canonical Simulator smoke passed on iPhone 17 Pro / iOS 26.5 across all five
  roots, Visual Timer, day/night scenery fixtures, reduced motion, and the
  ordinary-glass Today fixture.
- Focused visual QA covered bright and dark canyon scenery, populated Today and
  Calendar roots, tab transitions, scroll gestures, a deep Calendar editor,
  iPhone 17 Pro, and iPhone 17e. No black-background regression was observed.
- No crash report, fatal assertion, or `UINavigationBar` regression was found.
  Build output retained only the known no-AppIntents metadata notice and signed
  embedded-binary copy notice; Simulator logs retained launch-metric delivery
  and one audio-plugin factory diagnostic without a crash.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

## Remaining physical QA

- Confirm toolbar clearance, safe-area balance, and unobscured content on a
  physical Dynamic Island iPhone and another available iPhone size.
- Judge perceived tab/scroll smoothness on physical hardware; Simulator A/B did
  not reproduce a meaningful app CPU hotspot, so no speculative performance
  rewrite was retained.
- Confirm thin ordinary glass, nested-row transparency, text readability, and
  selected-control emphasis over representative bright and dark scenery.
- Reconfirm Generate Full Day, Start Route, calendar editing/deletion,
  stale-route invalidation, virtual-event routing, Live Location, Live Day,
  route buffer, Maps provider selection, Session Note, and timer behavior.

## Deliberate non-work

- No timer redesign/audio work, Session Note work, calendar/routing features,
  provider writing, scenery assets, animated-camera changes, navigation rewrite,
  release workflow, signing, version, or build-number changes.
- No broad cleanup or module extraction was performed.
- No TestFlight dispatch or main-branch merge belongs to this checkpoint.

## Build 126 integrated local candidate

- Integration branch: `fix/build126-visual-foundation-repair`.
- Exact common base: `0aa161c3b8edcb15dc69c0da9dc03f7c6e4f33fd`.
- Retained Terra candidate: `8a5137b6697c2c4f93374aad16a9b3727cc6fc64`.
- Retained Luna candidate: `c169150de80071de5a481cff4fb00e83a1d78d86`.
- The only worker overlaps were this handoff and `scripts/validate_current.py`;
  the validator was reconciled to enforce both architectures. There was no
  project-file or asset overlap.
- Theme Center visibility now calls the root-owned, reference-counted
  `LifeRouteVisualActivityCoordinator`. Its private Theme Center request is
  idempotent across repeated appear/disappear callbacks and is covered by
  executable open/close-cycle contracts.
- The Foundation semantic-role contract is the production SwiftUI role type,
  preventing a duplicate test-only vocabulary from drifting. Old ordinary
  depth machinery is absent.
- Today inherits the intended hierarchy through shared components. Calendar
  received the bounded remaining migration: agenda events are passive rows
  under one day/week major-group surface. Tools tiles are semantic controls
  inside their existing glass-effect container and no longer own card shadows.
- Resources, Setup, and Theme Center retain Luna's explicit migration. Theme
  Center catalogs use static thumbnails for all 12 core, 8 Dynamic, and 12
  scenery themes; catalog source contains no live renderer path.
- The native iOS 26 five-tab shell, transparent UIKit host repair, five
  independent paths, deep tab suppression/restoration, programmatic root
  selection, and Visual Timer-under-Tools ownership are retained. Integrated
  Simulator root cycling and screenshots showed no opaque black host surface.
- Fast and full validation passed. Executable totals were Day Route 177,
  Calendar Edit 29, Session Note 162, Visual Timer 119, Runtime Feedback 32,
  Visual Activity 32, and Scenery Effects 54: 605 assertions total.
- Fresh signing-disabled Debug and Release iOS 26.5 Simulator builds passed.
  The warning audit found one known no-AppIntents metadata notice and zero
  unexpected compiler warnings.
- The canonical iPhone 17 Pro smoke matrix passed all five roots, Visual Timer,
  all 12 day/night scenery fixtures, Royal Current motion/reduced-motion, and
  ordinary glass over bright scenery. Theme Center open/scroll/select/close
  passed; two visible frames were byte-identical while suspended, while frames
  after close diverged as ambient motion resumed. Repeated open/close cycles did
  not leak a suspension request in the executable contract.
- `scripts/run_visual_activity_contract_tests.sh` is executable. The protected
  shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

### Remaining physical-only acceptance

- No physical iPhone was connected. Perceived tab/scroll smoothness, DEBUG
  renderer-mode A/B attribution, Dynamic Island clearance, representative
  device-size layout, glass/readability judgment over bright and dark scenery,
  and the complete route/calendar/location/Session Note/timer physical matrix
  remain unclaimed.
- The production environment renderer is unchanged; no Simulator evidence
  justified a speculative GPU/renderer rewrite.
