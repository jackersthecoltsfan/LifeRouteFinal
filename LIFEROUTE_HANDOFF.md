# LifeRoute Project Handoff

This file is the durable handoff between LifeRoute development threads. Keep it compact, current, and free of secrets or unrelated personal information.

## Resume protocol

At the start of a new LifeRoute thread, read:

1. `LIFEROUTE_HANDOFF.md`
2. `AGENTS.md`
3. `APP_CREATION_PLAYBOOK.md`
4. `TESTFLIGHT_SETUP.md`
5. `GITHUB_ACTIONS_RUNBOOK.md`
6. relevant files in `ReusableAppWorkflow/`

Then inspect live GitHub/Actions state before acting on recorded workflow status.

## Current state — 2026-08-26

Repository: `jackersthecoltsfan/LifeRouteFinal`

v0.4.0 product merge commit:
`b59f9c244419786d92d9c898d9430c0f92ff3d70`
(`Merge LifeRoute v0.4.0 direct startup`)

PR `#13` (`LifeRoute v0.4.0 — remove local login gate`) was merged after its branch validations succeeded.

v0.4.0 was released to TestFlight from SHA:
`3d7993804ad008fbbd8993afae066eed314fcb74`

That SHA differs from the product merge only by the documentation-only handoff update `Update handoff after v0.4.0 merge validation`; no app/runtime files changed between the validated product merge and the released SHA.

TestFlight workflow `LifeRoute → TestFlight` run `#70` / ID `33006131821` completed successfully, including:

- exact-SHA release-source verification;
- deterministic LifeRoute preparation;
- full LifeRoute regression audit;
- Apple connection and bundle-ID validation;
- archive and signed IPA export;
- the actual `Upload to TestFlight` step;
- IPA artifact save;
- temporary signing-asset cleanup.

The first release request for merge SHA `b59f9c...` was safely rejected after `main` advanced by the documentation-only handoff commit. A second exact-current-main request (`#15`) was accepted and produced successful TestFlight run `#70`. Release-request issues `#14` and `#15` are closed.

## v0.4.0 direct-startup decision

Physical-device testing showed that the legacy local username/PIN login screen remained unreliable even after PIN fields accepted input. v0.4.0 therefore launches directly into LifeRoute.

Implementation:

- a deterministic early bypass returns before legacy local-auth startup work executes;
- no PIN derivation, auth overlay/style construction, login rendering, settings polling, or native `authStatus` startup request runs on the normal v0.4.0 path;
- stale auth overlay/styles/settings rows and auth-lock attributes are defensively removed;
- the legacy local-auth implementation remains recoverable below the bypass for a future redesign;
- native Keychain/biometric infrastructure remains present and hardened but dormant from normal startup;
- Google Calendar OAuth remains separate, intact, and read-only (`calendar.readonly`);
- no credentials, secrets, signing material, or provider tokens were exposed.

The deterministic path remains rooted in `scripts/prepare_build.sh`; the v0.4.0 bypass is applied through the existing auth preparation chain.

## Validation evidence

Branch/runtime validation:

- confirmation iOS Build Check `#616` / run ID `33005620839` — success
- preparation — success
- full LifeRoute regression audit — success
- iOS Simulator build — success

Merged-main validation for SHA `b59f9c244419786d92d9c898d9430c0f92ff3d70`:

- iOS Build Check `#617` / run ID `33005847996` — success
- `Prepare the same features used by TestFlight` — success
- `Full LifeRoute regression audit` — success
- `Build LifeRoute for iOS Simulator` — success

Release validation for TestFlight run `#70` / ID `33006131821`:

- release-source guard — success
- prepare — success
- full regression audit — success
- archive — success
- signed IPA export — success
- TestFlight upload — success

Validated areas include auth direct-startup/no-touch-blocking behavior, Google OAuth scope preservation, client profiles/pickers, navigation, Day/Week/Month immediate selected state, routing/gap planning, Live Day/Live Activity, address/home/current/live location, stop/place search and duration, Tools and visual timer, First/Then/session-planning/visual tools, categorized themes, premium haptics/motion/accessibility, AI journeys/runtime safety, external-service limits, state invariants, and no legacy programmatic document scrolling.

Performance/smoothness gates passed all four review angles:

1. runtime pressure and freeze prevention
2. motion and touch responsiveness
3. scroll/lifecycle stability
4. release-artifact and navigation integrity

## Performance and UI requirements to preserve

Do not reintroduce whole-document/broad class MutationObservers, repeated full-document scans, forced synchronous layout/reflow tricks, duplicate interaction/transition owners, heavy iPhone blur/filter animation, unnecessary timers/polling, repeated critical-path geometry measurements, or programmatic document scrolling.

Preserve immediate tactile response, lightweight spring motion/haptics, reduced-motion accessibility, immediate Day/Week/Month synchronization, premium dark-blue/gold styling, and categorized Themes (`Classic`, `Metallic`, `Scenery`, `Dynamic`, `Fluid`, `Living`).

## Next action

v0.4.0 direct-startup work is complete, validated, and uploaded to TestFlight. The next step is physical-device testing of TestFlight build `#70`, especially launch responsiveness, absence of the local login overlay, Day/Week/Month response, navigation/touch feel, themes, routing/location, provider connections, and the most-used ABA/Tools workflows.

For the next substantial development task, inspect current `main` and branch into a fresh isolated feature branch. Before any eventual later TestFlight release, rerun deterministic preparation, the full regression suite, performance/smoothness gates, and iOS Simulator build against the final release candidate, then require Brandon's explicit release authorization.
