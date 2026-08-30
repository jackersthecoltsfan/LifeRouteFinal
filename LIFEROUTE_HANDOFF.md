# LifeRoute current engineering handoff

## Active workstream — v0.8.3 maintenance and routing stabilization

- Exact base: `81ebc834b2f7609a44d066239a1ee4970aa4d9db` (`origin/main` after PR #120)
- Branch: `fix/v0.8.3-experimental-session-note-and-routing`
- Current physical diagnostic release: LifeRoute v0.8.2 Build 115
- Next candidate build is expected to be 116 if no intervening workflow run occurs; the repository does not hardcode it.
- Do not merge, dispatch TestFlight, or submit to the App Store without product-owner authorization.

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
into this branch. Review it only for superseded harmless cleanup after v0.8.3.

## Next milestone — v0.9.0

After v0.8.3 is merged and physically validated, begin the dedicated new native
SwiftUI UI implementation based on the LifeRoute Design thread. Figma and broader
visual redesign work belong to v0.9.0, not this maintenance branch.
