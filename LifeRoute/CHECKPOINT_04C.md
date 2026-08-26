# Checkpoint 04C — Legacy migration mapper / cleanup boundary

This marker triggers exact-head validation for the pure native v0.4-to-v0.5 migration mapper.

The checkpoint:
- maps only reviewed legacy `liferoute_v3` clients, manual appointments, saved places, and home address;
- preserves existing native v0.5 records over duplicates;
- uses deterministic imported identities and restart-safe merges;
- keeps legacy client-code normalization pure and independent of main-actor client state;
- constructs deterministic imported UUIDs through compiler-safe explicit components with no random fallback;
- resolves the shared persistence owner inside an explicit main-actor merge body rather than a default argument;
- does not run an automatic WebKit/localStorage reader at startup;
- does not import provider caches, route/GPS state, cosmetic/runtime state, or the old global visual library;
- does not reactivate the legacy LifeRoute WebView UI or JavaScript startup graph.

The old WebKit website data remains untouched for a possible explicit, migration-only reader after native physical-device reliability is proven.
