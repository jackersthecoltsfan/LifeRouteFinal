# LifeRoute v0.5.1 Handoff

This is the source-of-truth handoff for LifeRoute **v0.5.1**.

Repository: `jackersthecoltsfan/LifeRouteFinal`

Starting branch/source: `main`

Starting release SHA: `5c07b7d1fcfe7c2b031386bdc516230aa353ed3d`

Previous rebuild: `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md`

## v0.5.0 release state

LifeRoute v0.5.0 completed the native functional-core rebuild and was merged into `main` at:

`5c07b7d1fcfe7c2b031386bdc516230aa353ed3d`

Exact merged-main validation passed in GitHub Actions run `33027781669`, including all accumulated audits through Checkpoint 07 and the actual iOS Simulator build.

The owner explicitly authorized the first v0.5.0 TestFlight release. Release request issue `#21` dispatched TestFlight workflow run `#73` / run ID `33028083541` from the exact merged-main SHA. The workflow completed successfully, including:

- exact authorized-SHA verification;
- v0.5.0 functional-core preparation/audit;
- Apple connection validation;
- bundle/version verification;
- real-device archive;
- archived v0.5.0 identity verification;
- signed IPA export;
- **Upload to TestFlight — success**;
- IPA artifact save;
- temporary signing-asset cleanup.

The next release gate is **physical iPhone confirmation of v0.5.0**. CI, Simulator, archive, signing, and TestFlight success are not substitutes for physical interaction testing because v0.4.0 previously passed automated validation while remaining unusable on-device.

## v0.5.1 product intent

v0.5.1 is the first post-rebuild polish release.

Primary intent after physical-device confirmation:

1. preserve the stable native SwiftUI functional architecture from v0.5.0;
2. reintroduce the desired premium LifeRoute visual identity in independent cosmetic layers;
3. improve clarity, hierarchy, responsiveness, accessibility, haptics, motion, and perceived quality without changing functional ownership;
4. keep performance and stability at least as strong as v0.5.0;
5. make every cosmetic slice independently revertible.

Do **not** reactivate the quarantined WKWebView/legacy JavaScript runtime. Do **not** make appearance code responsible for navigation, persistence, provider state, routing, calendar logic, clients, or Session Tools behavior.

## Immediate gate — physical iPhone test of v0.5.0

Before beginning cosmetic implementation, install the processed v0.5.0 TestFlight build on the physical iPhone and perform a focused smoke test.

Minimum physical-device checks:

- app launches normally and remains responsive;
- all primary tabs/navigation controls are tappable;
- buttons do not exhibit the v0.4.0 dead-touch failure;
- Day / Week / Month calendar views navigate and render;
- manual appointments can be created and deleted;
- provider calendar events remain read-only;
- routing/current-location flows open and respond;
- saved places and home address behave normally;
- clients can be viewed/edited as intended;
- Session Tools open and respond;
- client-specific visual supports remain scoped to the correct client;
- persistence survives relaunch for representative native data;
- no obvious freezes, repeated tasks, runaway loading, or severe layout breakage.

If any functional/stability regression appears on the physical device, **v0.5.1 becomes fix-first**. Stop cosmetic work, reproduce the issue, add a focused regression audit where practical, repair it in the smallest native slice, validate, and re-test physically before resuming polish.

## Recommended v0.5.1 branch

After the v0.5.0 physical-device smoke test is green, create a new branch from the exact current validated `main` head, recommended name:

`polish/v0.5.1-ui-foundation`

Do not continue feature work on the old `rebuild/v0.5.0-functional-core` branch.

Before the first v0.5.1 TestFlight candidate, set the shipping marketing version to **0.5.1** while allowing build numbers to continue increasing normally.

## Cosmetic direction

The desired LifeRoute direction is premium, modern, professional, streamlined, elegant, slightly futuristic, and highly legible. The core visual identity should remain **dark blue + gold**, with deeper dark-theme options and a restrained high-end feel rather than visual clutter.

Preserve/reintroduce cosmetic work as separate slices:

1. **Design system foundation**
   - semantic color tokens;
   - dark-blue/gold core palette;
   - typography hierarchy;
   - spacing, corner-radius, elevation/material tokens;
   - reusable button/card/input states;
   - accessibility contrast and Dynamic Type behavior.

2. **App shell + navigation polish**
   - cleaner top-level hierarchy;
   - simpler, sleeker navigation surfaces;
   - selected/unselected states;
   - consistent toolbar treatment;
   - no duplicate navigation owners or cosmetic overlays intercepting touch.

3. **Screen component polish**
   - Today/routing surfaces;
   - Calendar Day/Week/Month;
   - Clients;
   - Session Tools;
   - visual-support library/boards/schedules;
   - Setup/settings.

