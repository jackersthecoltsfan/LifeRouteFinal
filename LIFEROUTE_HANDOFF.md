# LifeRoute current engineering handoff

## Current authority

- Build 123 / `f9c2b13c4c8c7c19c67e3f118176635ea8576808` remains the last physically accepted TestFlight release.
- Sanitized development baseline: `08615656deb0f4c71e92464c886f7c68522a8a31`.
- Feature branch: `feat/generated-day-navigation-calendar-edit-v1`.
- Isolated worktree: `/Users/brand/Documents/GitHub/LifeRouteFinal-generated-day-navigation-calendar-edit-v1`.
- Stop point: `GENERATED-DAY NAVIGATION + MANUAL CALENDAR EDITING IMPLEMENTATION CHECKPOINT`.

Do not merge this branch, dispatch TestFlight, change signing/version/build
numbers, or create a shipping archive without separate owner authorization.

## Feature checkpoint

- `CalendarCoreState` owns one manual-event update operation. It preserves the
  event ID and manual source, validates title and timed ranges, calculates
  all-day intervals, moves events across day indexes, sorts, and persists the
  complete manual collection without mutating provider events.
- Calendar rows now open honestly: manual events reuse the appointment sheet in
  edit mode; Apple, Google, and calendar-link events open source-managed,
  read-only details. Existing row deletion remains and the edit sheet adds a
  bounded confirmed Delete action.
- `LifeRouteGeneratedItinerary.startRouteDecision` owns destination selection
  from the authoritative canonical itinerary. It rejects wrong-day/stale
  itineraries and skips virtual, empty, non-routable, and all-day destinations.
- `DayRoutePlanningCore` remains the Maps-launch owner. Start Route validates
  canonical itinerary membership, preserves transport mode, honors the existing
  persisted Apple Maps / Google Maps / Waze preference, reports success only
  after a successful handoff, keeps failures visible, and prevents overlapping
  launch tasks.
- The exact `Home — Microsoft Teams Meeting` virtual-location regression remains
  chronological while the surrounding physical route stays actionable.

## Validation checkpoint

- Preparation, fast validation, and full validation passed using the sanitized
  contract cache.
- Day Route: `177` assertions.
- Calendar Edit: `29` assertions.
- Session Note: `162` assertions.
- Visual Timer feedback: `119` assertions.
- Runtime Feedback: `25` assertions.
- Scenery Effects: `54` assertions.
- Fresh generic Debug and non-archival Release Simulator builds passed for the
  app plus embedded Live Activity extension and both simulator architectures.
- Compiler warning audit: zero unexpected warnings; only the two known
  no-AppIntents metadata notices.
- Canonical Simulator smoke passed on iPhone 17 Pro / iOS 26.5. The first fresh
  Today and Calendar screenshots caught transient launch frames; one bounded
  six-second readiness retry rendered both roots correctly. Later smoke roots
  rendered normally.
- Interactive Simulator QA passed add, prefilled edit, title/location/date/time
  change, cross-day move, persistence, bounded deletion, generated-day
  readiness, stale-after-edit rejection, regeneration, exact
  virtual-plus-physical routing, and Apple Maps handoff with driving mode and
  the correct physical destination. After deleting only `QA Virtual Meeting`,
  app reconstruction retained exactly the unrelated physical QA appointment;
  deterministic contracts also retained provider/imported events.
- No LifeRoute crash reports, fatal errors, runtime failures, failed
  preconditions, or assertion failures were found. Fresh-smoke logs contained
  one Simulator CFBundle audio/plugin factory notice; text-entry QA also emitted
  known Simulator keyboard/haptics service noise.
- Shared scheme SHA-256 must remain
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

## Remaining physical QA

- Confirm manual add/edit/move/all-day/delete persistence on a physical iPhone.
- Confirm provider-event read-only details with connected Apple, Google, and
  calendar-link accounts; no provider mutation is implemented.
- Confirm Start Route and visible failure/cancellation behavior with installed
  Apple Maps and any configured third-party provider on a physical iPhone.
- Confirm transport mode, live-origin behavior, repeated-tap suppression, and
  the exact virtual-plus-physical itinerary under real network/location state.

## Deliberate non-work

- No provider write scopes or mutation, recurring-event editing, calendar
  toggles/deduplication, To-Do changes, stop-management redesign, broad routing
  refactor, visual/scenery/navigation-container work, sanitation, release
  workflow, signing, version, or build-number changes.
- No second calendar store, generated itinerary, route-ordering engine,
  current/next-step engine, or Maps subsystem was introduced.
- No TestFlight dispatch or main-branch merge belongs to this checkpoint.
