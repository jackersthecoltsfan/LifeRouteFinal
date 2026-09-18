# LifeRoute current build architecture

## Authority

LifeRoute v0.9.1 candidate source is checked in directly under `LifeRoute/`,
`LifeRouteLiveActivityWidget/`, and `LifeRoute.xcodeproj/`. A normal checkout is
the product tree; no release replay or source mutation is required.

`MARKETING_VERSION` is owned by the app and extension build configurations in
the Xcode project and is synchronized at `0.9.1`. `CURRENT_PROJECT_VERSION` is
the synchronized source development build. The separately authorized
TestFlight workflow overrides the build number with its run number for both
targets.

The source/application version (`MARKETING_VERSION=0.9.1`), current canonical
Git SHA, and any external TestFlight build number are separate identities.
Verify the current `main` SHA from Git before continuity-sensitive work; do not
infer a TestFlight build number from the source version or Git SHA.

## Canonical day planning

`V054ContentView` owns one `DayRoutePlanningCore` and one
`LiveDayActivityCore`. Route generation publishes one immutable
`LifeRouteGeneratedItinerary` only after every required MapKit leg succeeds.
Today, total raw driving, usable gaps, Gap Filler eligibility, Leave By / Leave
In, Live Day, and the Live Activity payload consume that snapshot through the
pure contracts in `DayItineraryContracts.swift`; they do not rebuild route or
departure state independently.

Route Buffer is persisted by `RoutingLocationCore` and applies once per timed
appointment arrival. It never alters the displayed raw MapKit duration and does
not apply to an untimed Return Home leg. Calendar owns schedule browsing and
appointment/provider management, then hands the selected date to Today for
planning.

## Current commands

- `scripts/prepare_build.sh`: idempotent preflight; confirms required owners and
  runs fast validation. It does not rewrite shipping source.
- `scripts/validate_fast.sh`: current semantic architecture, versions, target
  structure, AppIcon, navigation/theme ownership, and clinical boundaries.
- `scripts/validate_full.sh`: fast validation plus calendar/routing,
  persistence/migrations, ABA tools, timer, Live Activity, WebView quarantine,
  and release-policy contracts.
- `scripts/assess_xcode_warnings.py`: rejects unexpected warning lines from
  native Debug/Release build logs while classifying only the two exact observed
  Xcode no-AppIntents notice spellings.
- `scripts/run_simulator_smoke.sh`: GitHub macOS runner smoke for the five root
  sections, repeated-launch persistence, and live-theme/Reduce Motion modes.

## Scratch and durable evidence

Routine generated build material uses the reusable scratch policy rooted at
`~/Library/Developer/LifeRouteBuilds`. Current GitHub CI and TestFlight paths
place DerivedData, archives, exports, and native fixture module caches below a
stable LifeRoute-specific subdirectory there. Durable receipts, logs, manifests,
screenshots/video, and explicit final artifacts are staged separately for
checkpoint or workflow-artifact retention.

Use `python3 scripts/liferoute_storage.py checkpoint-copy SOURCE DESTINATION`
to create a durable checkpoint copy. The destination must be below an approved
LifeRoute durable root; generated directories such as `DerivedData`,
`derived-data`, `build`, `ModuleCache.noindex`, and `Index.noindex` are
excluded. Final artifacts are retained only when supplied explicitly with
`--artifact`, so a routine build tree is never copied as evidence by accident.

Use `python3 scripts/liferoute_storage.py closeout NAME --dry-run` to inspect a
scratch directory. Actual closeout requires `--confirm` and still refuses
paths outside the approved scratch root, protected checkpoint/evidence roots,
the source/Git checkout, or any tree containing symlinks. Development and
validation use disposable fixtures; no historical checkpoint is migrated or
deleted by this policy.

## CI and release

Pull requests run current semantic validation and native Debug/Release
Simulator compilation. The shared `LifeRoute` scheme compiles the embedded Live
Day extension. Simulator smoke launches Today, Calendar (`schedule` internally),
Tools, Resources, and Setup. Native CI rejects all unexpected compiler warnings.
The exact known no-AppIntents metadata notices are classified separately because
LifeRoute does not link App Intents and adding that framework would change the
product solely to suppress toolchain noise; the supported spellings are listed
below.

## Hosted Apple toolchain and warning identity

The Luna 12 baseline map was: both relevant Apple jobs used the hosted
`macos-26` image, neither set `DEVELOPER_DIR` explicitly, and neither emitted
an Xcode/SDK identity receipt. iOS CI retained its Debug/Release logs and
Simulator smoke evidence for 14 days. TestFlight retained the Luna 6 recovery
bundle and exported IPA for 7 days, but its recovery manifest did not carry
toolchain identity. TestFlight archived Release for a generic iOS destination,
exported with `method=app-store-connect` and `stripSwiftSymbols=true`, then
uploaded the IPA with `xcrun altool`. The warning assessor recognized only the
older App Intents spelling and did not allowlist signed-widget strip notices.

The macOS `native-validation` job in `.github/workflows/ios-ci.yml` and the
`release` job in `.github/workflows/testflight.yml` both emit a concise
`HOSTED APPLE TOOLCHAIN` receipt after reusable build scratch is prepared. It
records the safe GitHub runner identity fields exposed by the job, `sw_vers`,
`uname -a`, `xcode-select -p`, the effective `DEVELOPER_DIR` when present,
`xcodebuild -version`, Swift compiler identity, and iOS/iOS Simulator SDK
version, build metadata, and path. It deliberately does not dump the full
environment or any signing, App Store Connect, or provisioning values.

The iOS CI receipt is retained with the existing 14-day native evidence
artifact. The TestFlight receipt is visible in the workflow summary and is
retained as a separate 7-day artifact. The Luna 6 recovery manifest is not
coupled to this receipt because the toolchain identity is workflow-run
provenance rather than an archive/IPA identity field.

The intentional App Intents classification is limited to these exact observed
messages:

- `warning: Metadata extraction skipped. No AppIntents.framework dependency found.`
- `warning: Metadata extraction skipped, no AppIntents.framework dependency found`

The second spelling is the Xcode 27 form observed in retained local build
logs. Neither form justifies adding `AppIntents.framework`; LifeRoute does not
link it, and the assessor still fails on every other warning.

The signed-widget notice is intentionally not allowlisted:
`warning: not stripping binary because it is signed:`. Retained local evidence
shows it in both signed Debug-iphoneos and Release-iphoneos device copy phases
for `LifeRouteLiveActivityWidget.appex`, while the TestFlight export options
request `stripSwiftSymbols=true`. Therefore the current classification is
`MONITOR — RELEASE RELEVANCE NOT YET PROVEN`: it is distinguishable as a
signed-device strip notice, but this lane has no new hosted macOS 26 Release /
TestFlight output that proves it is harmless at export time. If it appears in
the current warning-assessor inputs, it remains an unexpected, blocking line.

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
