# LifeRoute — Confirmed GitHub to TestFlight

LifeRoute uses automatic validation with **manual-only TestFlight release**:

1. **iOS Build Check** runs automatically on relevant changes to `main`.
2. It runs the deterministic build preparation, full regression audit, and an iOS Simulator build.
3. Passing CI does **not** upload to TestFlight and does **not** dispatch the TestFlight workflow.
4. A TestFlight upload happens only after Brandon explicitly confirms that a TestFlight run should be used.
5. After that confirmation, **Send to TestFlight** is manually dispatched. It prepares the app again, reruns the regression audit, validates Apple credentials and bundle IDs, archives the real-device Release build, exports the signed IPA, uploads it to App Store Connect/TestFlight, and cleans temporary Apple signing assets.

This policy exists because App Store Connect enforces an application upload limit. Routine development, auditing, web previews, and GitHub commits must never spend a TestFlight upload automatically.

## Release-control commit tags

These tags remain useful for clarity, but they are no longer the primary protection against accidental TestFlight uploads because TestFlight is manual-only at the workflow level.

- `[no-testflight]` — explicitly indicates validation/build work with no TestFlight release.
- `[web-only]` — web/preview-only change; no TestFlight release.
- No release-control tag — still does **not** authorize TestFlight. Explicit confirmation is always required.

## One-time GitHub secrets

Repository **Settings → Secrets and variables → Actions** needs these four secrets:

1. `APPLE_TEAM_ID` — Apple Developer Team ID.
2. `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key ID.
3. `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect issuer ID.
4. `APP_STORE_CONNECT_PRIVATE_KEY` — complete contents of the `AuthKey_XXXXXXXXXX.p8` file, including the BEGIN/END PRIVATE KEY lines.

Do not commit the `.p8` file itself.

## App identifiers

- Bundle ID: `Com.Brandongood.LifeRoute`
- Live Activity bundle ID: `Com.Brandongood.LifeRoute.LiveActivity`
- Xcode project: `LifeRoute.xcodeproj`
- Scheme: `LifeRoute`

The GitHub TestFlight workflow run number becomes the TestFlight build number automatically.

## Normal LifeRoute update from now on

The intended routine is:

1. Brandon tells ChatGPT/Codex what should change.
2. The implementation is made and committed to GitHub.
3. GitHub automatically prepares, audits, builds, and may publish the web preview when relevant.
4. ChatGPT reports the validation/build status and leaves TestFlight untouched.
5. When Brandon explicitly says to send the validated version to TestFlight, the **Send to TestFlight** workflow is manually dispatched once.
6. Brandon installs/tests that build on the iPhone and reports any UX or functional problems.

**Never infer TestFlight permission from a code-change request, a successful audit, a successful build, a request to “launch,” or a web publish request. The user must explicitly confirm TestFlight.**

## Automatic repair monitor

A ChatGPT condition-watch named **LifeRoute Build Repair** may monitor the build chain. On a failed build it may make targeted repairs when authorized by the project workflow, but repair/validation work does not authorize a TestFlight upload.

## Signing cleanup

GitHub-hosted Macs are temporary. Xcode automatic signing may create a temporary Apple Development certificate and development provisioning profile during a release. The workflow records the signing assets that existed before the build and removes only temporary development assets created by that run. Existing Distribution certificates are not intentionally removed.

The TestFlight workflow prevents two release jobs from signing at the same time, reducing duplicate signing assets from accidental overlapping runs.

## What Brandon should not have to do for routine development

- Open Xcode on a PC/Mac.
- Download or convert `.p8` / `.p12` files again.
- Create a new distribution certificate for every build.
- Manually increment TestFlight build numbers.
- Manually run normal CI checks.
- Read GitHub logs when ChatGPT can inspect them directly.

For TestFlight specifically, Brandon's only required action is the **explicit release confirmation**; ChatGPT/Codex can handle the manual workflow dispatch after that confirmation.
