# LifeRoute current engineering handoff

## Build 123 physical-acceptance authority

- Marketing version: `0.9.1`.
- Exact stable Build 122 baseline and current `main` at branch creation:
  `b7866decf0b10793ad3a41ff0c548a58d9087a02`.
- Build 123 branch: `fix/v0.9.1-build123-physical-acceptance`.
- Isolated worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-build123-physical-acceptance`.
- The guarded TestFlight workflow remains the only build-number owner. The
  checked-in `CURRENT_PROJECT_VERSION` remains `2`; do not hard-code `123`.

This checkpoint contains exactly the authorized ordinary-glass, Visual Timer
completion-output, and composite virtual-location repairs. Build 122's physical
stability repairs and all frozen navigation, environment-host, Live Day, Live
Location, general routing, performance, scenery, Session Note, Image Playground,
Developer Velocity, PR #127, cleanup, and v0.9.2 work remain untouched. `main`
was not promoted and no TestFlight workflow was dispatched.

## Ordinary surface composition

Build 122 reduced opacity on each native Clear glass layer, but large cards and
their child rows still participated independently in native adaptive glass
inside `GlassEffectContainer`. On physical iPhone those nested adaptive blur and
darkening passes compounded, so reducing only the outer layer opacity did not
make scenery read through the hierarchy.

Build 123 removes native adaptive glass from the ordinary ambient, card,
readability, and toolbar roles. These roles now use a lightweight custom
readability fill (`0.025`-`0.075` for dark scenes and `0.040`-`0.105` for bright
scenes), a `0.028` neutral highlight, and the existing subtle border/shadow.
Native Regular glass remains reserved for selected and legibility controls.
Reduce Transparency, increased-contrast, and pre-iOS 26 material fallbacks are
unchanged.

The Simulator canyon fixture shows scene detail plainly through the large Today
cards, timeline area, Calendar rows, Tools cards, Resources rows, and Setup rows.
Physical appearance remains authoritative.

## Visual Timer completion output

The output path has no hidden attenuation: generated mono PCM reaches an
`AVAudioPlayerNode` at persisted player volume up to `1`, through the established
`.playback` / `.default` / `.mixWithOthers` session. Build 122's limitation was
the cue master itself: peak normalization held `0.92` peak, but the 1.20-second
three-note waveform retained a `1.61`-`1.70` crest factor and too little
sustained practical output.

Build 123 keeps the `0.92` clipping headroom, uses one 2.10-second five-note
completion event, extends the sustained envelope, and applies bounded `tanh`
soft limiting at drive `1.40`. Deterministic 44.1 kHz measurements are:

- Warm: RMS `0.5405 -> 0.6650`; crest `1.702 -> 1.383`; energy
  `15458.6 -> 40959.8`.
- Soft: RMS `0.5590 -> 0.6797`; crest `1.646 -> 1.354`; energy
  `16539.2 -> 42780.6`.
- Clear: RMS `0.5717 -> 0.6890`; crest `1.609 -> 1.335`; energy
  `17295.6 -> 43961.6`.

Sound Off and 0% remain silent. Persisted volume, Ring/Silent playback,
Warm/Soft/Clear identities, a single completion event, bounded samples, smooth
attack/release, and the independent completion-haptic preference are preserved.
Same-device physical loudness and sound-quality comparison is still required.

## Composite virtual-location routing

The Build 122 classifier recognized exact provider-only labels and meeting URLs,
but exact-set matching let `Home — Microsoft Teams Meeting` pass through as a
MapKit destination. Build 123 splits only explicit composite separators and
rejects a known virtual provider segment when every remaining segment is from a
narrow non-address context list such as Home or Virtual.

The exact physical-QA string now remains a chronological timed commitment,
constrains both usable gaps, receives no MapKit leg, and preserves the bridged
physical route and truthful Leave By behavior. Exact provider labels, meeting
URLs, `Virtual — Zoom Meeting`, empty locations, and all-day locations remain
non-routable. `123 Microsoft Teams Way` and
`123 Main Street — Microsoft Teams Meeting` remain routable controls.

## Validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: `163` assertions (Build 122 floor `159`).
- Session Note: `162` assertions (floor preserved).
- Visual Timer feedback: `119` assertions (Build 122 floor `100`).
- Runtime feedback: `25` assertions (Build 122 floor `21`).
- Scenery effects: `54` assertions (floor preserved).
- Fresh Debug and Release generic-Simulator clean builds passed with no emitted
  compiler-warning lines.
- Debug and Release each produced the v0.9.1 main app and embedded Live Activity
  extension.
- Canonical Simulator smoke passed all five roots, the Visual Timer deep route,
  all 12 scenery profiles, Dynamic, Reduce Motion, and ordinary-glass fixtures.
  Calendar and Tools first landed on pre-settlement frames during rapid launch
  automation; bounded five-second settled retries rendered both correctly.
- Simulator review found no `NSAssertion`, `UINavigationBar`, fatal, uncaught-
  exception, `SIGABRT`, or crash signature, and no LifeRoute diagnostic report.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.
- App/extension version, source build number, project structure, signing, bundle
  identifiers, protected scheme, and workflows are unchanged.

## Physical QA and stop condition

Owner review should physically verify only the three Build 123 acceptance items:

- ordinary large/nested cards show scenery plainly while text remains readable,
  including bright scenes and accessibility fallbacks;
- 100% Visual Timer completion output is in the same practical loudness class as
  the same-device reference without clipping, harsh distortion, duplicated
  playback, or any silence/identity/haptic regression;
- a real calendar event with `Home — Microsoft Teams Meeting` generates the day
  without `MKErrorDomain` error 4, while a real physical-address control still
  routes correctly between surrounding commitments.

Stop at `v0.9.1 BUILD 123 PHYSICAL ACCEPTANCE IMPLEMENTATION CHECKPOINT` for
owner review. Do not promote `main`, dispatch TestFlight, or begin any frozen or
deferred work.
