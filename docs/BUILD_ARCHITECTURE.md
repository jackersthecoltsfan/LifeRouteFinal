# LifeRoute current build architecture

## Authority

LifeRoute v0.8.1 shipping source is checked in directly under `LifeRoute/`,
`LifeRouteLiveActivityWidget/`, and `LifeRoute.xcodeproj/`. A normal checkout is
the product tree; no release replay or source mutation is required.

`MARKETING_VERSION` is owned by the app and extension build configurations in
the Xcode project and is synchronized at `0.8.1`. `CURRENT_PROJECT_VERSION` is
the synchronized source development build. The separately authorized
TestFlight workflow overrides the build number with its run number for both
targets.

## Current commands

- `scripts/prepare_build.sh`: idempotent preflight; confirms required owners and
  runs fast validation. It does not rewrite shipping source.
- `scripts/validate_fast.sh`: current semantic architecture, versions, target
  structure, AppIcon, navigation/theme ownership, and clinical boundaries.
- `scripts/validate_full.sh`: fast validation plus calendar/routing,
  persistence/migrations, ABA tools, timer, Live Activity, WebView quarantine,
  and release-policy contracts.
- `scripts/assess_xcode_warnings.py`: rejects unexpected warning lines from
  native Debug/Release build logs while classifying one exact Xcode 26.6 notice.
- `scripts/run_simulator_smoke.sh`: GitHub macOS runner smoke for the five root
  sections, repeated-launch persistence, and live-theme/Reduce Motion modes.

## CI and release

Pull requests run current semantic validation and native Debug/Release
Simulator compilation. The shared `LifeRoute` scheme compiles the embedded Live
Day extension. Simulator smoke launches Today, Calendar (`schedule` internally),
Tools, Resources, and Setup. Native CI rejects all unexpected compiler warnings.
Xcode 26.6's exact no-AppIntents metadata notice is classified separately because
LifeRoute does not link App Intents and adding that framework would change the
product solely to suppress toolchain noise.

Main uses the same current contract. TestFlight has one production owner:
`.github/workflows/testflight.yml`. It requires a full exact current-main SHA,
a successful exact-SHA main CI run, full validation, signed archive identity for
both bundle IDs, and explicit dispatch. Ordinary pushes never upload.

## Rollback and history

The pre-consolidation safety reference is
`checkpoint/pre-canonical-baseline-build106`. Historical patches, audits,
fixtures, and release markers live under `scripts/archive/`; historical handoffs
and checkpoints live under `docs/archive/`. They are archaeology, not active
build inputs.

Use short-lived feature/fix branches and meaningful physically validated
release tags/checkpoints. Never rebuild current development by restoring the old
Build A/B/C-style reconstruction chain.
