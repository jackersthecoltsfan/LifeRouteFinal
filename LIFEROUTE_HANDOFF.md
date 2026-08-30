# LifeRoute current engineering handoff

## Current maintenance baseline — v0.8.3 physical QA

- Authoritative merged `main`: `07bcd4b93b389b2b7fab85364cb0d35f84736d5a`
  (PR #122)
- Runway branch: `chore/pre-v0.9-runway`, created from that exact SHA
- This branch is pre-v0.9 hygiene and documentation only; it must remain
  isolated until v0.8.3 physical-device QA passes.
- Do not merge this branch, dispatch TestFlight, change versions/build numbers,
  or begin the v0.9.0 redesign during this workstream.

The Session Note generator now presents a stable inline “Experimental AI Tool”
warning before normal use. It tells users that generated notes may be incomplete
or inaccurate, must be reviewed and edited, and must not be treated as final
clinical documentation. The existing validators, bounded repair, degraded and
fallback states, evidence-safe fallback, provenance, and `SN-DIAG-1` diagnostic
receipt remain intact. Build 115 established Apple Foundation Models model-quality
failure with bounded-repair nonrecovery; prompt, validator, retry, and model
architecture tuning is deferred until the iOS 27 Foundation Models reevaluation.

The stop-persistence root cause was view-local `@State` ownership in
`DayRoutePlanningView`. Leaving the view discarded the stops because the
canonical native snapshot had no day-stop field. Day stops now have stable IDs,
day and before/after placement, semantic duplicate protection, backward-compatible
decoding, and canonical persistence through `LifeRoutePersistenceStore` and
`RoutingLocationCore`. Removal writes through the same owner, preventing stale
deleted stops from returning.

The Generate Full Day omission had two linked causes: it read only the transient
view array and routed only one selected appointment. A shared deterministic day
sequence now combines before-stops, every chronological calendar event, and
after-stops. MapKit leg generation uses all located events and also supports a
stop-only day; unlocated events remain visible in the generated schedule instead
of being silently removed. Today/Live Day and the Live Activity payload expose
the saved-stop sequence, while existing navigation-app handoffs, travel modes,
current-location/Home fallback, and Return Home behavior remain in place.

## Validation checkpoint

- Day Route executable contracts: 14 assertions
- Session Note executable contracts: 162 assertions
- `prepare_build`, fast validation, and full validation: pass
- Fresh Debug and Release Simulator builds: pass
- App and embedded Live Activity extension: compile and validate in both configurations
- Warning budget: 2 known no-AppIntents toolchain notices, 0 unexpected warnings
- `git diff --check`: pass
- Shared `LifeRoute.xcscheme`: restored and unchanged from `origin/main`

Simulator QA on iPhone 17 Pro / iOS 26.5 exercised the actual UI: a stop was
added, survived navigation away/back, survived terminate/relaunch, generated a
two-leg route exactly once between Current Location and Home, was removed, and
remained absent after another relaunch. The Session Note warning was also visible
and exposed as one combined VoiceOver description. Physical-device QA remains
necessary for Foundation Models behavior, real-device location timing, external
navigation handoff, and Live Activity presentation.

PR #119 (`chore/v0.8.2-light-hygiene`) remains separate and must not be merged
into this branch. Its release/handoff documentation is superseded by v0.8.3.
The only still-useful unique change is removal of two unused imports and one
obsolete comment from `V054ToolsDashboard.swift`; that narrow cleanup is
reproduced on the runway branch. PR #119 should be closed as superseded after
the runway branch is reviewed.

## Pre-v0.9 UI migration boundaries

- App entry: `LifeRouteApp.swift` owns `LifeRouteApp`, root theme injection,
  shared chrome, and debug fixtures. Its `ContentView()` resolves through the
  `ContentView = V054ContentView` typealias in `V054ContentView.swift`.
- Navigation shell: `V054ContentView.swift` owns the five paged root
  `NavigationStack`s and custom bottom toolbar. `AppNavigation.swift` owns
  `AppSection`, `AppRouter`, per-section paths, and deep-destination toolbar
  suppression.
- Major root screens: `V054TodayView.swift`, `V054ScheduleView.swift`,
  `V054ToolsDashboard.swift`, `ResourcePortalViews.swift`, and
  `V054SetupView.swift`.
- Major supporting screens: `DayRoutePlanningView.swift`,
  `AIClinicalToolsViews.swift`, `SessionToolsViews.swift`, `ClientViews.swift`,
  `V054ClientViews.swift`, `V054ThemeCenterView.swift`, and
  `V054AddressField.swift`.
- Shared visual infrastructure currently lives primarily in
  `LifeRouteApp.swift`: theme palettes/store, design tokens, root chrome,
  `LifeRouteScreenHeader`, `LifeRouteSectionLabel`, `LifeRouteIconBadge`, card
  treatment, and primary/secondary button styles. Preserve these reusable seams
  unless the v0.9 design intentionally replaces them.
- Preserve the existing domain owners and inject them into replacement screens:
  calendar/provider, routing/location, persistence, client profiles, session
  tools, Live Activity, and `AppRouter`. A visual migration must not silently
  create competing state ownership.
- `LifeRoute/ContentView.swift` is a legacy native shell outside the shipping
  Sources phase. `LifeRoute/LifeRouteWebView.swift` is a quarantined legacy
  bridge outside Sources and is explicitly checked by current validation.
  Consider removal only after v0.9 replacements and any historical-reference
  need are resolved.
- `LifeRoute_GitHub_Upload_Fresh/` is an unreferenced tracked historical source
  snapshot, not an active build input. Its retention value is ambiguous, so
  defer removal until the v0.9 migration or a separate archival decision.

## Next milestone — v0.9.0

After v0.8.3 passes physical QA and this runway cleanup is reviewed/merged if
appropriate, begin the dedicated new native SwiftUI UI implementation based on
the LifeRoute Master and Design threads. Replace old UI incrementally and remove
it only after each replacement exists and preserves its domain contracts. Figma
and broader visual redesign work belong to v0.9.0, not this maintenance branch.
