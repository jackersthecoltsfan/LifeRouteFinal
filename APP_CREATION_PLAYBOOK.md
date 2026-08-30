# LifeRoute App Creation → TestFlight Playbook

This is the canonical streamlined workflow for LifeRoute and the reusable app workflow derived from it.

## Operating model

The product owner should normally do only three things:

1. Describe what should change in normal language.
2. Explicitly authorize a TestFlight release when a validated version is ready to test.
3. Test the resulting build on the iPhone and report feedback.

ChatGPT/Codex handles implementation, repository edits, deterministic preparation, audits, GitHub workflow inspection, build-failure diagnosis, and release verification wherever the connected tools allow it.

Do not make the product owner manually copy source files, read routine CI logs, increment build numbers, or redo signing setup during normal iterations.

## Canonical sources

Before substantial work, read the applicable sources in this order:

1. `LIFEROUTE_HANDOFF.md` — current live project state and next action.
2. `AGENTS.md` — repository development/security rules.
3. `APP_CREATION_PLAYBOOK.md` — this operating model.
4. `TESTFLIGHT_SETUP.md` — exact release authorization/signing behavior.
5. `GITHUB_ACTIONS_RUNBOOK.md` — Actions outage, queue, cancellation, and recovery rules.
6. relevant material in `ReusableAppWorkflow/`.

The GitHub repository is the source of truth for code and workflow configuration. Live GitHub run state must be re-read rather than assumed from an old chat handoff.

## Product/design workflow

### Small or obvious change

Implement directly using the established architecture and design system, add/update appropriate deterministic checks, and validate.

### Significant visual/navigation change

Use a quick mockup or Figma pass when seeing the direction first is likely to prevent rework. Once the product owner approves the direction, proceed without redundant confirmation unless a consequential new tradeoff appears.

LifeRoute should remain premium, sleek, intelligent, streamlined, professional, and futuristic, with a dark-blue/gold core identity and customizable themes. Preserve accessibility, touch ergonomics, performance, and clarity.

## Engineering workflow

1. Read the handoff and applicable canonical docs.
2. Inspect the existing end-to-end behavior before editing.
3. Preserve unrelated changes and existing working architecture.
4. Implement the smallest maintainable change that satisfies the product request.
5. Update canonical checked-in source and the relevant current semantic validation together.
6. Add/update focused deterministic audits or tests.
7. Commit to GitHub.
8. Inspect the resulting validation rather than assuming success.

Prefer native SwiftUI/current Apple APIs where practical, while preserving the established WKWebView/native-bridge architecture until functionality is deliberately migrated.

## Deterministic build ownership

`scripts/prepare_build.sh` is the small shared canonical-source preflight for native CI and local development. Pages uses its own browser-artifact builder; TestFlight runs the full current validation contract.

It must remain:

- deterministic and safe to rerun;
- representative of the code actually shipped;
- validation-only and responsible for proving the checked-in v0.8.3 source has the required current owners and contracts.

Do not immediately rerun the same deep audits in every workflow. Workflow-specific independent checks should focus on what that workflow uniquely produces, such as the simulator compile or final browser artifact.

## Validation architecture

### iOS Build Check

Runs for changes that can affect the native/shared app, preparation/build scripts, or the iOS CI definition itself.

It should:

- prepare the exact shared source;
- run the full regression audit;
- compile the iOS Simulator build;
- cancel superseded validation for the same workflow/ref;
- avoid triggering merely because an unrelated workflow file changed.

### Publish Web Preview

Runs for changes that affect the browser/WebView runtime, relevant preparation scripts, or the Pages workflow itself.

It should:

- prepare the exact shared source;
- run full regression plus independent web-specific checks;
- build and audit the final browser artifact;
- deploy GitHub Pages;
- avoid replaying or renaming archived historical audits.

### Release Policy Check

Use a small Ubuntu workflow for release-policy/workflow-architecture changes. It owns release-isolation and workflow-efficiency audits so policy documentation or workflow edits do not unnecessarily consume a macOS runner.

