# LifeRoute v0.6.0 — New Chat Handoff

## Start here

Continue LifeRoute from the completed v0.5.4 release. Do **not** redesign from scratch and do **not** simplify away previously requested features. The app has already gone through several regressions where newer code visually or functionally replaced things the user wanted. For v0.6.0, the rule is:

> **Preserve working behavior, restore/advance the user-approved pre-Codex product direction, and use older functional versions as regression references whenever a newer implementation loses functionality.**

Repository: `jackersthecoltsfan/LifeRouteFinal`

Current release line after v0.5.4 TestFlight upload:
- TestFlight release workflow SHA: `a9cef84eb818721c74a7804ddf4fff452e3a350b`
- LifeRoute v0.5.4 uploaded successfully as TestFlight build **#77**
- Release request issue #29 completed and closed
- v0.5.4 passed inherited functional/persistence/performance/stability audits, the dedicated 50-angle v0.5.4 restoration audit, branch Simulator compile, main validation, signed archive, app + Live Activity identity verification, IPA export, TestFlight upload, artifact save, and signing cleanup.

The handoff-file commit occurs after the uploaded release and therefore is documentation-only, not the exact binary SHA that Apple received.

---

## Critical visual baseline — DO NOT FORGET THIS

The user-approved **preview image from the pre-v0.5.4 design discussion is the visual target**. In the conversation, the user explicitly said they loved that preview and wanted the actual app to get as close to it as possible. Later, when the first restored theme picker still looked like simple icon/gradient cards, the user posted two screenshots and said the **second screenshot / preview** is what themes should look like.

If the new chat has access to the project conversation images, locate that preview and treat it as the primary visual reference. If it cannot access the image directly, ask the user to re-upload it before making major visual changes rather than guessing.

### Preview/design language

LifeRoute should feel:
- premium, sleek, modern, professional, elegant, futuristic, smart
- primarily dark/navy/black with **gold** as a signature accent in the core LifeRoute look
- immersive rather than flat
- high contrast and highly legible
- rounded but not childish
- visually layered with glass/panel depth, soft glow, atmospheric imagery, refined shadows, and deliberate spacing
- dense enough to be useful but not cluttered
- clearly more like a polished commercial iPhone app than a generic SwiftUI Form

### Preview-style Today screen

The approved direction included a strong cinematic hero area at the top, then compact quick actions and useful dashboard cards below. Preserve this hierarchy:
1. immersive themed/cinematic hero
2. compact Quick Actions
3. Today overview / next event / timing
4. Live Day / Generate Day
5. route/day planning and gap suggestions

Do not revert Today to a plain list/Form or a collection of generic navigation rows.

### Themes

Themes must not be “the same card with different colors/icons.”

Scenery themes should use **realistic cinematic / CGI-quality environmental imagery** or an equally convincing bundled visual treatment: mountains, ocean, forest, aurora, dramatic sky, etc. They should feel like full visual identities.

Metallic/dynamic/fluid themes should likewise have distinct material/energy/flow character, not category-level icon swaps.

The theme selection experience should visually show what each theme actually looks like. The user specifically objected to the earlier simplistic theme cards.

Current v0.5.4 introduced `CinematicThemeViews.swift` / `LifeRouteCinematicBackdrop`. For v0.6.0, improve this toward durable high-quality app assets rather than weakening it. Remote imagery is acceptable as a temporary implementation but **bundled/local licensed or generated imagery is preferable for reliability/offline behavior and visual consistency**.

---

## Navigation baseline

Top-level tabs remain:
- **Today**
- **Schedule**
- **Tools**
- **Resources**
- **Setup**

`AppRouter` remains the navigation owner. Keep native SwiftUI `NavigationStack` navigation. The legacy WebView runtime stays quarantined and should not be reactivated.

The current v0.5.4 executable shell is intentionally separated from the older repaired shell. `V054ContentView` / v0.5.4 composition became the runtime direction while older files remain useful regression references.

Do not casually remove a tab, turn Resources back into generic shortcuts, or bury major Tools behind Setup.

---

## Product behavior that existed before Codex and must remain in the mental model

The pre-Codex LifeRoute concept is broader than a calendar viewer. The product is a **smart day-routing companion for an RBT**, with the ability to expand later to other LifeRoute roles.

Core concept:
- link calendars
- understand the user’s day
- identify gaps between obligations
- use current location / route timing
- suggest useful things that fit inside those gaps
- remember places/preferences so recommendations are relevant
- launch Maps for real navigation
- reduce wasted commuting/gap time

### Routing / gap planning requirements

