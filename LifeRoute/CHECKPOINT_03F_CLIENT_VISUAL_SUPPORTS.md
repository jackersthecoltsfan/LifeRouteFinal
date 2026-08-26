# Checkpoint 03F — Client-Specific Visual Supports

Validation marker for the native functional-core rebuild.

Rules enforced by this checkpoint:
- Every visual icon belongs to one saved ABA-style client code.
- Choice boards can reference only icons belonging to the same client.
- First/Then visual pickers expose only the selected client's icon library.
- Visual schedules can reference only icons belonging to the same client.
- No general/unassigned visual-support library is active.
- Visual-support state remains session-only until checkpoint 04 persistence.
- Selected image data remains local to the native app state; no upload path is introduced.
- The legacy WebView visual-support runtime remains quarantined.
