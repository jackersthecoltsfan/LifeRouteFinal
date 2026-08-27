# LifeRoute v0.7.0 — Visual Contract and UI Architecture

This document is **Checkpoint 0** for the native SwiftUI v0.7.0 overhaul. The approved v0.7.0 target preview supplied by the product owner is the visual source of truth. The functional baseline remains v0.6.3 TestFlight build #83 at main SHA `9471190b41c073a39c100cd2482f0b7b665d714b`.

Checkpoint 0 changes no feature behavior. **Build A** may restyle the global shell and shared visual primitives only; screen-family redesigns remain in later builds.

## Compact visual implementation checklist

### Background treatment

- Use a deep navy / near-black app base with restrained blue depth rather than generic grouped-form gray.
- Keep content readable over the background with intentionally layered dark surfaces.
- Core themes remain **color schemes only**: no decorative symbols, watermark artwork, random imprints, or scene illustrations.
- Do not redesign app-wide Scenery behavior in Build A. True persistent Scenery architecture is reserved for **Build F**.

### Card geometry and material

- Prefer dark translucent/navy panels with continuous rounded corners in the roughly 16–20 pt visual range.
- Use thin, restrained strokes to separate cards from the page.
- Keep elevation subtle: short soft shadow or localized accent glow, never broad neon bloom.
- Accent/selected cards may use a colored tint or border while remaining visually dark and legible.

### Typography hierarchy

- Primary text is high-contrast and usually white on dark themes; secondary metadata is muted.
- Screen headers are compact and intentional, not oversized form-style large titles.
- Use small uppercase section labels for hierarchy where the preview does so.
- Gold/accent color communicates selection and priority, not body text everywhere.
- Preserve Dynamic Type and avoid fixed layouts that force labels to clip or wrap vertically.

### Spacing rhythm

- Base rhythm: compact 8 pt, standard 12 pt, comfortable 16 pt, spacious 24 pt.
- Default page horizontal inset is approximately 16 pt.
- Card-to-card spacing should generally land near 10–12 pt.
- Maintain clear bottom safe-area clearance above the tab shell.

### Icon treatment

- Prefer SF Symbols or equivalent native vector symbols.
- Use crisp line/filled variants according to selection state.
- Primary chrome/action icons use the active theme accent; semantic tools may use restrained supporting hues.
- Icon containers are compact rounded squares/circles with dark tinted fills rather than oversized illustrations.

### Navigation and tab bar

- Preserve the exact five top-level destinations and existing router ownership: **Today, Schedule, Tools, Resources, Setup**.
- Keep one `NavigationStack` path per tab under `AppRouter`; do not introduce a competing navigation owner.
- Build A may restyle the existing native `TabView` / UIKit bar appearance, but it must not replace routing behavior.
- Bottom navigation uses a dark translucent surface, subtle separator, accent-selected icon/title, and muted unselected items.
- The selected state may receive a restrained glow/pill treatment only if it remains robust across supported iPhone sizes.
- Top navigation remains compact, with accent-colored actions and clear back behavior.

### Buttons

- Primary actions: full-width where appropriate, approximately 48–50 pt minimum visual height, accent/gold gradient or fill, strong contrast, continuous rounded corners.
- Secondary actions: low-contrast dark fill with thin accent/neutral stroke.
- Preserve at least 44 pt practical touch targets.
- Press feedback should be restrained and must respect Reduce Motion.

### Selected states and chips

- Compact filters/chips use capsule geometry.
- Selected chips use accent/gold fill or outline with strong text contrast.
- Unselected states remain clearly tappable without competing visually with the selected state.

### Strokes, shadows, and glows

- Default to approximately 1 pt strokes.
- Use small localized accent glows for focus/selection only.
- Avoid heavy drop shadows, large blur fields, or persistent neon effects.

### Responsive iPhone behavior

- Portrait iPhone is the primary target, including compact-width devices.
- Five tab labels must remain readable and tappable without clipping or overlap.
- Prefer flexible frames, layout priority, `ViewThatFits`, adaptive grids, and content-driven sizing over fragile fixed widths.
- A two-column card grid is allowed only where width supports it; collapse to a single column rather than squeezing content.
- Large Dynamic Type must not produce catastrophic overlap; landscape should remain usable even when it is not the primary visual target.

### Scenery behavior

- Build A preserves current theme persistence/backdrop behavior and shell transparency.
- No new remote-image dependency or scenery-specific screen rewrite belongs in Build A.
- Build F owns the deliberate conversion to true app-wide Scenery with adaptive readability layers.

## Architecture decision: restyle versus replace

### Reuse and protect

- `AppRouter` remains the sole top-level navigation owner.
- `AppSection` remains the canonical five-tab map.
- Existing per-tab `NavigationPath` state remains intact.
- `V054ContentView` keeps the existing `TabView` plus five `NavigationStack` destinations.
- `LifeRouteThemeStore`, `LifeRouteThemePalette`, theme persistence, and environment injection remain the color source.
- Existing calendar, routing/location, saved-place, client, session-tool, timer/audio, Live Activity, migration, and Apple Foundation Models logic are outside Build A visual scope.
- `LifeRouteWebView.swift` and `LifeRoute/Web` remain quarantined from the active native runtime.

### Restyle in Build A

- Global page/shell background layering.
- Shared design tokens: spacing, radii, page inset, control heights, strokes, elevation.
- Shared card, button, section-label, chip/pill, icon-container, and compact-header primitives.
- Native navigation-bar and tab-bar chrome.
- Safe-area and bottom-bar presentation.
- Selected/unselected tab appearance.

### Replace later, not in Build A

- Today/Home composition: Build B.
- Schedule/calendar/route-planning composition: Build C.
- Tools and ABA clinical workflow composition: Build D.
- Resources, clients, saved places, Setup and Theme Center composition: Build E.
- True app-wide Scenery architecture: Build F.
- Final motion/responsiveness/accessibility cleanup: Build G.

## Build A implementation guardrails

1. Start from the last accepted green main baseline after Checkpoint 0 is merged.
2. Implement shared shell/design-system changes through the deterministic preparation architecture so `scripts/prepare_build.sh` still represents the actual shipped tree.
3. Do not remove, rename, or hide any top-level tab or existing destination.
4. Do not rewrite business/domain state while restyling the shell.
5. Keep iOS 16 compatibility for the current deployment target.
6. Keep Core themes free of decorative artwork/imprints.
7. Preserve current Scenery behavior until Build F.
8. Require the full preparation/regression suite and an actual iOS Simulator compile before merge.
9. Do not begin Build B until Build A has passed native validation and visual review.

## Checkpoint 0 acceptance

Checkpoint 0 is complete when this visual/architecture contract is committed, its focused audit passes through the canonical preparation path, and the repository's iOS Build Check completes successfully without production behavior changes.
