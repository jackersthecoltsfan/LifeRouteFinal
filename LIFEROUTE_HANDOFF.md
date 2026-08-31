# LifeRoute current engineering handoff

## Current development baseline — v0.9.0 Scenic Royal

- Build 116 physical QA was accepted.
- PR #123 supplied the approved pre-v0.9 runway and PR #119 was closed as
  superseded without merging.
- Authoritative post-runway `main` and v0.9.0 branch point:
  `f35b59b5b337ba27a6196bb8d1687f4fe23f8dfc`.
- Active branch: `feature/v0.9.0-scenic-royal-ui`.
- Phase 0 architecture and Phase 1 foundation checkpoints are accepted. The
  Phase 1 remote checkpoint is `fe46286f916c095d61e5ebc5ef163b3d2d9b21ed`.
- Phase 2 Today/route implementation is accepted at
  `9e56b733ae7b1a4250d188eeea089a796aa0a0df`. The local safety branch
  `checkpoint/v0.9.0-phase2-local` resolves to that exact commit.
- Phase 3 Schedule/travel-presentation implementation is accepted at
  `92e1a5f25791393c95137d6e15162c95ce11b1a9`. The remote feature branch was
  verified at that exact Phase 3 commit before Phase 4 began.
- Phase 4 Tools/Visual Timer implementation is accepted and finalized remotely at
  `09f8c1831db83b90dbd9019d34475069682a6360`.
- Phase 5 Resources implementation is accepted and finalized remotely at
  `446866ea59f86663ad4c285023e9cd3deb88259a`.
- Phase 6A Setup, shared Address Field, Home Base, Saved Places, Add Place, and
  Weekly To-Dos presentation is accepted and finalized remotely at
  `0287ef8e0d9d61c1ea298638003464fffe947cbc`.
- Phase 6B Clients and Theme Center presentation is accepted and finalized
  remotely at `996d9b995f257bc38bcfed3edfc4042e400ba37f`.
- Phase 7 final integration is complete in the checkpoint commit containing
  this handoff. It corrects Setup deep-route toolbar suppression and adds an
  accessibility-mode readability floor to shared root-screen headers; no
  product-domain behavior changed.
- The owner authorized candidate
  `c2055255f8c0aec3041c38d5cda6853f606ac620` for v0.9.0 TestFlight. Its
  product tree was merged unchanged, and release identity metadata is being
  synchronized to v0.9.0 before exact-main validation and guarded upload.
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

## v0.9.0 Phase 7 final integration checkpoint

- Canonical preparation, fast validation, and full validation pass.
- Executable contracts pass: Day Route 30 assertions, Session Note 162
  assertions, and Visual Timer feedback 42 assertions.
- Fresh Debug and Release iOS 26.5 Simulator builds pass for the app and the
  embedded Live Activity extension. Warning assessment reports only the known
  no-AppIntents toolchain notice and zero unexpected compiler warnings.
- Canonical Simulator smoke passes all five roots plus motion and Reduce Motion
  fixtures. Direct toolbar selection stays synchronized across Today, Calendar,
  Tools, Resources, and Setup. Desktop pointer-driven root swiping remains
  inconclusive because the automation moved the Simulator window instead of
  delivering the gesture; the paged `TabView` and five independent
  `NavigationStack` owners are unchanged.
- Direct Simulator QA proves Tools deep routes and Setup's Clients/Theme Center
  deep routes suppress the root toolbar, Back restores it, MapKit address
  autocomplete returns six results and selects a suggestion, client code
  normalization/persistence survives relaunch, and theme selection applies
  immediately and survives relaunch.
- Phase 7 found no crash, hang, app runtime fault, scrolling regression, audio
  engine leak symptom, or memory-growth signal requiring ETTrace or memgraph.
  Simulator-only haptic-library and app-launch-measurement messages remain
  physical-device verification items, not app compiler warnings.
- Legacy presentation candidates remain deferred. `ContentView.swift` is
  outside Sources but retained as the documented historical shell;
  `ClientViews.swift` is still a compiled companion to that shell;
  `CinematicThemeViews.swift` still supplies the active root backdrop; and
  `LifeRouteWebView.swift` plus bundled web assets remain explicitly
  quarantined. No deletion met both zero-dependency and archival-decision proof.
