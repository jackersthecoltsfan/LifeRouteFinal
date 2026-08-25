# LifeRoute integration architecture

LifeRoute normalizes calendar sources into one schedule model, then combines that schedule with location, routing, Saved Places, To-Dos, and user preferences. Provider data is treated as read-only unless a feature explicitly says otherwise.

## Calendar sources

### Apple Calendar — implemented

The native iOS bridge uses EventKit. On iOS 17+ LifeRoute requests full event access so it can read existing events; older supported iOS versions use the prior EventKit event-access request. LifeRoute does not create, edit, save, or delete Apple Calendar events.

Normalized Apple events include:
- event id
- title
- start/end ISO-8601 timestamps
- location
- calendar title
- all-day flag
- source = `apple`

### Google Calendar — implemented read-only

The iPhone app uses OAuth authorization-code flow with PKCE and the read-only scope:

`https://www.googleapis.com/auth/calendar.readonly`

The public iOS OAuth client ID and redirect scheme live in `LifeRoute/Info.plist`; no OAuth client secret is stored in the app. Refresh tokens are stored in Keychain and access tokens remain in memory. LifeRoute reads the user's accessible Google calendars, pages through events, normalizes them into the same schedule model as Apple Calendar, and can disconnect by deleting the stored refresh token.

The browser preview has its own Google Calendar helper/persistence layer and likewise uses read-only access. Production secrets or refresh tokens must not be embedded in web code or localStorage.

### CentralReach — scaffolded read-only, waiting on approved credentials

CentralReach's prepared base URL is:

`https://partners-api.centralreach.com/enterprise/v1/`

Prepared schedule endpoints:
- `GET schedule/events/by-provider`
- `GET schedule/events/by-appointment-with`

Production use still requires organization-approved partner authentication/API access. CentralReach credentials must never be committed to this repository or stored in browser JavaScript/localStorage.

Recommended production design:
1. Obtain approved CentralReach partner/API access.
2. Keep `client_secret`, API keys, JWTs, and other privileged credentials in an approved secure service rather than the WebView.
3. Request only schedule data necessary for the signed-in user.
4. Normalize returned events into LifeRoute's shared calendar model.
5. Keep CentralReach schedule behavior read-only.
6. Minimize caching, logging, and analytics for schedule payloads and follow the organization's privacy/security requirements.

## Location and routing

### Current location — implemented

The native app uses Core Location with When-In-Use permission. Current coordinates are used for live route origins and commute calculations while the app is active. The permission copy explicitly states that live location is not stored in calendar events.

### Apple MapKit route calculations — implemented

Build preparation adds native MapKit support for:
- route duration
- route distance
- current-location or address-based origins
- saved-place and event destinations
- multi-leg gap/store comparisons
- nearby point-of-interest/store search
- bounded route recovery/fallback behavior

These calculations support before-first, between-event, and after-last planning as well as store-branch comparison.

### Apple Maps — implemented handoff

LifeRoute can open Apple Maps for place lookup and turn-by-turn route handoff. Selected gap routes are stored in LifeRoute first and opened only when the user chooses Open route.

### Google Maps — implemented handoff

LifeRoute can hand routes and place searches to Google Maps using supported Maps URLs. A Maps API key is not required merely for this external handoff.

### Browser routing — implemented for preview

The web preview includes a routing bridge plus a nearby-store fallback so the major planning interactions can be exercised outside the native iPhone build. Browser services are fallbacks for preview/testing and do not replace the native MapKit path.

## Saved Places, To-Dos, and store preferences

Saved Places can include:
- name
- address/searchable place
- type
- useful visit duration
- whether the place should be considered in gap suggestions

To-Dos can include a fixed address or preferred store chains. For shopping tasks, LifeRoute can search nearby branches and compare route time/distance plus visit duration against the available schedule gap before the user chooses a branch.

## Google Maps saved-list import

The UI may expose an import entry point, but automatic Google Maps saved-list ingestion is not treated as implemented until there is a supported Google data/API/export path. Manual Saved Places work now.

## Authentication and local credentials

LifeRoute uses username + 4-digit PIN authentication. The native build stores credential material using Keychain; the browser implementation uses PBKDF2-derived local credential data. This authentication is separate from calendar-provider OAuth.

## Release architecture

The web preview, iOS CI, and TestFlight all begin with the same deterministic `scripts/prepare_build.sh` pipeline. Stability and full regression audits run before compile/release gates.

Relevant `main` changes trigger iOS Build Check. A separate guarded workflow may dispatch TestFlight only when that exact current `main` commit completed iOS Build Check successfully. TestFlight itself has no direct push trigger and remains manually dispatchable.

## Secrets policy

Never commit:
- App Store Connect private `.p8` keys
- OAuth client secrets
- CentralReach `client_secret`
- CentralReach API keys or JWTs
- production access tokens or refresh tokens

Public OAuth client IDs and redirect schemes are identifiers, not secrets. GitHub Actions release credentials belong in GitHub Actions Secrets. Runtime provider credentials belong in Keychain or another approved secure architecture appropriate to the provider.
