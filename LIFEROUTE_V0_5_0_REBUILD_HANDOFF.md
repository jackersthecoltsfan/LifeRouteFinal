# LifeRoute v0.5.0 Architecture Rebuild Handoff

This is the current restart document for the LifeRoute v0.5.0 rebuild. It supersedes the v0.4.0 interaction-hotfix strategy for new development.

## Repository / validation branch

Repository: `jackersthecoltsfan/LifeRouteFinal`

Rebuild branch: `rebuild/v0.5.0-functional-core`

Branch base: `64b0c2fef3172a101885e9bdaf4eb7860cc41997`

Draft validation PR: `#20` — `LifeRoute v0.5.0 functional-core rebuild`.

Current branch / PR head at handoff: `61ce2de0755eb871876d7665742f081ba72415d1`.

Keep the PR draft/unmerged until the rebuild reaches the exact-SHA release checkpoint.

The last v0.4.0 interaction hotfix reached TestFlight, but physical-device testing still showed unusable buttons. Treat that as the final signal that the old active interaction architecture must remain quarantined rather than patched further.

## Core rebuild decision

LifeRoute v0.5.0 is native-first SwiftUI with explicit ownership. The active target must not depend on the old WebView interaction runtime.

Preserve useful domain/native capability, but do not reactivate:
- the legacy 62-module JavaScript startup graph;
- global click/pointer/touch interception;
- broad `MutationObserver` behavior;
- speculative rebinding/polling timers;
- duplicate route/navigation owners;
- hidden overlays that can capture taps;
- cosmetic modules that mutate functional state;
- the username/PIN startup gate.

`LifeRouteWebView.swift` and `LifeRoute/Web/` remain in Git only as migration/reference material. They are not active Sources/Resources.

## Release requirement

The first rebuilt TestFlight candidate must be marketing version `0.5.0`.

Do not upload a TestFlight build unless:
1. the functional rebuild sequence is complete enough for meaningful device testing;
2. persistence, performance, stability, and the second full functionality pass are green;
3. the exact release SHA passes deterministic preparation/audits and iOS build;
4. the user explicitly authorizes the upload.

Full cosmetic layering remains deferred until a functional v0.5.0 build is proven reliable on a physical iPhone.

## Rebuild sequence

### Layer 0 — inventory / quarantine
Complete.

### Layer 1 — minimal native interaction shell
Complete and green.

### Layer 2 — native navigation / state ownership
Complete and green.

### Layer 3 — deterministic functional features
Implemented in audited batches:
1. calendar Day/Week/Month core;
2. current location, routing, home and saved places;
3. client profiles;
4. Session Tools;
5. Apple + Google Calendar native providers;
6. client-specific visual supports.

Provider access remains read-only. Google refresh credentials stay in Keychain. Provider refresh is explicit/bounded rather than polled.

### Layer 4 — persistence / data cleanup
04A and 04B are green. 04C is implemented and awaiting corrected exact-head Simulator validation.

Completed / implemented persistence slices:
- 04A: clients + client visual-support data — green;
- 04B: manual LifeRoute appointments + home address + saved places — green;
- 04C: pure-native v0.4 legacy mapper/merge boundary — implemented; audit passed on the first validation attempt, but the first Swift compile found isolated mapper compiler errors. Those errors were fixed. The corrected head has not yet received a new GitHub Actions run because PR event delivery has been delayed.

Persistence uses one versioned native JSON snapshot in protected Application Support, atomic writes, tolerant decoding, corruption backup/recovery, and deterministic sanitization.

Do not persist:
- Apple/Google event caches;
- provider connection/status objects;
- current GPS coordinates;
- calculated route estimates;
- transient Session Tool scratch state unless deliberately added later.

04C deliberately does **not** activate a WebKit/localStorage reader at startup. It only provides a reviewed native JSON mapping/merge boundary that can accept known legacy data later. Old WebKit website data remains untouched for a possible explicit migration-only reader after the native build is proven reliable on physical hardware.

### Layer 5 — performance
Initial code-first inventory is complete; implementation has **not** started yet.

Highest-priority performance targets found:
1. `LifeRoutePersistenceStore` is `@MainActor` and synchronously reads/encodes/writes the entire JSON snapshot, including visual-photo bytes. Every save currently serializes the whole state on the interaction thread.
2. `loadClientVisualSupports()` and `loadRoutingState()` call full-state sanitization again on reads even though state is already sanitized at load/save boundaries.
3. visual-support getters repeatedly filter/sort broad arrays during view rendering (`icons(for:)`, `choiceBoards(for:)`, `schedules(for:)`, repeated `icon(id:for:)` lookups).
4. `ClientVisualIconThumbnail` performs `UIImage(data:)` decoding inside SwiftUI `body`, meaning image decode can repeat during view invalidation/scrolling.
5. calendar view code performs repeated event filtering for Day/Week/Month rendering. This is acceptable at tiny data sizes but should be reviewed/precomputed before provider calendars scale event counts.
6. broad `ObservableObject` ownership is currently manageable because state is split by domain, but avoid adding any new mega-observable/global environment object that would widen invalidation fan-out.

