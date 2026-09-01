# LifeRoute current engineering handoff

## Build 121 stabilization authority

- Marketing version: `0.9.1`.
- Exact Build 120 baseline and current pre-promotion `main`:
  `583e244942f83ea02195937fded3171431595e5c`.
- Build 121 branch: `fix/v0.9.1-build121-stabilization`.
- Isolated worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-build121-stabilization`.
- Repair commits before this integration checkpoint:
  - `7425d6e` — stabilize the iOS 26 navigation-container lifecycle.
  - `ca5cc66` — increase Visual Timer completion output.
  - `80b6d51` — add Build 121 stabilization contracts.
- The guarded TestFlight workflow remains the only build-number owner. The
  checked-in `CURRENT_PROJECT_VERSION` remains `2`; do not hard-code `121`.

The Developer Velocity branch
`chore/v0.9.1-fast-iteration-v1` at
`f1ceab70c126a8f1e8e8e11ba2278c490d3e4f61` and PR #127 were not used or
modified. No v0.9.2 or scenery-motion enhancement work is part of Build 121.

## Crash evidence and repair

The authoritative Build 120 crash is incident
`FCAC94ED-77DD-424E-8B30-A3E04951D9BC` on iPhone18,1 / iOS 26.6.1:
`EXC_CRASH (SIGABRT)` on the main thread through
`NSAssertionHandler -> UINavigationBar.layoutSubviews -> CoreAnimation`.

The prior safeguard disabled direct custom navigation-bar appearance on iOS
26, but `refreshVisibleChrome` still synchronously traversed live UIKit
controllers during launch, theme changes, and foreground restoration. It also
mutated the tab controller and could force layout while a SwiftUI-owned
navigation bar was already laying out.

Build 121 makes live controller-tree chrome refresh a legacy fallback for iOS
16-25 only. On iOS 26 and later the guard returns before `UIApplication`, scene,
window, or controller access. The forced `setNeedsLayout` path is removed, and
no new push/pop toolbar-background visibility mutation was introduced.

## Intermittent black-background repair

Physical video and an exact Build 120 Simulator reproduction showed scenery
still visible in the top and bottom bands while a black center covered Calendar
or other lazily materialized roots. Theme selection restored the center. This
proves that the persistent scenery host and selected image survived; an opaque
UIKit/SwiftUI navigation-container surface covered the environment.

All five root stacks now use one shared `LifeRouteRootNavigationStack`. On iOS
26, the root content declares a clear navigation container background inside
the `NavigationStack`; the existing shared deep-destination boundary does the
same. Older systems retain the established fallback. This replaces timing-
dependent recursive UIKit clearing without per-screen background patches.

## Visual Timer audio repair

There is no quiet source asset or hidden player attenuation: completion audio
is generated PCM, maximum persisted volume reaches `AVAudioPlayerNode.volume =
1`, and the approved `.playback` plus `.mixWithOthers` session remains intact.
Build 120's short, fast-decaying waveform carried too little sustained energy.

Build 121 uses a 1.20-second three-note cue, slower bounded decay, restrained
presence harmonics, and whole-cue peak normalization to `0.92`. Depending on
the selected tone, RMS is 1.94-2.01 times Build 120 and total signal energy is
8.66-9.31 times Build 120. Samples are finite, non-clipped, and retain digital
headroom. Sound Off, 0% silence, persisted volume, tone selection, Ring/Silent
policy, countdown/completion ownership, and independent completion haptics are
unchanged.

## Scenery scope

The Build 120 fixed-camera environment and localized effects are preserved.
No scenery source, profile, effect, intensity, clock, mask, artwork, panning,
zooming, or animation architecture changed. A bounded read-only check found
the shared host active and its effects changing in Simulator; further physical
perceptibility work remains deferred.

## Local validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: 114 assertions.
- Session Note: 162 assertions.
- Visual Timer feedback: 77 assertions.
- Runtime feedback: 16 assertions.
- Scenery effects: 54 assertions.
- Fresh Debug and Release generic Simulator builds passed.
- Both builds compiled and validated the embedded Live Activity extension.
- Full Simulator smoke passed for all five roots, running Visual Timer, all 12
  scenery profiles, Dynamic, Reduce Motion, and ordinary glass.
- Focused stress passed: background/foreground restoration, immediate Calendar
  capture, Theme Center theme change plus immediate pop, and ten consecutive
  five-root cycles. Scenery remained visible with no navigation crash.
- Simulator logs contained no `NSAssertionHandler`, `UINavigationBar`,
  `SIGABRT`, uncaught-exception, or fatal signature. Rapid automation produced
  Simulator system-gesture timeouts; the known audio-component factory and
  Simulator audio-overload messages were also observed without a crash.
- Warning assessment found two known no-AppIntents notices and zero unexpected
  compiler warnings.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.
- App and extension marketing version remain `0.9.1`; source build number
  remains `2`; project, signing, bundle IDs, and workflows are unchanged.

## Physical QA still required

Simulator evidence cannot close the physical blockers. Verify on the exact
Build 121 TestFlight source:

- no recurrence of the navigation-bar assertion during root/deep navigation,
  theme changes, background/foreground, lock/unlock, or prolonged normal use;
- no black frame immediately or after delay on all roots and Theme Center;
- maximum and normal persisted timer volume are unmistakably louder and clean,
  with no clipping, harsh distortion, truncation, or duplicate completion;
- Sound Off, 0%, Ring/Silent, tone choice, completion timing, and independent
  haptics remain correct;
- Visual Timer rendering remains stable and overall physical frame pacing is
  acceptable;
- Live Day, ActivityKit, GPS, and MapKit behavior remain correct.

The owner authorized the exact validated Build 121 candidate to be published,
fast-forwarded to `main` only if `main` remains the Build 120 baseline, gated by
exact-SHA iOS Current Baseline and Release Policy Check, and dispatched once to
the existing guarded TestFlight workflow. Stop polling as soon as Upload to
TestFlight becomes `in_progress`.
