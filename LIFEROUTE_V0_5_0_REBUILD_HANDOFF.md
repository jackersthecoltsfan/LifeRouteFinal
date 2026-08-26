# LifeRoute v0.5.0 Architecture Rebuild Handoff

This is the restart document for the LifeRoute v0.5.0 rebuild. It supersedes the v0.4.0 hotfix strategy for new development work.

## Repository / rebuild branch

Repository: `jackersthecoltsfan/LifeRouteFinal`

Rebuild branch: `rebuild/v0.5.0-functional-core`

Branch base: `64b0c2fef3172a101885e9bdaf4eb7860cc41997`

Draft validation PR: `#20` — `LifeRoute v0.5.0 functional-core rebuild`. Do not merge until the rebuild sequence reaches the exact-SHA release checkpoint.

The last v0.4.0 interaction hotfix was uploaded successfully to TestFlight in workflow run #72 / run ID `33013143643`. Physical-device testing still showed that buttons remained unusable. Treat that as the final signal that the existing active interaction/runtime architecture must be rebuilt rather than patched further.

## Product decision: rebuild the active architecture

LifeRoute v0.5.0 is a controlled architecture rebuild from the functional core upward.

Do not keep stacking interaction hotfixes onto the existing active runtime. Rebuild the operational architecture so ownership is explicit, startup is deterministic, and every interaction has one clear owner.

This does **not** mean discarding every useful part of LifeRoute. Stable pieces may be migrated selectively after they are reviewed. Candidates include domain logic, data models, native bridges, calendar normalization, routing logic, location services, provider integrations, OAuth/Keychain work, and reusable visual assets.

Legacy WebView interaction plumbing, duplicated event owners, accumulated patch layers, broad observers, repeated timers/polling, fragile startup ordering, stale compatibility shims, and runtime effects that cannot prove their value should not be carried forward merely because they already exist.

Prefer progressively more native SwiftUI architecture where practical, in line with `AGENTS.md`. Keep WebView/native bridge compatibility only where it is still justified.

## Primary goal

**Make LifeRoute reliably operable first.**

The first v0.5.0 TestFlight candidate is intentionally a performance/functionality build, not the final cosmetic build.

It must prove on a physical iPhone that:

- every primary navigation button works;
- every visible button/control has exactly one functional owner;
- forms accept input reliably;
- overlays cannot invisibly intercept taps;
- calendar/day/week/month controls work;
- routing/location actions work;
- Setup and Session Tools navigation works;
- provider connection actions remain functional;
- startup remains responsive;
- repeated navigation does not progressively slow or freeze;
- app state survives appropriate relaunches without stale UI/runtime state breaking interactions.

Performance, stability, and correctness take priority over visual effects until this is proven on-device.

## Apple / TestFlight version requirement

The rebuild must appear in App Store Connect / TestFlight as marketing version:

`0.5.0`

Do not allow the prepared Xcode project, app target, Live Activity target, archive, or exported IPA to inherit `0.4.0`.

Build numbers may continue increasing normally under marketing version 0.5.0.

Preparation must fail if any prepared shipping target is not 0.5.0.

## Architecture rebuild sequence

Build one layer at a time. Do not skip ahead.

### Layer 0 — inventory and quarantine

Before rebuilding behavior:

- inventory every startup script/module, event owner, observer, timer, overlay, persisted state key, generated patch, native bridge, and major feature surface;
- classify each as `core`, `migrate later`, `cosmetic chunk`, `legacy/quarantine`, or `remove`;
- identify duplicate ownership and startup-order dependencies;
- document which localStorage/persisted keys are safe to retain, migrate, or reset;
- establish a minimal startup graph.

No legacy interaction module should remain active by default unless explicitly approved into the new core.

### Layer 1 — minimal interaction shell

Build the smallest possible app shell with:

- direct startup;
- one navigation owner;
- semantic buttons/controls;
- no cosmetic animation dependencies;
- no broad MutationObservers;
- no global pointerdown/pointerup interception;
- no hidden overlay that can capture taps;
- no speculative rebinding timers;
- no duplicate route/navigation owners.

Audit this layer before adding features.

### Layer 2 — core navigation and state

Add and prove:

- top-level navigation;
- Today / Schedule / Session Tools / Resources / Setup destinations;
- state ownership and restoration;
- contextual navigation;
- back/close behavior;
- first-run behavior without interaction blocking.

Audit every destination and transition.

### Layer 3 — core functional features

Reintroduce major functional areas in small batches. Current sequence:

