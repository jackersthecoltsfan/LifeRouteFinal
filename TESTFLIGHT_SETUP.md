# LifeRoute — GitHub to TestFlight setup

The repository now contains two GitHub Actions workflows:

- **iOS Build Check** — builds the app for the iOS Simulator without signing.
- **Send to TestFlight** — manual release workflow for signed App Store/TestFlight builds.

## Required GitHub Actions secrets

In the repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:

1. `APPLE_TEAM_ID` — Apple Developer Team ID.
2. `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key ID.
3. `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect issuer ID.
4. `APP_STORE_CONNECT_PRIVATE_KEY` — the complete contents of the downloaded `AuthKey_XXXXXXXXXX.p8` file, including the BEGIN/END PRIVATE KEY lines.

Do not commit the `.p8` file to GitHub.

## App identifiers

The workflow expects:

- Bundle ID: `com.brandongood.liferoute`
- Xcode project: `LifeRoute.xcodeproj`
- Scheme: `LifeRoute`
- Marketing version: `0.3.0`

Each workflow run uses the GitHub Actions run number as the build number so repeated TestFlight uploads do not reuse the same build number.

## First release

1. Make sure the four secrets above are present.
2. Open the repo's **Actions** tab.
3. Select **Send to TestFlight**.
4. Choose **Run workflow**.
5. Watch the Archive, Export, and Upload steps.
6. After Apple's processing completes, the build should appear in App Store Connect/TestFlight.

The workflow uses automatic signing and an App Store Connect API key. If Apple rejects automatic signing on the first attempt, inspect the workflow log; the most likely remaining issue will be the Apple Team/bundle identifier's signing configuration rather than the app code itself.
