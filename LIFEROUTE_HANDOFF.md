# LifeRoute Project Handoff

This file is the durable handoff between LifeRoute ChatGPT threads. It should stay compact, current, and free of secrets or unrelated personal information.

## How a new LifeRoute chat should resume

At the start of a new LifeRoute project thread, read:

1. `LIFEROUTE_HANDOFF.md`
2. `AGENTS.md`
3. `APP_CREATION_PLAYBOOK.md`
4. `TESTFLIGHT_SETUP.md`
5. `GITHUB_ACTIONS_RUNBOOK.md`
6. relevant files in `ReusableAppWorkflow/`

Then inspect live GitHub state before assuming that a workflow/run status recorded here is still current.

The user should only need to say:

> Continue LifeRoute from the repository and the current handoff.

## Current project state — 2026-08-26

Repository: `jackersthecoltsfan/LifeRouteFinal`

Default branch: `main`

Current main at the time this handoff was prepared: `a0ee0fdab88d7dab91bc8e9f858266d21eb288c5`

Active workflow-hardening branch: `workflow-hardening-2026-08-26`

### Current product/release objective

Release the PIN-entry reliability fix to TestFlight after current-main validation is healthy.

Original PIN fix commit: `546fe01cdd2560d80994dff0fdf805822ed84e47` (`Fix PIN entry on web and iPhone`).

The fix uses reliable masked numeric PIN inputs and preserves 4-digit validation/Keychain hardening. Subsequent commits have primarily changed release/workflow infrastructure rather than the app runtime.

The user has already explicitly authorized this PIN-fix TestFlight release. Do not ask for release authorization again for this specific release target unless the app/runtime source changes materially after this handoff.

### Latest useful validation evidence

- iOS Build Check #574 for main SHA `924417ea6585ee594646a0869c77371483bf8774` completed successfully.
- The corresponding web preview passed all app/runtime/regression audits but failed one stale documentation-wording policy assertion.
- That assertion was corrected on main in `a0ee0fdab88d7dab91bc8e9f858266d21eb288c5`; no app runtime behavior changed in that commit.

### Current external blocker

GitHub reported a major Actions outage on 2026-08-26 beginning at 15:11 UTC, with Pages also degraded. The incident involved a database primary, failover, inbound throttling, and gradual traffic restoration. Several old LifeRoute workflow records remained stuck in `queued` even after normal cancellation requests.

Do not interpret those stale queued records as an app build failure. Follow `GITHUB_ACTIONS_RUNBOOK.md` and check current GitHub Status before attempting recovery.

## Workflow-hardening work in progress

The hardening branch is intentionally off `main` while GitHub Actions is unstable. It currently includes these process improvements:

- narrowed iOS CI triggers so unrelated workflow-file edits do not launch macOS builds;
- workflow-scoped concurrency keys;
- Pages removal of duplicate deep audits already owned by `prepare_build.sh`;
- a lightweight Ubuntu `policy-check.yml` for release/workflow policy changes;
- stronger release-isolation audit that verifies only `testflight.yml` contains actual upload machinery;
- removal of inert `auto-testflight.yml` and `release.yml` placeholder workflows;
- a workflow-efficiency audit to prevent trigger/polling/duplication regressions;
- a short-lived assistant TestFlight bridge that requires already-completed successful validation instead of polling for up to two hours;
- `GITHUB_ACTIONS_RUNBOOK.md` for provider-outage diagnosis and safe cancellation escalation.

Before merging this hardening branch, run/verify the two policy audits and review the workflow diff after GitHub Actions returns to normal.

## Release policy

TestFlight is explicit-confirmation-only.

- Normal pushes may validate/build/publish the web preview but never upload to TestFlight.
- `testflight.yml` is the sole workflow containing Apple signing/upload machinery and remains manual (`workflow_dispatch`) only.
- ChatGPT/Codex may use the guarded owner-authorized release-request bridge after the user has explicitly authorized release and the required validation has already succeeded.
- Do not create a release request while GitHub Actions is degraded/outage.

## Automatic conversation handoff protocol

ChatGPT should proactively prepare a new-thread handoff before context quality degrades. There is no reliable user-visible numeric token meter available to the assistant, so use observable context-pressure signals rather than waiting for the platform to reject another message.

### Refresh this file when

Refresh the current-state sections after any of these:

- a TestFlight release succeeds or fails in a way that changes next steps;
- a major feature implementation reaches a stable commit;
- CI/release architecture changes materially;
- a significant external incident changes the plan;
- the active objective or branch changes;
- a long troubleshooting sequence reaches a clear conclusion.

Do not update this file for every minor cosmetic edit or every workflow status poll.

### Proactively recommend a new LifeRoute thread when any strong signal occurs

- ChatGPT/app explicitly reports that the conversation is too long.
- The assistant has to reconstruct already-established project state from summaries/history more than once in a short span.
- The current thread has crossed multiple major implementation/release/troubleshooting phases and old tool results are becoming necessary to answer ordinary follow-ups.
- The assistant notices conflicting or stale remembered workflow state that requires repeated re-reading before acting.
- A large new phase is about to start (for example, a major UI rebuild or API integration) after a long completed phase.
- The user asks whether a new thread would be better.

Do not wait until the current thread actually loses continuity. When one strong signal or several moderate signals appear, prepare the handoff first and then tell the user that a clean LifeRoute thread is recommended.

### Handoff procedure

1. Re-read live GitHub state relevant to the active objective.
2. Update this file with current main SHA, active branch, goal, latest validations/releases, blockers, key decisions, and exact next action.
3. Keep the handoff concise; link to canonical repository docs instead of duplicating them.
4. Tell the user a new thread is recommended and provide only this short opening prompt:

> Continue LifeRoute from the repository and the current handoff.

5. In the new thread, read this file before asking the user to repeat anything.

## Next actions after GitHub recovery

1. Confirm GitHub Actions/Pages are operational and allow backlog to settle.
2. Re-read the five historical queued/zombie runs; force-cancel only if they still meet the runbook criteria.
3. Verify and finish the workflow-hardening branch.
4. Merge hardening to `main` only after static review/policy audits pass.
5. Obtain one clean current-main iOS validation and web preview as required.
6. Use the already-authorized guarded release path for the PIN-fix TestFlight build.
7. Verify the exact `Upload to TestFlight` step succeeds and report the new build number.
