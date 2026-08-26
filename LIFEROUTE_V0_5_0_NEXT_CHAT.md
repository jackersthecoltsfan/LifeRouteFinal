# LifeRoute v0.5.0 — Next Chat Resume Note

Use this only as the quick entrypoint. The full source of truth is `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`.

## Start here

1. Work only from branch `rebuild/v0.5.0-functional-core` in `jackersthecoltsfan/LifeRouteFinal`.
2. Read `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md` first, then `AGENTS.md` and the relevant runbooks.
3. Inspect the **live branch/PR #20 head and Actions state** instead of assuming a hard-coded bookkeeping SHA is still the branch head.
4. Do not merge PR #20 yet.

## Current functional state

Green through Checkpoint 05A:
- native SwiftUI shell/navigation;
- Day/Week/Month calendar core;
- Apple + Google read-only calendar providers;
- current location/MapKit routing;
- clients/setup;
- Session Tools;
- client-specific visual icons, Choice Boards, First/Then and Visual Schedules;
- protected persistence for clients + client visuals + manual appointments + home + saved places;
- pure-native reviewed legacy data mapping/merge boundary;
- off-main ordered snapshot persistence, external protected image blobs, indexed visual/calendar derivation, and cached/downsampled thumbnails.

The legacy WebView/JavaScript interaction runtime remains quarantined and must stay inactive.

## Checkpoints 04C and 05A

04C implements a pure-native, WebKit-free legacy v0.4 mapping/merge boundary for only reviewed data: clients, manual appointments, saved places, and home address.

The first 04C audit passed. The first Simulator compile then found three isolated Swift mapper issues, all fixed:
- actor-isolated client-code normalization removed from parsing;
- deterministic UUID construction simplified into compiler-safe explicit components with no random fallback;
- `LifeRoutePersistenceStore.shared` removed from a main-actor default argument.

04C is green on runtime-equivalent head `5295d93141b9a3e45af6dd4cc21855308999da3a`; run `33021676527` passed its accumulated audits and actual Simulator build.

05A is green on runtime commit `c63bf974daf65dbffca2e8210962a16ad0cdb25c`; run `33024385161` passed every accumulated preparation/audit step, the focused performance-architecture audit, and the actual iOS Simulator build.

Do not add an automatic startup WebKit/localStorage reader. Preserve old WebKit data untouched until native physical-device reliability is proven.

## Immediate next action — Layer 6 stability

Inspect the live branch, draft PR #20, and Actions state first. Then verify one interaction owner per action, deterministic foreground/background/relaunch behavior, graceful provider failures, no overlay/pointer/race regressions, and no lifecycle-created duplicate tasks.

Do not change product behavior, add cosmetics, reactivate legacy WebView/JavaScript code, merge PR #20, or upload to TestFlight.

After Layer 6: Layer 7 second full functionality pass → exact merged-main validation → v0.5.0 functional TestFlight candidate only with explicit authorization → physical iPhone confirmation → cosmetics reintroduced one audited chunk at a time.
