# Living Themes — Phase 2A

The current product family is **Living Themes**: twelve Scenic Royal identities.
Rainforest Day, Ocean Day and Ocean Night have implemented environmental motion.
The remaining nine are explicitly **Motion pending** and keep fixed scenery.
Implementation/GPU evidence is not physical acceptance. Brandon accepted the
Rainforest Day parent `9494e81c814d6cbe958dc190263d8fec141cdb27` on iPhone 17 Pro /
iOS 27.0; the Phase 2A candidate requires his new regression and Ocean review.

## Registry and retirement

`LivingThemeRegistration.all` records each exact persisted identity, family,
Day/Night variant, selected program (or pending status) and common policies.
`LifeRouteTheme.livingThemeCatalog` exposes the twelve; Core retains its twelve
still choices. Theme Center shows individual motion readiness without claiming
that the whole catalogue has completed Living motion.

The original eight Dynamic Themes are retired. Their fixed Scenic companions
already used by the accepted parent define the migration:

| Retired ID | Current ID |
| --- | --- |
| dynamic.royalCurrent | scenery.mountains.night |
| dynamic.midnightPrism | scenery.mountains.night |
| dynamic.auroraBloom | scenery.arctic.night |
| dynamic.solarPulse | scenery.desert.night |
| dynamic.emeraldFlow | scenery.rainforest.night |
| dynamic.oceanGlass | scenery.ocean.night |
| dynamic.obsidianSpectra | scenery.mountains.night |
| dynamic.plasmaOrchid | scenery.canyon.night |

`LifeRouteThemeStore` remains the sole persistence owner and retains
`liferoute.selectedTheme`. Existing aliases first resolve through their established
mapping, then retire to a current identity. The old `arcticPulse` alias explicitly
preserves Mountains Night, the environment previously displayed by its Royal
Current fallback. Unknown inputs retain the existing Core Royal fallback.
A changed stored identity is saved once; reopening a canonical selection does not
write again. Current taps publish once. Direct legacy assignments normalize before
persistence. Tests exercise actual store instances against isolated UserDefaults.

Dormant compatibility code is retained for Phase 2D reconciliation: legacy enum
identities/palettes, Dynamic motion signatures and frame/environment types in
`LifeRouteApp.swift`, `scenicRoyalDynamicSceneryTheme` and style cases in
`ScenicRoyalThemeBridge.swift`, eight Dynamic thumbnails/mappings, the
`DynamicRoyalCurrent` artwork, and historical cinematic fallback types in
`CinematicThemeViews.swift`. Quarantined `ContentView.swift`, `LifeRouteWebView.swift`
and `LifeRoute/Web/` remain outside the shipping source set. No active Living
branch invokes Dynamic or historical generic scenery motion. DEBUG fixtures no
longer admit retired Dynamic raw identities; the historical `royal-current`
fixture names its migrated Mountains Night scenery.

## Environmental programs

Both programs use one opaque Metal triangle over the existing fixed artwork.
The accepted Rainforest shader remains byte-for-byte unchanged: descending
waterfall advection, winding downstream flow, local spray and four gently flexing
leaf clusters. Fixed trunks, rock banks and camera retain their exact normal-mode
pixels. No new fog/rain refinement was added.

The Ocean photographs are both 941 × 1672 and show open water without exposed
shore, rocks or buildings. Day's horizon is approximately y=.303; Night's is .335.
The shared `livingOceanFragment` uses configured horizons, crest slope/position,
shallow-water attenuation and night reflection position. Perspective-compressed
wave phases propagate toward the viewer, with crossing ripples, small local
refraction and crest heave. Day preserves recognizable seabed forms with
subpixel foreground refraction and modulates existing bright crest material.
Night moves water outside the moonlit corridor as well as the reflected light
on that same surface. Sky, moon and horizon remain fixed. No stars/particles are
needed, and no beach surf is invented where the artwork has none.

Both fragments reside in the existing `LivingRainforest.metal` compilation unit;
the original Rainforest prefix and 32-byte primary uniform ABI are preserved.
Ocean alone uses its explicit 32-byte geometry/lighting buffer. Day/Night share
the physical model rather than independent engines.

## Ownership and lifecycle

