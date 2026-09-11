# Living Themes — complete twelve-scene engineering catalogue

All twelve Scenic Royal Living identities now have environmental programs. The camera stays fixed; local water, weather, cloud, fog, aurora and heat systems move through artwork-calibrated regions. Engineering validation and Simulator recordings do not establish physical acceptance. Rainforest Day at `9494e81c814d6cbe958dc190263d8fec141cdb27` retains Brandon's accepted status; the complete candidate awaits phone audition.

## Registry and family programs

`LivingThemeRegistration.all` is the explicit twelve-scene registry: identity, family, Day/Night variant, selected fragment, primary motion, secondary/ambient effects and shared quality/lifecycle policies. All entries are implemented. Core still has its twelve static choices. No Living identity uses the retired Dynamic renderer.

| Scene | Primary motion | Secondary / ambient |
| --- | --- | --- |
| Rainforest Day | Accepted waterfall and winding stream | Spray; four local leaf clusters |
| Rainforest Night | Artwork-supported moonlit stream | River mist, local foliage, sparse layered rain |
| Ocean Day | Overlapping arriving swell, travelling crest, break, foam and dissipation | Surface ripples, localized spray, evolving clouds |
| Ocean Night | Same finite wave physics with scene geometry and light | Moving moon reflection, clouds, stars, rare meteor |
| Arctic Day | Broad travelling spindrift/weather banks | Cloud/haze layers, channel ripple, three-depth snow |
| Arctic Night | Evolving visible aurora curtains | Lake reflection, cold haze, sparse snow, stars/meteor |
| Mountains Day | Reforming clouds and valley fog | Near haze, lake ripple |
| Mountains Night | Rolling valley fog and high cloud | Lake ripple, stars/meteor |
| Canyon Day | Evolving clouds and broad canyon atmosphere | Narrow material-gated river flow, distance haze |
| Canyon Night | Night cloud and canyon mist | River flow, stars/meteor |
| Desert Day | Basin-local heat refraction and warm haze | High clouds, restrained distant dust |
| Desert Night | Evolving atmosphere inside the rock-arch opening | Cool haze, stars/meteor |

Ocean's canonical timing contract was extracted from agreeing committed production/tests at `15b4266` in `919d99af`. It bounds wave lifetime at 14.2–18 seconds and nominal starts at 6.3 seconds plus 0–1.7 seconds of seed variation. These are current engineering values, not owner-specified perceptual timing. GPU probes exercise developed later swells overlapping older crests/break/foam, monotonic travel and complete event dissipation. Five bounded event slots and independently varied lifetime/strength/curvature prevent one uniform displacement cycle. Fine aerated lip texture replaces the initial broad pale segments. No shoreline is fabricated.

Day/Night share a family program where geometry supports it. Mountains, Canyon and Desert use common fragments with separate typed artwork descriptors. Ocean shares event physics with separate water geometry/light. Rainforest Night uses a separate stream topology because its photograph has no distinct waterfall. Arctic's day spindrift and night aurora use separate fragments, sharing weather infrastructure and a family rate authority. Eight fragment programs use one accepted renderer; there are no twelve independent engines.

`LivingMotionContracts.h` imports the family headers for Swift tests; Metal reads those headers directly. Scene geometry, light, seeds and cloud/weather amounts are typed `LivingAtmosphereConfiguration` values bound once at buffer(2). Existing primary uniforms stay 32 bytes and Ocean geometry stays 32 bytes. See `LIVING_FAMILY_MOTION_CONTRACTS.md` for the externally frozen authority pattern.

Clouds combine photographed cloud material with multiple evolving depth fields; fog combines far/near billows in local regions. Weather uses depth-dependent rates and spatial density. Night sky motion excludes fixed moons and terrain. The common meteor envelope is short and uncommon, with scene-seeded offsets. Secondary effects never substitute for the scene's primary system.

## Ownership, framing and quality

`LifeRouteThemeStore` remains the selection/persistence authority. The existing backdrop host owns one `LivingEnvironmentSurface`, which releases old resources, cancels stale work, waits a cancellable 250 ms settling interval and prepares only the final exposed scene. No frame updates a SwiftUI/root publisher. Native lifecycle, active-time clock, teardown and two-buffer submission ownership are unchanged.

Background, inactive state, detachment, Theme Center and Timer D exposure suspension release heavy scene ownership. Resume retains active time; hidden time never advances the simulation. Camera framing remains centered aspect-fill and never depends on time, gyro or accelerometer.

Normal rendering uses 30 fps and a maximum drawable dimension of 1280. Reduce Motion uses 15 fps, 960 pixels, quarter amplitude and no secondary/ambient detail while preserving recognizable primary motion. Low Power/serious thermal use 20 fps, 960 pixels and reduced primary amplitude with secondary/ambient detail removed. Critical thermal or disabled effects shows the still artwork without continuous submissions. These mechanical policies are not physical thermal acceptance.

Rainforest Day's entire accepted 6,455-byte shader remains unchanged. All 94 comparable parent render images are byte-identical. Waterfall, stream, spray and foliage tests pass; fixed trunk/canopy/rock regions are exactly stationary.

## Retirement and retained debt

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


## Evidence and reproduction

Use process-local `DEVELOPER_DIR=/Users/brand/Downloads/Xcode.app/Contents/Developer`. Host Swift uses that toolchain's MacOSX27 SDK; Simulator/device commands unset inherited SDKROOT.

- Run `scripts/check_living_family_contracts.py --checkpoint <run-checkpoint>` before each validation/finalization step. It checks the external Ocean hash and every frozen family header/descriptor.
- `scripts/check_ocean_timing_authority.py` checks the canonical header, its event consumers, shared test import and divergence negative controls.
- `scripts/run_living_theme_render_tests.sh <external-output> <scene-id>` renders the actual production program: event phases for Ocean, fixed/moving pixels, still/calm identity, longer-time evolution and 90-frame sequences.
- `scripts/run_living_theme_native_tests.py --simulator <booted-UDID> --app <Simulator-app> --output <new-external-directory>` exercises the full paired catalogue sweep, lifecycle, rapid settling, constraints and repeated release using the production surface.
- `scripts/capture_living_scene.py` records a privacy-empty Simulator host of that same surface. Passing scene commits include `docs/evidence/living-themes-20260910/<scene>/motion.mp4`, validation metrics and source manifests.
- Full validation, actual theme-store migration, Timer ABC/D and native foreground integration remain independent gates. The external native XCTest project exercises real toolbar taps, all twelve Theme Center selections and Timer fullscreen/resume.

The sole detailed receipt is `/Users/brand/Documents/LifeRouteCheckpoints/living-themes-full-expansion-20260910/LIVING_THEMES_FULL_EXPANSION_RECEIPT.md`. It owns final source identity, signed artifact/hash, actual native/performance results and the empty physical QA matrix. No physical install, TestFlight or release is authorized by this implementation.
