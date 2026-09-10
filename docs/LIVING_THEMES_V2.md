# Living Themes V2, Phase 1

Rainforest — Day (`scenery.rainforest.day`) is the first V2 scene. It uses the
existing Scenic Royal photograph and catalog entry. The waterfall carries
continuously descending texture and turbulent filaments; water follows the
stream, spray rises locally, and four foliage clusters flex gently. Trunks,
rock banks, distant scenery and the centered aspect-fill camera stay fixed.
Rain and screen-wide particles are intentionally absent from this sunlit scene.
This is a photographic animation candidate, not captured live-action footage.
Motion realism, iPhone frame pacing, warmth and battery use require physical QA.

## Ownership

`LifeRouteApp` -> `LifeRouteThemeStore` remains the sole selected-theme and
persistence authority. Its existing environment values are projections. No
migration, new theme identifier, catalog conversion or preference key is added.

`lifeRouteChrome` -> `ScenicRoyalEnvironmentHost` remains the single background
presentation owner. Foreground UI determines geometry and safe areas and retains
its existing Scenic Royal materials, semantic colors and readability veil.
The five root hosts, independent navigation stacks and Timer D owner remain.

`LifeRouteLiveThemeEnvironment` dispatches exclusively to V2 for Rainforest —
Day, otherwise to its existing legacy rendering body. V2 replaces that scene's
legacy image-copy/Canvas/Timeline path; it does not stack on top of it. Dynamic
companion themes and every other still/live catalog entry retain their renderer.

`LivingThemeScene` supplies artwork and a Metal fragment function. A future
second scene uses the same playback, resource, framing and quality machinery.
`LivingEnvironmentSurface` owns one `MTKView` and one `LivingSceneRenderer`.
Only MetalKit drives continuous frames; no SwiftUI frame-time state, new display
link, publisher, timer or foreground invalidation is introduced.

## Resource and lifecycle contract

- One opaque, single-triangle pass; one immutable 941 x 1672 source texture
  (about 6.7 MB allocated on the validation host); no mipmaps or frame decoding.
- Maximum drawable long edge 1280 pixels, preferred 30 fps. Low Power Mode or
  serious thermal state uses 960 pixels/20 fps and removes secondary mist.
- Reduce Motion, disabled effects and critical thermal state use a static
  rendered photograph with no continuous driver. The environment stays visible.
- Existing reference-counted ambient suspension pauses V2 during paging and
  Theme Center. Expanded Timer D visibility acquires/releases a handle from that
  same coordinator; it does not change Timer presentation/geometry/feedback.
- Inactive scene, application resignation, detachment, or suspension stops
  scheduling. Active monotonic time is retained. Resume excludes hidden time;
  a hitch advances at most 0.1 seconds, with no catch-up loop.
- One serial preparation actor performs pipeline/texture preparation outside
  the main actor and rejects cancelled queued requests. A theme change cancels
  preparation, removes notification observers/delegate, releases resources and
  drawables, and stops the old renderer. GPU work is bounded to two submissions;
  when busy, a frame is skipped instead of blocking on the in-flight semaphore.
- A static image covers asynchronous preparation. GPU/asset failure retains or
  restores static scenery without a retry loop. Background entry releases
  drawable storage; immutable scene resources can remain until theme teardown.
- Artwork-space masks share the exact centered aspect-fill coordinate map in
  portrait and landscape. Time cannot change camera framing. Two phase-offset
  advected samples hand over at zero weight to avoid texture wrap jumps.

MetalKit scheduling follows Apple's [MTKView contract](https://developer.apple.com/documentation/metalkit/mtkview).
GPU completion/ownership uses [command completion handlers](https://developer.apple.com/documentation/metal/mtlcommandbuffer/addcompletedhandler(_:)).

## Validation

Use coherent Xcode 27 per process. For host Swift contracts set `SDKROOT` to
that Xcode's MacOSX27.0 SDK; for Simulator/device builds unset inherited SDKROOT
and let the explicit SDK/destination select the platform. Do not change the
shared scheme or global developer directory.

- `bash scripts/run_living_theme_tests.sh`: executable dispatch, quality,
  visibility, active-time, geometry and uniform-layout contracts; also included
  in `scripts/validate_full.sh`.
- `bash scripts/run_living_theme_render_tests.sh <external-output>`: compiles the
  production Metal source for the Mac GPU, verifies real water/foliage movement,
  fixed regions, static Reduce Motion, phase continuity and opaque output; emits
  a short 30 fps PNG sequence and host-GPU measurements.
- `python3 scripts/run_living_theme_native_tests.py --simulator <booted-UDID>
  --app <built-Simulator-LifeRoute.app> --output <new-external-output>`: actual
  production surface/renderer, bundled assets/shader, attachment, pause/resume,
  Reduce Motion, rapid switching, and weak-reference teardown on Simulator.
- `-LifeRouteLivingDiagnostics` enables DEBUG aggregate frame submission/CPU/GPU
  and lifecycle logs. No frame logging, timers, or production instrumentation.
  These measurements concern the renderer and host, not physical acceptance.

Existing full validation, theme/readability/persistence, root ownership and
visibility, Timer D/ABC/presentation, Planner A, Flexible-Place, Calendar B,
Day Route, Regenerate Route and anonymous baseline contracts remain applicable.
The external Phase 1 receipt binds all results, final SHA, native integration and
signed artifact hash. The later installer must re-hash immediately before install.