1. calendar normalization and Day/Week/Month;
2. location/current location/home address and routing/saved places;
3. clients/setup data;
4. Session Tools / ABA tools;
5. provider connections such as Apple Calendar and Google Calendar read-only OAuth;
6. Resources and remaining deterministic functional surfaces;
7. Live Activity/native integrations where still useful;
8. AI/recommendation layers only after deterministic core features are stable.

Each feature batch gets its own checkpoint and focused audit before the next is added.

### Layer 4 — persistence and data cleanup

Audit all persisted data and migrations.

- remove obsolete keys;
- migrate only data that still maps cleanly to the new architecture;
- prevent stale v0.4.0 runtime state from reactivating removed UI/interaction systems;
- provide safe defaults if old persisted values are malformed or incompatible;
- avoid deleting useful user-entered product data unnecessarily.

Add deterministic persistence/migration tests.

### Layer 5 — performance layer

Only after core functionality works:

- measure startup work;
- eliminate repeated scans/layout work;
- remove unnecessary timers/polling;
- keep native work off critical interaction paths;
- verify repeated navigation does not increase handlers, nodes, tasks, or memory pressure;
- preserve reduced-motion/accessibility behavior.

### Layer 6 — stability layer

Verify:

- one owner per interaction;
- no duplicate startup systems;
- no overlay/pointer-event traps;
- no race-prone delayed UI rewrites;
- no stale event ownership after navigation;
- deterministic lifecycle behavior across foreground/background/relaunch;
- safe provider error handling;
- graceful failure when external services are unavailable.

### Layer 7 — second full functionality pass

Repeat all critical workflows after performance/stability changes.

Do not release the first v0.5.0 TestFlight build unless this second functionality pass is green.

## First v0.5.0 TestFlight checkpoint

The first v0.5.0 TestFlight release should contain:

- rebuilt functional core;
- essential features required for meaningful physical-device testing;
- persistence/data migration needed for safe use;
- performance layer;
- stability layer;
- minimal functional styling only.

It should **not** depend on the old cosmetic runtime.

After deterministic preparation, focused layer audits, full regression, and iOS Simulator build pass, upload this performance/functionality candidate to TestFlight as **0.5.0** for physical-device validation.

Do not begin layering full cosmetics into the TestFlight candidate until physical-device interaction is confirmed reliable.

## Preserve current appearance as modular cosmetic chunks

Do **not** delete the existing LifeRoute appearance work. Preserve it as a library of optional cosmetic chunks that can be added back on top of the rebuilt core one at a time.

The key rule is: **appearance must never be required for functionality.**

Preserve/refactor current appearance work into independently enableable modules such as:

1. **Core visual identity chunk** — dark-blue/gold palette, typography, spacing, cards, borders, base shadows.
2. **Vector icon chunk** — refined navigation/action icons and consistent stroke/size treatment.
3. **Theme framework chunk** — categorized Themes (`Classic`, `Metallic`, `Scenery`, `Dynamic`, `Fluid`, `Living`).
4. **Glass/material chunk** — lightweight translucent/glass surfaces with iPhone-safe blur budgets.
5. **Motion chunk** — page transitions, button press motion, selection transitions, reduced-motion fallbacks.
6. **Haptics/sound chunk** — post-action haptics and subtle feedback that never participates in event delivery.
7. **Dynamic/scenery chunk** — animated or living backgrounds, environmental effects, creatures/scenery.
8. **Onboarding/polish chunk** — welcome/tour and premium finishing details.

Quarantine these chunks from the first functional-core release. Reintroduce them sequentially only after physical-device confirmation of the prior build.

Every cosmetic chunk must have its own performance/stability audit and must be removable without affecting navigation, data, routing, calendar, tools, or provider functionality.

## Checkpoint / save-progress protocol

Every meaningful rebuild step must be saved so regressions can be localized precisely.

For each layer or feature batch:

1. make one clearly named commit/checkpoint;
2. add/update a focused audit or executable test;
3. record the commit SHA and what it introduced;
4. record validation status;
5. do not mix unrelated architectural/cosmetic work into that checkpoint;
6. keep the previous known-good checkpoint recoverable.

## Checkpoint table

