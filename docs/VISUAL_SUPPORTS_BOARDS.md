# Visual Supports boards

Visual Supports contains **Boards**, **Image Generator**, and **Image Library**.
Boards contains First / Then, Choice Board, Visual Schedule, and Token Board.
All four are reusable visual artifacts. A schedule has no completion lifecycle;
a token board has empty printable slots and no earning or reward-unlock state.

## Ownership and saved data

`ClientVisualSupportCore` owns the existing General/client image libraries and
board records. `LifeRoutePersistenceStore` remains the single native writer.
Boards store image UUID references; rendering never generates or replaces an
image. Editing updates the same board ID and retains its creation date.

Schema 8 adds token boards and an optional schedule kind. Schema 7 files decode
without either addition. An old two-step schedule stays unclassified until the
user explicitly chooses **Edit as First / Then**. **Open as First / Then** also
offers that layout without changing the record. Readable existing `.visual`
files retain their canonical UUID filenames and exact bytes.

The existing storage recovery behavior for an unreadable image file remains:
it may load as a text visual. The new compatibility proof covers readable
saved images; it does not recover already missing or unreadable files.

Editors wait for the real writer before reporting a saved preview. On failure,
the in-memory draft keeps its ID for retry and the library displays an explicit
unsaved-change warning. A successful retry clears the warning.

## Shared layout

`BoardArtifact` is an immutable derived snapshot. `BoardCanvas` is the single
layout used for preview, PNG, and PDF. Images aspect-fit inside rounded square
cells with 0.75-point black outlines. Labels sit outside image-backed cells;
text-only cells show the label once. Export contains only the canvas.

- First / Then uses two ordered cells, or one column at accessibility text sizes.
- Choice supports eight items in two columns or nine in three columns. A column
  change cannot silently discard a selected image.
- Visual Schedule uses a vertical sequence with four steps per page. Preview
  provides previous/next page controls; exported PNG files and PDF pages retain
  the same boundaries and step order.
- Token Board supports 3–10 empty slots and a reward image, label, or both.
- Accessibility text sizes place schedule/reward images above their labels.

Preview captures its width and Dynamic Type setting for export. PDF uniformly
scales that exact layout to a 612-point page width. **PDF page height follows
content; it is not fixed US Letter pagination.** A print dialog can fit the
artifact to the selected paper size.

## Export, privacy, and work bounds

The explicit Export menu offers Share Image, Save Image to Photos, and Share
PDF / Save to Files. Photos uses add-only permission. PNG pages are newly
encoded board pixels; source filenames, source EXIF/GPS, client codes, and
private paths are not copied into export names or metadata. Filenames use the
board kind, UTC date, and page index, for example
`LifeRoute_VisualSchedule_2026-09-15_001.png`.

The user's chosen Photos, Files, or sharing destination can follow their own
cloud settings. LifeRoute does not promise those destinations remain local.

ImageIO decoding runs in an actor with a bounded cache. Preview retains one
page's decoded images, and export loads/releases pages sequentially. PNG
allocation is bounded before rendering: at most 20 million pixels, an
8,000-pixel height, and a minimum useful output width. Excessively tall labels
produce an actionable error instead of a clipped or blank artifact. Native
ImageRenderer drawing still runs on the main actor during the explicit export.

Partial exports are removed on failure. Temporary completed exports are removed
after Photos completion or share-sheet dismissal. Preview dismissal is disabled
while an export is being prepared. Process termination can leave files in the
system temporary directory until the operating system purges them.

## Verification entry points

- `bash scripts/run_visual_support_persistence_tests.sh`: actual schema 7 disk
  fixtures, source bytes, same-ID edits, ownership, deletion, failed writes/retry.
- `python3 scripts/run_board_artifact_render_review.py --help`: copies the exact
  production renderer into a separate Simulator fixture app, inspects PNG/PDF
  content, page order, metadata, accessibility layouts, bounds, and determinism.
- `python3 scripts/run_board_production_ui_tests.py --help`: exercises actual
  production routes using synthetic Simulator data, preserving and restoring
  pre-existing native state and preferences with hash verification.

Mechanical tests do not establish physical visual acceptance, Photos/Files
destination behavior, or the perceptual quality of native Liquid Glass.