4. **Icons + imagery**
   - refined vector icon language;
   - consistent sizing/alignment;
   - high-quality thumbnail treatment;
   - retain efficient image decoding/downsampling behavior from v0.5.0.

5. **Themes**
   - categorized themes remain available through a compact selector rather than a full-page wall of options;
   - categories: `Classic`, `Metallic`, `Scenery`, `Dynamic`, `Fluid`, `Living`;
   - include additional dark themes;
   - theme changes must remain presentation-only.

6. **Motion + tactile feedback**
   - subtle page transitions;
   - responsive button press feedback;
   - tasteful microinteractions;
   - haptics where they improve confirmation/navigation;
   - optional restrained sound feedback;
   - respect Reduce Motion and accessibility settings.

7. **Background/effect layers**
   - glass/material treatments;
   - scenery/dynamic/fluid/living backgrounds;
   - effects must be bounded and performance-aware;
   - no persistent animation that materially harms responsiveness or battery life.

8. **Onboarding + final polish**
   - premium onboarding/setup presentation;
   - consistency pass across every screen;
   - accessibility labels/hit targets/contrast;
   - device-size layout review;
   - final performance/stability regression pass.

## Cosmetic checkpoint protocol

Do not implement the entire cosmetic vision in one giant change.

For every v0.5.1 cosmetic slice:

1. start from the last known-good checkpoint;
2. make one clearly bounded appearance change;
3. keep underlying domain/state ownership unchanged unless a narrowly justified bug fix is required;
4. add/update focused executable audits where the slice introduces enforceable invariants;
5. run the accumulated v0.5.0 functional/performance/stability audit suite;
6. compile the actual iOS app on the Simulator runner;
7. inspect the diff for accidental functional changes;
8. preserve the previous checkpoint as an easy recovery point;
9. periodically validate major cosmetic checkpoints on the physical iPhone, especially anything affecting navigation, overlays, gestures, transitions, image-heavy views, or long-running effects.

If a cosmetic slice causes interaction, performance, persistence, or provider regressions, revert that slice rather than patching around it with additional presentation machinery.

## Architectural invariants carried forward from v0.5.0

- Active app remains native SwiftUI.
- `LifeRouteWebView.swift` and `LifeRoute/Web` remain quarantined and out of active target/resources unless a future migration plan is explicitly approved.
- No automatic startup WebKit/localStorage migration reader.
- Native persistence remains authoritative for the rebuilt app.
- Large visual image bytes remain outside repeated whole-snapshot JSON work.
- Persistence writes remain ordered/atomic and off the interaction-critical path as designed in Checkpoint 05A.
- Visual-support lookups retain explicit client ownership and derived indexes.
- Calendar presentation uses derived/indexed data rather than repeated broad scans in render paths.
- Async work remains owned/cancellable with stale-completion guards.
- Provider failures preserve last-known-good data where the v0.5.0 architecture specifies that behavior.
- Calendar provider events remain read-only unless a later product decision explicitly changes that contract.
- Manual appointments remain user-editable/deletable.
- Appearance must never become a dependency for core functionality.

## Release process for v0.5.1

Before any v0.5.1 TestFlight upload:

1. all intended v0.5.1 cosmetic/fix checkpoints are green;
2. accumulated functional/performance/stability audits pass;
3. actual iOS Simulator build passes on the exact candidate SHA;
4. candidate is merged to `main` only with explicit user authorization when a PR is used;
5. exact merged-main validation passes;
6. owner explicitly authorizes the v0.5.1 TestFlight upload;
7. TestFlight workflow uses the exact validated SHA;
8. physical iPhone validation follows the upload.

Do not automatically upload or release merely because CI is green.

## New-thread / Codex start procedure

At the beginning of v0.5.1 work:

1. read `LIFEROUTE_V0_5_1_HANDOFF.md` first;
2. read `AGENTS.md`;
3. read `APP_CREATION_PLAYBOOK.md`;
4. read `GITHUB_ACTIONS_RUNBOOK.md`;
5. read `TESTFLIGHT_SETUP.md` when release/signing work is relevant;
6. consult `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md` for architecture/quarantine history;
7. inspect live `main`, current branch, PRs, and Actions before modifying code;
8. never assume a stale handoff SHA is still current—verify live state first.

## Immediate next action

**Wait for Apple/TestFlight processing if necessary, install v0.5.0 on the physical iPhone, and complete the physical-device smoke test.**

If that test is green, create the v0.5.1 polish branch from the exact current `main` head and begin with the **Design System Foundation** only. Do not start multiple cosmetic layers at once.
