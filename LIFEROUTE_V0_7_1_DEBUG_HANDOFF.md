# LifeRoute v0.7.1 Debug Build Handoff

## Intermediate TestFlight physical-validation milestone — 2026-08-28

The exact validated exemplar checkpoint was uploaded successfully for intermediate physical-iPhone validation without merging or modifying `main`.

- Release source branch: `fix/v0.7.1-theme-runtime-visual-regression`
- Exact release SHA: `fd7638f8d811b3821e7c6b85c1b81ed39070e81c`
- Exact validated implementation parent: `01fdde591a52e3a2774dfd95458e92f81a0de136`
- Fresh pre-release iOS Build Check: run `878`, ID `33192461705` — successful
- TestFlight workflow: run/build `97`, ID `33193336126` — successful
- Apple upload result: `UPLOAD SUCCEEDED with no errors`
- Apple delivery UUID: `4281365a-cc62-45eb-8e8f-6322cb1d8a36`
- Archived/TestFlight identity: LifeRoute `0.7.0 (97)` plus the matching Live Day extension

The unchanged canonical TestFlight workflow still sets `RELEASE_MARKETING_VERSION` to `0.7.0`; therefore this v0.7.1 exemplar code checkpoint appears in TestFlight as marketing version `0.7.0`, Build `97`. The code and assets are the exact v0.7.1 exemplar checkpoint described below; no version-label or release-workflow change was introduced after validation.

Before release, run 878 replayed canonical preparation, the complete historical audit chain, the focused v0.7.1 theme-runtime audit, the protected-regression audit, the actual iOS Simulator build, and all four exemplar launches/captures. The TestFlight workflow then replayed canonical preparation/audits again, passed the exact-SHA guard and release contract, produced and verified the signed generic-device archive, exported the IPA, uploaded it to Apple, saved the short-lived IPA artifact, and cleaned the temporary Apple signing asset created by the run.

The remaining Dynamic and Scenery themes remain intentionally unexpanded. The next gate is physical-iPhone validation of Canyon — Day, Royal Current motion, Today using each exemplar, persistence/tab switching, Reduce Motion, lifecycle/background behavior, readability, responsiveness, timer/Live Activity protection, and absence of theme flashes or competing clocks.

## Exemplar validation milestone — 2026-08-28

The corrected theme-runtime architecture has passed the deliberately narrow four-exemplar gate. Do not interpret this milestone as validation of the remaining Dynamic or Scenery catalog.

- Validated branch: `fix/v0.7.1-theme-runtime-visual-regression`
- Validated code SHA: `01fdde591a52e3a2774dfd95458e92f81a0de136`
- Required Codex-first workflow commit `d91e40b272dda0d19dbcf38aa335ef01dc38ab6e` is an ancestor of the validated SHA.
- GitHub Actions Simulator run: `33190020502`
- Screenshot artifact: `liferoute-v0.7.1-visual-fixtures` (`9693594790`)
- Artifact digest: `sha256:23e61fddc6e104181b20445194aeeaa7077e500c85773e41c40ce03a484e5af0`

The run passed canonical preparation, the accumulated historical audits, the focused v0.7.1 theme-runtime audit, the protected-regression audit, an actual iOS Simulator build, four app launches, and four screenshot captures. Simulator visual inspection passed:

1. Canyon — Day
2. Royal Current
3. Today using Canyon — Day
4. Today using Royal Current

The approved exemplar architecture is asset-backed and source-controlled. Canyon and Royal Current each use a reference-quality hero asset with restrained motion/compositing driven by the existing single root live-theme phase. Theme Center previews remain deterministic, Reduce Motion and lifecycle pausing remain intact, and no local Today timer or competing background owner was added. Today reuses the same production exemplar artwork within a constrained hero canvas, preserving the split white/gold wordmark, semantic quick actions, selected-day paging, and full selected-day agenda behavior. Native iOS 26 glass effects retain availability-safe material fallbacks.

All implementation changes live in the authoritative patch/audit/preparation chain; generated materialized Swift output was not committed as a competing source of truth. The Simulator fixture harness defines its debug compilation condition explicitly and validates app liveness and screenshot output before upload.

The remaining themes have intentionally not been scaled. No TestFlight upload was performed, and `main` was not modified. The next implementation step is to expand only from this proven architecture, followed by the broader representative sweep and physical-iPhone regression described below.

## Purpose

This handoff starts a clean LifeRoute v0.7.1 debugging build focused on correcting the failed visual/runtime implementation of Dynamic and Scenery themes and restoring Today/welcome-screen visual parity with the approved references.

