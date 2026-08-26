# LifeRoute v0.5.0 — Next Chat Resume Note

Use this only as the quick entrypoint. The full source of truth is `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`.

## Start here

1. Work only from branch `rebuild/v0.5.0-functional-core` in `jackersthecoltsfan/LifeRouteFinal`.
2. Read `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md` first, then `AGENTS.md` and the relevant runbooks.
3. Inspect the **live branch/PR #20 head and Actions state** instead of assuming a hard-coded bookkeeping SHA is still the branch head.
4. Do not merge PR #20 yet.

## Current functional state

Green through Checkpoint 04B:
- native SwiftUI shell/navigation;
- Day/Week/Month calendar core;
- Apple + Google read-only calendar providers;
- current location/MapKit routing;
- clients/setup;
- Session Tools;
- client-specific visual icons, Choice Boards, First/Then and Visual Schedules;
- protected persistence for clients + client visuals + manual appointments + home + saved places.

The legacy WebView/JavaScript interaction runtime remains quarantined and must stay inactive.

## Checkpoint 04C

04C implements a pure-native, WebKit-free legacy v0.4 mapping/merge boundary for only reviewed data: clients, manual appointments, saved places, and home address.

The first 04C audit passed. The first Simulator compile then found three isolated Swift mapper issues, all fixed:
- actor-isolated client-code normalization removed from parsing;
- deterministic UUID construction simplified into compiler-safe explicit components with no random fallback;
- `LifeRoutePersistenceStore.shared` removed from a main-actor default argument.

Runtime compile fixes are committed through `d4fb77f13fb9194618ddd0ce475dddc31c52f5fe`. Later commits are documentation/validation-marker bookkeeping on top of the same runtime.

At the previous chat stop, GitHub Actions had still not emitted a corrected-head pull-request run despite path-matched commits and PR retriggers. Therefore the **first action** is:
- inspect the current live PR #20 head;
- check whether accumulated audits + the iOS Simulator build have now run on a runtime-equivalent corrected 04C head;
- if green, mark 04C complete in the handoff;
- if not, trigger/repair validation without changing functional architecture.

Do not add an automatic startup WebKit/localStorage reader. Preserve old WebKit data untouched until native physical-device reliability is proven.

## Performance Layer 05A — next after 04C green

Initial code-first performance inventory is complete. Highest-priority targets:
1. `LifeRoutePersistenceStore` performs synchronous whole-snapshot JSON encode/write on `@MainActor`, including visual image bytes.
2. read methods redundantly sanitize the entire state after load/save boundaries already sanitized it.
3. visual-support views repeatedly filter/sort broad arrays and repeatedly search icon IDs during rendering.
4. `ClientVisualIconThumbnail` decodes `UIImage(data:)` inside SwiftUI `body`.
5. calendar Day/Week/Month rendering repeatedly filters event collections and should be reviewed for provider-scale event counts.

For 05A, preserve current ownership and optimize these costs directly. Do not introduce polling, global observers, broad mega-state objects, cosmetic animation systems, or legacy runtime code.

After 05A: Layer 6 stability → Layer 7 second full functionality pass → exact merged-main validation → v0.5.0 functional TestFlight candidate → physical iPhone confirmation → cosmetics reintroduced one audited chunk at a time.
