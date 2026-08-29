# LifeRoute — GitHub to TestFlight

LifeRoute uses automatic validation with **explicit-confirmation-only TestFlight release**.

Passing CI never uploads an app. Ordinary pushes never dispatch the TestFlight workflow. A release happens only after the product owner explicitly authorizes it.

## Normal release sequence

1. Relevant changes land on `main`.
2. **iOS Build Check** prepares the exact shared source, runs regression checks, and compiles the simulator build.
3. **Publish Web Preview** runs when the web/runtime artifact changed and publishes the validated browser preview.
4. **Release Policy Check** validates release/workflow isolation when release documentation or workflow architecture changes.
5. ChatGPT/Codex reports the validated state. TestFlight remains untouched.
6. The product owner explicitly authorizes a TestFlight release.
7. The release is started either with GitHub's **Run workflow** control for `Send to TestFlight`, or through the guarded assistant release-request bridge.
8. `testflight.yml` prepares/audits again, validates Apple credentials and bundle IDs, archives, exports, uploads, and cleans temporary signing assets.
9. The exact **Upload to TestFlight** step is verified before the release is reported as successful.

## Assistant release-request safeguard

The assistant path exists so the product owner can authorize a release in ChatGPT even when the connected GitHub tool does not expose workflow dispatch directly.

ChatGPT/Codex must **not** create the release request until required validation is already completed successfully. The bridge is intentionally fail-fast and does not hold a runner while waiting for CI.

A request is eligible only when:

- it is a newly opened GitHub issue;
- the issue author is the repository owner;
- the issue title is exactly `LifeRoute TestFlight release @ <current main SHA>`, binding the request to an exact-SHA release target;
- the body is exactly one of:
  - `AUTHORIZED_TESTFLIGHT_RELEASE=YES`
  - `AUTHORIZED_TESTFLIGHT_RELEASE=YES;REQUIRE_WEB_PREVIEW=YES`

The bridge rechecks that exact main SHA before validation and again before dispatch, requires a completed successful release-equivalent iOS validation, requires a completed successful release-equivalent web preview when requested, then dispatches `testflight.yml` with the same authorized SHA.

A feature request, successful build, request to continue, request to launch, or web-preview request does **not** authorize TestFlight.

## GitHub Actions outage rule

Do not create an assistant release request while GitHub Actions is degraded or in outage. Follow `GITHUB_ACTIONS_RUNBOOK.md` first. Release authorization remains valid, but dispatch waits until GitHub service health and required validation are reliable.

## Sole release path

`.github/workflows/testflight.yml` is the only workflow allowed to contain Apple signing, IPA export, or TestFlight upload machinery.

It remains `workflow_dispatch` only. Other workflows may validate or dispatch it through the explicitly guarded assistant bridge, but may not sign/upload an app themselves.

## One-time GitHub secrets

Repository **Settings → Secrets and variables → Actions** requires:

1. `APPLE_TEAM_ID`
2. `APP_STORE_CONNECT_KEY_ID`
3. `APP_STORE_CONNECT_ISSUER_ID`
4. `APP_STORE_CONNECT_PRIVATE_KEY`

The private-key secret contains the complete contents of the App Store Connect `.p8` key. Never commit the `.p8` file, private certificates, or private keys.

The same App Store Connect API key can generally be reused for routine LifeRoute releases while its permissions remain valid; a fresh key/certificate should not be created for every build.

## App identifiers

- Bundle ID: `Com.Brandongood.LifeRoute`
- Live Activity bundle ID: `Com.Brandongood.LifeRoute.LiveDay`
- Xcode project: `LifeRoute.xcodeproj`
- Scheme: `LifeRoute`

The Xcode project owns synchronized app/extension marketing version `0.8.1` and one synchronized source development build number. The GitHub TestFlight workflow intentionally overrides the app and extension build number with its run number.

## Signing cleanup

GitHub-hosted Macs are ephemeral, but Xcode automatic signing can create Apple-side development certificates/provisioning assets during release work.

The release workflow snapshots existing signing assets before archive/export and cleans temporary assets created by that run. Existing Distribution assets are not intentionally removed.

TestFlight release concurrency is serialized so two release Macs do not create/sign at the same time.

## Release-control labels/tags

`[no-testflight]` and `[web-only]` may still be used as descriptive commit metadata, but they are not the security boundary. **No commit tag authorizes TestFlight.** Explicit release confirmation is always required.

## What the product owner should not need to do routinely

- Open Xcode or use a PC/Mac just to produce a build.
- Download/convert `.p8` or `.p12` files again.
- Create a distribution certificate for every release.
- Increment build numbers manually.
- Manually run ordinary CI checks.
- Read GitHub logs when ChatGPT/Codex can inspect them.

For routine TestFlight releases, the product owner's required action is the explicit release decision plus real-device testing after the build becomes available.