## GitHub Actions health preflight

Before attempting to repair a queue problem, follow `GITHUB_ACTIONS_RUNBOOK.md`.

In particular:

- check the official GitHub Status page before making queue-repair commits;
- during a GitHub Actions incident, stop generating replacement runs and keep diagnostics/hardening work off `main`;
- normal cancel is attempted once, then force-cancel once only when GitHub is operational and the run meets the zombie criteria;
- after service recovery, allow backlog to settle and create only one fresh current-main validation per required workflow.

A queued run with no jobs is a scheduler/provider-state problem, not an Xcode or application failure.

## TestFlight release model

LifeRoute uses **explicit-confirmation-only TestFlight release**.

Passing CI does not upload an app. A normal push never uploads an app. A request to continue, launch, build, preview, or fix the app does not imply release authorization.

`testflight.yml` is the only workflow allowed to contain Apple signing/export/upload machinery and remains `workflow_dispatch` only.

### Direct manual release

The product owner may use GitHub's **Run workflow** control for `Send to TestFlight` after explicitly deciding to release.

### Assistant-initiated release

When the product owner explicitly authorizes a release, ChatGPT/Codex may use the guarded owner-authorized release-request bridge.

Before creating that request, ChatGPT/Codex must:

1. re-read current `main`;
2. confirm the required iOS validation is already completed successfully and release-equivalent;
3. confirm the web preview is already completed successfully when the release request requires it;
4. verify GitHub Actions is not in a current outage/degraded state;
5. then create the exact guarded release request.

The release bridge must fail fast when validation is absent; it should not occupy a runner for long periods polling CI.

After dispatch, verify the resulting `Send to TestFlight` run and the exact **Upload to TestFlight** step. Keep the release request open until success/failure has been verified.

## TestFlight signing rules

Repository Actions secrets remain the source for:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`

Never commit private keys/certificates. Routine releases should not require downloading `.p8`/`.p12` files again or using a PC/Mac for certificate work.

The TestFlight workflow serializes release jobs so two ephemeral Macs do not create signing assets at the same time. Temporary signing assets created by the runner should be cleaned up according to `TESTFLIGHT_SETUP.md`.

## Failure handling

For a genuine workflow/app failure:

1. identify the exact failed run/job/step;
2. inspect its logs;
3. distinguish source defect, audit defect, workflow defect, external dependency, Apple signing issue, and provider outage;
4. make one evidence-based targeted fix;
5. validate the replacement run;
6. avoid speculative commit loops.

If the provider itself is degraded, do not treat it as a code-repair cycle.

## Conversation continuity

`LIFEROUTE_HANDOFF.md` is the durable cross-thread state file.

ChatGPT should refresh it after major milestones, release changes, substantial workflow changes, or concluded troubleshooting incidents. It should proactively recommend a clean LifeRoute thread when context-pressure signals described in that file appear, before continuity actually degrades.

The user should not need to paste a long handoff. The new thread opening prompt is:

> Continue LifeRoute from the repository and the current handoff.

The new thread must read the handoff and live repository state before asking the user to repeat prior decisions.

## Manual steps reserved for the product owner

Only require the product owner when an external/legal/security/user-experience boundary genuinely requires it, such as:

- Apple Developer/App Store Connect account creation, legal agreements, renewal/payment, or 2FA prompts;
- initial creation of app/bundle records or repository secrets when tools cannot do so safely;
- explicit TestFlight release authorization;
- installing/testing the build on the physical iPhone;
- product/UX decisions that cannot be safely inferred.

Do not assign PC-side work merely because it is traditional; prefer GitHub/connected-tool automation when safe.

## Short normal loop

**Product owner:** describe change.

**ChatGPT/Codex:** inspect → implement → audit/build → report validated state.

**Product owner:** explicitly authorize TestFlight when desired.

**ChatGPT/Codex:** guarded dispatch → verify upload.

**Product owner:** test on iPhone → report feedback.

Repeat.
