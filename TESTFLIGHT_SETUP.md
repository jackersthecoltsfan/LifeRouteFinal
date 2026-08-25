# LifeRoute — Automated GitHub to TestFlight

LifeRoute now uses an automatic release chain:

1. **iOS Build Check** runs on relevant changes to `main`.
2. It runs the same deterministic build preparation used by TestFlight, the full regression audit, and an iOS Simulator build.
3. **Auto TestFlight After CI** checks that the validated commit is still the current `main` commit.
4. If the commit is eligible for release, it automatically dispatches **Send to TestFlight**.
5. The TestFlight workflow prepares the app again, reruns the regression audit, validates Apple credentials and bundle IDs, archives the real-device Release build, exports the signed IPA, uploads it to App Store Connect/TestFlight, saves a short-lived IPA artifact, and cleans temporary Apple signing assets.

## Release-control commit tags

The assistant/build process chooses these when appropriate; the user should not need to manage them during normal work.

- `[no-testflight]` — validate the change but do not create a TestFlight build.
- `[web-only]` — web/preview-only change; do not create a TestFlight build.
- No release-control tag — a passing current `main` commit is eligible for automatic TestFlight promotion.

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
3. GitHub automatically prepares, audits, and builds it.
4. If the commit is release-eligible and CI passes, GitHub automatically signs and uploads it to TestFlight.
5. Brandon updates/installs the build in the TestFlight app and tests it on the iPhone.
6. Brandon reports any UX or functional problems; the cycle repeats.

Opening GitHub Actions and manually pressing **Run workflow** is now a fallback/debugging action, not the normal release process.

## Automatic repair monitor

A ChatGPT condition-watch named **LifeRoute Build Repair** monitors the build chain. On a failed build it may make up to two targeted repairs (`auto-repair 1/2`, then `auto-repair 2/2`). If both fail, it stops changing code and escalates the current failure and attempted fixes instead of continuing indefinitely.

## Signing cleanup

GitHub-hosted Macs are temporary. Xcode automatic signing may create a temporary Apple Development certificate and development provisioning profile during a release. The workflow records the signing assets that existed before the build and removes only temporary development assets created by that run. Existing Distribution certificates are not intentionally removed.

The TestFlight workflow prevents two release jobs from signing at the same time, reducing duplicate signing assets from accidental overlapping runs.

## What Brandon should not have to do for routine releases

- Open Xcode on a PC/Mac.
- Download or convert `.p8` / `.p12` files again.
- Create a new distribution certificate for every build.
- Manually increment TestFlight build numbers.
- Manually run the CI workflow.
- Manually dispatch TestFlight after every successful build.
- Read GitHub logs when the automatic repair layer can resolve the failure safely.