- Physical-device TestFlight QA remains required for the Ring/Silent switch,
  timer tone quality and haptic strength, external Apple/Google/Waze handoff,
  live location/MapKit behavior, Live Activity presentation, and real-device
  Foundation Models behavior. Stop before TestFlight until the owner authorizes
  the exact candidate.

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

## v0.9.0 Phase 2 validation checkpoint

- Today now uses the shared Scenic Royal material/component layer and the
  persistent root scenery; the old Today-only exemplar background and duplicate
  glass modifiers are retired.
- Quick Actions, Today/Day Overview, gap suggestions, and Live Day retain their
  existing state owners and behavior while using shared Scenic Royal cards,
  headers, interactive surfaces, and buttons.
- `FullRouteHandoffContracts.swift` adds a pure, executable provider policy. The
  normal route-results flow exposes one `Start full route in <provider>` action;
  individual MapKit legs remain the timing/distance and fallback source of truth.
- Google Maps receives one ordered directions URL only when every stop fits the
  conservative three-mobile-waypoint and 2,048-character limits. Apple Maps
  receives a complete single leg and LifeRoute-managed sequential continuation
  for multi-leg routes. Waze and every unverified/over-limit sequence receive an
  explicit sequential continuation. No fallback truncates, sorts, or rewrites
  route legs.
- Day Route executable contracts: 30 assertions; Session Note executable
  contracts: 162 assertions.
- Preparation, fast/full validation, Debug and Release Simulator builds, app and
  Live Activity extension compilation, canonical seven-capture Simulator smoke,
  and `git diff --check`: pass.
- Warning budget remains the known no-AppIntents toolchain notice only, with zero
  unexpected compiler warnings. Runtime log review found no Phase 2 crash, fault,
  or hang.
- Today visual evidence covers Canyon, bright Arctic, Rainforest, and Royal
  Current. A combined Accessibility Extra Large, Increased Contrast, Reduce
  Transparency, and Reduce Motion bright-Arctic pass remained legible and
  reflowed Quick Actions to two columns.
- Direct pointer-driven root swiping could not be repeated because the Mac
  interactive desktop was locked. The unchanged paged five-stack navigation was
  re-smoked through all five root launches and remains protected by semantic
  validation; repeat one physical swipe when the desktop is available.

## v0.9.0 Phase 3 validation checkpoint

- Schedule now uses the shared Scenic Royal heading, compact controls, grouped
  glass, readability cards, date controls, chronological event rows, travel-plan
  link, and connected-calendar status treatment. Day/Agenda, Week, Month,
  manual appointments, and read-only provider actions retain their existing
  `CalendarCoreState` and `CalendarProviderCore` owners.
- `ScenicRoyalScheduleComponents.swift` contains stateless date, event, travel,
  connection, and route-leg presentation components. Accessibility text sizes
  switch event rows to a vertical hierarchy, expand and center the selected
  week date, and replace the space-constrained segmented range control with a
  labeled menu. Month-grid numerals remain spatially bounded while retaining
  complete VoiceOver labels and event counts.
- Day Route presentation now uses the same Scenic Royal fields, inset rows,
  readability surfaces, and ordered route-leg rows. Saved-stop persistence,
  MapKit leg calculation, route ordering, full-route provider policy, sequential
  fallback, and single primary handoff action are unchanged.
- Representative iPhone 17 Pro / iOS 26.5 evidence covers Canyon, bright Arctic,
  Rainforest, Royal Current, populated chronological event rows, and a combined
  Accessibility Extra Large, Increased Contrast, Reduce Transparency, and
  Reduce Motion pass. The accessibility pass initially exposed fixed calendar
  control clipping; the final pass confirms readable range/date controls and
  vertically reflowed events.
- Preparation, fast/full semantic validation, 30 Day Route assertions, 162
  Session Note assertions, fresh Debug and Release Simulator builds, app and
  Live Activity extension compilation, `git diff --check`, and protected-domain
  diff audit pass. The warning budget remains the known no-AppIntents notice
  only, with zero unexpected warnings; runtime log review found no app errors or
  faults.
