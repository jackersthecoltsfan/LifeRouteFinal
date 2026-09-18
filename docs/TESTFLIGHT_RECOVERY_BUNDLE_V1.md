# TestFlight Recovery Bundle V1

This document records the bounded D-01/D-02 recovery-evidence contract for
LifeRoute's current TestFlight workflow. It does not authorize a dispatch,
upload, release, or App Store Connect mutation.

## Current-state map at implementation start

The executed release owner is `.github/workflows/testflight.yml`. It remains a
manual `workflow_dispatch` workflow with exact-SHA checkout/current-main
guards, the existing validation gate, automatic signing, archive/export, IPA
upload, and signing-asset cleanup.

Before this change, the workflow:

- created `LifeRoute.xcarchive` and the export directory below the ephemeral
  runner scratch root;
- verified the archived app and widget version, build, and bundle IDs;
- uploaded the exported IPA as `LifeRoute-v0.9.1-TestFlight-build-<run>`;
- retained that IPA artifact for 7 days;
- did not retain the archive, app dSYM, widget dSYM, UUID relationships,
  source/tree identity, a release manifest, or a human-readable receipt.

The reusable `ReusableAppWorkflow/testflight.template.yml` is a generic
bootstrap template. It has different trigger and identity semantics and does
not describe LifeRoute's app-plus-widget exact-SHA release contract. The live
`.github/workflows/testflight.yml` is therefore the authoritative owner for
this application, and the generic template is intentionally not mechanically
duplicated in this V1 lane.

## V1 bundle contract

After archive/export and before the TestFlight upload, the live workflow runs
`scripts/testflight_recovery_bundle.py`. It fails closed unless it can verify:

- the exported IPA and archived app/widget bundles exist;
- archive and IPA marketing version, build number, and bundle IDs agree;
- every app Mach-O UUID is present in the application dSYM UUID set;
- every widget Mach-O UUID is present in the widget dSYM UUID set;
- the required dSYM bundles exist and are retained;
- the source commit and tree SHAs are full, lowercase Git identities.

The uploaded recovery artifact has this layout:

```text
LifeRoute-TestFlight-Recovery-<run>/
├── ipa/<exported IPA>
├── symbols/app/<application dSYM>/
├── symbols/widget/<widget dSYM>/
├── archive-source/
│   ├── Info.plist
│   ├── Products/Applications/<app>/Info.plist
│   ├── Products/Applications/<app>/PlugIns/<widget>/Info.plist
│   ├── dSYMs/
│   ├── BCSymbolMaps/                  (when produced)
│   └── SCMBlueprint                   (when produced)
├── manifest.json
└── RECEIPT.md
```

`archive-source` is an allow-listed archive-equivalent. It retains the
metadata, dSYMs, optional BCSymbolMaps, and optional source-control blueprint
needed for symbol/reconstruction recovery without copying the signed archive's
embedded provisioning profile or any runner signing material.

`manifest.json` uses stable sorted JSON keys and schema version 1. It records
source/tree identity, branch/ref, version/build, app/widget bundle IDs,
archive/export identity, workflow run identity, app/widget binary and dSYM
UUID arrays, matched UUID arrays, validation results, and SHA-256 records for
the IPA, each dSYM, and the archive-equivalent directory. A dSYM may also
contain companion `debug.dylib` UUIDs; those extra UUIDs are retained and
recorded while every shipped binary UUID must still be present. Directory hashes are deterministic over
sorted relative paths, byte sizes, and per-file SHA-256 values.

`RECEIPT.md` is a concise human-readable projection of the same evidence. The
generator receives only release identity and workflow metadata; it does not
read or serialize secret environment values. Its archive-equivalent allowlist
also rejects prohibited secret/provisioning-looking output paths.

## Retention and safety

The existing 7-day GitHub artifact retention is preserved for both the
original IPA artifact and the new recovery artifact. V1 does not increase the
retention period or paid storage exposure. A longer policy requires a separate
owner decision.

The workflow trigger, exact-SHA guard, signing/authentication steps, build
number strategy, archive/export commands, IPA upload command, distribution
behavior, and signing cleanup remain in their existing owners and order. This
lane does not dispatch the workflow or modify Build 127.
