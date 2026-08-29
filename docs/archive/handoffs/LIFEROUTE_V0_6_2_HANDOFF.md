# LifeRoute v0.6.2 — Clean iOS Build Handoff

## Start here

Continue LifeRoute as **v0.6.2** from the successfully shipped **native iOS v0.6.1 TestFlight baseline**. This handoff is for the clean iOS/native development thread.

Repository: `jackersthecoltsfan/LifeRouteFinal`

## Exact shipped baseline — do not lose this

- Released version: **LifeRoute v0.6.1**
- TestFlight build: **#80**
- Exact source SHA Apple received: `41f3a497eba562397785017851ff66a9b86b6ae2`
- TestFlight workflow run: **33107859181**
- Release request issue: **#41**
- Apple upload result: **UPLOAD SUCCEEDED with no errors**
- Delivery UUID: `9af5e4dd-09e5-44e9-ac50-677665eefafd`
- Main app archive identity verified as **0.6.1 (80)**
- Live Day extension archive identity verified as **0.6.1 (80)**
- Signed IPA export succeeded
- Temporary Apple signing certificate created by CI was revoked/cleaned successfully
- Premium navy/gold LR AppIcon passed the production guard as a **1024×1024 opaque RGB PNG with no alpha channel**

Treat SHA `41f3a497eba562397785017851ff66a9b86b6ae2` as the authoritative v0.6.1 native regression baseline even if `main` later advances for documentation or web-preview-only fixes.

---

# Priority rule for v0.6.2

> **Native iOS / TestFlight work is higher priority than the web preview.**

Order of priority:
1. Native iOS correctness and release health
2. Native regression/build validation
3. TestFlight release readiness
4. Web preview parity/polish

A web-preview issue must not destabilize or delay a healthy native release unless it exposes a genuine shared-source regression.

---

# Native architecture — non-negotiable

The active shipping app is **native SwiftUI**.

- `AppRouter` remains the single top-level navigation owner.
- Keep native `NavigationStack` navigation.
- Top-level tabs remain:
  - Today
  - Schedule
  - Tools
  - Resources
  - Setup
- The active runtime is the v0.5.4/v0.6.x native shell and later native additions.
- `LifeRouteWebView.swift` and the old Web/JavaScript runtime remain **quarantined** and must not become the active iOS shell.
- Do not resurrect old global JavaScript/WebView tap patches to solve a native problem.
- Keep application state/persistence owned by the reviewed native domain objects rather than ad-hoc `UserDefaults`, `@AppStorage`, or browser storage.

Current bundle identities:
- App: `Com.Brandongood.LifeRoute`
- Live Day extension: `Com.Brandongood.LifeRoute.LiveDay`

---

# What v0.6.1 accomplished — preserve all of it

## 1. Production app icon fixed

v0.6.1 completed the premium LifeRoute icon work.

The build now generates and validates the approved navy/gold LR icon before release.

