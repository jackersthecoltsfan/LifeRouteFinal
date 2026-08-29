# LifeRoute current engineering handoff

## Active workstream

- Product baseline: LifeRoute v0.8.0 / shipped Build #106 structure
- Trusted base: `6aaf9ac5234acd3178701fe0f4494675833b84fd`
- Branch: `chore/v0.8.0-build106-canonical-baseline`
- Rollback reference: `checkpoint/pre-canonical-baseline-build106`
- Canonical source promotion: `d6fa77321bcb4fb03421cc6883ebb222ae7fffdd`

Phase A consolidated the historical deterministic reconstruction chain into
checked-in canonical source. Phase B removes the remaining source-level Swift
concurrency warnings and adds a strict unexpected-warning gate plus cache
hygiene. Product behavior, including known Build #106 physical defects, remains
intentionally unchanged. No v0.8.1 donor has been merged, cherry-picked, or
copied.

## Current architecture

The final Build #106 shipping Swift, Xcode project, extension, and assets are
checked in directly. `scripts/prepare_build.sh` is a fast validation-only
preflight. Use `validate_fast.sh` for development feedback and
`validate_full.sh` for merge/release-grade current invariants.

Historical patches/audits are under `scripts/archive/`. Historical handoffs and
checkpoints are under `docs/archive/`. They are not active build inputs. See
`docs/BUILD_ARCHITECTURE.md` and `docs/archive/build106-canonical-capture.md`.

Native/TestFlight is authoritative. The browser preview is separated and
classified in `docs/WEB_PREVIEW_CLASSIFICATION.md`; the legacy WKWebView runtime
remains outside app Sources and Resources.

## Release boundary

Do not merge this branch or upload TestFlight without explicit authorization.
The sole active release workflow is exact-SHA guarded and requires successful
current main CI, full validation, synchronized app/extension identity, signed
archive verification, and explicit dispatch.

PR #101 and `preserve/v0.8.1-uncommitted-product-donor` remain frozen donor
references for the later selective v0.8.1 re-port. They are out of scope here.

## Phase B validation boundary

Phase B is limited to warning debt and repository-quality cleanup. It does not
redesign or repair Build #106 product behavior. Before this branch advances,
run fast and full canonical validation, prove warning-assessor fixtures, and
require the GitHub macOS Debug/Release/extension/Simulator check to pass with
zero unexpected compiler-warning lines. Keep PR #102 unmerged until separately
authorized.
