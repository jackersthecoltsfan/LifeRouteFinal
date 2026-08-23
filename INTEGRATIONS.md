# LifeRoute integration architecture

LifeRoute is structured so calendar providers feed one normalized read model, while navigation providers are interchangeable route handoffs.

## Calendar sources

### Apple Calendar — implemented

The native iOS bridge uses EventKit. On iOS 17+ Apple requires `requestFullAccessToEvents` for an app that needs to read existing events; on iOS 16 the app falls back to the older EventKit event-access request. LifeRoute does not contain event create, edit, save, or delete calls.

The web UI receives normalized Apple events from the native bridge with:

- event id
- title
- start/end ISO-8601 timestamps
- location
- calendar title
- all-day flag
- source = `apple`

### Google Calendar — scaffolded, credentials not committed

Public configuration lives in `LifeRoute/Web/config.js`.

Planned permission: `https://www.googleapis.com/auth/calendar.readonly`.

Do not put an OAuth client secret in the app or repository. The remaining implementation is the native/mobile OAuth authorization flow plus mapping Google Calendar events into the same normalized event shape used by Apple Calendar.

### CentralReach — scaffolded as read-only

CentralReach documents a REST API base URL of:

`https://partners-api.centralreach.com/enterprise/v1/`

The read-only schedule endpoints prepared for LifeRoute are:

- `GET schedule/events/by-provider`
- `GET schedule/events/by-appointment-with`

CentralReach authentication uses an OAuth 2.0 client-credentials flow to obtain a JWT plus a CentralReach API key. Those credentials must never be committed to this repo or stored in the WebView/localStorage.

Recommended production design:

1. Obtain organization-approved API access from CentralReach.
2. Keep `client_secret` and CR API key in a secure backend or another approved secret-storage architecture rather than browser JavaScript.
3. Request only the schedule data needed for the signed-in user.
4. Map the response into LifeRoute's normalized event shape.
5. Keep CentralReach data read-only inside LifeRoute; do not add POST/PATCH schedule operations.
6. Minimize local caching, logging, and analytics for schedule payloads. Treat schedule content according to the organization's privacy/security requirements.

## Navigation providers

### Apple Maps — implemented route handoff

The native bridge opens Apple Maps using Apple Maps direction/place URLs. The UI can select Apple Maps as the default provider or ask each time.

### Google Maps — implemented route handoff

The native bridge opens Google Maps web direction/search URLs. This does not require a Maps API key merely to hand a route or place to Google Maps.

### Live route calculations — API-ready, not activated

Current manual drive estimates remain supported. The UI and data model are ready for live travel-time results later. A future routing service should provide:

- origin/destination
- travel duration
- distance
- arrival/leave-by time
- optional alternatives

LifeRoute should use that result to validate whether a saved place actually fits inside a gap.

## Saved places and memberships

Saved places work without an API. Each place has:

- name
- address/searchable place
- type (Gym, Home, Coffee, Grocery, Park, Library, Errand, etc.)
- useful visit duration
- whether it should be considered in gap suggestions

This is the foundation for membership-aware suggestions. Live routing can be added without changing the saved-place UI.

## Google Maps saved-list import

The UI includes an import entry point, but it is intentionally not pretending that a supported saved-list import exists without the required Google data/API path. Manual save works now; automated import can be connected later if a supported export/API flow is chosen.

## Secrets policy

Never commit:

- App Store Connect private `.p8` keys
- Google OAuth client secrets
- CentralReach `client_secret`
- CentralReach API keys or JWTs
- production access tokens

GitHub Actions release credentials belong in GitHub Actions Secrets. Runtime user/service credentials should use Keychain or an approved backend architecture, depending on the provider.
