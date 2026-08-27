# LifeRoute v0.6.1 — New Chat Handoff

## Start here

Continue LifeRoute from the **completed v0.6.0 TestFlight release**. Do **not** redesign from scratch, do **not** simplify away working behavior, and do **not** assume that newer code supersedes older user-approved functionality unless that was explicitly decided.

Repository: `jackersthecoltsfan/LifeRouteFinal`

## Current release baseline

- Latest uploaded release: **LifeRoute v0.6.0 build #78**
- Exact source SHA Apple received: `0def9ef7649ce4bb9525d9a738901ceac088959d`
- Release PR: **#30**
- TestFlight workflow run: **33099507856**
- Apple result: **UPLOAD SUCCEEDED with no errors**
- Delivery UUID: `4995ca63-cddb-4096-9f76-d22969fc9fcc`
- Main app and Live Day extension were archive-verified as **0.6.0 (78)** before upload.
- Release authorization issue #31 was closed as completed after upload.
- Temporary signing assets were cleaned up successfully.

This handoff is documentation created after the shipped binary. Treat `0def9ef7649ce4bb9525d9a738901ceac088959d` as the exact TestFlight v0.6.0 code baseline.

---

# Non-negotiable regression rule

> **Preserve working behavior, use older working LifeRoute versions as regression references, and never assume a simpler/newer implementation means an older feature was intentionally removed.**

LifeRoute has already experienced regressions where newer work lost features or drifted away from the approved appearance. v0.6.1 must remain additive/regression-safe.

## Regression reference order

When something in v0.6.1 breaks, disappears, or feels visually/functionally weaker, compare in this order:

1. **v0.6.0 build #78 / SHA `0def9ef...`** — current released functional baseline.
2. **v0.5.4 build #77** — prior strong native restoration baseline.
3. v0.5.3 repair history — useful for interaction/location/timer/general repairs.
4. `polish/v0.5.2-graphics-restoration` — graphics/appearance history.
5. `polish/v0.5.1-ui-foundation` — native UI foundation history.
6. `rebuild/v0.5.0-functional-core` — functional native core history.
7. Earlier project conversations/screenshots/previews when code history no longer captures an approved requirement.

Do not remove a feature simply because it is absent from the newest screen. First check whether it existed in a prior working build or project conversation.

---

# CRITICAL v0.6.1 priority: App icon still needs to be changed

**The app icon was NOT completed in v0.6.0. Do not mark it done.**

The repository currently contains a checked-in 1024×1024 AppIcon and a separate LR logo/source asset from the icon history. During v0.6.0 work, the existing 1024 icon was deliberately left untouched because the available assets did not prove which binary was the newest user-approved LR artwork.

For v0.6.1:

- Replace the installed/app-store icon with the **newer approved LifeRoute LR version** the user previously requested.
- Reference the earlier LifeRoute icon-design conversation and screenshots rather than guessing.
- The intended icon direction is bold, modern, professional, premium, dark navy/black + gold, with a strong **LR** identity.
- If the exact approved newer icon image is not accessible in the new chat/project history, ask the user to re-upload it before replacing the binary.
- Do not accidentally restore an older icon just because it exists in Git history.
- Ensure the final app icon is a valid production 1024×1024 asset and verify it in the signed archive/TestFlight build before calling this task complete.

