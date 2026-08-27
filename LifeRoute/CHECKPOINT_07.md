# Checkpoint 07 — Second full functionality pass

Status: **In validation**.

Checkpoint 07 repeats the native functional-core contract after the performance and stability layers. It adds no cosmetic/runtime dependency.

The pass found and corrected one functional omission: manual appointments could be created and persisted but had no rendered delete action. Calendar rows now expose an accessible destructive action for manual appointments only; Apple and Google provider events remain read-only. The action is passed through a narrow closure so the indexed immutable calendar presentation boundary remains intact.

The pass covers these connected journeys:

- direct native launch, all five top-level tabs, native stack navigation, cross-tab routing, close/back, and deterministic path reset;
- explicit current-location request, home fallback, saved-place add/remove, route estimates, and Apple Maps handoff;
- manual appointment add/remove, Day/Week/Month presentation and navigation, Apple Calendar refresh, Google read-only connect/refresh/disconnect, and provider-cache isolation;
- ABA client add/edit/remove with the reviewed clinical/session fields and durable UUID ownership;
- Visual Timer, Quick Session Notes, Session Plan Organizer, client icon library, Choice Boards, First/Then, and Visual Schedules;
- protected native persistence, ordered atomic writes, corruption recovery, external visual blobs, and the reviewed pure-native legacy merge boundary;
- Checkpoint 05A performance invariants and Checkpoint 06 lifecycle/race invariants;
- active-target quarantine of the WebView/JavaScript runtime and marketing version `0.5.0`.

The executable gate is `scripts/audit_v0_5_0_second_functionality_pass.py`. Checkpoint 07 becomes green only after the full accumulated preparation/audit suite and an actual iOS Simulator build pass on the same runtime commit.
