# ChatGPT Build Repair Automation Template

Use this when a future app should self-heal failed GitHub/TestFlight builds before bothering the user.

## Policy

Check the latest build state on `main`, including:

- iOS Build Check
- automatic TestFlight dispatcher
- TestFlight release workflow when applicable

If successful or still legitimately in progress: **do not notify**.

If failed:

1. Inspect the failed workflow job, failed step, and logs.
2. Identify the most likely root cause.
3. Make a targeted code/workflow fix directly on `main`.
4. First repair commit must contain: `auto-repair 1/2`.
5. Re-check the replacement build on the next monitoring run.
6. If still failing, inspect the new failure and make one more targeted repair.
7. Second repair commit must contain: `auto-repair 2/2`.
8. If still failing after attempt 2, make **no more automatic changes**. Notify the user with:
   - current failing step/error
   - repair 1 summary
   - repair 2 summary
   - what decision/input is now needed
9. If either repair succeeds and reaches TestFlight, notify the user briefly and say which repair attempt succeeded.

## Recommended timing

Use a recurring `condition_watch` at the fastest supported cadence (currently hourly).

## Important guardrails

- Never infer success from an empty GitHub status list.
- Prefer workflow/job/step/log evidence.
- Do not create speculative fixes without reading the failure.
- Do not keep repairing indefinitely.
- Do not notify for a build that is merely queued or legitimately still running.
