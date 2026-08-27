# LifeRoute Project Handoff

This is the durable LifeRoute thread handoff.

## Current active development

LifeRoute has entered a **v0.5.0 architecture rebuild** after repeated v0.4.0 physical-device failures where buttons remained unusable despite successful CI, Simulator builds, and TestFlight uploads.

Repository: `jackersthecoltsfan/LifeRouteFinal`

Active rebuild branch: `rebuild/v0.5.0-functional-core`

Detailed rebuild handoff: `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`

Current green runtime checkpoint: **06 — stability architecture**, commit `cc2b9c694147378a19e2f27d3148bfc184e8262e`; GitHub Actions run `33026667496` passed all accumulated audits and the actual iOS Simulator build.

At the start of a new LifeRoute thread, read in this order:

1. `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`
2. `AGENTS.md`
3. this file for the active pointer
4. `APP_CREATION_PLAYBOOK.md`
5. `TESTFLIGHT_SETUP.md`
6. `GITHUB_ACTIONS_RUNBOOK.md`
7. relevant files in `ReusableAppWorkflow/`

Then inspect the live rebuild branch and Actions state before modifying code.

## v0.5.0 product decision

v0.5.0 is a controlled rebuild of the active app/runtime architecture from the functional core upward. Do not continue stacking hotfixes onto the v0.4.0 interaction runtime.

The first goal is a minimal, deterministic, high-performance functional core that works reliably on a physical iPhone. Every rebuild layer gets its own checkpoint commit and focused audit so regressions can be traced to the exact layer that introduced them.

The first v0.5.0 TestFlight candidate is a **functionality/performance/stability** build. Full cosmetic richness comes later, after physical-device operability is confirmed.

Apple/TestFlight marketing version must be **0.5.0** for the app and all shipping targets; build numbers may continue increasing normally.

## Appearance preservation

Do not discard the current visual work. Preserve/refactor it as independently enableable cosmetic chunks that sit on top of the rebuilt functional core and are not required for functionality.

Preserve as modular chunks:

- dark-blue/gold core identity;
- refined vector icons;
- categorized Themes (`Classic`, `Metallic`, `Scenery`, `Dynamic`, `Fluid`, `Living`);
- glass/material treatments;
- motion/transitions;
- haptics/sound feedback;
- dynamic/scenery/living effects;
- onboarding/premium polish.

These chunks remain quarantined during the initial functional rebuild and are reintroduced one at a time only after the prior checkpoint works on a physical iPhone. If one breaks functionality, revert only that chunk and return to the last known-good checkpoint.

## Historical release note

The last v0.4.0 hotfix release was TestFlight workflow run #72 / run ID `33013143643`, built from `64b0c2fef3172a101885e9bdaf4eb7860cc41997`. The workflow completed successfully, including `Upload to TestFlight`, but physical-device testing still showed unusable buttons. CI success is therefore not sufficient evidence of interaction correctness for v0.5.0; physical-device checkpoints are mandatory before cosmetics are layered back in.

## Immediate next action

Validate **Layer 7 — second full functionality pass** from the green Checkpoint 06 runtime as defined in `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`.

Require all accumulated audits and an actual iOS Simulator build on the exact Layer 7 runtime SHA. If green, stop for explicit PR #20 merge authorization. Keep TestFlight untouched and do not add cosmetic chunks yet.