This is a fix-first engineering thread. Do not continue stacking new cosmetic phases until this debugging build is visually and functionally green.

## Repository / branch / baseline

Repository: `jackersthecoltsfan/LifeRouteFinal`

Current `main` at handoff creation:

`4d30c9949515b324d4425393337afc01ede3b485`

Successful v0.7.0 TestFlight release:

- Version: LifeRoute v0.7.0
- TestFlight Build: #96
- Exact release SHA: `4d30c9949515b324d4425393337afc01ede3b485`
- TestFlight workflow run: `33146676283`
- Release checkpoint: `checkpoint/v0.7.0-phase-3-testflight-96`
- Pure Phase 3 app/source checkpoint before release-workflow-only fixes: `a59062befde909da834d8862b1202aa137a13f91`

Dedicated v0.7.1 debugging branch already exists:

`fix/v0.7.1-theme-runtime-visual-regression`

It currently points to the exact v0.7.0 Build #96 release SHA:

`4d30c9949515b324d4425393337afc01ede3b485`

No v0.7.1 source implementation has been committed yet. The only intended change at handoff time is this documentation file.

## Why v0.7.1 exists

Physical-iPhone screenshots showed that the Theme system is technically wired but visually wrong.

### Scenery failure

The 20 Scenery identities exist and persist, but the renderer is procedural SwiftUI geometry (`LifeRouteSceneryRidge`, `LifeRouteSceneryDune`, `LifeRouteSceneryWave`, gradients, circles, etc.). That produces flat symbolic landscapes rather than the detailed cinematic scenes shown in the approved reference images.

The current Scenery motion signatures are also extremely slow, making ambient motion difficult or impossible to perceive on-device.

The result: Mountains/Ocean/Desert/etc. are identifiable only as simplified shapes and colors, not as the premium Day/Night environments the user approved.

### Dynamic failure

The 12 Dynamic identities exist and share a root TimelineView, but the visual implementation is mostly moving gradients plus `LifeRouteLiquidRibbon` shapes. Later opacity/illumination repairs increased visibility but did not change the underlying visual architecture.

The result: Dynamic themes read as dark fields with faint moving ribbons rather than the luminous layered liquid-glass compositions shown in the reference gallery.

### Today / welcome-screen mismatch

The Today hero still owns a local `LifeRouteCinematicBackdrop` composition and several opaque card surfaces. It does not visually match the approved preview where the selected app-wide environment remains visible behind the interface and the UI floats over it.

The approved Today direction is the split `Life` white + `Route` gold wordmark, cinematic selected environment, restrained glass quick actions/cards, and a clean premium hierarchy. Do not reintroduce the square LR brand mark into the Today hero.

The Today Overview must continue showing every appointment/event for the selected day, not only the next event.

## Approved visual references

The reference images supplied by the user are acceptance targets, not loose inspiration.

### Scenery reference set

10 families × explicit Day/Night = 20 selectable environments:

1. Mountains — Day / Night
2. Ocean — Day / Night
3. Desert — Day / Night
4. Alpine — Day / Night
5. Rainforest — Day / Night
6. Grassland — Day / Night
7. Volcanic — Day / Night
8. Canyon — Day / Night
9. Arctic — Day / Night
10. Coastal Cliffs — Day / Night

The approved visual standard includes detailed cinematic terrain, atmosphere, lighting, depth, environmental identity, and unmistakable Day/Night separation.

### Dynamic reference set

12 premium Dynamic Liquid Glass themes:

1. Royal Current
2. Midnight Prism
3. Aurora Bloom
4. Solar Pulse
5. Emerald Flow
6. Arctic Halo
7. Ocean Glass
8. Rose Ember
9. Obsidian Spectra
10. Plasma Orchid
11. Verdant Mist
12. Titanium Glow

The approved visual standard includes large luminous glass forms, layered depth, flowing highlights, refraction, glow, strong theme-specific color identity, and clearly perceptible elegant motion.

### Core reference set

Keep the 12 approved still Core Glass themes working. v0.7.1 is not permission to regress or replace them.

## v0.7.1 implementation direction

Treat this as a renderer-architecture correction, not another opacity tweak.

### Scenery architecture

Do not attempt to recreate detailed landscape photography using a handful of SwiftUI polygons/shapes.

The detailed visual scene should be the hero visual layer. Use scene artwork / high-detail visual assets or another architecture capable of matching the approved references, then layer restrained native animation/compositing over it where appropriate:

- cloud/fog drift;
- water shimmer/wave movement;
- aurora movement;
- fire/lava glow;
- atmospheric light drift;
- subtle parallax/depth;
- lighthouse/glow effects where relevant.

The scene itself must remain visually rich and recognizable even when Reduce Motion freezes animation.

### Dynamic architecture

Replace the current faint-ribbon look with a richer full-frame liquid-glass composition. Dynamic themes should visibly resemble the approved gallery: broad translucent structures, luminous edges, layered curves, highlights, refraction, depth, and unmistakable theme-specific motion.

Do not solve this by merely increasing opacity on the existing small ribbons.

### Root ownership

Preserve the good architecture already achieved:

- one `LifeRouteThemeStore` persistence owner;
- one persistent app-wide environment above the five-tab shell;
- one shared root live-theme clock for the selected live environment only;
- no 20 simultaneous Scenery timelines;
- Theme Center thumbnails remain deterministic/static;
- Reduce Motion freezes the live visual state;
- inactive/background lifecycle pauses live work;
- selected theme remains mounted across tab/navigation changes.

Improve the renderer without regressing those properties.

### Today / welcome screen

Today should reveal and use the same selected environment as the rest of the app instead of presenting a competing local mini-backdrop.

Target composition:

- `Life` in white + `Route` in gold;
- selected scenery/dynamic/core environment visible as the visual canvas;
- premium restrained glass surfaces over the environment;
- quick actions, overview, gap fillers, and Live Day remain legible;
- Today hero should visually resemble the approved reference image rather than the current opaque teal-card composition;
- preserve selected-day paging and full selected-day agenda behavior.

## Functional areas that are protected

Do not change these unless a regression requires a tightly scoped fix:

- five-tab shell: Today / Schedule / Tools / Resources / Setup;
- `AppRouter` / `openSettings`;
- canonical horizontal selected-day swipe;
- calendar services and selected-day state;
- routing/location behavior;
- clients and ABA tools;
- persistence contracts;
- saved places / gap filler behavior;
- Live Day / Live Activity synchronization;
- timer behavior and cadence;
- official AppIcon identity;
- native-source ownership under `LifeRoute/`;
- quarantined legacy WebView runtime;
- deterministic `scripts/prepare_build.sh` materialization.

Native/TestFlight behavior remains higher priority than the legacy web preview.

## Build / audit requirements

Do not call v0.7.1 fixed because it compiles.

### Deterministic regression

Keep accumulated historical audits green and add focused v0.7.1 audits for the new renderer architecture where practical.

Run canonical preparation through `scripts/prepare_build.sh`.

Run an actual iOS Simulator compile before merge.

After merge, re-run merged-main validation and a second actual Simulator compile, following the repository checkpoint pattern.

### Visual regression gate

Visual correctness is now an explicit acceptance criterion.

For representative reference themes, produce Simulator screenshots and compare them to the approved visual references before declaring success.

Minimum representative gate before full sweep:

1. Canyon — Day
2. Arctic — Night
3. Rainforest — Day
4. Mountains — Night
5. Grassland — Day
6. Royal Current
7. Midnight Prism
8. Aurora Bloom
9. Ocean Glass
10. Obsidian Spectra
11. Today screen using a Scenery theme
12. Today screen using a Dynamic theme

If a renderer compiles but still resembles the failed Build #96 screenshots instead of the approved references, the visual test fails.

### Physical iPhone regression

After Simulator/audit success, physical-device QA must cover:

- all 20 Scenery identities visibly distinct;
- Day/Night unmistakably distinct;
- all 12 Dynamic identities visually distinct;
- Dynamic motion clearly visible but restrained;
- Scenery ambient motion visible where intended;
- Reduce Motion freezes the scene;
- Core remains still and correct;
- selected theme persists after relaunch;
- selected environment does not reset when switching tabs;
- leaving/re-entering Theme Center does not reset it;
- background/resume remains clean;
- no flashes to another theme;
- no competing clocks;
- Today uses the selected environment correctly;
- all selected-day events still appear;
- route/open-current-location flows still work;
- timer survives backgrounding;
- Live Activity remains synchronized;
- light/day themes remain readable;
- dark/night themes remain readable;
- repeated switching/scrolling remains responsive;
- no obvious heat/battery spike.

## Existing technical debt to avoid disturbing during this debug build

The retained `scripts/audit_v0_7_0_testflight.py` still contains stale Phase-2-era language. The active TestFlight workflow behavior is Phase-3-aware, and historical compatibility comments were intentionally retained so release remained deterministic.

