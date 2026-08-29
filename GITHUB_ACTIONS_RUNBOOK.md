# LifeRoute GitHub Actions Runbook

This runbook defines how ChatGPT/Codex should diagnose and recover LifeRoute CI, Pages, and TestFlight workflow problems without creating unnecessary queue pressure or requiring PC access from the product owner.

## First rule: classify the problem before changing the repository

When Actions looks stuck, check these in order:

1. Read the current LifeRoute workflow runs and jobs.
2. Check the official GitHub Status page for **Actions** and **Pages**.
3. Distinguish a GitHub service incident from a LifeRoute workflow failure.

### GitHub service incident

Treat the problem as upstream when the official status page reports Actions degraded/outage, or when GitHub reports a current Actions incident that matches the observed queue behavior.

During an upstream incident:

- Do not create repeated commits just to wake the queue.
- Do not repeatedly dispatch replacement workflows.
- Do not repeatedly send cancel/force-cancel requests to the same run.
- Do not open a TestFlight release request.
- Keep workflow-hardening or diagnostic edits on a non-`main` branch.
- Preserve the exact current `main` SHA and release target.
- Wait for GitHub to report recovery, then allow a short backlog-drain period before taking one recovery action.

A service outage can leave old workflow records visually stuck in `queued` even after a cancellation request was accepted. Those records are not evidence that LifeRoute code is broken.

## Repo-specific stuck-run test

Only treat a run as a LifeRoute-side zombie when all of the following are true:

- GitHub Actions is reported operational.
- The run has remained `queued` or `in_progress` for at least 10 minutes with no meaningful job progress.
- Its `updated_at` has not advanced.
- A normal cancellation was sent once and the run remains unchanged after at least 2 minutes.

If the run has no jobs at all, the problem is before runner execution and should not be debugged as an Xcode/app failure.

## Safe cancellation escalation

Use exactly this escalation order:

1. Normal cancel once: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel`.
2. Wait at least 2 minutes and re-read the run.
3. If GitHub is operational and the run still ignores cancellation, use force-cancel once: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/force-cancel`.
4. Re-read the run. Do not loop cancellation requests.

GitHub documents `force-cancel` specifically for workflow runs that do not respond to normal cancellation. It requires Actions write permission.

If the connected GitHub tool does not expose cancel/force-cancel directly, ChatGPT/Codex may create a temporary, tightly scoped helper workflow on a non-main maintenance branch. The helper must target explicit run IDs, use `actions: write`, perform no release action, and be removed or left off `main` after recovery.

## TestFlight runs require extra care

A TestFlight run is not equivalent to disposable CI once its release job has actually started.

- Do not cancel/retry an actively signing or uploading TestFlight run merely because it is slower than usual; respect the workflow timeout unless there is clear evidence of failure.
- If a stale TestFlight run never created a job and is only a pre-run queue zombie, it can be force-cancelled after GitHub recovers using the normal zombie criteria.
- If cancellation/outage happened after archive/export/upload may have started, first determine whether App Store Connect received the build before dispatching another release. Avoid duplicate uploads and unnecessary build-number consumption.
- Remember that TestFlight cleanup intentionally runs after failures so temporary Apple signing assets can be removed. Force-cancel is an emergency recovery tool, not normal release control.
- Never dispatch a replacement TestFlight run until the prior release state is understood.

## Standing LifeRoute TestFlight authorization

The product owner has granted ChatGPT standing authorization to initiate **one TestFlight physical-validation release in any rolling 60-minute window** when the current checkpoint is meaningfully worth testing and prerequisite validation/release-state checks have passed.

- This standing authorization does not make every commit releasable and does not bypass exact-SHA, CI, signing, or prior-release-state safeguards.
- A second or additional TestFlight initiation inside the same rolling 60-minute window requires explicit owner authorization.
- Explicit owner authorization may direct a specific additional release when needed.
- Standing TestFlight authorization does **not** imply authorization to merge a pull request or modify `main`; merge authority remains separate.

## Recovery after GitHub reports service restoration

1. Wait approximately 5 minutes for GitHub to drain/reconcile backlog.
2. Re-read queued and in-progress LifeRoute runs.
3. Force-cancel only stale runs that still meet the zombie criteria.
4. Do not rerun every historical job.
5. Produce exactly one current iOS validation and, when needed, one current web preview for the intended release source.
6. Verify those current validations before any TestFlight release request.
7. Only then use the standing once-per-hour authorization or a specific owner authorization to initiate TestFlight.

## Prevention rules

### Keep triggers narrow

- iOS CI must not trigger on every `.github/workflows/**` edit.
- iOS CI should run for app/native/shared source, build/preparation scripts, and its own workflow file.
- Release-policy-only audit changes belong to the lightweight policy workflow, not a macOS simulator build.
- Pages should run only for web/runtime sources, build scripts that affect the browser artifact, and its own workflow file.

### Keep expensive work single-owned

`scripts/prepare_build.sh` is a fast validation-only preflight over canonical source. `validate_fast.sh` supplies development feedback and `validate_full.sh` supplies merge/release-grade semantic validation. Pages is independently triggered only by Web preview owners and builds the browser artifact without historical native reconstruction.

### Keep release authorization short-lived

The assistant TestFlight release bridge must not hold a runner for long periods waiting for CI. ChatGPT/Codex should verify completed successful validation first, then create the authorized release request. The bridge should fail fast when required validation is absent.

### Keep TestFlight isolated

- `testflight.yml` remains `workflow_dispatch` only.
- Ordinary pushes never upload to TestFlight.
- The assistant bridge may dispatch `testflight.yml` only after successful release-equivalent validation and either the standing once-per-hour authorization or a specific explicit owner authorization.
- Assistant dispatch passes the exact authorized release SHA; `testflight.yml` refuses a mismatched SHA.
- No other workflow may contain Apple signing secrets or TestFlight upload machinery.

### Avoid queue-amplifying repair behavior

Never use a new commit as the first response to a queue outage. Code changes are appropriate only for a demonstrated workflow/configuration defect. During a GitHub outage, extra pushes create more event records and make the eventual backlog harder to reason about.

## Today’s incident pattern (2026-08-26)

The LifeRoute queue problem coincided with GitHub's official Actions incident beginning at 15:11 UTC. GitHub reported a database-primary problem, a partial failover, inbound throttling, upstream Vitess investigation, and gradual traffic ramp-up. Pages was also degraded. LifeRoute had current validation successfully execute during partial recovery while older queued records remained stale, confirming that the app itself was not the root cause.

This pattern should be recognized immediately in future incidents: check provider status before repeatedly modifying the repository.