- Direct pointer-driven root swiping and direct Day Route tapping remain
  unavailable while the Mac desktop is locked. The five-stack root/navigation
  sources are unchanged and their semantic regression checks pass; repeat the
  physical interaction smoke when the desktop is available.

## v0.9.0 Phase 4 validation checkpoint

- The active Tools dashboard now uses Scenic Royal headings, readability
  surfaces, and a reusable adaptive tool tile while preserving the six approved
  destinations. Visual Schedule remains hidden.
- Visual Timer retains the existing absolute-deadline countdown owner and
  start, pause, resume, add-minute, completion, and reset semantics. A pure
  `VisualTimerFeedbackCurve` adds exponential late-stage visual urgency and a
  slower, lower pitch curve without becoming a second timer engine.
- Warm, Soft, and Clear audible profiles plus an independent Sound toggle,
  bounded volume, and optional completion haptics persist through four narrow
  `UserDefaults` keys. Turning Sound off preserves the selected audible tone.
  Audio uses the ambient session category so it mixes with other audio and
  respects the physical Ring/Silent setting. Silent mode does not start the
  tone engine.
- Reduce Motion lowers the visual update cadence and removes pulse animation.
  VoiceOver receives only bounded minute/30-second/10-second/5-second/completion
  milestones; the continuously changing timer display is not a live region.
- Visual Timer feedback executable contracts: 42 assertions. Day Route: 30;
  Session Note: 162. Preparation, fast/full validation, fresh Debug and Release
  Simulator builds, app and Live Activity extension compilation, canonical
  seven-capture Simulator smoke, and `git diff --check` pass.
- Representative iPhone 17 Pro / iOS 26.5 evidence covers Canyon, bright
  Arctic, Rainforest, and Royal Current plus Accessibility Extra Extra Large,
  Increased Contrast, and Reduce Motion. Runtime review found no app crash,
  fault, or hang; one Simulator CoreAudio factory-registration diagnostic did
  not prevent the engine from starting, accelerating, completing, and pausing.
- The warning budget remains the known no-AppIntents toolchain notice only,
  with zero unexpected compiler warnings. Physical-device QA remains required
  for the Ring/Silent switch, audible tone character, system-volume interaction,
  completion haptics, and VoiceOver spoken cadence.
- Direct pointer-driven root swiping could not be repeated because Computer Use
  again reported the interactive Mac desktop locked. All five root launches,
  toolbar selection fixtures, the unchanged five-stack source architecture,
  and semantic navigation checks pass; repeat a real swipe at the next physical
  interaction opportunity.

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

## v0.9.0 Phase 5 validation checkpoint

- The active Resources root now uses Scenic Royal readability cards, adaptive
  inventory metadata, four lazy category groups, accessible portal rows, and a
  Scenic Royal local add-portal form. Bright scenery remains visible without
  becoming the text contrast surface.
- `ResourcePortalCore` remains the sole state owner. Its 27 built-in portals,
  four category identities and ordering, custom create/delete persistence, URL
  normalization, direct external-link behavior, and local-first boundary are
  unchanged.
- Built-in and custom rows retain stable portal IDs. Custom portals are identified
  with both an icon and the explicit text `Custom portal`; VoiceOver receives
  explicit built-in/custom values, external-browser hints, and delete hints.
- Accessibility text sizes move custom-row deletion below the launch action and
  stack header metadata without shrinking text. Shared Scenic Royal materials
  continue to provide Increased Contrast and Reduce Transparency behavior; this
  phase adds no animation or timer work.
- Preparation, fast/full validation, 30 Day Route assertions, 162 Session Note
  assertions, 42 Visual Timer feedback assertions, Debug and Release Simulator
  builds, app and Live Activity extension compilation, and `git diff --check`
  pass. `ResourcePortalDomain.swift` and every other protected domain have no
  Phase 5 diff.
- iPhone 17 Pro / iOS 26.5 evidence covers Canyon, bright Arctic, Rainforest,
  Royal Current, and a seeded persisted custom portal. A combined Accessibility
  Extra Large, Increased Contrast, Reduce Transparency, and Reduce Motion bright-
  Arctic pass remains legible and reflows metadata and rows without shrinking
  text. The warning budget remains the known no-AppIntents notice only.

