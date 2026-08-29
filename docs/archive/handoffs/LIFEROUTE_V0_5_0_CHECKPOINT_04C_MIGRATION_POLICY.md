# LifeRoute v0.5.0 Checkpoint 04C — Legacy Data Migration / Cleanup Policy

## Goal

Preserve useful v0.4 user-entered product data without reactivating the v0.4 WebView UI, JavaScript startup graph, interaction patches, or cosmetic runtime.

Migration is split into two independent boundaries:

1. **Pure native mapper/merge logic** — reviewed, deterministic, WebKit-free.
2. **Legacy storage reader** — optional one-time adapter that may be evaluated later after physical-device reliability is proven. It may only export known legacy keys into the pure mapper and must never load the old LifeRoute UI/runtime.

The first v0.5.0 functional candidate does not require the reader to run automatically at startup.

## Known legacy keys

### `liferoute_v3`

Top-level shape:

```json
{
  "events": [],
  "places": [],
  "prefs": {}
}
```

The final v0.4 persistence wrapper already filtered provider-fetched events and retained only manual events in this store.

### `liferoute_home_address_v3`

Dedicated home-address fallback used by the v0.4 home/location layer. Legacy priority was:

1. dedicated home key;
2. `prefs.homeAddress`;
3. a saved place whose type was `Home`.

### `liferoute_visual_tools_v2`

Old visual-support state was a **global library** with global First/Then selections and board selection. It had no trustworthy client ownership.

**Rule: never auto-import or auto-assign these global icons to a client.** Preserve old WebKit website data untouched until an explicit user-directed assignment/import workflow exists, if one is still desired after the native app is validated.

## Automatic native mapping allow-list

### Manual calendar events

Map only events whose source is missing or `manual`.

Legacy fields:
- `id`
- `date` (`YYYY-MM-DD`)
- `title`
- `start` (`HH:mm`)
- `end` (`HH:mm`)
- `address` / `location`
- `allDay` when present

Do not migrate legacy route-planning fields such as `drive` or `buffer` into calendar ownership.

Reject malformed dates/times and invalid end-before-start ranges rather than repairing them speculatively.

### Saved places

Map:
- `id` -> deterministic native UUID seed;
- `name`;
- `address`;
- `type` -> `LifeRoutePlaceKind` when recognized, otherwise `other`;
- `minVisit` or legacy `min` -> minimum visit minutes;
- `useInGaps`, with legacy `member == "yes"` as a fallback.

Reject blank names/addresses. Preserve existing native saved places over duplicate legacy records.

### Home address

Resolve in the legacy priority order above, but only fill the native home address when the native store does not already have a home value.

### Client profiles

Read `prefs.clients` only.

Map the existing compatibility aliases already used by v0.4:
- `first2`
- `last2`
- `address`
- `preferredActivities` or `reinforcers`
- `currentTargets` or `targets`
- `behaviorsOfConcern` or `behaviors`
- `communicationNotes` or `fctNotes`
- `promptingNotes` or `reinforcementNotes`
- `caregiverNotes` or `settingNotes`
- `clinicalNotes` or `notes`
- `updatedAt` when valid

Generate a deterministic native UUID from the normalized four-letter client code for imported clients. Existing native clients win on duplicate code.

## Explicitly ignored / quarantined legacy state

Do not import:
- provider-fetched Apple or Google event payloads;
- Google OAuth/refresh credentials from browser storage (credentials remain Keychain-owned);
- selected Day/Week/Month/date UI state;
- route/gap selections or calculated route estimates;
- current GPS coordinates;
- timer/session scratch state;
- auth/PIN/welcome state;
- overlay/navigation/rebinding state;
- theme/cosmetic runtime flags;
- old global visual-library ownership or First/Then icon selection.

## Merge rules

Native v0.5 data always wins over legacy data when both represent the same logical record.

A migration import must be idempotent and restart-safe:
- deterministic IDs for imported clients/places;
- preserve manual event legacy IDs with a migration namespace;
- dedupe by client code / saved-place normalized identity / event ID;
- write through the existing protected client, routing, and manual-calendar persistence owners rather than adding a second persistence owner;
- each category write remains atomic, and an interrupted import can be rerun safely to complete remaining categories without duplicating earlier ones.

Malformed legacy JSON must produce an empty/no-op migration result. It must never block app launch, navigation, text entry, calendar providers, routing, or Session Tools.

## WebKit reader decision

Do **not** add an automatic startup `WKWebView` merely to reach old localStorage. The v0.5 reliability goal takes priority, and iOS 26 has active WebKit behavior changes around local file loading. The old website data remains untouched because v0.5 does not clear `WKWebsiteDataStore`.

If a one-time reader is added later, it must:
- use a minimal migration-only document, not `LifeRoute/Web/index.html`;
- load no legacy scripts;
- expose no visible interactive surface;
- read only the allow-listed keys above;
- pass exported strings directly to the pure native mapper;
- destroy its WebView after completion;
- never become an app navigation or feature-state owner;
- fail closed/no-op if the legacy storage origin cannot be reached reliably.

## Completion criteria for 04C mapper checkpoint

- pure native legacy JSON mapper exists and compiles;
- no WebKit dependency in mapper/persistence domain;
- mapper ignores provider/cosmetic/runtime/global-visual state;
- deterministic merge preserves existing native records;
- focused audit validates the allow-list and quarantine rules;
- accumulated preparation and iOS Simulator build are green.
