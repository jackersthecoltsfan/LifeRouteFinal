# LifeRoute Control Policy

This file records the current product-owner operating authorization for LifeRoute development. It supplements the historical handoffs and release runbook when older documentation conflicts with this policy.

## Control-center priority

- ChatGPT is the primary LifeRoute control center for planning, repository inspection, implementation, GitHub edits, audits, CI diagnosis, release coordination, and review of screenshots/screen recordings.
- Minimize Codex usage to preserve usage/time limits.
- Use Codex only when local Xcode/Simulator/native execution, local repository tooling, or another capability unavailable from the ChatGPT control conversation is genuinely required.
- Do not hand ordinary GitHub edits, code review, planning, release coordination, or visual diagnosis to Codex merely for convenience.

## TestFlight standing authorization

The product owner grants ChatGPT standing authorization to initiate TestFlight physical-device validation when it materially helps catch issues before further development, subject to all rules below.

1. ChatGPT may autonomously initiate at most **one TestFlight release in any rolling 60-minute window**.
2. Any additional TestFlight release inside that same 60-minute window requires fresh explicit product-owner authorization.
3. The one-per-hour authorization is a ceiling, not a cadence target. Do not release simply because an hour elapsed; release only at a meaningful, validated physical-device checkpoint.
4. Prefer a TestFlight checkpoint when physical-device behavior cannot be proven adequately by deterministic audits, CI, Simulator screenshots, or other lower-cost validation and when discovering a defect early would prevent significant rework.
5. Before an autonomous TestFlight release, require the relevant deterministic preparation/audits and an available iOS compile/build validation for the exact intended source.
6. Preserve exact-SHA/release-source guarding and verify the prior TestFlight state before dispatching a replacement.
7. Never create overlapping TestFlight release jobs. If the previous release state is unclear, resolve it before another release.
8. User-initiated explicit authorization can permit a release that would otherwise be blocked by the one-per-hour assistant limit.

## Branch and release safety

- Do not modify `main` casually. Continue feature/fix work on the active branch until its validation gate is appropriate for merge/release.
- TestFlight physical-validation builds may be intermediate checkpoints and do not imply that a branch is production-ready.
- Preserve recoverable green checkpoints and protected regression contracts.
- A successful upload is not proof of physical-device correctness; incorporate the owner's real-device screenshots or recordings before scaling a visual/runtime architecture.

## Current interpretation

For the v0.7.1 theme-runtime work, ChatGPT should continue fixing and validating through GitHub/CI first. Once the runtime repair reaches a meaningful green checkpoint, ChatGPT may use the standing once-per-hour authorization to start the next TestFlight physical-device validation without asking again, provided no assistant-initiated TestFlight has been started in the preceding 60 minutes. Additional releases within that window require owner approval.