## v0.9.0 Phase 6A validation checkpoint

- The active Setup root now uses six Scenic Royal disclosure groups in the
  established order: Appearance, Profile & Work, Navigation & Places, Weekly
  To-Dos, Clinical, and Privacy. Theme Center and Clients remain navigation
  links only; their destination screens are intentionally outside Phase 6A.
- `ScenicRoyalSetupComponents.swift` provides stateless Setup headers, grouped
  cards, navigation rows, saved-place rows, weekly to-do rows, status text, and
  accessibility-aware disclosure presentation. Existing `@AppStorage`,
  `LifeRouteThemeStore`, and `RoutingLocationCore` ownership remains unchanged.
- `V054AddressField` retains its `LifeRouteAddressAutocomplete` state owner,
  MapKit address/point-of-interest completion, six-result limit, flexible
  destination behavior, manual-entry fallback, validation path, and focus-
  controlled visibility. The Scenic Royal suggestion surface adds explicit
  labels, button traits, and selection hints without introducing a view model.
- Focused Schedule regression on iPhone 17 Pro / iOS 26.5 opened the manual-
  appointment sheet, returned six MapKit suggestions, selected the complete
  Apple Park address, retained a manual address, dismissed suggestion/focus
  state, cancelled without creating data, and returned to the ordinary agenda.
- Representative visual evidence covers Canyon, bright Arctic, Rainforest, and
  Royal Current. A combined Accessibility Extra Large, Increased Contrast,
  Reduce Transparency, and Reduce Motion Arctic pass reflows instead of
  truncating; Setup groups, fields, suggestions, and actions remain individually
  exposed through the accessibility hierarchy.
- Preparation, fast/full validation, 30 Day Route assertions, 162 Session Note
  assertions, 42 Visual Timer feedback assertions, Debug and Release Simulator
  builds, app and Live Activity extension compilation, warning-budget audit,
  runtime review, protected-domain diff audit, and `git diff --check` pass.
- Home Base restored the same protected persisted address across repeated app
  termination, rebuild installation, theme launches, and final relaunch. No
  Phase 6A source changes touch routing or persistence domains.

## v0.9.0 Phase 6B validation checkpoint

- The active Clients list and editor now use bounded Scenic Royal presentation
  components while retaining `ClientProfileCore` ownership, local editor state,
  code normalization and duplicate detection, sorting, address entry, visual-
  library cleanup associations, persistence, and immediate deletion behavior.
- Accessibility text sizes stack client identity, metrics, and code fields.
  The visible code badge is hidden from accessibility so each code is announced
  once; edit and remove controls include client-specific labels and hints.
- Theme Center remains inside Setup and continues to use the authoritative
  `LifeRouteThemeStore`. The production inventory is unchanged at 12 Core, 8
  Dynamic, and 12 Scenery themes (32 unique identifiers), with immediate
  selection and `liferoute.selectedTheme` relaunch persistence intact.
- Theme previews use fixed phases only. Category controls and cards expose name,
  category, live/still character, and selected state; selected cards add a
  checkmark and stronger boundary. Accessibility text sizes use one column.
- iPhone 17 Pro / iOS 26.5 evidence covers Canyon, bright Arctic, Rainforest,
  and Royal Current. The combined Accessibility Extra Large, Increased
  Contrast, Reduce Transparency, and Reduce Motion Arctic pass remains legible
  and reflows without shrinking text.
- Preparation, fast/full validation, 30 Day Route assertions, 162 Session Note
  assertions, 42 Visual Timer feedback assertions, Debug and Release Simulator
  builds, app and Live Activity extension compilation, warning-budget review,
  runtime review, protected-domain diff audit, and `git diff --check` pass.
  Simulator-only Accessibility and haptic-library diagnostics produced no app
  crash, hang, or protected-domain issue.

## Next milestone — v0.9.0 Phase 7

After the owner accepts Phase 6B, run the accepted cross-app Phase 7 integration
and release-readiness matrix. Legacy deletion, merge, and TestFlight remain out
of scope until their separate proof and authorization gates are satisfied.
