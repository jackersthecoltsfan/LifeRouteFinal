# LifeRoute current engineering handoff

## Active workstream — v0.8.2 physical-QA corrections

- Branch: `fix/v0.8.2-physical-qa-corrections`
- Exact canonical base: `ab99e3eb421875e1a1d8b2a8d9191a8c5ab977a5`
- Product scope only: Session Note reliability/input behavior and Visual AI
  Studio consolidation.
- Separate release-plumbing PR #106 is out of scope and remains untouched.

This branch started in an isolated worktree from the exact canonical base. The
dirty preservation worktree and its uncommitted files were not modified. The
checked-in Swift source remains canonical; `scripts/prepare_build.sh` remains
validation-only and does not replay historical patches.

## Session Note corrective architecture

- `SessionNoteEvidencePacket` creates role-neutral, bounded model evidence.
  Typed facts remain primary, clear quantitative OCR is supplemental, and
  saved profile material is reduced to terminology context rather than event
  evidence. Profile/client identifiers are scrubbed before prompt assembly.
- `ABATerminologyNormalizer` canonically handles the approved high-confidence
  ABA terms at safe word boundaries. Ambiguous abbreviations such as NET, ABC,
  SD, MO, and schedule abbreviations require ABA context; normal English such
  as “played in the net outside” remains unchanged. Normalization occurs on
  focus loss, keyboard Done, and immediately before generation rather than on
  every keystroke.
- The Foundation Models instructions are compact. The first bounded request
  retains normalized typed facts, quantitative OCR, and small terminology
  context. A context-size failure retries exactly once with the same typed
  facts, tighter quantitative OCR, and no saved context. A second context-size
  failure ends safely without clearing facts, screenshots, selection, editor
  state, or the previous draft.
- Generated text passes deterministic identifier scrubbing, ABA casing,
  Markdown/heading/list cleanup, paragraph repair, and validation for identity,
  terminology, data values/types, prompt levels, required closing language,
  unsupported absence claims, and obvious template/repetition. Unsafe output
  receives at most one bounded repair request; a still-unsafe result is not
  accepted as the editable final draft.
- The existing timeout, cancellation, background cancellation, active-request
  isolation, stale-result rejection, and previous-draft preservation remain.
  Runtime logs contain state/error transitions only, never clinical content or
  identifiers.
- Session Facts and the editable draft use native focus ownership, standard
  autocorrection/spellcheck and sentence capitalization, a visible keyboard
  Done action, interactive scroll dismissal, and practical header-tap
  dismissal. Generation clears focus before starting.

## Visual AI Studio corrective architecture

- Visual AI Studio now embeds the Illustrated Icon Generator directly; the
  redundant “Open Illustrated Icon Generator” subpage action is removed.
- The single screen presents explicit Text only, Take photo, and Photo Library
  input. Camera permission denial and camera unavailability keep text/library
  paths usable. Reference and generated images remain in memory until the user
  explicitly saves an approved visual through the existing protected,
  client-isolated library.
- Exact label text remains separate from artwork interpretation. The existing
  functional ABA visual-support prompt, reference/result comparison,
  regenerate/review/save flow, General versus client library isolation, Choice
  Boards, First / Then, and manual workspace remain available.
- Visual Schedule remains absent from the user-facing Tools experience. Dormant
  storage and compatibility types remain unchanged.
- Root horizontal paging, root/toolbar synchronization, hidden page indicators,
  deep Tools/Session Note toolbar suppression, and back navigation were not
  refactored.

## Deterministic validation

- Pure-Foundation Swift fixtures cover terminology and ambiguous English,
  client/clinician identity leakage, Markdown/headings/scaffolding, supported
  versus invented numeric data, measurement-type changes, prompt-level
  invention, normal/delayed/empty/unavailable generation, bounded repair and
  repair failure, context retry success/failure, timeout, cancellation,
  previous-draft preservation, typed-facts preservation, and stale-result
  rejection.
- `scripts/validate_full.sh` and the native Simulator smoke both run the Swift
  contract fixture executable. `scripts/validate_current.py` audits the new
  product contracts, direct Visual AI flow, version, and preserved navigation,
  privacy, WebView, and release boundaries.
- Windows semantic fast/full validation and `git diff --check` pass. Xcode,
  Simulator, app/extension Debug and Release compilation, warning-budget, and
  native smoke evidence must come from the draft PR’s macOS CI on the exact
  final branch head; this host has no Apple runtime or XcodeBuildMCP service.

## Release and deferred-work boundary

- Marketing version is staged as 0.8.2 for app and extension. The separate
  guarded TestFlight workflow intentionally remains at its existing v0.8.1
  contract; this product branch is not release-authorized.
- Do not merge, tag, dispatch TestFlight, upload to App Store Connect, or alter
  PR #106 from this workstream.
- Slightly smoother page transitions, deeper app-wide haptics, and the proposed
  timer sound/accelerando/crescendo/final-haptic redesign are deferred. Timer
  code is untouched.
- Physical iPhone validation remains final authority for Foundation Models,
  keyboard behavior, identifier/data fidelity, camera permissions, Image
  Playground output, and the consolidated Visual AI workflow. Do not declare
  v0.8.2 complete based on Simulator or CI alone.
