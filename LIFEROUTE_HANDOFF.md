# LifeRoute current engineering handoff

## Current authority

- Build 123 / v0.9.1 is the accepted stable physical baseline.
- Exact baseline and unchanged local/remote `main`:
  `f9c2b13c4c8c7c19c67e3f118176635ea8576808`.
- Sanitation branch: `chore/post-v0.9.1-sanitation-v1`.
- Isolated worktree:
  `/Users/brand/Documents/GitHub/LifeRouteFinal-post-v0.9.1-sanitation-v1`.
- Detailed evidence:
  `docs/POST_V091_SANITATION_VELOCITY_CHECKPOINT.md`.
- Stop point: `POST-v0.9.1 SANITATION / VELOCITY CHECKPOINT`.

Do not merge this branch, create Build 124, open a PR, or dispatch TestFlight
without separate owner authorization. Build 123's ordinary-glass opacity and
Visual Timer physical-loudness limitations remain deferred product issues.

## Sanitation v1 result

Five behavior-neutral, independently rollbackable slices are retained:

1. `93e6d842` — Debug Swift explicitly uses `-Onone`.
2. `711e385b` — historical `ClientViews.swift` is excluded from app compilation;
   its source and the historical `ContentView.swift` remain retained.
3. `4e4887a7` — five Swift contract runners share one content-addressed compiler
   cache while preserving focused entry points.
4. `32f09ec` — full validation reuses its source snapshot, workflow reads have
   one owner, release policy runs in fast validation, CI notices contract-only
   changes, and accepted assertion floors are executable.
5. `dc2dd8e` — a specific local Debug destination builds its active architecture;
   generic Simulator/CI remains dual architecture.

No production Swift implementation changed. Navigation, routing, Live Location,
Live Day/Activity, Session Note/Plan, Visual Timer behavior/audio, glass,
scenery, calendar, haptics, accessibility, app icon, signing, identifiers,
versions, release workflows, and the protected shared scheme remain frozen.

## Measured developer effect

- Preparation median: `0.07 -> 0.05 s`.
- Fast validation median: `0.06 -> 0.05 s`.
- Full validation median: `11.64 -> 3.76 s` warm; cold `10.10 s`.
- Generic fresh Debug: `201.11 -> 101.70 s`.
- Generic fresh Release: `223.99 -> 188.37 s`.
- Generic no-change Debug median: `1.24 -> 1.21 s`.
- Specific local fresh Debug, dual versus active architecture:
  `121.28 -> 62.53 s`.
- Specific local real leaf edit median: `8.71 -> 5.33 s`.
- Real generic shared-style edit median: `26.41 -> 22.28 s`.
- Real generic planning/core edit median: `11.58 -> 10.37 s`.
- Real generic leaf edit was noisy and slower: `7.98 -> 10.12 s`; retained as
  an explicit regression because the ordinary local leaf path, generic clean
  path, shared-style path, and core path materially improve.

Timestamp-only results are lower-bound invalidation measurements and are labeled
separately in the detailed report. Exact temporary source edits, hashes,
DerivedData paths, raw trials, medians, and task fan-out are also preserved there.

## Validation checkpoint

- Day Route: `163` assertions.
- Session Note: `162` assertions.
- Visual Timer feedback: `119` assertions.
- Runtime Feedback: `25` assertions.
- Scenery Effects: `54` assertions.
- Preparation, fast validation, cold full validation, and warm full validation
  passed.
- A negative Runtime Feedback floor test failed as intended, then the restored
  25-assertion fixture passed with its original hash.
- Contract cache invalidation created a distinct binary after a temporary source
  change, then the exact fixture bytes were restored.
- Fresh generic Debug at the final native compile surface and final fresh
  generic Release passed with app plus extension, dual architectures, and zero
  unexpected compiler warnings. The final branch also passed three no-change
  generic Debug builds.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

## Deliberate non-work

- PR #127-style wholesale splitting remains rejected because its recorded
  cleanup increased no-change Debug `1.97 -> 5.39 s`, fresh Debug
  `110.68 -> 245.92 s`, and fresh Release `116.38 -> 253.54 s`.
- Broader dead-declaration deletion, mega-file splitting, folder redesign,
  wrappers/protocols, Scenic Royal ownership extraction, smoke-suite ownership
  changes, and labeled-card/place-symbol abstractions are deferred.
- No benchmark infrastructure was added; the checkpoint report is the durable
  reproduction record.

## Next owner action

Review the isolated branch and the detailed checkpoint. The recommendation is to
keep all five small commits and stop. If a future cleanup proposes shared-style
decomposition, require a real source-byte benchmark that reduces the observed
19-file fan-out without slowing the specific local edit/build/run loop.