Recommended first performance checkpoint (`05A`):
- keep the same feature/domain ownership;
- eliminate redundant persistence sanitization on read;
- move full snapshot encoding/disk writes off the interaction-critical path while preserving ordered/atomic writes and crash safety;
- keep visual image bytes out of repeated JSON work where practical, or at minimum avoid re-encoding unchanged large image blobs per unrelated state mutation;
- cache/downsample decoded visual thumbnails outside SwiftUI `body`;
- add stable per-client visual indexes/lookups so views are not repeatedly filtering and sorting entire arrays;
- add a focused performance-architecture audit before making cosmetic changes.

Do not optimize by reintroducing timers, global observers, polling loops, or hidden caches whose invalidation rules are unclear.

### Layer 6 — stability
After Layer 5 is green, verify one owner per interaction, deterministic foreground/background/relaunch behavior, provider failures that degrade gracefully, no overlay/pointer/race regressions, and no lifecycle-created duplicate tasks.

### Layer 7 — second full functionality pass
Repeat critical workflows after performance/stability work. This must be green before the first v0.5.0 TestFlight release.

## Client-specific visual-support product rule

This is now a core invariant:
- every saved icon belongs to a client;
- every choice board belongs to a client and can reference only that client’s icons;
- First / Then only resolves visuals from the selected client, with text fallback;
- every visual schedule belongs to a client and can reference only that client’s icons;
- there is no general/unassigned visual library;
- durable ownership uses the client profile UUID, while the four-letter ABA code is editable display identity;
- changing a client code must not orphan that client’s visuals;
- deleting a client prunes that client’s persisted visual records.

The legacy v0.4 visual library was global. Never auto-assign legacy global icons to a client during migration.

## Persistence / migration policy

Known legacy v0.4 durable data:
- `liferoute_v3`: manual events, places, preferences, including client profiles;
- `liferoute_home_address_v3`: dedicated home-address fallback;
- feature-specific stores such as the old global `liferoute_visual_tools_v2` library.

04C currently maps only reviewed fields:
- client profiles, including known old field aliases;
- manual schedule events only;
- saved places;
- home address.

04C merge rules:
- existing v0.5 native client records win on duplicate ABA code/ID;
- existing v0.5 saved places win on normalized name+address identity;
- existing v0.5 home address wins when already populated;
- existing native manual events win on duplicate imported ID;
- imported IDs are deterministic/restart-safe;
- malformed data fails closed / is skipped;
- Apple/Google/provider event caches are not imported;
- old visual libraries are not imported or guessed into client ownership;
- no auth/theme/overlay/interaction-runtime state is mapped;
- mapper code imports Foundation only and does not import WebKit.

The first 04C validation attempt used head `12e991c37c61a9fd2610379ba0b2e3dece9b52a5`. Its 04C audit passed, but the Simulator compile found three isolated mapper issues:
1. calling a `@MainActor` client normalization helper from nonisolated parsing;
2. an overly dense deterministic UUID expression that Swift's compiler rejected;
3. a `@MainActor` `.shared` singleton used as a default argument.

Fixes were committed through `d4fb77f13fb9194618ddd0ce475dddc31c52f5fe` and then documented/retriggered. The current exact head is `61ce2de0755eb871876d7665742f081ba72415d1`.

As of this handoff, GitHub has **not yet emitted a pull-request workflow run or status check for `61ce2de…`**, despite the branch/PR head being correct and a close/reopen retrigger. Therefore:
- do **not** mark 04C green yet;
- first action in the next chat is to inspect Actions for `61ce2de…`;
- if no run exists, trigger validation using the available GitHub workflow/PR mechanism without changing runtime behavior;
- only after the corrected 04C audit + iOS Simulator compile are green should Layer 5 code changes begin.

## Checkpoint table