`LifeRouteApp` → `LifeRouteThemeStore` remains the selection authority.
`lifeRouteChrome` → `ScenicRoyalEnvironmentHost` remains the single backdrop owner.
Foreground geometry, navigation, materials/readability, accent colors and Timer D
behavior are unchanged. No scene frame updates SwiftUI state or root publishers.

One persistent `LivingEnvironmentSurface` immediately changes its still image,
releases the previous renderer and cancels its pending activation. A cancellable
250 ms task waits for the final exposed selection before allocating Metal.
Serial preparation checks cancellation before and after pipeline/texture work;
publication also verifies the current scene. There is no obsolete allocation
queue or overlapping scene cache. Theme Center feedback and haptics stay immediate.

Detachment, inactive scene, application background and ambient cover release the
renderer, textures and drawable ownership. Already submitted GPU work is bounded
to two buffers and can finish; debug resource counts measure application ownership,
not instantaneous driver memory. Re-entry prepares one scene and resumes retained
active time. Scene changes reset only the environmental clock. Hidden time never
advances it, and a hitch advances at most 0.1 seconds with no catch-up loop.
A static image covers settling or GPU failure without an automatic retry loop.
Timer D and Theme Center use the unchanged reference-counted ambient suspension
coordinator. No Timer behavior was modified.

Normal policy remains 30 fps / 1280-pixel maximum drawable dimension. Low Power
Mode or serious thermal state removes secondary detail and uses 20 fps / 960.
Reduce Motion shares one calm policy across both families: 15 fps / 960, primary
amplitude .25, no secondary foam/spray. Disabled effects or critical thermal state
retain a still photograph with no continuous submissions. A pending policy redraw
may complete after the driver pauses; steady-state tests sample after that turn.

There is no app-level user motion control. A future small persisted **Full / Calm /
Still** preference should feed this existing quality policy independently of the
system Reduce Motion setting. Phase 2A adds no such control or Theme Center redesign.

## Reproducible validation

Use `DEVELOPER_DIR=/Users/brand/Downloads/Xcode.app/Contents/Developer` (Xcode 27).
Host Swift tests also use that toolchain's `MacOSX27.0.sdk` as `SDKROOT`; Simulator
and device builds select their own SDK with inherited SDKROOT unset.

- `scripts/run_living_theme_tests.sh`: registry, shared quality, active-time,
  visibility and fixed framing contracts; included in full validation.
- `scripts/run_theme_readability_contract_tests.py`: actual store migration,
  persistence/no-repeat, canonical selection publication and unchanged palette /
  readability contracts. All historical raw IDs remain covered.
- `scripts/run_living_theme_render_tests.sh <external-output> [scene-id]`:
  production shader, moving/fixed regions, deterministic output, still/calm,
  90-frame sequence and host GPU cost. Run all three implemented scenes.
- `scripts/run_living_theme_native_tests.py --simulator <booted-UDID> --app
  <built-Simulator-app> --output <new-external-directory>`: production surface,
  seven-entry transition sequence covering all six directed pairs, actual Metal,
  lifecycle notifications, constrained/calm policy, rapid settling, stale identity
  rejection and nine cycles returning ownership counts to zero. Its Timer check
  proves the exposure contract; actual Timer UI remains a separate integration test.
- `-LifeRouteLivingDiagnostics`: opt-in DEBUG aggregate frame CPU/GPU and lifecycle
  evidence. No per-frame production logging or user data.

The external checkpoint contains the untouched-parent Rainforest build, native
and GPU baseline; the same external instrumented harness for before/after CPU,
GPU, interval distribution and resident memory; exact rendered preservation;
regression logs, native integration, source and signing receipts, canonical bundle
hash, and an empty phone checklist. Baseline source is captured before any shared
renderer edit. Measurements are Simulator/host evidence, not phone pacing,
perceptual quality, thermal or battery acceptance.

Sole Phase 2A receipt:
`/Users/brand/Documents/LifeRouteCheckpoints/living-themes-phase2a-ocean-20260910/LIVING_THEMES_PHASE2A_RECEIPT.md`.
Later installation must independently rehash the signed bundle and stop on mismatch.

Future waves are recorded only: Phase 2B Rainforest Night and Arctic pair; Phase 2C
Mountains and Canyon pairs; Phase 2D Desert pair, all-twelve sweep and final legacy
retirement/deletion decision. Each waits for judgment of the preceding proof.
