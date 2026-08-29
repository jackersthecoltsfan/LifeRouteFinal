# Historical build archaeology

These files preserve LifeRoute's pre-canonical reconstruction history. They are
not production source owners and must not run from current preparation, pull
request validation, main validation, Pages, or release workflows.

- `legacy_precanonical/`: pre-versioned native/WebView patches and audits.
- `v0_5/`: native v0.5 reconstruction and compatibility checks.
- `v0_6/`: v0.6 reconstruction, hotfixes, and icon generation.
- `v0_7/`: Build A-E, theme-phase, v0.7.1, and fixture tooling.
- `v0_8_historical/`: cumulative v0.8.0 patches, audits, and old release marker.

The shipping Build #106 result produced by this history is checked directly into
`LifeRoute/`, `LifeRouteLiveActivityWidget/`, and `LifeRoute.xcodeproj/`.
Current automation begins at `scripts/prepare_build.sh` and uses
`scripts/validate_fast.sh` or `scripts/validate_full.sh`.

Do not restore an archived script to the active build path to implement a new
change. Change canonical source and a current semantic validator instead.
