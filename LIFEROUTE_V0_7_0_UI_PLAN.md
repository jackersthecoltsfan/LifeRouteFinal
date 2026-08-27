# LifeRoute v0.7.0 — Phased UI Overhaul Plan

## Purpose

LifeRoute v0.7.0 is the major native SwiftUI visual overhaul. The goal is to move from the current functional-skeleton UI to the polished target design without attempting the entire redesign in one risky release.

The work will be broken into independently testable TestFlight checkpoints. Each checkpoint must preserve the working v0.6.3 feature set and must pass the full native preparation/regression suite plus an actual iOS Simulator compile before it can become the new baseline.

## Starting baseline

- Repository: `jackersthecoltsfan/LifeRouteFinal`
- Native priority: iOS/TestFlight first; web preview never blocks native release work unless explicitly requested.
- Starting main SHA: `9471190b41c073a39c100cd2482f0b7b665d714b`
- Starting shipped app: LifeRoute v0.6.3, TestFlight build #83.
- Legacy `LifeRouteWebView.swift` and the old Web runtime remain quarantined.
- Existing functionality must remain intact during the redesign: calendar/event loading, selected-day browsing and route planning, saved places/clients, ABA session-note generation, timer, Live Activity, theme selection, location/routing, and all existing native tools.

## Visual direction

The finished interface should feel premium, modern, sleek, bold, professional, streamlined, and futuristic rather than like a generic form-based utility app.

LifeRoute's signature visual identity remains blue/gold at its core, with the broader theme system staying customizable. Core themes are color schemes only; they should not contain random decorative imprints or artwork. Scenery themes will eventually become true app-wide environments during the overhaul.

The previously approved target UI preview/image is the visual reference for v0.7.0. Because that exact image is not stored in this handoff, the new development chat should receive the target preview again before the first visual implementation PR. We should derive a short visual checklist from it before changing code so every build can be compared against the same target.

## Development rule for every checkpoint

For every UI checkpoint:

1. Start from the last green main SHA.
2. Use a narrow feature branch for that checkpoint only.
3. Keep business/data logic separate from visual work whenever possible.
4. Add or update audits that lock the intended UI structure without overfitting to incidental implementation details.
5. Open a PR.
6. Require the full preparation/regression suite to pass.
7. Require actual Xcode iOS Simulator compilation to pass.
8. Merge only after green native validation.
9. Run main-branch native validation again.
10. Send that checkpoint to TestFlight when visual/device review is useful.
11. Do not begin the next checkpoint until the current checkpoint is visually accepted or any critical regressions are fixed.

No giant multi-screen UI PRs.

---

# Checkpoint 0 — Visual contract and UI architecture

## Goal

Define the target before touching the major views.

## Work

- Re-upload the approved target preview to the new chat.
- Break the preview into reusable visual rules:
  - page background treatment;
  - card shape/radius/material;
  - spacing rhythm;
  - typography hierarchy;
  - icon size and treatment;
  - navigation bar/tab bar treatment;
  - button hierarchy;
  - selected/unselected states;
  - shadows/glows/strokes;
  - safe-area behavior;
  - scenery behavior;
  - compact iPhone layout rules.
- Identify which current components can be restyled versus replaced.
- Create a v0.7 design-system layer rather than hardcoding the same styling in every screen.
- Decide the exact navigation mapping without deleting or hiding existing functionality.

## Acceptance gate

No feature behavior changes. Current app must still compile and all tests remain green.

This checkpoint may stay internal and does not require a TestFlight build unless the new shell is already visible.

---

# Checkpoint 1 — Global shell and design system

## Goal

Make the app frame look like v0.7 while leaving individual screen content mostly unchanged.

## Work

- Introduce reusable v0.7 design tokens/components for:
  - page backgrounds;
  - cards;
  - headers;
  - pills/chips;
  - primary/secondary buttons;
  - icon containers;
  - section labels;
  - bottom navigation;
  - modal/sheet chrome.
- Redesign the global navigation/tab shell to match the target preview.
- Standardize safe-area and bottom-bar behavior.
- Preserve all existing tab destinations and routing during this checkpoint.
- Ensure Dynamic Type and reduced-motion behavior remain sane.
- Keep Core themes as clean color systems only.

## TestFlight checkpoint

**v0.7.0 Build A** — expected first v0.7 TestFlight build after #83.

## Acceptance criteria

- Navigation works exactly as before.
- No clipped tab labels or overlapping controls on supported iPhone sizes.
- No random theme artwork/imprints.
- Existing screens may still look old internally, but the global frame must be stable.

---

# Checkpoint 2 — Today/Home screen overhaul

## Goal

Redesign the highest-traffic screen first and make it the visual benchmark for every later screen.

## Work

- Rebuild the Today/Home composition to match the target preview.
- Preserve selected-day functionality introduced in v0.6.3.
- Preserve previous/next day navigation and compact date picker behavior.
- Preserve quick actions, Today's Overview/day overview, route launch, current location, Live Day/Live Activity, and gap suggestions.
- Make the layout responsive rather than relying on fragile fixed widths.
- Remove redundant visual blocks where the target design consolidates information, but do not remove functionality.
- Validate landscape/large Dynamic Type enough to avoid catastrophic layout breakage even though portrait iPhone remains the design priority.

## TestFlight checkpoint

**v0.7.0 Build B**

## Acceptance criteria

