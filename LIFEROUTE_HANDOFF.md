# LifeRoute current engineering handoff

## Current authority

- Build 123 / `f9c2b13c4c8c7c19c67e3f118176635ea8576808` remains the last fully accepted physical TestFlight baseline.
- Build 124 functional continuation baseline: `3ccbcc275c72297650fd4140664498fe95957149`.
- Build 125 candidate branch: `fix/build125-visual-foundation-performance`.
- Isolated worktree: `/Users/brand/Documents/GitHub/LifeRouteFinal-build125-visual-foundation-performance`.
- Stop point: `BUILD 125 VISUAL FOUNDATION + PERFORMANCE IMPLEMENTATION CHECKPOINT`.

Do not merge this branch, dispatch TestFlight, change signing/version/build
numbers, or create a shipping archive without separate owner authorization.

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
