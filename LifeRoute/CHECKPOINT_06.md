# Checkpoint 06 — Stability architecture

Status: **In validation**.

This checkpoint hardens the green native functional core without changing product behavior or adding cosmetic/runtime dependencies.

## Interaction and lifecycle ownership

- `ContentView` retains the domain owners but creates no fire-and-forget tasks for persistence, routing, Maps, or calendar providers.
- one lifecycle owner coalesces persistence flush requests during inactive/background transitions;
- an ordered persistence flush continues until any write queued during its first await is also complete;
- cancellable routing/location work stops on true background transitions, not transient inactive phases;
- system-owned Apple permission and Google authentication flows survive transient inactive phases while remaining single-flight and stale-result guarded;
- the Apple EventKit permission continuation remains one retained, single-flight operation because the system permission prompt is not safely cancellable.

## Provider resilience

- Apple and Google refreshes are single-flight operations with retained task ownership;
- Google sign-in, token exchange, calendar discovery, pagination, and event fetching reject canceled or superseded generations before publishing state;
- disconnect cancels sign-in/network work and invalidates stale completions before clearing Keychain credentials;
- provider errors and cancellations preserve the last successfully normalized calendar events;
- Google network requests use finite timeouts, while pagination detects repeated tokens and enforces a maximum page count;
- provider event replacement publishes one coherent observable mutation and skips no-op updates.

## Routing and media race protection

- each saved place has at most one route task, and Apple Maps lookup has one task owner;
- route results are generation-checked after geocoding and directions awaits;
- deleting a place cancels its route work before removing state;
- Core Location callbacks are accepted only for an explicit in-flight request, so authorization changes do not trigger startup location work;
- photo selection loads through SwiftUI task identity and rejects canceled or superseded selections.

## Guardrails

- semantic SwiftUI controls remain the only interaction owners;
- no WebView/JavaScript startup graph, global touch interception, broad observer, polling loop, persistence timer, duplicate navigation owner, or cosmetic dependency is introduced;
- the executable gate is `scripts/audit_v0_5_0_stability_architecture.py`;
- Checkpoint 06 becomes green only after the full accumulated preparation/audit suite and an actual iOS Simulator build pass on the same runtime commit.
