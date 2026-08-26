# LifeRoute v0.5.0 Architecture Rebuild Handoff

This is the restart document for the LifeRoute v0.5.0 rebuild. It supersedes the v0.4.0 hotfix strategy for new development work.

## Repository / rebuild branch

Repository: `jackersthecoltsfan/LifeRouteFinal`

Rebuild branch: `rebuild/v0.5.0-functional-core`

Branch base: `64b0c2fef3172a101885e9bdaf4eb7860cc41997`

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

Add a deterministic version audit that fails preparation/release if any prepared shipping target is not 0.5.0.

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
- Today / Schedule / Session Tools / Resources / Setup destinations as appropriate to the rebuilt information architecture;
- state ownership and restoration;
- contextual navigation;
- back/close behavior;
- first-run behavior without interaction blocking.

Audit every destination and transition.

### Layer 3 — core functional features

Reintroduce major functional areas in small batches. Suggested order:

1. calendar normalization and Day/Week/Month;
2. location/current location/home address;
3. routing and saved places;
4. clients/setup data;
5. Session Tools / ABA tools;
6. provider connections such as Google Calendar read-only OAuth;
7. Live Activity/native bridges where still useful;
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

- measure startup script/module count;
- reduce startup work;
- eliminate repeated scans and layout reads;
- cap observers to narrow containers;
- remove unnecessary timers/polling;
- keep native/WKWebView work off critical interaction paths;
- verify repeated navigation does not increase handler counts, DOM nodes, timers, or memory pressure;
- preserve reduced-motion/accessibility behavior.

### Layer 6 — stability layer

Verify:

- one owner per interaction;
- no duplicate startup modules;
- no overlay/pointer-event traps;
- no race-prone delayed DOM rewrites;
- no stale event handlers after navigation;
- deterministic lifecycle behavior across foreground/background/relaunch;
- safe bridge error handling;
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

Quarantine these chunks from the first functional-core release. Reintroduce them sequentially only after Brandon confirms the prior build remains functional on a physical iPhone.

Every cosmetic chunk must have its own performance/stability audit and must be removable without affecting navigation, data, routing, calendar, tools, or provider functionality.

If adding a cosmetic chunk breaks physical-device functionality, revert only that chunk/checkpoint and continue from the last known-good commit.

## Checkpoint / save-progress protocol

Every meaningful rebuild step must be saved so regressions can be localized precisely.

For each layer or feature batch:

1. make one clearly named commit/checkpoint;
2. add/update a focused audit or executable test;
3. record the commit SHA and what it introduced;
4. record validation status;
5. do not mix unrelated architectural/cosmetic work into that checkpoint;
6. keep the previous known-good checkpoint recoverable.

Suggested checkpoint naming:

- `v0.5.0 checkpoint 00 — inventory/quarantine`
- `v0.5.0 checkpoint 01 — minimal interaction shell`
- `v0.5.0 checkpoint 02 — core navigation`
- `v0.5.0 checkpoint 03A — calendar core`
- `v0.5.0 checkpoint 03B — routing/location core`
- `v0.5.0 checkpoint 03C — setup/clients core`
- `v0.5.0 checkpoint 03D — Session Tools core`
- `v0.5.0 checkpoint 04 — persistence migration`
- `v0.5.0 checkpoint 05 — performance`
- `v0.5.0 checkpoint 06 — stability`
- `v0.5.0 checkpoint 07 — second functionality pass`
- `v0.5.0 cosmetic 01 — core identity`
- `v0.5.0 cosmetic 02 — vector icons`
- etc.

Maintain a compact checkpoint table in this handoff as work progresses.

## Checkpoint table

| Checkpoint | Commit | Status | Notes |
|---|---|---|---|
| Rebuild baseline | `64b0c2fef3172a101885e9bdaf4eb7860cc41997` | Baseline only | v0.4.0 runtime; buttons still unusable on physical device. Do not treat as functional core. |

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
5. start with **Layer 0 inventory/quarantine**, not cosmetics and not another interaction hotfix;
6. create/update the checkpoint table after every completed layer.

## Immediate next action

Begin **v0.5.0 checkpoint 00 — inventory/quarantine**.

Map the existing architecture before deleting or migrating anything. Specifically inventory startup scripts, event ownership, overlays, observers, timers, persistence keys, generated patch layering, native bridges, functional feature modules, and all cosmetic modules that should be preserved as optional chunks.

Then produce a proposed minimal v0.5.0 startup/runtime graph and only after that begin checkpoint 01, the minimal interaction shell.
