# LifeRoute v0.7.1 Theme Library — Codex Handoff

## Isolation and status

- Branch: `feature/v0.7.1-theme-library-finish-codex`
- Exact base: `00f98f4cade1b6cb14ce65d3b62203c0efda4ef2` (physically validated Build #98 architecture)
- Simulator-validated code SHA: `d56ed5deebf084703927964fe714e7faad2de444`
- This branch is non-shipping production prep. It has not been merged and no TestFlight workflow was triggered.
- The active LifeRoute product/release branch remains owned by the main development thread.

## Finished retained themes

Dynamic (8): Royal Current, Midnight Prism, Aurora Bloom, Solar Pulse, Emerald Flow, Ocean Glass, Obsidian Spectra, and Plasma Orchid.

Scenery (12): Mountains Day/Night, Ocean Day/Night, Desert Day/Night, Rainforest Day/Night, Canyon Day/Night, and Arctic Day/Night.

Royal Current and Canyon Day remain the protected Build #98 references. The retired Dynamic and Scenery identifiers remain available for migration compatibility but are hidden from the retained picker catalogs and received no new artwork.

## Implementation summary

- The seven new Dynamic implementations are distinct full-screen SwiftUI compositions rather than palette variants: prism facets, aurora veils, solar rings/rays, emerald vertical flow, ocean lenses/caustics, obsidian spectra, and orchid petals/tendrils.
- Eleven new Scenery identities use optimized bundled 941×1672 JPEG artwork. Canyon Day continues to use its existing reference PNG.
- Scenery ambience is shared and family-specific: restrained mist, water highlights, desert haze, canyon light/haze, and arctic aurora/snow haze.
- The single persistent `LifeRouteLiveThemeEnvironment`, single root 20 fps `TimelineView`, lifecycle pausing, app-wide host, and Reduce Motion still phases remain intact.
- Theme Center previews remain static. Selected themes load no network imagery.
- `scripts/prepare_build.sh` materializes the Dynamic layer, then Scenery, then DEBUG-only fixture hooks; matching audits run after each terminal layer.

## Validation evidence

Final GitHub Actions run: [iOS Build Check #33217191235](https://github.com/jackersthecoltsfan/LifeRouteFinal/actions/runs/33217191235), successful on `d56ed5d`.

- Full `scripts/prepare_build.sh`: passed.
- Xcode 26.6 / iPhone Simulator 26.5 Debug build: passed.
- Fresh local deterministic replay: all 95 ordered Python patch/audit steps passed.
- Fixture artifact: `liferoute-v0.7.1-theme-matrix`, artifact ID `9704197158`, 85 PNGs, retained until 2026-09-11.
- All 20 themes: real Today screen captured, then real Schedule screen selected in the same process and captured.
- Apple Vision OCR: found the top `LifeRoute` title on all 20 Today fixtures and the top `Schedule` title on all 20 follow-ups; no URL-confirmation dialog was present.
- Full-background gate: all 40 app-shell fixtures passed; no blank/black middle-to-lower application surface.
- Reduce Motion: all 20 stable phases rendered, passed image-health checks, and were quantitatively distinct.
- Scenery Day/Night pairs: all six pairs differed across 98.63%–99.13% of sampled pixels.
- Human contact-sheet inspection: all retained scenes/compositions are visually distinct, full-screen, and readable on Today and Schedule; no final visual failure found.

### Dynamic motion results

Frames were captured three seconds apart from the production renderer. Changed-pixel results:

| Dynamic theme | Changed pixels |
| --- | ---: |
| Royal Current | 97.66% |
| Midnight Prism | 98.24% |
| Aurora Bloom | 37.90% |
| Solar Pulse | 72.03% |
| Emerald Flow | 59.78% |
| Ocean Glass | 59.85% |
| Obsidian Spectra | 83.34% |
| Plasma Orchid | 64.70% |

## Size and performance review

- New Scenery source artwork: 3,658,387 bytes (3.49 MiB).
- Final compiled `Assets.car`: 8,269,192 bytes.
- Final Debug Simulator `.app`: 28,964 KiB (about 28.29 MiB).
- Approximate bundle increase attributable to the new artwork is about 3.5 MiB before asset-catalog recompression; no duplicate giant near-identical assets were added.
- The retained animation architecture still uses one root clock at 20 fps. New renderers add no per-tab/per-screen timers, `TimelineView`s, network work, or persistent state owners.
- The complete matrix finished in about 18 minutes. No crash or process loss occurred across repeated theme launches and tab transitions.

No ETTrace/Instruments profile or physical-device thermal/FPS trace was produced because this work ran from a Windows host through GitHub's macOS Simulator runner. Physical-device confirmation is still recommended before shipping, especially for sustained animation smoothness and thermal behavior.

## Known issues and remaining gates

- No known visual, blank-background, readability, motion, or Reduce Motion failure remains in the final Simulator fixture set.
- Physical-iPhone review is still required after integration; Simulator success does not replace device thermal, sustained-FPS, OLED contrast, and hand-feel validation.
- No ETTrace/Instruments trace was captured, so performance evidence is architectural plus repeated runtime stability rather than a frame-time profile.
- The GitHub fixture artifact expires on 2026-09-11; rerun the branch workflow if durable visual evidence is needed later.
- The fixture signal and raw theme overrides are compiled only under `DEBUG`; they do not alter release behavior.

## Exact changed files at validated code SHA

- `.github/workflows/ios-ci.yml`
- `LifeRoute/Assets.xcassets/SceneryArcticDay.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryArcticDay.imageset/SceneryArcticDay.jpg`
- `LifeRoute/Assets.xcassets/SceneryArcticNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryArcticNight.imageset/SceneryArcticNight.jpg`
- `LifeRoute/Assets.xcassets/SceneryCanyonNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryCanyonNight.imageset/SceneryCanyonNight.jpg`
- `LifeRoute/Assets.xcassets/SceneryDesertDay.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryDesertDay.imageset/SceneryDesertDay.jpg`
- `LifeRoute/Assets.xcassets/SceneryDesertNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryDesertNight.imageset/SceneryDesertNight.jpg`
- `LifeRoute/Assets.xcassets/SceneryMountainsDay.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryMountainsDay.imageset/SceneryMountainsDay.jpg`
- `LifeRoute/Assets.xcassets/SceneryMountainsNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryMountainsNight.imageset/SceneryMountainsNight.jpg`
- `LifeRoute/Assets.xcassets/SceneryOceanDay.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryOceanDay.imageset/SceneryOceanDay.jpg`
- `LifeRoute/Assets.xcassets/SceneryOceanNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryOceanNight.imageset/SceneryOceanNight.jpg`
- `LifeRoute/Assets.xcassets/SceneryRainforestDay.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryRainforestDay.imageset/SceneryRainforestDay.jpg`
- `LifeRoute/Assets.xcassets/SceneryRainforestNight.imageset/Contents.json`
- `LifeRoute/Assets.xcassets/SceneryRainforestNight.imageset/SceneryRainforestNight.jpg`
- `scripts/audit_v0_7_1_dynamic_library_finish.py`
- `scripts/audit_v0_7_1_scenery_library_finish.py`
- `scripts/audit_v0_7_1_theme_fixture_matrix.py`
- `scripts/capture_v0_7_1_visual_fixtures.sh`
- `scripts/compare_v0_7_1_theme_fixtures.py`
- `scripts/patch_v0_7_1_dynamic_library_finish.py`
- `scripts/patch_v0_7_1_scenery_library_finish.py`
- `scripts/patch_v0_7_1_theme_fixture_matrix.py`
- `scripts/prepare_build.sh`
- `scripts/validate_v0_7_1_fixture_text.swift`

This handoff file and the pointer in `LIFEROUTE_HANDOFF.md` are documentation-only additions after the validated code SHA.

## Integration guidance for the main LifeRoute thread

Do not merge this branch wholesale onto a newer product branch. It intentionally remains based on Build #98 and does not contain unrelated toolbar/Setup/product work.

Recommended selective integration:

1. Cherry-pick `4dd353e` (`Finish retained v0.7.1 Dynamic themes`).
2. Cherry-pick `130167c` (`Finish retained v0.7.1 Scenery themes`).
3. Resolve `scripts/prepare_build.sh` by keeping the finish layers after the proven Build #98 runtime patch and after any newer canonical product patches.
4. Optionally cherry-pick the fixture-tooling commits `a82aafb`, `8bc1f0c`, and `d56ed5d` if the shipping branch should retain the full matrix.
5. Run the full deterministic preparation, iOS build, 20-theme matrix, and physical-device review on the integration branch before exposing these themes in a shipping picker.

No release action is implied or authorized by this handoff.
