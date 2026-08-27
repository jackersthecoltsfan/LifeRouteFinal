# LIFEROUTE v0.7.0 — NEW CHAT HANDOFF

Continue LifeRoute development as **v0.7.0**, the major native SwiftUI UI overhaul.

## Repository

`jackersthecoltsfan/LifeRouteFinal`

## Release baseline

The last shipped functional baseline is:

- LifeRoute **v0.6.3**
- TestFlight **build #83**
- main SHA: `9471190b41c073a39c100cd2482f0b7b665d714b`

That baseline includes:

- the v0.6.3 ABA session-note context-window fix;
- responsive selected-day browsing/route launch;
- date-selector hotfix from TestFlight build #83;
- Core themes reduced to clean color schemes without decorative imprints;
- timer audio refinements;
- Live Activity support;
- existing native calendar/routing/client/tools functionality.

Do not regress any of those systems.

## Planning branch

The phased UI plan and this handoff are stored on:

`planning/v0.7.0-ui-overhaul`

Read:

`LIFEROUTE_V0_7_0_UI_PLAN.md`

before making code changes.

## Critical development strategy

Do **not** build the entire v0.7.0 redesign in one PR.

Implement it as sequential, independently validated checkpoints:

1. **Checkpoint 0 — Visual contract + architecture**
2. **Build A — Global shell + reusable design system**
3. **Build B — Today/Home overhaul**
4. **Build C — Schedule/calendar/route-planning overhaul**
5. **Build D — Tools + ABA clinical workflow overhaul**
6. **Build E — Resources/clients/saved places/Setup overhaul**
7. **Build F — True app-wide Scenery themes + visual unification**
8. **Build G — Polish/responsiveness/accessibility/release candidate**

Each checkpoint gets its own narrow branch and PR. Require the full preparation/regression suite and actual Xcode iOS Simulator compilation before merge. After merge, require main validation again. Use TestFlight checkpoints for real-device visual review before starting the next major screen family.

## First action in the new chat

The user should upload the previously approved **target v0.7.0 UI preview image** again. Treat that image as the visual source of truth.

Before changing production views, extract a compact implementation checklist from the image covering:

- background treatment;
- card geometry/material;
- typography hierarchy;
- spacing;
- icon treatment;
- navigation/tab bar;
- buttons;
- selected states;
- shadows/strokes/glows;
- responsive iPhone behavior;
- scenery behavior.

Then begin **Checkpoint 0 / Build A only**. Do not start later checkpoints early.

## Visual direction

The final app should feel:

- sleek;
- premium;
- professional;
- bold;
- elegant;
- streamlined;
- futuristic;
- intentional rather than generic/form-heavy.

LifeRoute's signature Royal identity remains dark blue + gold, with the broader customizable theme system preserved.

### Core themes

Core themes are **color schemes only**. Do not add decorative symbols, imprints, watermark-like artwork, random shapes, or scene illustrations to Core themes.

Requested Core catalog remains:

- Royal — dark blue + gold
- Cobalt Shine — dark/bold/bright/light blues
- Golden — gold/bronze
- Sunflare — burnt oranges and related warm tones
- Noir — dark silver/black/chrome
- Kaleidoscope — bright vibrant rainbow
- Light — light pastel shades only
- Dark — dark colors only
- Classic — white/grey/black only
- Accessible — minimal distraction, black/white only

### Scenery themes

The user confirmed Scenery still does not truly appear on every page in v0.6.3. Do **not** patch the old UI further for this. Solve it deliberately in **Build F** after the new page architecture is in place.

## Functional systems that are protected

The v0.7.0 UI work must preserve:

- calendar/event loading and persistence;
- selected-day browsing and planning;
- current-location behavior;
- routing and Google Maps handoff;
- saved places/gap suggestions;
- client storage;
- ABA session-note generation;
- the v0.6.3 bounded Apple Foundation Models request/context-window fix;
- timer engine/audio behavior;
- Live Activity extension;
- theme persistence;
- all existing migration/persistence behavior.

Do not mix major new product features into the UI overhaul unless required for the target UI to function.

## Native priority / build rules

- TestFlight/native iOS is always higher priority than web preview.
- Web preview must not block native work unless the user explicitly requests it.
- Keep `LifeRouteWebView.swift` and the old Web runtime quarantined.
- Do not reintroduce the legacy WebView architecture.
- Never merge a UI checkpoint if preparation/regression or the real Simulator build is red.

## Recommended branch pattern

Use branches such as:

- `feature/v0.7.0-shell`
- `feature/v0.7.0-today-ui`
- `feature/v0.7.0-schedule-ui`
- `feature/v0.7.0-tools-ui`
- `feature/v0.7.0-data-setup-ui`
- `feature/v0.7.0-scenery-ui`
- `release/v0.7.0-rc`

Always branch from the last accepted green main baseline, not from stale parallel UI branches.

## New-chat opening prompt

The user can paste:

> @Build iOS Apps @SwiftUI Expert @GitHub
>
> Continue LifeRoute as v0.7.0 from `LIFEROUTE_V0_7_0_HANDOFF.md` and `LIFEROUTE_V0_7_0_UI_PLAN.md` on branch `planning/v0.7.0-ui-overhaul` in `jackersthecoltsfan/LifeRouteFinal`.
>
> Use main SHA `9471190b41c073a39c100cd2482f0b7b665d714b` / v0.6.3 TestFlight build #83 as the functional baseline. I am attaching the target UI preview image again. Start with Checkpoint 0 and Build A only. Do not attempt the entire overhaul in one build.

## Definition of success for v0.7.0

v0.7.0 is complete only when the major native screens share one coherent visual system, the target reference is substantially reproduced, Scenery works app-wide, all important existing functionality survives, and the final release candidate passes both the full native regression suite and actual iOS Simulator compilation before TestFlight release.
