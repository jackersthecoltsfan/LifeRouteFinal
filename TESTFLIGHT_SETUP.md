# LifeRoute — GitHub to TestFlight

LifeRoute uses two GitHub Actions workflows:

- **iOS Build Check** — automatically checks relevant code changes on the iOS Simulator without Apple signing.
- **Send to TestFlight** — the one-button manual release workflow.

## One-time GitHub secrets

Repository **Settings → Secrets and variables → Actions** needs these four secrets:

1. `APPLE_TEAM_ID` — Apple Developer Team ID.
2. `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key ID.
3. `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect issuer ID.
4. `APP_STORE_CONNECT_PRIVATE_KEY` — complete contents of the `AuthKey_XXXXXXXXXX.p8` file, including the BEGIN/END PRIVATE KEY lines.

Do not commit the `.p8` file itself.

## App identifiers

- Bundle ID: `Com.Brandongood.LifeRoute`
- Xcode project: `LifeRoute.xcodeproj`
- Scheme: `LifeRoute`
- Marketing version: `0.3.0`

The GitHub run number becomes the TestFlight build number automatically.

## Normal release from now on

1. Open **Actions**.
2. Choose **Send to TestFlight**.
3. Click **Run workflow**.
4. Wait for the green check. The run summary confirms the TestFlight upload and build number.

No PC-side certificate work should be needed for routine releases.

## Signing cleanup

GitHub-hosted Macs are temporary. Xcode automatic signing may create a temporary Apple Development certificate and development provisioning profile during a release. The workflow now records the signing assets that existed before the build and, at the end of the run, deletes **only the new development certificate/profile created by that run**. Existing Distribution certificates are not touched.

The TestFlight workflow also prevents two release jobs from signing at the same time, which avoids duplicate signing assets from accidental double-runs.

If the cleanup step ever shows a warning, the TestFlight upload can still be valid; inspect that cleanup step before the next release so temporary Development certificates do not begin accumulating again.