Preserve these prior requests even when they are not yet fully mature:
- current location is the assumed commute origin when available
- saved Home address is a fallback and explicit Return Home destination
- easy saved-place creation
- saved client/service addresses
- route timing and Maps handoff
- add stops **before** an appointment
- add stops **after** an appointment
- explicit **Return Home** option
- saved preferred locations/categories for errands
- gap suggestions based on actual available time
- future concept: user can say an errand such as groceries and have preferred chains/categories such as Walmart, Giant, BJ’s, etc., then see nearby route/time choices
- future concept: memberships/preferences (gym, etc.) can make gap suggestions smarter
- Google Maps import/launch direction was discussed historically; current implementation is Apple/MapKit-first. Do not forget the broader routing concept when v0.6.0 planning begins.

v0.5.4 added `DayRoutePlanningCore.swift` and `DayRoutePlanningView.swift` for before/after stops and Return Home. Treat that as the beginning of the full route-sequencing system, not the endpoint.

---

## Live Day / Lock Screen

Live Day is intended to be more than an in-app card.

v0.5.4 added:
- `LiveDayActivityAttributes.swift`
- `LiveDayActivityCore.swift`
- `LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift`
- WidgetKit/ActivityKit Live Activity extension
- Lock Screen UI
- Dynamic Island UI on supported devices

Intended Live Day content:
- current or next event
- countdown / leave-time countdown
- route summary when known
- Return Home state
- time-aware day context

For v0.6.0, physical-device testing matters. Verify the real Lock Screen and Dynamic Island behavior on TestFlight before substantially extending it. Live Activity updates initiated only from the app are not a substitute for remote push updates if future requirements include long-lived background freshness; evaluate that separately if needed.

---

## Address autocomplete

The user explicitly wants address fields to auto-populate / autocomplete.

Use the shared native MapKit autocomplete behavior consistently for:
- Home
- saved places
- client/service addresses
- appointment locations
- route-stop addresses
- any new location/address field added later

Do not create a new plain address TextField without considering autocomplete.

---

## Tools tab — intended layout and features

Tools is a **session command center**, not a miscellaneous settings page.

Key tools that should remain visible and useful:
- Visual Timer
- Quick Notes
- Visual Supports
- First / Then
- AI Session Plan
- AI Session Note Generator

General/no-client mode must continue to work for visual supports and First/Then. Client-specific visual libraries must remain isolated.

### Timer

v0.5.4 intentionally increased synthesized timer audio approximately fivefold versus v0.5.3:
- rising pulse amplitude: ~0.60
- completion tones: ~0.85 with safe limiting
- playback player volume remains 1

Do not silently reduce the timer back to the quieter v0.5.3 contract. Physical-device test the new level; if it clips or is unpleasant, tune it deliberately rather than restoring the old low amplitude.

### AI Session Note Generator

The user explicitly asked to put the AI Session Note Generator back in.

v0.5.4 uses an on-device Apple Foundation Models direction when available and Vision OCR for optional screenshots/data images. The safety/product contract is important:
- supplied facts only
- no fabricated frequencies/percentages/prompts/behaviors/attendees/clinical outcomes
- saved client context may help terminology but must not be treated as proof something occurred
- user reviews/edits/copies the draft before use

Relevant files:
- `LifeRouteIntelligenceCore.swift`
- `AIClinicalToolsViews.swift`

### AI Session Plan

The user specifically rejected a Session Plan tool that merely mirrors entered text.

The AI plan should **actually organize** approved targets/reinforcers/context into a useful approximate session flow with time blocks, while not inventing clinical procedures.

Desired behavior example:
- pairing / setup
- approved NET or skill targets
- transition opportunities
- reinforcement/movement breaks when supported by supplied context
- table/structured work when supported by supplied context
- wrap-up

It must stay inside supervisor-approved information and should not generate new treatment protocols.

---

## Resources tab — very important

Resources is **NOT** a generic internal shortcut hub.

It is the user’s external **work portal launcher**.

The older/pre-Codex concept included categories such as:
- ABA Data & Clinical
- Finance & HR
- Training & Credentials
- Other ABA Work Portals

Examples discussed/restored include:
- CentralReach
- Motivity
- Rethink Behavioral Health
- BACB
- Relias
- ADP
- other employer-specific portals
- custom user-added links

v0.5.4 added:
- `ResourcePortalDomain.swift`
- `ResourcePortalViews.swift`

Keep the philosophy launch-only: LifeRoute opens the portal; credentials/account data stay with that service unless a future explicit integration is designed securely.

---

## Setup / clients

Keep Setup streamlined rather than turning it into a wall of controls.

Prior user requests that remain important:
- special Home address field
- location access
- Clients as a distinct management area under Setup
- ABA-style client identifiers using first two + last two initials
- no personal/demo client initials hard-coded in UI
- themes should be easy to select and preview
- more dark themes
- client profile editing should remain reliable and guarded from duplicate-save problems

