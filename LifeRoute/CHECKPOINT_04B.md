# Checkpoint 04B — Durable routing and manual calendar data

Validation marker for the v0.5.0 functional-core rebuild.

This checkpoint persists only user-entered deterministic data:

- manual LifeRoute appointments;
- home address;
- saved places.

It intentionally does not persist current GPS coordinates, route estimates, Apple Calendar event caches, Google Calendar event caches, provider status, or provider connection objects.

All durable values remain in the protected native Application Support snapshot introduced in checkpoint 04A. Legacy WebView/localStorage runtime remains quarantined.
