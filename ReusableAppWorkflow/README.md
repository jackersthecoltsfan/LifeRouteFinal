# Reusable iOS workflow templates

This directory contains non-production examples for bootstrapping another iOS
repository. Nothing here owns LifeRoute production CI, validation, signing, or
release behavior. LifeRoute production owners are `scripts/` and
`.github/workflows/` at the repository root.

The bootstrap creates reviewable starting points for:

- an iOS Simulator CI workflow;
- an explicitly dispatched TestFlight workflow;
- a deterministic validation-oriented `prepare_build.sh` hook; and
- Apple CI signing-asset cleanup support.

Templates must be reviewed and adapted for a new app's project, targets,
extensions, bundle identities, exact-SHA authorization, validation, and signing
requirements before production use. Do not copy LifeRoute product patches or
historical audits into a new preparation hook.

The retired automatic-TestFlight example is retained under `archive/` for
archaeology only and is no longer installed by the bootstrap.

```bash
bash ReusableAppWorkflow/bootstrap-ios-workflows.sh \
  "MyApp" "MyApp" "MyApp.xcodeproj" "com.example.MyApp" "MyApp" "myapp"
```

Required secrets for a reviewed TestFlight adaptation are `APPLE_TEAM_ID`,
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and
`APP_STORE_CONNECT_PRIVATE_KEY`. Never commit their values or a private `.p8`.