Client/service address fields should participate in the shared autocomplete system.

---

## Calendar / Schedule

Keep:
- day/week/month native calendar presentation
- manual LifeRoute appointments
- Apple Calendar connection
- Google Calendar read-only connection
- explicit refresh behavior
- provider events remain provider-owned/read-only inside LifeRoute
- manual events persist locally

Schedule should visually move toward the approved premium layout rather than a plain stock Form, but do not sacrifice working event CRUD/provider behavior during appearance work.

Appointment locations should use autocomplete.

---

## App-family / long-term ecosystem direction

Current primary product: **LifeRoute – RBT**.

Longer-term family concept:
1. LifeRoute – RBT
2. LifeRoute – LBS/BCBA
3. LifeRoute – Parent
4. additional companion/ecosystem products where useful

LifeRoute should remain independent of any single ABA billing/EHR/data platform so it can work alongside CentralReach, Motivity, Rethink, etc.

A future kid-facing skills/game idea exists, but do not reproduce proprietary assessments such as VB-MAPP without licensing. Use licensed alignment or original clinician-reviewed skill activities.

There is also a persistent product-ideas document in the user’s Google Drive named `LifeRoute — Running Product Ideas & Ecosystem` inside a `LifeRoute` folder. Use it when continuing ecosystem/product ideation if the connector is available.

---

## Architecture / regression rules

### Native-first
- Native SwiftUI is authoritative.
- `AppRouter` remains navigation owner.
- Legacy `LifeRouteWebView.swift` and `Web` resources remain quarantined from active build/runtime.
- Do not resurrect old JavaScript interaction patches, global tap handlers, or WebView-based UI.

### Older versions are regression references
Useful branches/history include:
- `rebuild/v0.5.0-functional-core`
- `polish/v0.5.1-ui-foundation`
- `polish/v0.5.2-graphics-restoration`
- v0.5.3 functional-repair history
- v0.5.4 restoration history / PR #28

When something in v0.6.0 appears simpler but loses behavior, compare against these older implementations before assuming the older feature was intentionally removed.

### Protect working releases
Do development on a v0.6.0 feature branch. Do not modify `main` until the branch passes the accumulated functional/persistence/performance/stability audits and a real iOS Simulator compile.

Before TestFlight:
1. audit branch
2. Simulator compile branch
3. merge exact validated code
4. validate `main`
5. update release guard/version deliberately
6. signed device archive with provisioning updates
7. verify app + extension identities
8. export IPA
9. upload to TestFlight
10. only call it complete after Apple upload succeeds

The v0.5.4 TestFlight workflow now signs/verifies both:
- `Com.Brandongood.LifeRoute`
- `Com.Brandongood.LifeRoute.LiveDay`

---

## Recommended first task for v0.6.0

**Do not immediately add more features. Start by physical-device smoke testing TestFlight v0.5.4 build #77.**

Specifically test:
- preview-style Today appearance on real device
- every top-level tab
- cinematic/scenery themes and image reliability
- theme switching throughout the app
- all important buttons/tap targets
- Schedule day/week/month and calendar connections
- address autocomplete in every location field
- client create/edit/delete
- Visual Supports with zero clients and client-specific isolation
- First/Then
- timer audibility and completion behavior
- AI Session Note availability/output/edit/copy
- AI Session Plan availability/output/edit/copy
- Resources portal launching and custom portal management
- before/after day-route stops
- Return Home
- Apple Maps leg handoff
- Live Day start/end/update
- Lock Screen Live Activity
- Dynamic Island behavior if supported
- app relaunch/persistence

Capture screenshots of anything visually wrong and treat the original preview image as the target during fixes.

Only after that smoke test should v0.6.0 expand into new functionality.

---

## Suggested new-chat opening message

Copy/paste this into the next LifeRoute chat:

> **Continue LifeRoute as v0.6.0 using `LIFEROUTE_V0_6_0_HANDOFF.md` in `jackersthecoltsfan/LifeRouteFinal` as the primary handoff. Treat TestFlight v0.5.4 build #77 as the current functional baseline. Also reference the older v0.5.0/v0.5.1/v0.5.2/v0.5.3 implementations whenever needed for regressions. Most importantly, preserve the user-approved pre-Codex design direction and preview image: premium dark/navy/gold, cinematic imagery, compact polished navigation/dashboard layout, and all previously requested routing/session/resource features. Do not simplify or remove working pieces. Start by reviewing v0.5.4 physical-device feedback, then create a v0.6.0 feature branch and proceed with regression-safe changes.**
