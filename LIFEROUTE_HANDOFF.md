# LifeRoute current engineering handoff

## Active workstream — v0.8.2 Build 114 physical-model root cause

- Current TestFlight candidate: LifeRoute v0.8.2 Build 114
- Exact Build 114 and branch base: `f2be4b10cbd9725a679e6a73db7cf94899ce7284`
- Branch: `fix/v0.8.2-session-note-physical-model-root-cause`
- Separate light-hygiene PR #119 remains an unmerged draft and is not this branch's base.
- Do not merge or dispatch TestFlight without product-owner authorization.

Physical QA showed the Build 114 state path `generating` → `repairing` →
explicit degraded fallback. Code tracing rules out a runtime exception or final
result substitution for that path: both model requests returned text, the
pipeline validated each candidate, and the UI displayed the pipeline's fallback
result and provenance. A successful fallback also means no structured screenshot
measurement was present, because measurement-bearing evidence fails closed
instead of constructing a source-only fallback.

The Mac's available Foundation Models runtime reproduced the same failure class
with the exact synthetic physical facts and Build 114 contract. Three unchanged
pipeline trials ended in fallback three out of three times. Initial candidates
retained rough dictation or changed attribution; repairs copied prompt/template
scaffolding or added unsupported clinical conclusions. Guided output, a minimal
delimiter-based repair prompt, and greedy sampling each failed to recover. A
professional target draft passes the same validator. The supported classification
is therefore model-quality failure with bounded-repair nonrecovery, not a proven
validator, OCR, runtime, provenance, or fallback defect. Mac behavior is strong
comparative evidence, not a substitute for exact physical-iPhone candidate codes.

This branch adds a privacy-safe `SN-DIAG-1` receipt. It records initial and repair
candidate presence/size, sentence and paragraph counts, source-overlap metrics,
rough-fragment counts, issue and hard-blocker codes, structured measurement
coverage counts, repair-attempt reasons, fallback reason, and final provenance.
It carries the receipt into degraded runtime state, logs the same bounded data
through OSLog in release builds, and offers Copy troubleshooting details without
including facts, OCR, target names, identifiers, or generated narrative.

Current local evidence: 162 executable Session Note assertions; preparation,
fast/full validation, Debug and Release Simulator app builds, standalone and
embedded Live Activity extension builds, native Simulator smoke, the diff
whitespace check, and zero unexpected compiler warnings pass. No prompt, retry, validator,
fallback, OCR, glass/readability, routing, or full-day behavior changed. Another
authorized physical build is required to capture exact iPhone pass diagnostics
and decide whether Apple Foundation Models remains the architectural ceiling or
a candidate-specific validator defect is exposed.

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
