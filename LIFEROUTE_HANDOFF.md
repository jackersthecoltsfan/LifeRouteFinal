# LifeRoute current engineering handoff

## Current development baseline — v0.9.0 Scenic Royal

- Build 116 physical QA was accepted.
- PR #123 supplied the approved pre-v0.9 runway and PR #119 was closed as
  superseded without merging.
- Authoritative post-runway `main` and v0.9.0 branch point:
  `f35b59b5b337ba27a6196bb8d1687f4fe23f8dfc`.
- Active branch: `feature/v0.9.0-scenic-royal-ui`.
- Phase 0 architecture is accepted. Phase 1 is the active implementation
  boundary; do not begin the Today/route migration until its checkpoint is
  reviewed.
- Do not dispatch TestFlight or merge the v0.9.0 branch without the owner's
  candidate-specific authorization.

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

## v0.9.0 Phase 1 validation checkpoint

- Day Route executable contracts: 14 assertions
- Session Note executable contracts: 162 assertions
- `prepare_build`, fast validation, and full validation: pass
- Fresh Debug and Release iOS 26.5 Simulator builds: pass
- App and embedded Live Activity extension: compile and validate in both configurations
- Warning budget: the known no-AppIntents toolchain notice only; 0 unexpected warnings
- `git diff --check`: pass
- Shared `LifeRoute.xcscheme`: unchanged from `HEAD`
- Canonical simulator smoke: five root captures plus motion and Reduce Motion
  visual fixtures pass on iPhone 17 Pro

Phase 1 adds the reusable Scenic Royal design system, theme bridge, native
iOS 26 Liquid Glass with iOS 16-25 material fallbacks, a persistent root-level
environment host, shared cards/badges/section headers, and a thin five-root
toolbar. The five existing `NavigationStack`s and paged root `TabView` remain
the navigation owner. Root selection synchronization, deep-route toolbar
suppression, and domain ownership remain unchanged.

The app target's Debug configuration now explicitly inherits `DEBUG`, making
the existing section/theme fixture arguments reliable for screenshot QA. The
condition is narrowly scoped to the app Debug configuration and is guarded by
`scripts/validate_current.py`.

Representative Simulator evidence covers Canyon, bright Arctic, Rainforest,
and Royal Current. Accessibility QA covers Accessibility Large, Increased
Contrast, Reduce Transparency, and Reduce Motion; VoiceOver labels/hints are
present in source. An iOS 16-25 runtime was not installed, so the fallback path
is compile-validated against the iOS 16 deployment target but still needs an
older-runtime visual pass when one is available.

Simulator QA on iPhone 17 Pro / iOS 26.5 exercised the actual UI: a stop was
added, survived navigation away/back, survived terminate/relaunch, generated a
two-leg route exactly once between Current Location and Home, was removed, and
remained absent after another relaunch. The Session Note warning was also visible
and exposed as one combined VoiceOver description. Physical-device QA remains
necessary for Foundation Models behavior, real-device location timing, external
navigation handoff, and Live Activity presentation.

PR #119 (`chore/v0.8.2-light-hygiene`) was closed as superseded and was not
merged. Its still-useful tiny cleanup was reproduced through the approved
pre-v0.9 runway instead.

## v0.9 UI migration boundaries

- App entry: `LifeRouteApp.swift` owns `LifeRouteApp`, root theme injection,
  legacy compatibility chrome, and debug fixtures. Its `ContentView()` resolves through the
  `ContentView = V054ContentView` typealias in `V054ContentView.swift`.
- Navigation shell: `V054ContentView.swift` owns the five paged root
  `NavigationStack`s and installs `ScenicRoyalToolbar`. `AppNavigation.swift` owns
  `AppSection`, `AppRouter`, per-section paths, and deep-destination toolbar
  suppression.
- Major root screens: `V054TodayView.swift`, `V054ScheduleView.swift`,
  `V054ToolsDashboard.swift`, `ResourcePortalViews.swift`, and
  `V054SetupView.swift`.
- Major supporting screens: `DayRoutePlanningView.swift`,
  `AIClinicalToolsViews.swift`, `SessionToolsViews.swift`, `ClientViews.swift`,
  `V054ClientViews.swift`, `V054ThemeCenterView.swift`, and
  `V054AddressField.swift`.
- New shared visual infrastructure lives in `ScenicRoyalDesignSystem.swift`,
  `ScenicRoyalMaterials.swift`, `ScenicRoyalEnvironment.swift`,
  `ScenicRoyalThemeBridge.swift`, `ScenicRoyalComponents.swift`, and
  `ScenicRoyalToolbar.swift`. Existing palettes, screen helpers, and button
  styles in `LifeRouteApp.swift` remain active compatibility seams for screens
  not yet migrated; retire them only after callsites have moved and validation
  proves them unused.
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

## Next milestone — v0.9.0 Phase 2

After the owner accepts the Phase 1 checkpoint, migrate Today and the route
experience onto the shared foundation while preserving Generate Full Day,
saved-stop persistence, route ordering, Live Day, gaps, and all existing domain
contracts. The approved one-tap provider-specific full-route handoff belongs to
that phase. The Visual Timer's bounded urgency/audio refinement remains deferred
to the Tools migration phase. Continue replacing old UI incrementally and remove
it only after each replacement is proven behaviorally equivalent.