| Checkpoint | Commit / validation | Status | Notes |
|---|---|---|---|
| Rebuild baseline | `64b0c2fef3172a101885e9bdaf4eb7860cc41997` | Baseline only | v0.4 runtime; physical buttons still unreliable. |
| 00 — inventory/quarantine | `558c649dfa501a4317d7bdc0aeb4ed6c4ef90e53` | Complete | Legacy interaction/runtime graph classified and quarantined. |
| 01 — minimal interaction shell | `5656d380345f6ca4b54f3dcb6a3030c9d9d9dde7` | Green | Native SwiftUI shell; legacy WebView removed from active Sources/Resources. CI #627. |
| 02 — core navigation | `066455a54a3552fe756a3da8877ec263faa6cd0a` | Green | One `AppRouter`, native stacks, semantic controls/back behavior. CI #629. |
| 03A — calendar core | `2a1f5024d215bc4f14280ab7a9b26fb7e2392513` | Green | Normalized events + Day/Week/Month + manual appointment core. CI #631. |
| 03B — routing/location | `6523c8af0931f3fe7e6975a8562a41c83a9361d5` | Green | Core Location + MapKit, home fallback, saved places, route estimates. CI #632. |
| 03C — client profiles | `d5aca2e916e5f1fccb2274e22a7736b9a5a542d9` | Green | ABA four-letter codes and client clinical/session context. CI #634. |
| 03D — Session Tools | `801f4601180f20889184e757e010972d94279431` | Green | Absolute-deadline timer, scratch notes, First/Then, deterministic session-plan organizer. CI #635. |
| 03E — native calendar providers | feature `98ebb84eceedecdc4b724947d9158a9c8c1d7430`; regression validated by `431c2db03b4786f5b84d513e11a04a187f551177` | Green | EventKit + Google read-only PKCE/Keychain; no WebView bridge runtime. CI #639 includes green accumulated provider audit/build. |
| 03F — client-specific visual supports | `431c2db03b4786f5b84d513e11a04a187f551177` | Green | Client-scoped icons, boards, First/Then and schedules; iOS 16-compatible native UI. Policy #22; CI #639. |
| 04A — client + visual persistence | `d2fff00154954fc21f55d22ab247d3c0c2a8e3aa` | Green | Protected Application Support snapshot, atomic writes, corruption recovery, client UUID visual ownership. Policy #35; CI #652 / run `33019810261`. |
| 04B — routing + manual calendar persistence | `dcfb886150ce7316ab83723b2c151b47849ba3d0` | Green | Manual appointments, home, saved places persist; provider events/GPS/route estimates remain transient. Policy #37; CI #654 / run `33020305153`. |
| 04C — legacy data mapper/cleanup boundary | feature/compile-fix through `d4fb77f13fb9194618ddd0ce475dddc31c52f5fe`; current exact head `61ce2de0755eb871876d7665742f081ba72415d1` | Pending corrected build | Pure native mapper/merge implemented. First audit passed; first compile exposed isolated mapper errors, now fixed. Corrected exact-head Actions run has not emitted yet. |
| 05A — performance architecture | — | Next after 04C green | Initial inventory complete; no performance code changes committed yet. |

## Cosmetic chunks preserved for later

Keep existing appearance work available but inactive as independent modules:
1. dark-blue/gold identity;
2. refined vector icons;
3. categorized Themes;
4. glass/material surfaces;
5. motion/page transitions/button press feedback;
6. haptics/sound;
7. scenery/dynamic/fluid/living backgrounds;
8. onboarding/polish.

Appearance must never be required for navigation, data, calendar, routing, Session Tools, clients, or provider functionality.

## Checkpoint protocol

For every remaining layer/slice:
1. make a clearly named checkpoint;
2. add/update focused executable audits;
3. record the exact feature/validation SHA;
4. run accumulated preparation/regression audits;
5. compile the actual iOS app on the Simulator runner;
6. keep the prior green checkpoint recoverable;
7. do not mix cosmetic work into functional checkpoints.

## New-thread start procedure

1. Read this file first.
2. Read `AGENTS.md`.
3. Read `LIFEROUTE_V0_5_0_CHECKPOINT_00_INVENTORY.md` when migration/quarantine context matters.
4. Inspect the live `rebuild/v0.5.0-functional-core` branch, PR #20, and current Actions state.
5. Confirm whether exact head `61ce2de0755eb871876d7665742f081ba72415d1` has received a green 04C iOS CI run.
6. If 04C is green, update this table and begin `05A` from the performance findings above.
7. Never return to v0.4 interaction-hotfix layering.

## Immediate next action

**Finish 04C validation, then begin Checkpoint 05A — performance architecture.**

Do not add a startup WebKit migration reader before the first physical-device reliability checkpoint. Preserve old WebKit data untouched. Keep the old global visual library quarantined.

For 05A, start with persistence/image/derived-state costs rather than adding UI polish:
- remove redundant read-time full-state sanitization;
- design ordered background persistence that preserves atomicity and data safety;
- stop decoding visual images directly in SwiftUI `body`;
- introduce stable per-client lookup/indexing or derived collections for visual supports;
- audit calendar derived-work scaling;
- add focused regression/performance audits;
- run full accumulated audits and an exact-head Simulator build before proceeding to Layer 6.
