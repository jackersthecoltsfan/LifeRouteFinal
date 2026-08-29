# LifeRoute Project Handoff

## Active checkpoint — v0.8.1 Build #106 physical-regression repair

The current checkpoint is isolated from `main` on:

- Branch: `fix/v0.8.1-build106-physical-regressions`
- Build #106 physical baseline: `6aaf9ac5234acd3178701fe0f4494675833b84fd`
- Follow-up implementation checkpoint: pending the v0.8.1 merge SHA

The v0.8.1 work remains a cumulative deterministic materialization layer. Checked-in Swift stays at the repository baseline; `scripts/prepare_build.sh` applies the authoritative patch scripts and now includes the focused v0.8.1 audits for Session Note, visual-support interpretation, paging/toolbar policy, and release-prep checks.

Implemented behavior:

- Build #106 physically exposed a failing Session Note generation path, a generic/literal visual-support interpretation path, abrupt screen movement, a toolbar that stayed in the way on deep screens, and an exposed Visual Schedule surface that should not have remained in the current product UI.
- v0.8.1 repairs Session Note with bounded generation, visible terminal failure states, preserved drafts/attachments, and a recoverable repair path that still preserves Master ABA output quality.
- v0.8.1 reworks the visual-support prompt pipeline so LifeRoute interprets the user concept before constructing the Apple image prompt, keeping the generated artwork aligned with ABA/PECS-style functional visuals and native labels.
- v0.8.1 removes the exposed Visual Schedule entry points while keeping Choice Boards, First / Then, and the protected visual library intact.
- v0.8.1 adds horizontal paging between Today, Calendar, Tools, Resources, and Setup, keeps the same authoritative router, and hides the custom toolbar on appropriate deep tool/editor screens so it stops crowding focused flows.
- The root theme clock remains protected and single-owned; the theme catalog, timer cadence, calendar flow, Live Activity, and persistence contracts remain unchanged unless explicitly noted above.

The previous Build #106 App Store Connect upload succeeded, but physical-device testing showed the checkpoint was not clean enough to promote. Treat Build #106 as the defective physical baseline until this v0.8.1 branch is validated and released.

This Windows environment has no local Xcode, Simulator, or XcodeBuildMCP connection, so visual/runtime fixture capture was not performed here. Device-only Apple Intelligence, Image Playground, Foundation Models, physical-device pacing, thermal, silent-mode, and Reduce Motion validation remain required. Keep the PR in draft until the v0.8.1 validation and release steps are complete.

## Historical checkpoint — v0.8.0 note-runtime repair plus completed theme library

Read `LIFEROUTE_V0_8_0_NOTE_THEME_INTEGRATION_HANDOFF.md` for the preceding note-runtime/theme integration history and its validation evidence.
