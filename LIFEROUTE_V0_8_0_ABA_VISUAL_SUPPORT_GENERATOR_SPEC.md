# LifeRoute v0.8.0 — ABA Visual Support Generator Specification

## Status

Approved product direction for the v0.8.0 functionality phase. This work follows the completed Master ABA Session Note foundation and must remain incremental.

## Product workflow

LifeRoute is not implementing a generic image playground. The product workflow is:

`PHOTO / TEXT → VISUAL-SUPPORT ICON → PERSONAL ICON LIBRARY → VISUAL SCHEDULE / CHOICE BOARD → PRINT / PDF / SHARE`

The purpose is to reduce the time required for an RBT, BCBA/LBS, clinician, teacher, or caregiver to turn a real object, place, activity, or concept into a usable ABA intervention material.

Photo-specific visuals are a first-class requirement because a child may recognize their actual cup, stroller, home, playground, tablet, store, or other environment more readily than an unrelated generic stock image.

## Canonical image-generation contract

For every generated visual-support icon:

- Create a realistically illustrated cartoon that remains immediately recognizable as the supplied real object, location, activity, or concept.
- Use clean bold outlines, soft natural shading, bright but natural colors, strong contrast, and a simple child-friendly composition.
- Produce square 1:1 artwork on a clean white background.
- Center the primary subject and let it occupy most of the available artwork area.
- Remove distracting or irrelevant background detail.
- Preserve identifying physical characteristics that support recognition and generalization.
- Do not introduce unrelated objects or scenery.
- Do not include people unless a person is necessary to communicate the requested concept.
- Maintain a consistent illustration style, line weight, shading approach, proportions, background, icon dimensions, typography, and label placement across the visual library.
- Prioritize functional recognition and visual clarity over decorative detail.
- Support visual schedules, choice boards, First/Then boards, communication books, transition supports, activity schedules, and related ABA visual supports.

## Exact-label rule

The user-supplied label is authoritative.

LifeRoute must not depend on generative-image text rendering for the label. Generated artwork should contain no caption, letters, logo, watermark, or embedded label. LifeRoute renders the exact user label as native text beneath the artwork so spelling, typography, accessibility, editing, and future print/PDF output remain deterministic.

## Native implementation direction

Use Apple’s Image Playground framework on supported iOS 26 Apple Intelligence devices:

- Seed the system generation sheet with the canonical ABA visual-support prompt.
- Allow either text-only generation or one optional reference image.
- Request square output and the Illustration style.
- Disable person personalization because unrelated people do not belong in this clinical visual-support workflow.
- Let the user review/refine the result in the system Image Playground UI before LifeRoute accepts it.
- Copy the approved temporary result into LifeRoute-owned image data and normalize it to a square white canvas before saving.
- Preserve the existing local photo/text icon workflow as the fallback on unsupported devices or whenever the user does not want generation.
- Store approved icon results through the existing `ClientVisualSupportCore` and protected native persistence owner. Do not introduce a second icon-library or persistence owner.

Image Playground may use Apple Intelligence and Private Cloud Compute under Apple’s system privacy protections. LifeRoute does not operate its own image-generation server and does not add a third-party API key in this phase.

## Phased roadmap

### Foundation checkpoint

- Canonical master prompt
- Single reference photo or text-only input
- Exact editable label
- System Image Playground review/regeneration
- Save approved result into the existing General/client icon library
- Graceful unsupported-device fallback
- Dedicated regression audit and actual Simulator compilation

### Batch checkpoint

- Select multiple reference photos
- Assign/edit labels per item
- Batch queue and progress state
- Review/regenerate an individual item without discarding the batch
- Consistency controls across the set
- Cancel/retry behavior and bounded memory use

### Builder checkpoint

- Reuse generated icons in Choice Boards, Visual Schedules, First/Then, and communication supports
- Improve search, filtering, duplication, editing, and library organization

### Print/PDF checkpoint

Default printable output:

- US Letter, 8.5 × 11 inches
- portrait
- 2 columns × 4 rows
- up to 8 standard icons per page
- consistent card dimensions
- adequate print margins and whitespace
- thin cutting guides
- allowance for cutting and laminating
- exact readable labels
- automatic additional pages
- print-ready PDF export/share

Future controls may include card size, rows/columns, portrait/landscape, labels on/off, borders, cut guides, schedule orientation, and icons per page.

## Protected boundaries

- Preserve the existing General and client-specific visual-library isolation.
- Preserve durable client UUID ownership and current icon/board/schedule persistence.
- Preserve existing Choice Board, Visual Schedule, First/Then, photo icon, and text-only icon behavior.
- Do not introduce a duplicate navigation stack, visual-state owner, or persistence store.
- Do not upload a TestFlight build solely for this code change.
- Do not implement batch generation or PDF export in the foundation checkpoint.
