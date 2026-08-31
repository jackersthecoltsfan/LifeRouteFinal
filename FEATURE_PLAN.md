# LifeRoute feature plan

## Implemented now

### Calendar and schedule
- Apple Calendar read-only sync through EventKit.
- Google Calendar read-only OAuth sync in the iPhone app, with reconnect persistence in Keychain.
- Browser Google Calendar support for the web preview.
- Combined Day, Week, and Month views with selectable calendar sources.
- Manual appointments alongside provider events.

### Routing and location
- Apple Maps and Google Maps route/place handoff.
- Current-location access for live commute starts.
- Apple MapKit travel-time and distance calculation in the native app.
- Browser route-time support for the web preview.
- Driving/transit-aware route behavior where supported.
- Before-first, between-event, and after-last stop planning.
- Persistent selected gap routes with explicit Open route / Change actions.
- Home and client/location anchors for route-origin choices.

### Places, errands, and shopping
- Saved Places and frequent/membership-place flags.
- To-Dos that can participate in route planning.
- Store-chain preferences for shopping tasks.
- Nearby branch search in the iPhone app with Apple MapKit.
- Web-preview store-search fallback.
- Branch comparison using route time, distance, stop duration, and available gap time.

### Experience and tools
- Previous / Today / Next Day navigation with viewport preservation.
- Live Day leave reminders and native notification support.
- Username + 4-digit PIN authentication with native Keychain support and PBKDF2 browser storage.
- RBT tools, visual-support tools, mileage/resources surfaces, and photo-based visual support inputs.
- Customizable classic, metallic, scenery, dynamic, light, and dark theme families.
- Sleek SVG-based interface icons instead of legacy transport emoji.
- Native/WebView stability guards for scrolling, touch delivery, and animation performance.

### Build and release
- Deterministic validation-only preparation for local development and native CI;
  the web preview has its own artifact builder.
- Full semantic and executable-contract validation before release builds.
- iOS Simulator compile validation on relevant `main` changes.
- Exact-SHA guarded TestFlight dispatch only after successful current-`main`
  validation and explicit owner authorization.

## Waiting on external access or a supported provider path

- CentralReach production schedule sync: code remains read-only/scaffolded until organization-approved partner credentials and authentication are available.
- Automatic Google Maps saved-list import: requires a supported Google data/API/export path; manual Saved Places remain available now.

## Good next product improvements

- Deduplicate matching events across multiple calendar sources.
- Let users select individual calendars within Apple and Google sources.
- Add opening-hours awareness to errands/store/place scoring.
- Improve route ranking with richer preference history and configurable detour tolerance.
- Add clearer offline/error-state diagnostics for provider outages.
- Expand automated interaction/UI tests beyond the current structural, syntax, regression, and compile gates.
