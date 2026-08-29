# LifeRoute v0.7.1 Renderer Architecture Plan

## Status

Engineering design checkpoint for `fix/v0.7.1-theme-runtime-visual-regression`.

This plan is intentionally written before large renderer edits. It translates the approved visual references into an implementation architecture that preserves the v0.7.0 persistence/lifecycle work while replacing the visually failed renderer layer.

## Current runtime trace

The current native theme path is:

1. `LifeRouteThemeStore` owns the persisted selected theme (`liferoute.selectedTheme`).
2. `LifeRouteApp.swift` provides the selected theme/palette into the app environment.
3. The app-wide selected environment is mounted above the five-tab shell and owns the single shared live theme clock.
4. Core themes are static.
5. Dynamic themes are currently rendered as gradients plus `LifeRouteLiquidRibbon`-style geometry.
6. Scenery themes are currently rendered by `LifeRouteSceneryFrame` and procedural geometry such as ridges, dunes, waves, gradients, circles, and related native primitives.
7. `V054ThemeCenterView.swift` uses deterministic/static previews and should remain non-live.
8. `V054TodayView.swift` still presents its own local cinematic/backdrop treatment rather than cleanly exposing the shared root environment.
9. `CinematicThemeViews.swift` contains a separate `LifeRouteCinematicBackdrop`/`AsyncImage` architecture for a limited legacy theme set; it is not an acceptable source of truth for the new 20 explicit Scenery identities and should not compete with the persistent root environment.
10. `scripts/prepare_build.sh` remains the canonical deterministic materialization path, so v0.7.1 source changes must be represented in the patch/audit chain rather than relying on edits that preparation can overwrite.

## Root cause

The failure is primarily architectural, not a tuning problem.

### Scenery

Procedural SwiftUI geometry is being asked to manufacture cinematic landscape photography/illustration. It can provide ambient motion and compositing, but it cannot reasonably produce the terrain detail, atmospheric depth, natural lighting, and strong Day/Night identity in the approved references.

### Dynamic

The current renderer uses small/faint mathematical ribbons as the hero visual. The approved references instead use broad layered translucent forms with bright edges, internal highlights, refraction-like depth, and full-frame composition.

### Today

Today visually competes with the root environment by adding a local backdrop and surfaces that are too opaque. This hides the theme rather than making the interface feel suspended within it.

## Corrected architecture

### 1. One persistent root environment remains authoritative

Do not add another clock or per-screen live renderer.

`LifeRouteLiveThemeEnvironment` remains the single live visual owner. It receives the selected theme and one root phase value. Core remains still. Dynamic and Scenery consume that shared phase only when selected.

Reduce Motion and inactive/background lifecycle continue to freeze the shared phase.

### 2. Scenery becomes bundled-asset-backed

The base Scenery scene should be a high-detail, source-controlled image asset for each explicit Day/Night identity.

Target catalog:

- 20 bundled scene assets, one per existing Scenery theme identity;
- no network dependency for the base selected environment;
- no `AsyncImage` or remote URL required for the live Scenery background;
- deterministic local availability after install;
- full-screen `scaledToFill` composition with theme-specific focal positioning where necessary.

SwiftUI remains responsible for restrained ambient overlays only, for example fog/cloud translation, water shimmer, aurora glow, lava bloom, atmospheric light, and subtle parallax. The static asset itself must already meet visual quality when motion is frozen.

### 3. Prove one Scenery exemplar before catalog rollout

First exemplar: **Canyon — Day**.

Acceptance target:

- realistic/high-detail canyon walls rather than polygons;
- strong warm daylight and atmospheric depth;
- image remains excellent with Reduce Motion enabled;
- subtle ambient light/haze movement when motion is enabled;
- root environment remains the only live owner;
- Theme Center thumbnail remains static.

Only after Simulator screenshot validation should the same asset-backed renderer contract be expanded to the other 19 Scenery identities.

### 4. Dynamic becomes a broad layered glass composition

Dynamic themes should use a shared renderer that draws a small number of large, stable layers rather than many independent animated objects.

Recommended structure:

- deep theme-specific base gradient;
- 2–4 broad translucent flowing glass forms occupying large portions of the screen;
- luminous edge/highlight layers offset from the body forms;
- blurred internal glow and caustic-like highlight bands;
- controlled blend modes and opacity to create depth;
- phase-driven slow transforms/shape deformation from the one root clock;
- no per-layer timers;
- no extra `TimelineView` instances.

