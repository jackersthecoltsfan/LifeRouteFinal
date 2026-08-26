# LifeRoute Project Handoff

This file is the durable handoff between LifeRoute development threads. Keep it compact, current, and free of secrets or unrelated personal information.

## How a new LifeRoute chat should resume

Read, in order:

1. `LIFEROUTE_HANDOFF.md`
2. `AGENTS.md`
3. `APP_CREATION_PLAYBOOK.md`
4. `TESTFLIGHT_SETUP.md`
5. `GITHUB_ACTIONS_RUNBOOK.md`
6. relevant files in `ReusableAppWorkflow/`

Then inspect live GitHub/Actions state before acting on any recorded workflow status.

The user should only need to say:

> Continue LifeRoute from the repository and the current handoff.

## Current project state — 2026-08-26

Repository: `jackersthecoltsfan/LifeRouteFinal`

Validated release baseline on `main`:
`0fb4c1b5e3873030295617f04577c254e1bc55d7`
(`Merge LifeRoute performance smoothness pass`)

Active isolated development branch:
`feature/v0.4.0`

Draft validation PR:
`#13` — `LifeRoute v0.4.0 — remove local login gate`

Latest validated v0.4.0 runtime commit before this documentation refresh:
`0e48338faccf5d416c01fad198cd2f49b6b97b6b`

Do not merge experimental work directly to `main`. Keep v0.4.0 isolated until its development phase is ready.

## Previous TestFlight release

The TestFlight workflow for main SHA `0fb4c1b5e3873030295617f04577c254e1bc55d7` completed successfully.

- Workflow: `LifeRoute → TestFlight`
- Run: `#68`
- Run ID: `33003904725`
- Result: success
- The actual `Upload to TestFlight` step succeeded.

This is the last confirmed TestFlight release state before v0.4.0 development.

## v0.4.0 authentication decision

Physical-device testing showed that PIN fields could accept input, but the local LifeRoute login screen itself remained unreliable/unresponsive.

For v0.4.0, the local username/PIN gate is therefore intentionally bypassed on startup.

Implemented behavior:

- LifeRoute launches directly into the main application.
- The legacy local-auth implementation remains recoverable below an immediate v0.4.0 bypass for a future authentication redesign.
- The bypass returns before PIN derivation, auth-style/overlay construction, login rendering, settings polling, or native `authStatus` startup requests can execute.
- Defensive cleanup removes any stale legacy auth overlay, auth styles, auth settings section, or auth-lock document attributes.
- Native Keychain and biometric infrastructure remains present and hardened but dormant from the normal v0.4.0 startup path.
- Google Calendar OAuth remains separate, intact, and read-only (`calendar.readonly`).
- No credentials, secrets, signing material, or provider tokens were exposed.

The deterministic build path applies this through the existing auth preparation chain; `scripts/prepare_build.sh` itself remains deterministic and unchanged for this feature.

## v0.4.0 validation evidence

Final branch validation for runtime commit `0e48338faccf5d416c01fad198cd2f49b6b97b6b` passed completely.

GitHub Actions:

- Workflow: `iOS Build Check`
- Run: `#614`
- Run ID: `33005423883`
- Conclusion: success

Required gates all passed:

1. `Prepare the same features used by TestFlight` — success
2. `Full LifeRoute regression audit` — success
3. `Build LifeRoute for iOS Simulator` — success
4. Xcode result — `** BUILD SUCCEEDED **`

The umbrella full regression audit reported:

- `577 checks passed, 0 failed`

Important focused validation also passed, including:

- v0.4.0 startup/auth bypass and no-overlay/touch-interception contract
- Google OAuth read-only/provider-auth preservation
- client pickers and saved-client profiles
- navigation architecture and four-tab navigation
- Day UI, Day/Week/Month immediate selected-state behavior, routing, and gap planning
- Live Day reminders and Live Activity integration
- address autocomplete, home persistence, current/live location, and stale-coordinate rejection
- stop/place search and planned-stop duration
- Tools, visual timer, First/Then, session planning, visual maker, and choice boards
- categorized theme catalog and deep theme runtime
- premium interactions, haptics, mobile ergonomics, accessibility, and appearance
- stability and state invariants
- AI user journeys, AI runtime/release safety, Vision/Image Playground/ABA-note hooks
- external-service privacy/workload limits
- no legacy programmatic document scrolling
- feature parity/performance

Performance/smoothness audit passed all four angles:

1. runtime pressure & freeze prevention
2. motion & touch responsiveness
3. scroll/lifecycle stability
4. release artifact & navigation contract

At the validated runtime commit, the branch differed from the release baseline only in five auth/auth-audit files. No calendar, routing, theme, tools, AI, navigation, or general performance implementation file was modified by this v0.4.0 login-removal task.

## Performance requirements to preserve

Do not reintroduce:

- whole-document or broad class-change MutationObservers
- repeated full-document scans
- forced synchronous layout/reflow tricks
- duplicate button/page-transition systems
- heavy iPhone blur/filter animation
- multiple interaction owners for one tap
- unnecessary polling/timers
- repeated geometry measurement on critical interaction paths
- programmatic document scrolling

Prefer transform/opacity, scoped observers, event delegation, immediate selected-state/touch feedback, lightweight spring motion, and one owner per interaction.

## UI state to preserve

Keep the premium Apple-style direction already validated:

- sleek professional dark-blue/gold identity
- immediate tactile response
- lightweight haptics and spring feedback
- smooth page/navigation transitions
- reduced-motion accessibility
- immediate Day/Week/Month selected-state synchronization
- categorized Themes accordion/dropdown organization: Classic, Metallic, Scenery, Dynamic, Fluid, Living
- strong mobile responsiveness with minimal clutter

## Release policy / next action

**Do not upload v0.4.0 to TestFlight until Brandon explicitly authorizes the release.**

The current v0.4.0 work is validated but remains on the isolated development branch/draft PR while additional v0.4.0 features may be added.

Next action: wait for the next v0.4.0 feature request. For every additional substantial feature, preserve the same regression/performance discipline. Before any eventual TestFlight release, rerun the complete preparation, full regression suite, performance/smoothness gates, and iOS build against the final release candidate, then require explicit release authorization.
