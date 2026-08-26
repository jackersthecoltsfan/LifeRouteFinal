# Checkpoint 05A — Performance architecture

This checkpoint improves the native functional core without changing product behavior or ownership.

## Persistence

- `LifeRoutePersistenceStore` remains the single main-actor owner of mutable native state.
- Full JSON encoding and protected atomic disk writes run on one serial actor, outside the interaction-critical path.
- Save requests are chained in order and revision-checked so an older request cannot overwrite newer state.
- pending writes are flushed on native scene transitions without polling or a persistence timer.
- visual photo bytes live in protected, atomically written files referenced by the JSON snapshot; unchanged immutable blobs are not re-encoded or rewritten for unrelated state changes.
- schema-v2 snapshots with embedded image data still decode and are externalized on the next native save.
- load methods return already-sanitized in-memory state without rerunning whole-state sanitization.

## Visual supports

- displayed client codes resolve through a stable native client index.
- icons, Choice Boards, schedules, icon IDs, and same-client ownership use mutation-maintained indexes.
- no-op client reconciliation does not republish the visual arrays.
- `ClientVisualIconThumbnail` requests scale-aware ImageIO downsampling from a bounded actor-owned cache; it does not call `UIImage(data:)` in SwiftUI `body`.

## Calendar

- calendar event mutations rebuild explicit day and source indexes.
- Day/Week/Month rendering receives one immutable derived presentation per parent render pass.
- week/month rows do not call `events(on:)` repeatedly or observe the broad calendar owner directly.

## Guardrails

- no WebView/JavaScript runtime is reactivated;
- no polling, persistence timer, broad observer, global input interception, duplicate navigation owner, or cosmetic dependency is introduced;
- provider caches, current GPS coordinates, and route estimates remain transient;
- protected storage, atomic replacement, corruption recovery, and legacy JSON compatibility remain intact.

The executable gate is `scripts/audit_v0_5_0_performance_architecture.py`. Checkpoint 05A is green only after the accumulated preparation/audit suite and an actual iOS Simulator build pass on the same runtime-equivalent commit.
