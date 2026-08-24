# App Workflow Library

The reusable iOS build/release system is stored in `ReusableAppWorkflow/`.

For any future iOS app, start with:

- `ReusableAppWorkflow/README.md`
- `ReusableAppWorkflow/bootstrap-ios-workflows.sh`
- the reusable CI/TestFlight templates
- the Apple signing cleanup helper
- `ReusableAppWorkflow/BUILD_REPAIR_AUTOMATION.md`

This is the canonical workflow pack created from the LifeRoute project. Reuse it rather than rebuilding the process from scratch.

No Apple private keys or secret values are stored here.