Do not casually rewrite that release audit during visual debugging. Keep v0.7.1 focused on app rendering and regression unless release validation actually requires a separate fix.

## Release rule

Do not upload another TestFlight build without new explicit authorization from the user for the v0.7.1 release.

The successful Build #96 checkpoint remains the rollback baseline.

## Codex-first engineering workflow

For v0.7.1 and future substantial native LifeRoute work, use a Codex-first execution model rather than treating this chat as the primary coding surface.

### Responsibility split

**Codex is the primary implementation engine.** Use it for:

- repository inspection and code tracing;
- authoritative patch-chain edits;
- SwiftUI implementation and refactoring;
- deterministic audit updates;
- `prepare_build.sh` materialization;
- actual Simulator compilation;
- Simulator launch and UI interaction;
- screenshot capture and visual iteration;
- code-first SwiftUI performance review;
- profiling/ETTrace work when visual correctness is already achieved;
- PR preparation and exact validated-head handoff.

**The ChatGPT LifeRoute engineering thread is the control room.** Use it for:

- product and architecture decisions;
- interpreting reference artwork as acceptance criteria;
- reviewing Codex checkpoints and Simulator screenshots;
- deciding whether a milestone is visually credible;
- preserving release rules and protected functionality;
- approving progression from exemplar work to full rollout;
- deciding when TestFlight authorization is appropriate.

Figma, Canva, and image generation may support the asset/design pipeline, but they should feed source-controlled assets and clear implementation specs into the native Codex workflow rather than becoming parallel implementation paths.

### Codex gating model

Do not ask Codex to implement all 32 live theme variants before proving the corrected architecture.

Use these gates:

1. Trace the current materialized theme runtime end-to-end.
2. Implement one representative Scenery exemplar to reference quality.
3. Compile and visually validate that exemplar in Simulator.
4. Implement one representative Dynamic exemplar to reference quality.
5. Compile and visually validate that exemplar in Simulator.
6. Validate Today with the selected Scenery exemplar and Dynamic exemplar using the shared root environment.
7. Only after those three visual gates pass, scale the proven renderer architecture across the remaining theme identities.
8. Run full deterministic regression and representative screenshot sweep.
9. Run performance review/profiling only after visual correctness is established.

A successful compile is only an intermediate signal. Codex should continue automatically through screenshot capture and visual comparison for any milestone whose acceptance criteria are visual.

### Reasoning setting

Keep Codex at Extra High for this v0.7.1 renderer/debugging work. Do not raise it further unless repeated serious debugging attempts leave a genuinely unresolved problem.

## Recommended execution order

1. Inspect the fully materialized current source and trace background ownership end-to-end.
2. Design the corrected renderer architecture before editing.
3. Fix Scenery visual architecture first using the approved reference set.
4. Fix Dynamic visual architecture second using the approved reference set.
5. Rework Today/environment composition for preview parity without changing Today domain behavior.
6. Add focused v0.7.1 renderer/visual-regression contracts.
7. Run canonical regression audits.
8. Run actual Simulator compile.
9. Capture representative screenshots and compare to references.
10. Fix remaining visual gaps.
11. Open PR only when the branch is functionally and visually credible.
12. Merge exact validated head and revalidate merged main.
13. Physical-iPhone QA.
14. Ask for explicit TestFlight authorization only after QA is ready.

## Codex / reasoning setting

The user has raised Codex reasoning above High to Extra High (not Max) for this debugging build. That is appropriate for the architecture/debugging work. Do not ask the user to raise it further unless repeated serious attempts reveal a genuinely unresolved reasoning/debugging problem.

## Clean restart prompt

Use this in a new engineering chat:

`@GitHub @Build iOS Apps @SwiftUI Expert Continue LifeRoute as v0.7.1 debugging from LIFEROUTE_V0_7_1_DEBUG_HANDOFF.md in jackersthecoltsfan/LifeRouteFinal. Use branch fix/v0.7.1-theme-runtime-visual-regression starting from exact v0.7.0 TestFlight Build #96 SHA 4d30c9949515b324d4425393337afc01ede3b485. The priority is to replace the failed procedural Scenery and faint Dynamic renderer architecture so the real app visually matches the supplied approved theme reference images, then restore Today/welcome-screen reference parity and run full functional + visual regression. Use the Codex-first workflow in the handoff: prove one Scenery exemplar, one Dynamic exemplar, and Today with both before scaling to the full theme catalog. Do not upload TestFlight without fresh explicit authorization.`
