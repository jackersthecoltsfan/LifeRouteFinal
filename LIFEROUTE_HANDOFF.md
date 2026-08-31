# LifeRoute current engineering handoff

## Current release and branch authority

- Released/TestFlight baseline: LifeRoute v0.9.0 Build 118.
- Exact authoritative Build 118 `main` SHA:
  `67b8b4c21df3700a66abb1bb1c4190e2b040cce1`.
- Active Build 119 branch:
  `feature/v0.9.1-build119-day-command-center`, created directly from that SHA.
- Target candidate: LifeRoute v0.9.1, expected TestFlight build 119.
- Do not merge or upload TestFlight until the owner explicitly approves the
  exact candidate after physical QA.

The post-v0.9 cleanup is deliberately outside this branch. Keep
`chore/post-v0.9-architecture-cleanup` at
`4ad63319e421f7f543f4b74eb87be15b4544dea2` and PR #127 draft, immutable,
unmerged, and unpicked until Build 119 is physically resolved.

## Build 119 bounded checkpoints

- `88d6ebe` — physical-device repair checkpoint: Scenic Royal glass/scenery,
  timer rendering and loudness, stronger retained haptics, and corrected icon.
- `b327bb8` — canonical day-planning checkpoint: Today, Calendar handoff,
  generated itinerary, usable gaps, Gap Fillers, Route Buffer, route-aware
  departure, Live Day, and Live Activity projection.
- `fe90792` — compact branded Today header with the official LifeRoute mark and
  the approved motto.
- Final integration owns v0.9.1 metadata, current documentation, complete
  regression validation, and remote verification. It must not dispatch the
  release workflow.

## Canonical day-planning architecture

`V054ContentView` owns one `DayRoutePlanningCore` and one
`LiveDayActivityCore`. The planner publishes one immutable
`LifeRouteGeneratedItinerary` only after all required MapKit legs succeed.

That single snapshot is authoritative for:

- Today’s chronological event/stop/drive/gap timeline;
- total raw MapKit driving time and distance;
- usable-gap calculations and Gap Filler fit/no-fit decisions;
- Leave By and Leave In;
- Live Day; and
- the Lock Screen Live Activity payload.

Gap candidate routing is an on-demand eligibility check inside the same planner.
It does not publish a second itinerary or departure engine. Adding a candidate
persists one intermediate stop anchored after the preceding appointment, then
regenerates the canonical route.

Route Buffer is persisted in the RBT Profile area. Presets are None, 5, 10, 15,
20, and 30 minutes, with a bounded 1–180 minute custom value. It applies once
before each fixed timed appointment arrival, regardless of how many drive legs
or intermediate stops precede that appointment. Raw MapKit drive time remains
separate and truthful. Return Home is untimed and receives no arrival buffer.

Calendar owns Agenda/Week/Month browsing, provider connections, and manual
appointment add/remove behavior. Its secondary selected-day action switches to
Today; it does not instantiate another planner.

## Physical-QA repair architecture

- Ordinary iOS 26 Scenic Royal surfaces use native clear Liquid Glass without
  dark under-card tint. Existing opaque accessibility fallbacks and the iOS
  16–25 material fallback remain.
- One persistent environment host still owns the 15 fps cadence. Static scenery
  is not transformed every tick; lightweight shared overlays make mountain,
  water, rainforest, and canyon motion more perceptible without new clocks.
- Dynamic themes remain scenery plus color/glow/mood plus native glass. Royal
  Current retains mountain depth under its blue/gold treatment.
- Visual Timer countdown semantics, tone choices, independent Sound/volume,
  Ring/Silent playback policy, and completion-haptic preference remain. The
  dial uses stable geometry and a timer-relative pulse phase; bounded synthesis
  gain is higher for physical-device audibility.
- Root, primary interaction, semantic success/warning, and timer-completion
  haptics retain their established moments and retained generators, with stronger
  impact intensity where appropriate.
- The 1024×1024 opaque app icon keeps the approved center mark and removes the
  visibly mismatched outer gold/white border.

## Validation ownership

- `scripts/prepare_build.sh` — deterministic preparation plus fast validation.
- `scripts/validate_fast.sh` — current structure, version, visual, navigation,
  and source-ownership contracts.
- `scripts/validate_full.sh` — fast validation plus full protected-domain and
  release-policy contracts.
- `scripts/run_day_route_contract_tests.sh` — canonical itinerary, ordering,
  provider, gap, Route Buffer, departure, Return Home, and Live projection.
- `scripts/run_session_note_contract_tests.sh` — Session Note safety and quality.
- `scripts/run_visual_timer_feedback_contract_tests.sh` — timer feedback/audio.
- `scripts/run_runtime_feedback_contract_tests.sh` — retained haptic/runtime
  feedback ownership.

Final integration validation completed against the v0.9.1 metadata:

- preparation passed in 0.15 seconds;
- fast validation passed in 0.11 seconds;
- full validation passed in 10.74 seconds;
- Day Route passed 104 assertions, Session Note 162, Visual Timer feedback 57,
  and Runtime Feedback 12;
- fresh Debug and Release Simulator builds passed in 208.01 and 207.18 seconds,
  respectively, with the app and Live Activity extension embedded and
  validated;
- warning assessment found zero unexpected compiler warnings (the two existing
  no-AppIntents-metadata notices remain informational);
- actual toolbar interaction rendered Today, Calendar, Tools, Resources, and
  Setup, while the Visual Timer deep destination correctly suppressed the root
  toolbar;
- Canyon, Royal Current, Arctic, and Rainforest fixtures rendered, including
  the motion-enabled and Reduce Motion paths; and
- the clean deep-route process produced no crash, fault, assertion, or
  error-level runtime log entries.

The committed shared `LifeRoute.xcscheme` remains byte-identical to the Build
118 baseline (SHA-256
`4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`).
`LifeRoute Local.xcscheme` remains under ignored `xcuserdata` and unshared.

## Protected boundaries and deferrals

Preserve the five paged root stacks, toolbar synchronization, iOS 26 native
navigation ownership, iOS 16–25 appearance fallback, route-provider policies,
calendar provider scope, stop/client/theme persistence, Session Note safety,
Visual Timer semantics, Live Activity schema, and the quarantined historical
WebView/runtime assets.

Do not pull PR #127 cleanup files into Build 119. Do not broaden this release
into accessibility polish, manual-event editing, a new itinerary persistence
layer, background route progression, ActivityKit schema redesign, or legacy
deletion.

Physical-device QA remains required for navigation and horizontal-swipe feel,
glass translucency, living-scenery perceptibility, Dynamic/theme performance,
stronger haptics, timer volume and glitch nonrecurrence, Ring/Silent behavior,
real MapKit/live-location routing, and Live Activity departure timing.

Historical v0.9.0 phase notes remain available in Git history and
`docs/archive/`; they are not current implementation instructions.
