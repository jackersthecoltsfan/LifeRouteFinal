# LifeRoute current engineering handoff

## Build 122 final stabilization authority

- Marketing version: `0.9.1`.
- Exact released Build 121 source and untouched `main`:
  `d8a4b818eda6f035da6666150a5d4515ec522461`.
- Active owner-directed stabilization branch:
  `fix/v0.9.1-build121-stabilization`.
- Active production worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-build121-stabilization`.
- The frozen donor/checkpoint remains intact at
  `/Users/brand/Documents/GitHub/LifeRouteFinal-build122-stabilization` on
  `fix/v0.9.1-build122-final-stabilization`.
- Preserved implementation commits:
  - `f1f411f30d9db158b8a0023d993b33877cefe6f7` — fix virtual routes and restore live origin.
  - `d2a05ee3d4241bec474e6e4c23f3a3e025f50ab3` — strengthen timer speaker-effective output.
  - `5c704c113932ccefb38a29bdbfdf94a14ba90605` — clarify glass and deepen haptics.
- The existing Build 121 branch was fast-forwarded to `5c704c1`; no commit was
  rewritten or cherry-picked.
- The guarded TestFlight workflow remains the only build-number owner. The
  checked-in `CURRENT_PROJECT_VERSION` remains `2`; do not hard-code `122`.

`main`, Developer Velocity branch `chore/v0.9.1-fast-iteration-v1`, and PR #127
were not modified. No TestFlight workflow was dispatched. No Session Note
anti-invention rule, v0.9.2 Scenic Orb feature, broad scenery redesign,
architecture cleanup, event editing, or calendar-management feature is part of
this candidate.

## P0 stability preservation

Build 121's iOS 26 lifecycle repair remains intact. Runtime UIKit controller-
tree chrome refresh is still disabled on iOS 26+, SwiftUI retains navigation
ownership, and no live `UINavigationBar` mutation or forced layout was restored.
The five roots still share one `LifeRouteRootNavigationStack`; no broad
five-root transparency modifier was added.

Focused Simulator stress covered settled five-root rendering, repeated root
switching, repeated deep navigation, and background/foreground restoration at
both a root and the Visual Timer destination. One scenery-only frame occurred
during rapid Simulator automation alongside RenderBox queue errors, but it did
not reproduce after a cold runtime reset, five consecutive Tools-to-Timer push/
pop cycles, or a deep-destination foreground restoration. No crash report,
UIKit assertion, fault, or fatal signature was produced, so no speculative
navigation or environment rewrite was made.

## Virtual and locationless routing

Virtual/locationless timed events now remain chronological itinerary nodes and
retain their exact start/end constraints while being excluded from MapKit
destinations. A conservative classifier rejects empty/all-day locations, exact
known provider-only labels, and known meeting URLs without treating an ordinary
physical address containing provider words as virtual.

Usable gaps retain virtual temporal anchors, omit travel/buffer to a virtual
commitment, and bridge the required physical route between the surrounding
routable commitments. Leave By targets the next routable appointment and does
not claim a departure that overlaps a still-active virtual commitment.

Full-day generation now carries a canonical selected-day token. Day, event,
stop, route option, return-home, or origin changes cancel and invalidate the
active calculation so a stale async result cannot publish into another day.

## Live Location

Today and Day Route use the existing `RoutingLocationCore`; no second location
engine was created. A shared route-origin status resolves and exposes
`Live / Current Location`, `Home`, locating/unavailable state, and the matching
action. Stale coordinates cannot remain canonical after Live is stopped or
authorization becomes denied/restricted.

Simulator interaction confirmed the visible `Use Live` control, transition to
`Live / Current Location` plus `Stop Live`, and deterministic fallback to Home
after stopping updates. Physical permission, GPS freshness, and route-origin
behavior remain physical-QA gates.

## Visual Timer audio

No hidden player attenuation or quiet asset exists: completion audio is
generated PCM, maximum persisted volume reaches player volume `1`, and the
approved `.playback` / `.default` / `.mixWithOthers` session is unchanged.
Build 121's three-note 1.20-second cue and peak normalization remain intact.

The remaining speaker weakness was spectral: the cue fundamentals were mostly
294-523 Hz, with only a weak third harmonic and very little energy in the
iPhone-speaker-effective upper-mid band. Build 122 raises the bounded third
harmonic and adds a bounded fourth harmonic, placing meaningful energy around
1.1-2.1 kHz without unbounded gain, clipping, or a longer overlapping cue.

Sound Off and 0% remain silent; persisted volume, Warm/Soft/Clear identity,
Ring/Silent behavior, completion timing, single-task ownership, and the
independent completion-haptic preference remain unchanged. Same-device physical
loudness comparison is still required.

## Ordinary glass and haptics

Ordinary iOS 26 glass was still dominated by full-strength native clear glass
over large and nested surfaces even after redundant custom tint/underlay removal.
Only ordinary ambient/card/readability/toolbar roles now place native glass on a
separate background layer at bounded opacity. Text stays fully opaque; selected
and legibility controls retain full native Regular glass. Reduce Transparency,
increased-contrast, and pre-iOS 26 fallbacks are unchanged.

Existing root-navigation and primary-action medium impacts were centrally raised
to their bounded maximum intensity. No new haptic event was added, and Visual
Timer completion haptics remain independently controlled.

A bounded smoothness audit found no additional proven low-risk invalidation fix.
The shared host, scene clock, effect layering, pause rules, and profile selection
also had no obvious scenery defect; no P3 scenery work was performed.

## Validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: 159 assertions (Build 121 floor: 114).
- Session Note: 162 assertions (floor preserved at 162).
- Visual Timer feedback: 100 assertions (Build 121 floor: 77).
- Runtime feedback: 21 assertions (Build 121 floor: 16).
- Scenery effects: 54 assertions (floor preserved at 54).
- Fresh Debug and Release generic-Simulator clean builds passed at product
  implementation HEAD `5c704c1` with no emitted compiler-warning lines.
- Debug and Release each built the main app and embedded Live Activity extension.
- Canonical Simulator smoke passed all five roots, Visual Timer, all 12 scenery
  profiles, Dynamic, Reduce Motion, and ordinary glass fixtures.
- Manual settled inspection passed all five roots, Today/Day Route deep
  navigation, repeated Tools/Visual Timer deep navigation, root switching,
  Live Location start/stop, and root/deep background-to-foreground restoration.
- Simulator logs contained no `NSAssertionHandler`, `UINavigationBar`, `SIGABRT`,
  uncaught-exception, or fatal signature. Expected Simulator XPC interruptions
  were observed during terminate/background stress; no LifeRoute diagnostic
  crash report was created.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.
- App and extension marketing version remain `0.9.1`; source build number remains
  `2`; project, signing, bundle identifiers, shared scheme, and workflows are
  unchanged.

## Physical QA and stop condition

Simulator and deterministic evidence do not prove physical perceived loudness,
glass transmission, haptic depth, swipe feel, GPS behavior, or absence of the
device-only navigation assertion. Owner review should physically verify:

- no navigation-bar assertion or retained blank/black content during root/deep
  navigation, background/foreground, lock/unlock, theme changes, and sustained use;
- virtual/locationless itineraries alongside physical-route controls;
- Live Location permission, freshness, origin labeling, Generate Full Day, and
  Live Day behavior;
- maximum Visual Timer completion output against the same-device reference,
  including cleanliness and every silence/identity/timing safeguard;
- ordinary glass transparency, existing haptic depth, and root-swipe feel.

Stop at the v0.9.1 final stabilization implementation checkpoint for owner
review. Do not promote `main`, dispatch TestFlight, resume Developer Velocity,
touch PR #127, begin v0.9.2, or implement deferred work.