Relevant path:
`LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

Historical source/logo path may include:
`LifeRoute/Web/liferoute-logo-source.png`

Remember: the source/logo file and active AppIcon have historically been different binaries; inspect visually and use the approved design reference.

---

# Critical visual baseline — approved preview image

The user-approved **LifeRoute preview/design image from the earlier project conversation remains the primary visual target**.

The user explicitly said they loved that preview and wanted the real app to get as close to it as practical. Treat that preview as a design reference alongside working released builds.

## New-chat instruction for the preview

If the new chat has access to project conversation images, locate the approved LifeRoute preview and compare major appearance work against it.

If the preview is not directly accessible, ask the user to re-upload it **before making major visual redesign decisions** rather than guessing.

For appearance work use both:
- the preview image as the **visual/design target**, and
- v0.6.0 / older working builds as the **functional/layout regression references**.

## Visual language to preserve

LifeRoute should feel:
- premium, sleek, modern, professional, elegant, futuristic, smart
- dark/navy/black-forward with **gold** as the signature core accent
- cinematic and immersive rather than flat
- high contrast and highly legible
- rounded/refined, not childish
- layered with glass/panel depth, atmospheric imagery, soft glow, controlled shadows, and deliberate spacing
- compact and information-dense without looking cluttered
- like a polished commercial iPhone app, not a generic SwiftUI `Form`

## Today-screen visual hierarchy

Preserve the preview-driven hierarchy:
1. immersive themed/cinematic hero
2. compact Quick Actions
3. Today overview / next event / timing
4. Live Day / Generate Day
5. route/day planning and gap suggestions

Do not regress Today into a plain list of navigation rows.

## Themes

Themes must propagate across the whole app and feel like distinct visual identities.

Scenery themes should use convincing environmental imagery/treatment. Metallic/dynamic/fluid themes should have their own material/energy character. Do not reduce themes to identical cards with different colors/icons.

The Theme Center should visually preview what each theme actually looks like.

---

# What v0.6.0 completed — do not regress

v0.6.0 was a targeted regression-repair/enhancement release built on the v0.5.4 native shell.

## Resource Hub

The native Resource Hub was restored to the broader pre-Codex portal catalog rather than the reduced subset.

It now includes a larger additive catalog across:
- ABA Data & Clinical
- Finance & HR
- Training & Credentials
- Other ABA Work Portals

It preserves custom links and includes both current and restored destinations rather than replacing one with another.

Important examples include CentralReach, Motivity, Rethink, BACB, Relias, ADP/Workforce Now/MyADP, BambooHR, Gusto, Paycom, Paylocity, UKG, Rippling, Workday, QuickBooks Workforce, Viventium, Theralytics, Ensora/Catalyst, Hi Rasmus, AlohaABA, HHAeXchange, Sandata, Microsoft 365, Google Workspace, Slack, Teams, Therap, etc.

Resources is an **external work-portal launcher**, not a generic in-app shortcuts page.

## Calendar/provider persistence

v0.6.0 fixed the relaunch regression where Apple/Google connection state could survive but previously imported provider events disappeared after the app was closed.

Provider event snapshots now persist through the native protected persistence store and are restored on relaunch.

Important persistence guardrails:
- provider events remain separate from manually created LifeRoute appointments
- provider events remain read-only/provider-owned inside LifeRoute
- cache is bounded/sanitized
- schema advanced from v3 to v4 using additive decoding so older installs migrate without losing existing data
- do not replace this with direct UserDefaults persistence

## AI Session Note Generator

The user likes the current Session Note generator and Session Plan generator. Treat both as regression references.

v0.6.0 additions around Session Notes:
- Scratch/Quick Notes can be pulled into the AI Session Note input
- imported scratch notes are filtered for the selected client
- scratch-note import appends instead of overwriting existing facts
- output instructions were tightened so notes read as a **cohesive chronological clinical narrative** instead of broken fact fragments
- supplied session data should be woven naturally throughout the narrative, similar to the user’s preferred ChatGPT-generated ABA notes

Do **not** rewrite or broadly refactor the successful AI Session Plan generator.

Session Note safety contract remains:
- supplied facts only
- no fabricated data/frequencies/percentages/prompts/behaviors/attendees/outcomes
- saved client context may help terminology but is not proof an event occurred
- user reviews/edits/copies before use

Relevant files:
- `LifeRouteIntelligenceCore.swift`
- `AIClinicalToolsViews.swift`

## AI Session Plan

The user explicitly said the current Session Plan generator works perfectly. **Do not change its successful output behavior without a demonstrated need.**

It should continue to organize supervisor-approved targets/reinforcers/context into a useful approximate session flow without inventing new clinical procedures.

## AI Visual Supports

v0.6.0 added an AI-enhanced visual-support layer while preserving manual workflows.

Intended behavior:
- user can type/paste a routine
- Apple on-device Foundation Models can draft 2–12 short ordered visual-schedule steps
- generated steps remain editable before save
- generated schedules save through the same existing visual-schedule persistence/validation path
- existing saved icons can be matched/reused by label
- Image Playground can generate a visual-support image and return it into the existing local icon library
- manual photo/text/icon workflows remain available as fallback
- if Apple Intelligence/Image Playground is unavailable, manual creation still works
- AI visual schedule generation must not invent treatment protocols or clinical procedures

Do not replace the manual Visual Supports workspace with AI-only behavior.

## Themes / interaction polish

v0.6.0 fixed several hard-coded color leaks in Today/Tools so active themes control more of the interface.

It also added live nav/tab chrome refresh behavior so already-mounted bars respond to theme switching without recreating the whole navigation tree.

Interaction feedback was expanded selectively:
- tool/navigation haptics
- portal-launch feedback
- calendar connect/refresh/disconnect/save/delete/range-change feedback
- subtle theme-change sound
- existing button animations/haptics remain

Keep feedback tasteful. Do not add sounds to every tap or make the app feel toy-like.

Respect Reduce Motion and the iPhone silent switch where applicable.

---

# Navigation baseline

Top-level tabs remain:
- **Today**
- **Schedule**
- **Tools**
- **Resources**
- **Setup**

`AppRouter` remains navigation owner.

Keep native SwiftUI `NavigationStack` navigation.

The legacy WebView runtime remains quarantined. Do not reactivate `LifeRouteWebView.swift`/legacy Web resources as the active application shell.

Active runtime direction is the v0.5.4/v0.6 native shell (`V054ContentView` composition and subsequent native additions).

---

# Core product direction that must stay in the mental model

LifeRoute is not just a calendar viewer. It is a **smart day-routing companion for an RBT**.

Core direction:
- connect calendars
- understand the user’s day
- identify usable gaps between obligations
- use current location and route timing
- suggest useful stops/activities that fit those gaps
- remember saved places/preferences
- route into Maps for real navigation
- reduce wasted commuting/gap time

## Routing/gap-planning requirements

Preserve these earlier approved concepts:
- current location is the assumed commute origin when available
- saved Home is fallback and explicit Return Home destination
- easy saved-place creation
- client/service addresses
- address autocomplete
- route timing and Maps handoff
- add stops before an appointment
- add stops after an appointment
- explicit Return Home option
- saved preferred locations/categories for errands
- gap suggestions based on actual available time
- future grocery/store preferences such as Walmart, Giant, BJ’s, etc., with nearby route/time choices
- future memberships/preferences such as gyms to improve gap suggestions

**Add Stop already exists in the current app. Do not duplicate it.**

---

# Live Day / Lock Screen

Keep the v0.5.4/v0.6.0 native Live Activity system:
- Live Day ActivityKit model
- Lock Screen UI
- Dynamic Island UI on supported devices

Intended Live Day content includes:
- current/next event
- countdown / leave-time countdown
- route summary when known
- Return Home state
- time-aware day context

Physical-device testing remains important before large changes here.

---

# Address autocomplete

Use shared native MapKit autocomplete consistently for:
- Home
- saved places
- client/service addresses
- appointment locations
- route stops
- future location/address fields

Do not add a new plain address TextField without considering autocomplete.

---

# Tools baseline

Tools remains a **session command center**, not a miscellaneous settings page.

Keep visible/useful:
- Visual Timer
- Quick Notes
- Visual Supports
- First / Then
- AI Session Plan
- AI Session Note Generator

General/no-client mode should still work where intended. Client-specific visual libraries must remain isolated.

### Timer

Preserve the louder v0.5.4+ timer audio contract unless physical-device testing demonstrates a need to tune it deliberately.

---

# Setup / clients

Keep Setup streamlined.

Preserve:
- special Home address field
- location access
- Clients as distinct management area
- ABA-style client identifiers using first two + last two initials
- no personal/demo client initials hard-coded in production UI
- reliable client create/edit/delete
- more dark themes / visual Theme Center
- address autocomplete for client/service addresses

---

# Calendar / Schedule

Keep:
- day/week/month native calendar presentation
- manual LifeRoute appointments
- Apple Calendar connection
- Google Calendar read-only connection
- explicit refresh behavior
- provider events read-only/provider-owned
- manual events locally editable/persistent
- provider snapshot persistence introduced in v0.6.0

Appearance can continue moving toward the approved premium design, but do not sacrifice working CRUD/provider behavior during polish.

---

# App family / long-term ecosystem

Current primary product: **LifeRoute – RBT**.

Long-term family concept:
1. LifeRoute – RBT
2. LifeRoute – LBS/BCBA
3. LifeRoute – Parent
4. additional companion/ecosystem products where useful

LifeRoute should remain independent of any single ABA billing/EHR/data platform so it can work alongside CentralReach, Motivity, Rethink, etc.

There is a persistent Google Drive document named:
`LifeRoute — Running Product Ideas & Ecosystem`
inside a `LifeRoute` folder. Use it when continuing ecosystem/product ideation if the Drive connector is available.

Do not reproduce proprietary assessments such as VB-MAPP without licensing. Use licensed alignment or original clinician-reviewed skill activities.

---

# Architecture / release guardrails

## Native-first

- SwiftUI native runtime is authoritative.
- `AppRouter` owns navigation.
- Legacy WebView resources remain quarantined.
- Do not resurrect old JavaScript/global-tap/WebView interaction patches.

## Protect working releases

For v0.6.1 development:

1. branch from current `main`
2. use v0.6.0 build #78 as baseline
3. make narrow/additive changes
4. keep accumulated v0.5/v0.6 audits passing
5. run real iOS Simulator compile before merge
6. merge only exact validated code
7. validate exact `main` SHA
8. deliberately update release/version guard
9. signed archive with both app + Live Day extension
10. verify archived app/extension version/build identities
11. export IPA
12. upload TestFlight
13. only call release complete after Apple returns successful upload
14. clean temporary signing assets

Current bundle identities:
- `Com.Brandongood.LifeRoute`
- `Com.Brandongood.LifeRoute.LiveDay`

Do not bypass exact-SHA release authorization/validation guards.

---

# Recommended first actions in the v0.6.1 chat

1. **Smoke-test TestFlight v0.6.0 build #78 on the physical iPhone** and collect screenshots/behavior notes.
2. **Fix the app icon** using the newer approved LR artwork. This remains an open task.
3. Compare any visual concerns against the approved preview image and older working screenshots.
4. Fix only demonstrated regressions first; do not immediately refactor working Session Plan/Session Note behavior.
5. Then continue v0.6.1 features/polish on a dedicated feature branch.

Suggested smoke-test areas:
- app icon on Home Screen/TestFlight-installed build
- Today visual hierarchy
- all top-level tabs
- theme switching across every major pushed screen/sheet
- Schedule day/week/month
- Apple/Google calendar refresh + relaunch persistence
- address autocomplete
- client create/edit/delete
- Visual Supports manual + AI paths
- Image Playground icon creation
- AI visual schedule drafting/edit/save
- First/Then
- timer volume/completion
- Scratch Notes → AI Session Note
- AI Session Note narrative/data incorporation
- AI Session Plan unchanged quality
- Resources links/custom portals
- route Add Stop before/after appointments
- Return Home
- Maps handoff
- Live Day Lock Screen/Dynamic Island
- app relaunch persistence generally

---

# Suggested opening message for the next LifeRoute chat

> **Continue LifeRoute as v0.6.1 using `LIFEROUTE_V0_6_1_HANDOFF.md` in `jackersthecoltsfan/LifeRouteFinal` as the primary handoff. Treat TestFlight v0.6.0 build #78 / SHA `0def9ef7649ce4bb9525d9a738901ceac088959d` as the current released baseline, and use v0.5.4 plus older v0.5.0–v0.5.3 working implementations as regression references whenever needed. Preserve the user-approved preview design direction—premium dark/navy/gold, cinematic imagery, compact polished dashboard/navigation—and do not simplify or remove working pieces. Important: the app icon is still NOT finished; v0.6.1 must replace it with the newer approved LR icon, using the earlier icon/design reference rather than guessing. Start with physical-device feedback from v0.6.0 build #78, then create a v0.6.1 feature branch and proceed with regression-safe changes.**
