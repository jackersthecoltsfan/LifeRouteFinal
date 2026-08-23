# LifeRoute feature plan

## Implemented without external API credentials

- Multi-source calendar selector for Apple Calendar, Google Calendar, and CentralReach.
- Apple Calendar native EventKit permission/read bridge.
- Apple Maps route and place handoff.
- Google Maps route and place handoff.
- User-selectable map provider or ask-each-time behavior.
- Saved places and frequent/membership-place flag.
- Gap suggestions based on saved place visit length.
- Manual appointments and weekly gap analysis.
- Customizable visual themes centered on a bold blue/gold design.
- GitHub Actions iOS build validation.
- Manual GitHub Actions TestFlight deployment workflow.

## Prepared but waiting for credentials/API access

- Google Calendar OAuth sign-in and event sync.
- CentralReach OAuth client-credentials/API-key authentication and read-only schedule sync.
- Live route time/distance calculations for validating gap suggestions.
- Supported Google Maps saved-place/list import flow.

## Later product improvements

- Deduplicate matching events across multiple calendar sources.
- User-selectable calendars within Apple/Google sources.
- Privacy-preserving offline cache for provider events if needed.
- Smarter gap scoring by route detour, opening hours, visit duration, preference, and membership value.
- Notification/leave-by reminders.
- Home/work anchors and route optimization across multiple stops.