On iOS 26+, native Liquid Glass APIs should be used for interface surfaces where appropriate, but the Dynamic background should not depend on `glassEffect` alone to create its artwork. The visual forms need to remain intentionally composed as background art.

### 5. Prove one Dynamic exemplar before catalog rollout

First exemplar: **Royal Current**.

Acceptance target:

- full-frame deep royal blue base;
- large luminous gold/white glass-current structures;
- clear depth and layered highlights;
- motion visibly perceptible within several seconds but not distracting;
- still frame remains premium with Reduce Motion enabled;
- no additional clock/timer ownership.

After Royal Current visually passes, reuse the renderer architecture for Midnight Prism, Aurora Bloom, Solar Pulse, Emerald Flow, Arctic Halo, Ocean Glass, Rose Ember, Obsidian Spectra, Plasma Orchid, Verdant Mist, and Titanium Glow through theme-specific palettes/composition parameters.

### 6. Today becomes environment-transparent

Today should not own a second selected-theme background.

The root selected environment should remain visible through the Today screen. Today should contain foreground content and restrained glass surfaces only.

Requirements:

- preserve split `Life` white + `Route` gold wordmark;
- remove/retire the competing local Today backdrop path;
- no square LR mark in the Today hero;
- quick actions use restrained translucent/native glass treatment;
- Overview, Gap Fillers, and Live Day use transparency levels that maintain readability while exposing the environment;
- preserve all selected-day events in Overview (`ForEach(selectedDayEvents)` behavior);
- preserve horizontal selected-day navigation and all existing actions.

On iOS 26+, grouped interactive surfaces should prefer native `GlassEffectContainer`, `glassEffect`, and glass button styles with availability-safe fallback materials.

## Performance constraints

The renderer should remain simple in ownership even when visually rich.

- exactly one shared live clock in the theme runtime;
- no simultaneous animation work for unselected themes;
- no live Theme Center thumbnails;
- no network image loading for selected Scenery scenes;
- keep large images asset-catalog managed and device-appropriate;
- avoid expensive derived work in SwiftUI `body`;
- use stable view identity and a stable root tree;
- avoid broad state invalidation from unrelated app state;
- profile only after visual correctness is achieved.

## v0.7.1 patch-chain plan

Introduce a focused authoritative pair after confirming exact materialization insertion points:

- `scripts/patch_v0_7_1_theme_visual_runtime_fix.py`
- `scripts/audit_v0_7_1_theme_visual_runtime_fix.py`

The patch should own only the theme renderer/Today visual composition and required asset references. It must not own calendar, routing, persistence, client, timer, Live Activity, AppIcon, or unrelated domain files.

The audit should verify at minimum:

- 12 Core identities remain;
- 12 Dynamic identities remain;
- 20 Scenery identities remain;
- one `LifeRouteThemeStore` owner;
- one shared live `TimelineView`/clock;
- Core remains non-live;
- Theme Center remains static;
- Scenery live base uses bundled assets rather than procedural ridge/dune/wave as the primary scene;
- no `AsyncImage`/remote network dependency in the live Scenery renderer;
- Royal Current uses the new broad layered Dynamic renderer contract;
- Today does not mount a competing `LifeRouteCinematicBackdrop`;
- Today retains the split wordmark and full selected-day agenda;
- Reduce Motion/lifecycle clock pausing remains intact;
- protected functional owners are untouched.

## Visual validation gates

### Gate A — Canyon Day

Do not proceed to all Scenery themes until the Simulator screenshot clearly resembles the approved cinematic Scenery direction.

### Gate B — Royal Current

Do not proceed to all Dynamic themes until the Simulator screenshot clearly resembles the approved layered liquid-glass direction and the motion is visibly perceptible.

### Gate C — Today

Test Today once with Canyon — Day selected and once with Royal Current selected. The root environment must visibly read through the interface while foreground content remains legible.

Only after A/B/C pass should the implementation scale to the complete catalog.

## Release protection

No TestFlight upload is authorized by this plan or by the v0.7.1 debugging work itself. Build #96 remains the rollback release baseline until the user explicitly authorizes a new TestFlight build.
