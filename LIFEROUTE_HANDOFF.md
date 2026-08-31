# LifeRoute current engineering handoff

## Current release and branch authority

- Frozen Build 119 source and `main` SHA:
  `7e58ced9d28147652f38eee781762819d1b72d8c`.
- Build 120 repair branch:
  `fix/v0.9.1-build120-physical-qa`.
- Build 120 isolated worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-build120-physical-qa`.
- Target candidate: LifeRoute v0.9.1 Build 120. The checked-in local build
  strategy remains unchanged; the guarded release workflow must supply the
  upload number only after separate owner authorization.
- Do not merge or dispatch TestFlight at this checkpoint.

The Developer Velocity branch
`chore/v0.9.1-fast-iteration-v1` at
`f1ceab70c126a8f1e8e8e11ba2278c490d3e4f61` was not used as the repair
baseline. PR #127 and its cleanup branch remain untouched.

## Build 120 bounded repair commits

- `04905cc` — repair Live Day start and the ActivityKit boundary.
- `d804cda` — stabilize Visual Timer rendering and increase bounded output.
- `c0934ee` — build the fixed-camera living-scenery and rendering foundations.
- Final integration owns the expanded smoke matrix, current handoff, final
  validation, and branch publication only.

## Live Day architecture and repair

`V054ContentView` continues to own one `DayRoutePlanningCore` and one
`LiveDayActivityCore`. The generated `LifeRouteGeneratedItinerary` remains the
single source for Today, appointments, saved stops, drive legs, gaps, Route
Buffer, departure guidance, Live Day, and Live Activity projection.

Build 119 visually allowed Start Live Day to look actionable while disabling
the control whenever a projection was absent. Its styling did not communicate
the disabled state, and starting the in-app run was coupled to ActivityKit
success. Build 120 validates the canonical projection, starts the in-app run
first, and requests ActivityKit separately. ActivityKit unavailable, denied,
disabled, or request-failure states now produce visible status without rolling
back a valid in-app Live Day. No parallel itinerary or departure engine was
introduced.

## Visual Timer repair

- The established countdown engine and completion semantics are unchanged.
- The rendering path no longer drives the whole glass card at 10 Hz. The text
  readout updates at one-second granularity, animation phase is timer-relative,
  the dial geometry is fixed, and decorative pulse/shadow work is locally
  bounded.
- Sound On/Off, persisted volume, 0% silence, tone choice, Ring/Silent playback
  policy, and independent completion haptics remain intact.
- Completion synthesis gain increased from 0.68 to 0.84 with a slower decay;
  executable fixtures bound peak output below 0.92 and verify materially higher
  RMS output. Physical loudness and distortion remain required QA.

## Fixed-camera living scenery

One persistent environment host owns a shared 15 fps cadence and pauses when
inactive or under Reduce Motion. The base image remains a static aspect-fill
composition outside the clock-driven effect subtree. No time-varying base
offset, position, scale, rotation, camera motion, parallax, or zoom remains.

Scene profiles select a small set of reusable local effects: cloud/fog/mist,
rain/snow, heat shimmer, occasional sand/snow gusts, aurora, celestial accents,
and water texture motion. Ocean, Rainforest, Canyon, and Arctic water motion
uses a duplicated copy of the exact scenic artwork clipped to scene-shaped
water masks. Only the masked baked water pixels receive small differential
translation/scale; the base camera stays fixed. Generic shimmer, glow, lines,
or particles are not used as a substitute for moving water.

The exact matrix is:

- Mountains Day/Night: moving clouds and upward valley fog.
- Ocean Day/Night: masked near/far water texture movement and moving clouds.
- Desert Day: heat shimmer, moving clouds, and occasional sand gusts.
- Desert Night: moving clouds and occasional sand gusts; no heat shimmer.
- Rainforest Day: masked waterfall and stream flow, cyclical mist, and rain.
- Rainforest Night: masked stream flow, moving clouds, and rain.
- Canyon Day: moving clouds, masked river flow, and a slow fog cycle.
- Canyon Night: moving clouds, masked river flow, and extremely slow celestial
  accents.
- Arctic Day: masked water ripple, snowfall, and moving clouds.
- Arctic Night: moving aurora, snowfall, and occasional loose-snow gusts, with
  no generated or animated cloud effect.

Artwork limitations are explicit: Arctic Night contains baked static clouds;
Rainforest Night has no distinct baked waterfall to animate convincingly; and
Canyon Night's moon/stars are baked, so only restrained local celestial
accents move. Source artwork was not regenerated or materially altered.

## Rendering and performance repair

- Removed the former whole-scene animation transform and broad root theme
  animation.
- Removed repeated live navigation-bar mutation on tab selection; UIKit chrome
  refreshes only for an actual presentation change.
- Kept static scenery, grading, and Royal Current identity imagery outside the
  environment clock's invalidation subtree.
- Reduced Dynamic-theme speed and intensity, removed unnecessary active
  compositing groups, and retained scenery beneath the treatment.
- Ordinary iOS 26 overlays now use clear native Liquid Glass with a much lighter
  veil, border, and shadow stack. Reduce Transparency and older-iOS material
  fallbacks remain stronger and unchanged.
- Visual Timer invalidation and geometry work is locally bounded as described
  above.

Focused Simulator ETTrace attempts established a tooling limit: the SwiftUI and
Animation Hitches instruments reported that they are unsupported on this
Simulator platform. No fabricated trace metrics are claimed. Code ownership,
deterministic contracts, repeated Simulator interactions, and paired scene
frames guide this checkpoint; physical frame pacing remains authoritative.

## Validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: 114 assertions.
- Session Note: 162 assertions.
- Visual Timer feedback: 71 assertions.
- Runtime feedback: 12 assertions.
- Scenery effects: 54 assertions.
- Fresh clean Debug Simulator build passed in 144.18 seconds.
- Fresh clean Release Simulator build passed in 219.66 seconds.
- Both builds contain and validate the embedded Live Activity extension.
- Expanded Simulator smoke passed for all five roots, the running Visual Timer,
  all 12 scenery profiles, Dynamic, Reduce Motion, and ordinary glass over
  scenery.
- Paired Simulator captures changed over time for Ocean Day/Night, Rainforest
  Day/Night, Canyon Day/Night, and Arctic Day water profiles.
- No crash report, fatal condition, assertion failure, or fault appeared during
  the final smoke. One Simulator audio-component factory log entry occurred
  without a crash. Builds emitted only the known no-AppIntents notice and the
  Simulator signed-extension strip warning; no source compiler warning appeared.
- The shared scheme remains byte-identical to Build 119 (SHA-256
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`).
- Marketing version remains 0.9.1 and `CURRENT_PROJECT_VERSION` remains 2. It
  was not manually changed to 120.

## Physical QA still required

Simulator evidence cannot close the release blockers. On the candidate's exact
SHA, verify:

- Start Live Day enters visible in-app running state from a real generated
  itinerary; intermediate stops, departures, Route Buffer, Return Home, GPS,
  and MapKit behavior remain correct.
- ActivityKit unavailable/denied/failure behavior is visible without killing
  Live Day, and supported launches project correctly to the Lock Screen.
- Root paging, Today scrolling, navigation, theme transitions, Dynamic plus
  scenery, glass-heavy Today, and Visual Timer maintain acceptable physical
  frame pacing with no timer rendering recurrence.
- Ordinary glass is approximately one-third as visually opaque as Build 119
  while text and controls remain readable, including accessibility fallbacks.
- Every scene effect is physically perceptible and natural; the base camera
  never pans, drifts, or zooms; masked water regions visibly move without seam
  artifacts; and Arctic Night has no generated/animated clouds.
- Timer maximum output is meaningfully louder without clipping/distortion, while
  Sound Off, 0%, persisted volume, tone choice, and Ring/Silent policy remain
  correct.

Known artwork limitations above require owner/physical-QA acceptance or a later
explicit asset decision. No further feature, release, or velocity work is
authorized from this checkpoint.
