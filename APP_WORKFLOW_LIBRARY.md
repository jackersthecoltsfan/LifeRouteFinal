# App Workflow Library

The reusable iOS build/release system is stored in `ReusableAppWorkflow/`.

For the full idea → TestFlight process, start with:

- `APP_CREATION_PLAYBOOK.md` — canonical streamlined workflow and manual-vs-automatic responsibilities.
- `TESTFLIGHT_SETUP.md` — LifeRoute's current exact-SHA, explicit-authorization GitHub → TestFlight release behavior.
- `ReusableAppWorkflow/README.md` — reusable architecture for future iOS apps.
- `ReusableAppWorkflow/bootstrap-ios-workflows.sh` — installs non-production workflow templates into a new app repository for review and adaptation.
- `ReusableAppWorkflow/BUILD_REPAIR_AUTOMATION.md` — two-attempt self-healing policy for failed builds.

The goal is to reuse this system rather than rebuilding CI, signing, TestFlight delivery, or failure-repair logic from scratch for each new app.

No Apple private keys or secret values are stored here.
