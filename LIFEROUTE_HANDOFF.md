# LifeRoute Project Handoff

## Non-shipping v0.7.1 theme-library branch complete — 2026-08-28

The isolated branch `feature/v0.7.1-theme-library-finish-codex`, based exactly on physically validated Build #98 SHA `00f98f4cade1b6cb14ce65d3b62203c0efda4ef2`, now contains the finished retained library: 8 Dynamic themes and 12 Scenery identities. The implementation code at `d56ed5deebf084703927964fe714e7faad2de444` passed deterministic preparation, Xcode Simulator build, the complete Today/Schedule fixture matrix, all Dynamic motion comparisons, all Scenery Day/Night comparisons, all Reduce Motion stills, full-background coverage, and title-position OCR in GitHub Actions run `33217191235`.

Detailed branch handoff: `LIFEROUTE_V0_7_1_THEME_LIBRARY_CODEX_HANDOFF.md`.

This experimental branch is not merged, did not trigger TestFlight, and does not supersede the active product/release pointer below. The main LifeRoute thread should selectively cherry-pick the implementation after reconciling its newer product work.

## Current v0.7.1 intermediate physical-validation build — 2026-08-28

The validated v0.7.1 theme-runtime exemplar checkpoint was uploaded successfully to TestFlight from `fix/v0.7.1-theme-runtime-visual-regression` without modifying `main`.

- Exact release SHA: `fd7638f8d811b3821e7c6b85c1b81ed39070e81c`
- Validated implementation SHA: `01fdde591a52e3a2774dfd95458e92f81a0de136`
- Fresh iOS validation: run `878`, ID `33192461705` — successful
- TestFlight release: Build `97`, run ID `33193336126` — upload successful
- TestFlight identity: LifeRoute `0.7.0 (97)` because the unchanged existing workflow still supplies marketing version `0.7.0`
- Detailed active handoff: `LIFEROUTE_V0_7_1_DEBUG_HANDOFF.md`

Only Canyon — Day, Royal Current, Today using Canyon — Day, and Today using Royal Current are approved and included as v0.7.1 renderer exemplars. Do not scale the remaining themes until Build 97 completes the physical-iPhone validation gate recorded in the active handoff.

This is the durable LifeRoute thread handoff.

## Current active development

LifeRoute v0.5.0 completed the native functional-core rebuild, passed exact merged-main validation, and uploaded successfully to TestFlight.

Repository: `jackersthecoltsfan/LifeRouteFinal`

v0.5.0 merged release SHA: `5c07b7d1fcfe7c2b031386bdc516230aa353ed3d`

v0.5.0 exact-main iOS validation: GitHub Actions run `33027781669` — green, including all accumulated audits through Checkpoint 07 and the actual iOS Simulator build.

v0.5.0 TestFlight release: workflow run `#73` / run ID `33028083541` — completed successfully, including archive, signed IPA export, and Upload to TestFlight.

Current handoff: `LIFEROUTE_V0_5_1_HANDOFF.md`

Control-chat handoff: `LIFEROUTE_CODEX_CONTROL_CHAT_HANDOFF.md`

At the start of a new LifeRoute development thread, read in this order:

1. `LIFEROUTE_V0_5_1_HANDOFF.md`
2. `LIFEROUTE_CODEX_CONTROL_CHAT_HANDOFF.md`
3. `AGENTS.md`
4. this file for the active pointer
5. `APP_CREATION_PLAYBOOK.md`
6. `GITHUB_ACTIONS_RUNBOOK.md`
7. `TESTFLIGHT_SETUP.md` when release/signing work is relevant
8. `LIFEROUTE_V0_5_0_REBUILD_HANDOFF.md` when architecture/quarantine history matters
9. relevant files in `ReusableAppWorkflow/`

Then inspect live `main`, the current development branch, PRs, and Actions before modifying code.

## Current release gate

The immediate gate is **physical iPhone validation of the uploaded v0.5.0 TestFlight build**.

CI/Simulator/TestFlight success is not enough by itself because the v0.4.0 runtime previously passed automated validation while physical-device buttons remained unusable.

Minimum physical confirmation should cover launch, primary navigation/taps, calendar Day/Week/Month, manual appointment create/delete, routing/location, saved places/home address, clients, Session Tools, client-specific visual supports, representative persistence after relaunch, and absence of obvious freezes or runaway loading.

If v0.5.0 has a physical-device functional or stability regression, v0.5.1 becomes fix-first and cosmetic work pauses until the device is green again.

## v0.5.1 direction

Once v0.5.0 is physically confirmed, v0.5.1 becomes the first post-rebuild polish release.

The desired direction is premium, modern, professional, streamlined, elegant, slightly futuristic, and highly legible, with the dark-blue/gold LifeRoute identity preserved.

Cosmetics must be reintroduced as independent, revertible layers rather than one giant rewrite:

- design-system foundation;
- app shell/navigation polish;
- screen component polish;
- refined vector icons and imagery;
- categorized Themes (`Classic`, `Metallic`, `Scenery`, `Dynamic`, `Fluid`, `Living`) with additional dark options;
- glass/material treatments;
- motion/page transitions/button press feedback;
- haptics and restrained sound;
- scenery/dynamic/fluid/living backgrounds;
- onboarding and final premium/accessibility polish.

Appearance must never own or become required for navigation, calendar behavior, routing, persistence, providers, clients, Session Tools, or visual-support data.

## Architecture carried forward

Do not return to v0.4 interaction-hotfix layering.

Keep the active app native SwiftUI. Keep `LifeRouteWebView.swift` and `LifeRoute/Web` quarantined and outside the active runtime. Do not add an automatic startup WebKit/localStorage migration reader. Preserve the v0.5.0 performance/stability architecture, including ordered persistence, external visual image blobs, visual indexes/downsample behavior, calendar presentation indexes, owned/cancellable async work, stale-completion guards, and provider-failure preservation.

## v0.5.1 checkpoint rule

Every cosmetic/fix slice gets a clearly bounded checkpoint, accumulated v0.5.0 functional/performance/stability audits, an actual iOS Simulator build, diff review for accidental functional changes, and a recoverable prior checkpoint.

Anything affecting navigation, overlays, gestures, transitions, image-heavy views, or persistent animation should also receive physical-iPhone confirmation before stacking more risky cosmetic layers.

## Immediate next action

Install the processed **v0.5.0 TestFlight** build on the physical iPhone and complete the smoke test described in `LIFEROUTE_V0_5_1_HANDOFF.md`.

If green, create a new v0.5.1 polish branch from the exact current `main` head, recommended name `polish/v0.5.1-ui-foundation`, and begin with **Design System Foundation only**.