Relevant paths:
- `scripts/generate_v0_6_1_app_icon.swift`
- `scripts/prepare_build.sh`
- `LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

Important regression guard:
- 1024×1024
- opaque RGB
- **no alpha channel**

Apple previously rejected an upload with error 90717 because the 1024 icon contained alpha. The repaired generator and `prepare_build.sh` guard now prevent recurrence. Do not weaken or remove that check.

## 2. AI Session Note output tightened to the user's preferred ABA note style

Preserve the successful Session Note behavior.

Generated notes should be:
- cohesive chronological third-person RBT narrative
- natural paragraph format
- based only on supplied session facts/data
- data woven throughout the narrative where appropriate
- observable/factual
- ABA terminology only when supported
- use **“the client”** rather than casual naming
- no generic clinical-report headings unless specifically useful
- no placeholders
- no fabricated environment, behavior, frequency, percentage, prompt level, attendee, outcome, treatment response, conclusion, or future plan
- zero-count behaviors mean not observed/recorded; they are not deficits

The user considers the current Session Plan generator successful. **Do not broadly refactor its output behavior without a demonstrated reason.**

Relevant files include:
- `LifeRouteIntelligenceCore.swift`
- `AIClinicalToolsViews.swift`
- Session Tools native views/domain files

## 3. RBT profile / clinical tool context

Preserve the RBT-focused profile/context introduced in v0.6.1 and the ABA privacy-first client workflow.

Client identifiers remain first-two + last-two initials.

Do not hard-code real/demo personal initials into production UI.

## 4. Navigation selection and native shell integrity

v0.6.1 preserved the five-tab native navigation model and repaired selection behavior.

Do not create a competing root navigation owner or extra `NavigationStack` tree.

## 5. Themes / appearance propagation

Preserve app-wide theme propagation and the premium visual direction:
- dark/navy/black-forward
- signature gold accent
- premium, sleek, elegant, modern, futuristic
- cinematic/immersive rather than flat
- legible, compact, professional
- differentiated scenery/metallic/dynamic identities rather than recolored generic cards

Theme switching should continue to propagate across already-mounted major screens/chrome rather than requiring a restart.

---

# v0.6.0 functionality still protected in v0.6.2

## Resource Hub

Keep the broad native Resource Hub / work-portal launcher. Do not reduce it back to a small subset.

It includes categories such as:
- ABA Data & Clinical
- Finance & HR
- Training & Credentials
- Other Work Portals

Resources launches external work destinations and supports custom links; it is not a miscellaneous shortcut drawer.

## Calendar/provider persistence

Preserve provider snapshot persistence across relaunch.

Important rules:
- manual LifeRoute appointments remain separate from provider events
- Apple/Google provider events remain read-only/provider-owned
- provider cache remains bounded/sanitized
- persistence stays in the protected native store
- do not replace with direct `UserDefaults`

## AI Visual Supports

Preserve both AI-assisted and manual workflows.

- on-device Foundation Models may draft editable schedule steps
- generated steps remain editable before saving
- saved schedules use the existing validated persistence path
- existing icons can be matched/reused
- Image Playground path remains additive
- manual photo/text/icon creation remains available
- AI must not invent treatment protocols

---

# Core product direction

LifeRoute – RBT is a **smart day-routing companion for an RBT**, not just a calendar viewer.

Preserve and continue building toward:
- connected calendars
- understanding the user's day
- usable-gap detection
- current-location-aware routing
- useful stop/activity suggestions that fit real gaps
- saved places/preferences
- client/service addresses
- route timing
- Maps handoff
- add stops before appointments
- add stops after appointments
- explicit Return Home
- future preferred grocery/store chains such as Walmart, Giant, BJ's, etc.
- future memberships/preferences such as gyms

**Add Stop already exists. Do not duplicate it.**

Current location is the preferred commute origin when available. Saved Home is fallback and an explicit destination.

Use shared native MapKit autocomplete for address fields instead of adding plain address text fields without autocomplete consideration.

---

# Tools baseline

Tools remains a session command center.

Keep visible/useful:
- Visual Timer
- Quick Notes
- Visual Supports
- First / Then
- AI Session Plan
- AI Session Note Generator

General/no-client workflows should remain available where intended. Client-specific visual libraries remain isolated by durable client ownership.

Timer behavior, completion audio, haptics, pause/resume/reset, and absolute-deadline timing are regression-sensitive.

---

# Live Day / Lock Screen

Preserve the native ActivityKit / WidgetKit system:
- Live Day activity
- Lock Screen UI
- Dynamic Island on supported devices
- current/next event
- countdown/leave timing
- route summary when known
- Return Home state

Physical-device testing remains important before major Live Day changes.

---

# v0.6.2 engineering note — Swift 6 warning to evaluate carefully

The successful v0.6.1 Release archive emits a Swift concurrency warning in `RoutingLocationDomain.swift` around `RoutingLocationCore : CLLocationManagerDelegate` crossing main-actor isolation.

It is a **warning in the current Swift 5 language mode**, not a v0.6.1 release failure. The compiler notes it can become an error in Swift 6 language mode.

For v0.6.2:
- treat this as technical debt worth reviewing
- do not blindly apply `nonisolated`, `@preconcurrency`, or actor annotations without validating Core Location callback behavior
- if repaired, preserve foreground-only live-location ownership, authorization flow, cancellation, and route-state behavior
- run the full routing/location/stability audits and a real Simulator compile after any change

Do not turn a future-compatibility cleanup into a routing regression.

---

# Release / CI guardrails

The v0.6.1 release debugging hardened several release gates. Preserve them.

## Exact-SHA release rule

Do not upload arbitrary `main` state.

Release flow should continue to:
1. validate the exact intended source
2. require successful release-equivalent iOS validation
3. confirm current main/exact SHA
4. archive app + Live Day extension
5. verify archive version/build/bundle identities
6. export signed IPA
7. upload through App Store Connect API credentials
8. require Apple upload success
9. save short-retention IPA artifact if configured
10. clean temporary signing assets

## TestFlight bridge fix from v0.6.1 debugging

The ChatGPT release bridge previously attempted to put a very large GitHub compare JSON response into a shell variable, causing `jq` parse errors and a false “no completed successful iOS Build Check” failure.

The bridge was repaired to query compact compare fields instead of holding megabytes of patch JSON in shell memory.

Do not regress to the oversized-shell-variable implementation.

## Web preview gate

A stale web regression gate was also repaired during v0.6.1 debugging so the Pages workflow no longer demands quarantined v0.4 native/WebView capabilities.

Treat web preview validation separately from native iOS unless shared-source evidence says otherwise.

---

# Regression reference order for v0.6.2

When something breaks/disappears:

1. **v0.6.1 build #80 / SHA `41f3a497...`** — current shipped native baseline
2. v0.6.0 build #78 / SHA `0def9ef...`
3. v0.5.4 build #77
4. v0.5.3 repair history
5. `polish/v0.5.2-graphics-restoration`
6. `polish/v0.5.1-ui-foundation`
7. `rebuild/v0.5.0-functional-core`
8. earlier approved screenshots/project conversations when code history is insufficient

Do not assume absence in newer code means intentional removal.

---

# Recommended opening actions in the new v0.6.2 iOS thread

1. Read this file first: `LIFEROUTE_V0_6_2_HANDOFF.md`.
2. Confirm the shipped baseline remains v0.6.1 build #80 / SHA `41f3a497...`.
3. Inspect current `main` versus that shipped SHA before native changes; documentation/web-only commits may exist after the shipped source.
4. Keep native/TestFlight work higher priority than web preview work.
5. Start v0.6.2 native work from the current validated native architecture without reactivating the old WebView runtime.
6. Before merging a native feature, run accumulated audits plus an actual iOS Simulator compile.
7. Use the v0.6.1 TestFlight binary/screenshots as the primary regression comparison during development.

## Suggested new-thread opener

`@Build iOS Apps @SwiftUI Expert @GitHub @OpenAI Developers\n\nContinue LifeRoute v0.6.2 using LIFEROUTE_V0_6_2_HANDOFF.md in GitHub. Treat v0.6.1 build #80 / SHA 41f3a497eba562397785017851ff66a9b86b6ae2 as the shipped native baseline. Native/TestFlight work has priority over the web preview.`

---

# Final handoff status

**v0.6.1 native release is complete and successful. v0.6.2 is ready to begin in a clean iOS-focused thread.**

Do not reopen the v0.6.1 icon/alpha upload issue; it is resolved by the opaque RGB generator and release guard.
