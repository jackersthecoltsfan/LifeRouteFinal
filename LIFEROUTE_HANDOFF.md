# LifeRoute current engineering handoff

## Active workstream — v0.8.1 clean physical-regression reintegration

- Branch: `fix/v0.8.1-clean-reintegration`
- Exact canonical base: `4982fb5addd3affb8bf123b8631b3d07cf9d87e8`
- Native-affecting validated head: `9c4be0d1ee9a57d06127ba9e1187a28cd2fd64cc`
- Draft PR: #103
- Rollback reference: `checkpoint/pre-canonical-baseline-build106`

PR #101 and donor commits `12d000b` through `32fc6d1` were inspected as
reference material only. The preservation donor `11b521d` was also reviewed.
No donor branch was merged or replayed. The PR #102 direct-source build,
warning budget, Simulator, extension, WebView quarantine, and exact-SHA release
architecture remain authoritative.

## Selectively reintegrated product behavior

- Session Note keeps the canonical actor-backed runtime, six in-memory
  attachments, explicit terminal states, stale-request protection,
  cancellation/background handling, previous-draft preservation, and
  supplied-facts-only on-device Foundation Models boundary. After one bounded
  correction pass, a substantive sanitized narrative is preserved instead of
  being discarded solely for residual formatting.
- ABA visual generation interprets common functional concepts before forming
  the Apple artwork prompt. LifeRoute still renders the exact user label
  separately and saves only through the protected native visual library.
- Exposed Visual Schedule AI, builder, and saved-schedule entry points are
  removed. Dormant schedule domain/types and persisted data remain intact;
  Choice Boards, First / Then, icon creation, and protected storage remain.
- The five root sections page horizontally as Today, Calendar, Tools,
  Resources, and Setup. The custom toolbar shares the same router selection
  and hides throughout deep Tools flows. Tools uses the refined filled glyph.
- App, extension, validator, documentation, and the existing exact-SHA
  TestFlight workflow are synchronized at marketing version 0.8.1.

## Intentionally omitted donor material

- Historical patch/audit reconstruction and all compatibility-only commits
  following the initial v0.8.1 donor commit.
- Old `prepare_build.sh` materialization, icon regeneration/fallbacks, legacy
  audit rewrites, generated-source churn, and AppIcon replacement.
- Donor Swift copies that would replace stronger canonical PR #102 owners.
- `11b521d` theme catalog, renderer, Theme Center, and Today rewrites from the
  contaminated consolidation workstream.
- Checkpoint/history relocation reversals and any WebView, CI architecture,
  warning-budget, Simulator, extension, or release-policy redesign.

## Validation evidence

Local Windows checks on the native-affecting head:

- `scripts/validate_current.py fast`: passed.
- `scripts/validate_current.py full`: passed.
- `git diff --check`: passed.

GitHub Actions at `9c4be0d1ee9a57d06127ba9e1187a28cd2fd64cc`:

- iOS Current Baseline run `33273590732` / #982: passed.
- Prepare canonical source, fast validation, and full validation: passed.
- Debug and Release app + embedded Live Day extension: both passed.
- Native Simulator smoke: passed across the five root sections plus theme
  motion and Reduce Motion fixtures.
- Compiler warning budget: 2 classified no-AppIntents toolchain notices and 0
  unexpected warning lines.
- Release Policy Check run `33273590772` / #171: passed.

This Windows host has no Bash/WSL, Xcode, Simulator, or Apple device runtime;
the exact shell wrappers and Apple-native gates therefore ran in GitHub CI.
Physical-device Foundation Models, Image Playground, paging/gesture feel,
deep-toolbar behavior, silent-mode, thermal, and Reduce Motion checks remain
required before promotion.

## Release boundary

Keep PR #103 in draft. Do not merge and do not trigger TestFlight until the
product owner separately authorizes the next step after review. `main` remains
at the validated PR #102 baseline, and no TestFlight action occurred during
this reintegration.
