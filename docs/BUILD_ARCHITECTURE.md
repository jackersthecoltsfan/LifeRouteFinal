# LifeRoute current build architecture

## Authority

LifeRoute v0.9.0 shipping source is checked in directly under `LifeRoute/`,
`LifeRouteLiveActivityWidget/`, and `LifeRoute.xcodeproj/`. A normal checkout is
the product tree; no release replay or source mutation is required.

The accepted TestFlight baseline for the post-v0.9 cleanup is Build 118 at exact
SHA `67b8b4c21df3700a66abb1bb1c4190e2b040cce1`. That recorded release state does
not replace live Git/GitHub verification and does not authorize another upload.

`MARKETING_VERSION` is owned by the app and extension build configurations in
the Xcode project and is synchronized at `0.9.0`. `CURRENT_PROJECT_VERSION` is
the synchronized source development build. The separately authorized
TestFlight workflow overrides the build number with its run number for both
targets.

## Current commands

- `scripts/prepare_build.sh`: idempotent preflight; confirms required owners and
  runs fast validation. It does not rewrite shipping source.
- `scripts/validate_fast.sh`: current semantic architecture, versions, target
  structure, AppIcon, navigation/theme ownership, and clinical boundaries.
- `scripts/validate_full.sh`: full semantic validation plus all executable
  contracts for calendar/routing, persistence/migrations, ABA tools, timer,
  runtime feedback, Live Activity, WebView quarantine, and release policy.
- `scripts/run_contract_tests.sh`: stable aggregate entry point for Day Route,
  Session Note, Visual Timer feedback, and runtime feedback contracts.
- `scripts/run_swift_contract_test.sh`: content-addressed per-suite compiler
  cache. Exact compiler, runner, source, or fixture changes invalidate reuse;
  every invocation still executes the assertion binary.
- `scripts/assess_xcode_warnings.py`: rejects unexpected warning lines from
  native Debug/Release build logs while classifying one exact Xcode 26.6 notice.
- `scripts/run_simulator_smoke.sh`: GitHub macOS runner smoke for the five root
  sections, repeated-launch persistence, and live-theme/Reduce Motion modes. It
  does not duplicate contract compilation already owned by full validation and
  waits five seconds by default so captures contain settled foreground content.

`validate_current.py` parses the app and extension `PBXSourcesBuildPhase`
entries, requires every active Swift file in the correct phase exactly once, and
rejects detached Sources build objects. Raw project-text occurrence is not
treated as target-membership proof.

For a cold contract/full-validation timing, point
`LIFEROUTE_CONTRACT_CACHE_DIRECTORY` at a fresh temporary directory. Normal
focused iteration may use the default temporary content-addressed cache.

`LIFEROUTE_SMOKE_SETTLE_SECONDS` may override the five-second Simulator capture
settle for a controlled experiment. Canonical evidence uses the default.

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

## Local schemes and Xcode

`LifeRoute.xcodeproj/xcshareddata/xcschemes/LifeRoute.xcscheme` is the committed
canonical scheme. It builds the app and embedded Live Activity extension.
Machine-specific Run configuration belongs in the ignored `LifeRoute Local`
scheme under `xcuserdata`; never move or share it.

Keep Xcode closed during broad project/scheme edits. If the shared scheme drifts
unexpectedly, stop, quit Xcode, restore only that tracked scheme from the current
branch, and verify that no other project file changed.
