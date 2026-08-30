# LifeRoute current engineering handoff

## Active workstream — v0.8.2 Session Note runtime quality and glass readability

- Branch: `fix/v0.8.2-session-note-runtime-quality-and-glass`
- Exact base: `d0f16d7e14b3b57e617a4ecb9b3e3e5d08afd2d7` (`origin/main`, PR #115 / Build 113 source)
- Rescue evidence branch: `rescue/session-note-uncommitted-2026-08-30`
- Rescue commit: `9d405d1d3211d4fb81f8eb0688f13ff454e94801`, local-only and not pushed
- Do not merge or dispatch TestFlight without product-owner authorization.

Build 113 could accept a safe near-copy because professional presentation was
not a readiness requirement, and both pipeline and runtime discarded whether a
nonempty draft was generated, repaired, or conservatively preserved. The
preserved rescue work added useful professional-reconstruction prompting and
synthetic coverage but did not add provenance, near-copy detection, fallback UI
handling, or the runtime-quality gate; those valid prompt/test portions were
selectively reproduced rather than blindly cherry-picked.

The current branch adds typed `generated`, `repaired`, `fallback`, and
`rejected` outcomes; a separate professional-readiness contract; conservative
near-copy and rough-dictation detection; one bounded reconstruction pass using
the original evidence; and explicit degraded fallback UI. Structured screenshot
measurements fail closed when conservative fallback would lose target/value/type
or prompt association. Logs remain content-free and privacy-safe.

Text-heavy Session Note and Session Plan editors now share an
accessibility-aware readability surface inside the existing glass card. Outer
glass and scenery remain visible, while the editor backing responds to increased
contrast and Reduce Transparency. A DEBUG-only dense-text fixture was reviewed
on Mountains Day/Night, Core Ocean, Dynamic Royal Current, extra-extra-large
Dynamic Type, increased contrast, and Reduce Transparency.

Current local evidence: 152 executable Session Note assertions; preparation,
fast/full validation, Debug and Release Simulator app/extension builds, native
Simulator smoke, and compiler warning budget all pass. The warning audit found
zero unexpected warnings. Simulator evidence does not validate real Foundation
Models prose; physical iPhone QA remains final authority for initial generation,
bounded repair, degraded fallback, OCR associations, and the visual result.

Branch publication and PR review are permitted for this workstream. Do not merge
or dispatch TestFlight without explicit product-owner authorization.

## Historical workstream — v0.8.2 Session Note validation severity

- Branch: `fix/v0.8.2-session-note-validator-severity`
- PR: #112, `Fix Session Note validation severity architecture`
- Exact base: `f02a144134c696a1364049b7e57e9dde91c15322`
- Validated code head: `25d1e6ae4840c191573d40789fd00ec0d6141b9b`
- Do not merge or dispatch TestFlight without product-owner authorization.

The former flat Session Note issue list is now a typed deterministic contract
with hard blockers, deterministic repairs, and nonfatal quality warnings.
Identity leakage, unsupported numeric/measurement/prompt data, context-only
events, inferred clinical claims, treatment changes, and invented supervisor
involvement remain hard blockers. Markdown, headings, lists, punctuation,
paragraph layout, unambiguous role terminology, and the approved continuation
close are normalized without an AI retry. Repetition and other benign prose
quality differences cannot cause terminal rejection.

The pipeline still permits at most one bounded Foundation Models repair. If a
hard blocker survives, a conservative fallback may return scrubbed typed facts
with the standard close when sufficient current-session evidence exists; saved
client context and OCR alone cannot manufacture fallback events. DEBUG logging
contains issue/repair codes and outcomes only. Terminal errors expose a safe
Identity, Evidence, or Clinical claim verification category without clinical
content.

PR-head CI run `33286466908` passed semantic validation (104 executable Session
Note assertions), Debug and Release app/extension builds, Simulator smoke, and
the compiler-warning budget (0 unexpected warnings). Policy run `33286466975`
also passed. Physical iPhone Foundation Models/OCR validation remains required;
recommended cases are safe paraphrases, mixed screenshot measurements,
supervisor guidance, formatting-heavy output, one-repair fallback, and a true
unsupported-data rejection with privacy-safe diagnostics.

## Previous workstream — v0.8.2 physical-QA corrections

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
