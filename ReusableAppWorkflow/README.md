# Reusable iOS App Build + TestFlight Workflow

This folder is the durable template for the build/release system developed while building LifeRoute.

The goal is simple: for a future iOS app, do **not** redesign CI, TestFlight delivery, signing cleanup, or the automatic repair policy. Reuse this pack and only substitute the new app's project-specific values.

## What this pack preserves

1. **Preflight / preparation hook**
   - One deterministic `scripts/prepare_build.sh` hook runs before both CI and TestFlight.
   - Project-specific generators, patch scripts, syntax checks, and marker checks belong there.

2. **iOS Build Check**
   - Runs on relevant pushes to `main`, pull requests, or manual dispatch.
   - Uses a GitHub-hosted macOS runner.
   - Runs the same preparation hook used by TestFlight.
   - Compiles for the iOS Simulator with code signing disabled.
   - Cancels stale CI when a newer commit arrives.

3. **Automatic TestFlight handoff**
   - Runs only after the iOS Build Check succeeds on `main`.
   - Confirms the validated SHA is still the current `main` commit before releasing.
   - Dispatches the TestFlight workflow only for the latest validated code.

4. **TestFlight release**
   - Uses App Store Connect API-key authentication.
   - Creates an ephemeral `.p8` file on the GitHub runner.
   - Uses Xcode automatic signing and provisioning.
   - Archives for a real iOS device, exports a signed IPA, uploads with `altool`, and keeps a short-lived IPA artifact.
   - Snapshots Apple development signing assets before the build and removes only temporary development assets created by that run.

5. **Automatic two-attempt repair policy**
   - A separate ChatGPT automation checks failed builds.
   - Repair attempt 1: inspect the failing GitHub Actions job/log, patch the most likely root cause, push a commit containing `auto-repair 1/2`.
   - Repair attempt 2: if the replacement build still fails, inspect the new failure, make one more targeted patch, and push `auto-repair 2/2`.
   - If the build still fails after attempt 2, stop changing code automatically and notify the user with the failure and both attempted fixes.
   - If a repair succeeds and reaches TestFlight, notify the user briefly.
   - The monitor currently runs hourly because that is the fastest supported automation cadence.

## Reuse this for another app

The future app only needs these app-specific values:

- `APP_NAME` — display/project label used in workflow text.
- `SCHEME` — Xcode scheme.
- `PROJECT` — Xcode project file, such as `MyApp.xcodeproj`.
- `BUNDLE_ID` — registered App Store bundle identifier.
- `APP_SOURCE_PATH` — main source folder used by CI path filters.
- `CONCURRENCY_PREFIX` — short lowercase slug for GitHub concurrency groups.

Then run:

```bash
bash ReusableAppWorkflow/bootstrap-ios-workflows.sh \
  "MyApp" \
  "MyApp" \
  "MyApp.xcodeproj" \
  "com.example.MyApp" \
  "MyApp" \
  "myapp"
```

The bootstrap script creates:

- `.github/workflows/ios-ci.yml`
- `.github/workflows/auto-testflight.yml`
- `.github/workflows/testflight.yml`
- `scripts/prepare_build.sh` if one does not already exist
- `scripts/apple_ci_assets.rb`

Existing app-specific `scripts/prepare_build.sh` content is preserved.

## GitHub secrets required

The workflow expects these repository secrets:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`

**Never commit the actual values or the private `.p8` key.**

The same App Store Connect API key can often be reused for future apps when its App Store Connect permissions cover them. Each new app still needs its own registered bundle ID and App Store Connect app record.

## Project-specific code

Do not put app-specific visual generation, feature patching, or validation into the reusable workflow templates. Put it in `scripts/prepare_build.sh`. That keeps the CI/release architecture reusable while letting each app have its own preparation logic.

## Canonical behavior

When asked in a future project to “use the saved app workflow,” this folder is the source of truth. Copy/bootstrap it first instead of inventing a new release pipeline.