- The Today/Home screen visually matches the approved reference direction.
- Date selector cannot collapse into narrow vertical text.
- All Today actions still work.
- This screen becomes the reference implementation for cards, typography, and spacing used later.

---

# Checkpoint 3 — Schedule / calendar / day-week planning UI

## Goal

Bring calendar and route-planning screens into the same design language without modifying calendar behavior.

## Work

- Redesign Schedule views and event cards.
- Redesign day/week browsing controls.
- Redesign DayRoutePlanningView and route-choice presentation.
- Keep event source, persistence, selected-date behavior, locations, route estimates, and Google Maps handoff unchanged.
- Improve information hierarchy for event time, location, travel time, and leave-by information.

## TestFlight checkpoint

**v0.7.0 Build C**

## Acceptance criteria

- No calendar regression.
- Selecting another date still plans that date rather than silently reverting to today.
- Route handoff works.
- Today and Schedule now look like one product rather than two separate UI eras.

---

# Checkpoint 4 — Tools and ABA clinical workflow UI

## Goal

Redesign the Tools experience while protecting the most failure-sensitive functional areas.

## Work

- Redesign Tools landing screen and tool cards.
- Redesign ABA session-note entry/generation screen.
- Do not change the validated v0.6.3 context-window logic while doing visual work.
- Preserve selected-client context behavior and anti-fabrication guardrails.
- Redesign timer presentation while preserving the validated audio/timing engine.
- Redesign choice-board/visual-support UI and other existing session tools.
- Keep generated output easy to review/copy.

## TestFlight checkpoint

**v0.7.0 Build D**

## Acceptance criteria

- Session-note generator works both with and without attached client.
- No return of the Apple Intelligence context-window overflow bug under normal use.
- Timer behavior/audio remains unchanged unless separately approved.
- Tools navigation remains complete; no missing Tools section.

---

# Checkpoint 5 — Resources, clients, saved places, and Setup

## Goal

Finish the major screen-family conversion while preserving configuration and user data.

## Work

- Redesign Resources.
- Redesign Clients management.
- Redesign Saved Places / My Places and preference controls.
- Redesign Setup/settings screens.
- Redesign Theme Center using the new v0.7 components.
- Preserve home address, location configuration, client data, saved-place categories, favorites, gap-suggestion preferences, and other existing persistence.
- Keep Core themes as pure color palettes.

## TestFlight checkpoint

**v0.7.0 Build E**

## Acceptance criteria

- Existing persisted user data survives update from v0.6.3.
- No settings become inaccessible.
- No client/saved-place fields disappear.
- Theme Center is visually consistent with the new shell.

---

# Checkpoint 6 — App-wide scenery themes and visual unification

## Goal

Solve the scenery problem properly as part of the new architecture instead of patching the old screen stack.

## Work

- Make Scenery themes render consistently behind/through every relevant page.
- Ensure screens use transparent or intentionally layered backgrounds rather than accidentally hiding the scenery.
- Keep content legible with adaptive scrims/materials.
- Avoid remote-image behavior that makes screens flash or fail unpredictably if possible; prefer a robust asset/rendering strategy appropriate to the final design.
- Review Core, Dynamic, and Scenery theme behavior across every major screen.
- Verify Light and Accessible themes separately for contrast and readability.

## TestFlight checkpoint

**v0.7.0 Build F**

## Acceptance criteria

- Scenery is visibly persistent across the app, not only on a hero card.
- No page becomes unreadable because of scenery.
- Core themes remain clean color schemes with no decorative imprints.
- Theme changes do not break navigation or layout.

---

# Checkpoint 7 — Polish, motion, responsiveness, and release candidate

## Goal

Turn the assembled redesign into a coherent release rather than continuing to add new features.

## Work

- Fix spacing inconsistencies and alignment drift.
- Normalize card heights and button sizing where appropriate.
- Add restrained transitions/micro-interactions consistent with reduced-motion settings.
- Audit clipping on compact iPhones and larger Pro Max layouts.
- Audit keyboard/sheet behavior.
- Audit loading/empty/error states.
- Audit color contrast and accessibility.
- Remove dead v0.6-era visual wrappers that are no longer used, without removing business logic.
- Run a complete regression of all tabs and important user flows.

## TestFlight checkpoint

**v0.7.0 Release Candidate / Build G**

## Acceptance criteria

- Full native regression suite green.
- Actual Simulator compile green.
- Device visual review accepted.
- No known P0/P1 functional regressions.
- No major screen still visibly belongs to the old design system.

Once accepted, this becomes the official v0.7.0 release baseline.

---

# Features explicitly protected during the redesign

The UI overhaul must not accidentally remove or rewrite these systems unless the user separately requests it:

- Google Calendar/event support and local calendar behavior.
- Current-location access and routing state.
- Google Maps navigation handoff.
- Selected-day planning.
- Smart gap/saved-place logic.
- Client storage and ABA-style client identifiers.
- ABA session-note generator and its v0.6.3 context-window fix.
- Timer cadence/pitch/volume/crescendo behavior.
- Live Activity extension.
- Theme persistence.
- Existing migration/persistence logic.
- Native-only build isolation; legacy WebView remains quarantined.

# Scope discipline

During v0.7.0, visual redesign takes priority over new feature expansion. If a new product feature idea appears, record it for a later release unless it is required to make the redesigned interface function correctly.

The key safety principle is: **one major screen family per build, verify it on-device, then continue.**