| Checkpoint | Commit | Status | Notes |
|---|---|---|---|
| Rebuild baseline | `64b0c2fef3172a101885e9bdaf4eb7860cc41997` | Baseline only | v0.4.0 runtime; buttons still unusable on physical device. Do not treat as functional core. |
| Checkpoint 00 — inventory/quarantine | `558c649dfa501a4317d7bdc0aeb4ed6c4ef90e53` | Complete | Architecture/quarantine inventory saved; legacy interaction layers classified; cache policy preserves useful product data. Version guard work began at `2523331faa2d67c5d4e1a2a750267987cb50c80d`. |
| Checkpoint 01 — minimal interaction shell | `5656d380345f6ca4b54f3dcb6a3030c9d9d9dde7` | Green | Native SwiftUI shell; legacy `LifeRouteWebView.swift` removed from active Sources and `LifeRoute/Web` removed from Resources; v0.4 patch stack no longer runs. CI #627 / `33015560338` passed preparation, audit, and Simulator build. |
| Checkpoint 02 — core navigation | `066455a54a3552fe756a3da8877ec263faa6cd0a` | Green | Root `AppRouter`, five native NavigationStacks, typed routes, semantic controls, native dismiss/back, centralized cross-tab navigation. Policy #12 / `33016029524` and iOS CI #629 / `33016029523` passed. |
| Checkpoint 03A — calendar core | `2a1f5024d215bc4f14280ab7a9b26fb7e2392513` | Green | Native normalized calendar events and source identity, deterministic Day/Week/Month calculations, in-memory validated manual appointments. No provider/persistence/cosmetic dependency. Policy #14 / `33016371522`; iOS CI #631 / `33016371727` passed. |
| Checkpoint 03B — routing/location core | `6523c8af0931f3fe7e6975a8562a41c83a9361d5` | Green | Native Core Location + MapKit, one-shot location requests, current-location-first routing with home fallback, session-only saved places, route estimates, Apple Maps handoff. Policy #15 / `33016701273`; iOS CI #632 / `33016701447` passed. |
| Checkpoint 03C — clients/setup core | `d5aca2e916e5f1fccb2274e22a7736b9a5a542d9` | Green | Client feature code introduced at `98df74bb622855a537046c380e3bacdbffb0bc9a`; composable audit correction finalized at this SHA. Native ABA-style four-letter client codes, service location, preferred activities, targets, behaviors of concern, communication/FCT, prompting, caregiver, and clinical notes. Policy #17 / `33016981569`; iOS CI #634 / `33016981568` passed. |
| Checkpoint 03D — Session Tools core | `801f4601180f20889184e757e010972d94279431` | Green | Native absolute-deadline visual timer using `TimelineView`, client-linked scratch notes, text First/Then, and deterministic session-plan organizer constrained to user-entered/saved supervisor-approved information. No polling timer, modal overlay, AI, persistence, haptics, or cosmetic dependency. Policy #18 / `33017293601`; iOS CI #635 / `33017293583` passed. |

## Active runtime / quarantine status

The active application target currently compiles the reviewed native SwiftUI core and native feature-domain files. `LifeRouteWebView.swift` and `LifeRoute/Web/` remain in Git/Xcode project groups only as migration/reference material; they are not active Sources/Resources. `scripts/prepare_build.sh` does not run the v0.4.0 patch stack or inject legacy JavaScript.

Build/cache policy: repository-local `build/` is cleared during preparation; Xcode DerivedData/archives/IPAs/user state remain gitignored. Do not blanket-delete user-entered product data or Keychain tokens merely as cache cleanup; persistence migration owns that decision later.

## Safety / compatibility constraints

Preserve unless a deliberate migration changes them:

- Google Calendar provider access remains read-only (`calendar.readonly`);
- no secrets or private signing material in source/browser storage;
- native Keychain/OAuth infrastructure may be reused if reviewed and stable;
- no username/PIN startup gate in the first v0.5.0 functional core;
- no whole-document/broad class MutationObservers;
- no programmatic document scrolling as a navigation mechanism;
- no global pre-click DOM mutation;
- no cosmetic layer may own business navigation or feature state;
- no TestFlight upload without explicit authorization and green exact-SHA validation.

## New-thread start procedure

At the beginning of the next thread:

1. read this file first;
2. read `AGENTS.md`;
3. read `LIFEROUTE_HANDOFF.md` for historical context;
4. inspect the live `rebuild/v0.5.0-functional-core` branch and current Actions state;
5. continue from the first incomplete checkpoint in the table; do not return to v0.4.0 hotfix layering;
6. create/update the checkpoint table after every completed layer.

## Immediate next action

Begin **v0.5.0 checkpoint 03E — native calendar providers**.

Extract only the stable native provider logic from the quarantined WebView coordinator. Add Apple EventKit read access first and feed normalized `LifeRouteCalendarEvent` values directly into `CalendarCoreState`. Then add Google Calendar read-only PKCE OAuth using the existing non-secret iOS client configuration, retain refresh tokens only in Keychain, and normalize Google events directly into the same calendar state. Do not reactivate `LifeRouteWebView`, JavaScript bridge message handling, or browser persistence. Keep provider refresh user-triggered / bounded rather than polling.