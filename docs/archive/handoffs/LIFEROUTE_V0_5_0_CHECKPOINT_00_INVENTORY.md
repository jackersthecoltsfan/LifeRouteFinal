# LifeRoute v0.5.0 — Checkpoint 00 Architecture Inventory / Quarantine

Status: active inventory for `rebuild/v0.5.0-functional-core`.

Purpose: document the v0.4.0 runtime that is being retired from active ownership, identify reusable domain/native pieces, and define the minimum runtime allowed into the v0.5.0 functional core.

## Current application entry path

1. `LifeRouteApp.swift` launches `ContentView`.
2. `ContentView.swift` currently hosts `LifeRouteWebView` as the entire application surface.
3. `LifeRouteWebView.swift` creates one `WKWebView`, registers the `lifeRoute` message handler, and loads bundled `LifeRoute/Web/index.html`.
4. `index.html` contains substantial inline state, rendering, persistence, routing and button logic before feature modules are added.
5. `scripts/prepare_build.sh` mutates the checked-in runtime with a long deterministic patch chain, then normalizes a large external JavaScript startup list into `index.html`.
6. CI and TestFlight build the prepared/mutated result, not merely the checked-in HTML/Swift source.

There are therefore multiple independent places capable of changing behavior: checked-in HTML/inline JavaScript, generated patches, appended feature modules, and the native WKWebView bridge.

## Prepared startup script order — legacy v0.4 runtime

The current preparation owner normalizes this JavaScript order:

1. `global-bridge.js`
2. `interaction-stability-v3.js`
3. `calendar-hub.js`
4. `auth-gate.js`
5. `icons.js`
6. `route-times.js`
7. `smart-context.js`
8. `live-location-v2.js`
9. `address-autocomplete-v1.js`
10. `home-location-v3.js`
11. `todos.js`
12. `grocery-stores.js`
13. `transport-mode.js`
14. `sleek-ui.js`
15. `store-sleek-ui.js`
16. `selected-gap-routes.js`
17. `saved-place-gap-options.js`
18. `live-day.js`
19. `end-home-route-web.js`
20. `day-controls-v5.js`
21. `rbt-tools.js`
22. `client-picker-sync-v1.js`
23. `client-profiles-v1.js`
24. `client-profile-tools-v1.js`
25. `mileage-tracker-web.js`
26. `resources-hub-web.js`
27. `toolbar-cleanup-v1.js`
28. `schedule-simplify-v1.js`
29. `visual-timer-v2.js`
30. `delight-ui-v1.js`
31. `timer-native-audio-v1.js`
32. `first-then-back.js`
33. `visual-resolver.js`
34. `ai-assistant-v1.js`
35. `visual-resolver-ai-v2.js`
36. `visual-quality-web.js`
37. `visual-tools.js`
38. `photo-source-picker-web.js`
39. `visual-object-focus-v2.js`
40. `image-playground-v1.js`
41. `visual-resolver-bridge.js`
42. `first-then-ai-studio-v1.js`
43. `ai-planning-v1.js`
44. `aba-ai-note-v1.js`
45. `live-themes.js`
46. `day-route-experience.js`
47. `boundary-stop-planner.js`
48. `stop-place-search-v4.js`
49. `stop-duration-v1.js`
50. `day-navigation-runtime.js`
51. `nature-settings-web.js`
52. `settings-classic-themes-web.js`
53. `photoreal-nature-web.js`
54. `dynamic-themes-web.js`
55. `fluid-scenes-v1.js`
56. `dynamic-animals-v1.js`
57. `theme-catalog-v3.js`
58. `ui-simplify-v4.js`
59. `refined-ui-v2.js`
60. `aesthetic-polish-v1.js`
61. `stability-runtime.js`
62. `delight-tail-v1.js`

Browser-preview-only support modules are additionally maintained for welcome/navigation cleanup, iCloud/Google calendar browser flows, and web routing/store fallbacks.

**Checkpoint 00 decision:** this 62-module graph is legacy/quarantined as an active startup architecture. Individual feature/domain modules may be reviewed and migrated later, but this list will not be carried wholesale into the v0.5.0 functional core.

## Generated patch preparation order

`prepare_build.sh` currently layers routing, location, address autocomplete, transport, store routing, multistop gaps, route origin choice, Live Activity, Live Day, RBT tools, provider selection, day navigation, auth, location UI, stability, themes, release hardening, external-link hardening, AI/visual tools, interaction finalization, no-programmatic-scroll, v0.4 cosmetic icons, v0.4 global interaction reliability, v0.4 performance, and v0.4 stability patches before running audits.

**Checkpoint 00 decision:** v0.5.0 behavior will not be added by extending this legacy patch chain. The v0.5.0 preparation path must become a small allow-list. Legacy patch files stay in history/reference until migration decisions are complete.

## Interaction / navigation ownership findings

### Base `index.html`

The base HTML already owns top-level tabs, view switching, forms, saved places, event editing, route launching, calendar actions and inline `onclick` controls. This is one interaction owner before external modules load.

### `config.js`

`config.js` adds a `DOMContentLoaded` owner, migrates preferences, replaces persistence behavior, adds/rewires Month/Week navigation, assigns `.tab.onclick`, wraps `window.showView`, and extends provider-calendar behavior. This creates additional navigation/state ownership on top of the base HTML.

### `day-navigation-runtime.js`

Binds Day controls with `addEventListener`, removes/replaces inline behavior, calls `preventDefault`/propagation controls, and runs a 100 ms rebinding interval for as many as 80 attempts. It also performs multiple delayed/rAF scroll restorations after navigation.

Classification: **legacy/quarantine**. Date movement logic may be migrated; rebinding/polling/scroll ownership may not.

### `stability-runtime.js`

Replaces `window.refreshCalendars` and `window.optimizeWeek`, removes inline handlers from bottom buttons, installs new click handlers, observes the bottom action subtree with `MutationObserver`, and schedules rebinding at 100/350/900/1800 ms.

Classification: **legacy/quarantine**. Functional actions can be rebuilt with one owner; observer/rebind architecture is prohibited in the functional core.

### `interaction-stability-v3.js`

Globally overrides document scroll APIs and `scrollIntoView`, wraps `HTMLElement.focus`, installs capture click/touch listeners, and uses delayed interaction-class reconciliation.

Classification: **legacy/quarantine**. Global browser/prototype replacement is not allowed in the v0.5.0 core.

### `delight-ui-v1.js`

Cosmetic module also owns behavior: global capture pointer/click listeners, dynamic button creation, contextual-tab handlers, DOM relocation of the appointment form, five delayed synchronization passes, and a whole-body `MutationObserver` watching subtree/class mutations.

Classification: **cosmetic chunk + interaction quarantine**. Appearance/audio concepts may return later, but this implementation cannot be required for navigation or feature state.

### Other compatibility/navigation layers

`toolbar-cleanup-v1.js`, `schedule-simplify-v1.js`, `ui-simplify-v4.js`, `refined-ui-v2.js`, `nav-cleanup.js`, `nav-portal-v1.js`, `top-nav-four-v1.js`, `premium-interactions-v1.js`, `interaction-liquid-v4.js`, `touch-playground-v1.js`, and related hotfix generators are treated as **legacy/quarantine** until individually reviewed.

## Global listener / observer / timer risk classes

Confirmed high-risk patterns include:

- capture-phase global click/touch/pointer listeners;
- whole-body or dynamically rebound `MutationObserver` behavior;
- delayed DOM reconciliation at multiple startup offsets;
- polling/rebinding intervals waiting for controls to appear;
- modules removing inline handlers and installing replacement handlers;
- multiple wrappers/replacements of global functions such as `showView`, `refreshCalendars`, and routing/navigation entry points;
- programmatic scroll preservation and global scroll API replacement;
- cosmetic modules observing functional DOM state.

**v0.5.0 rule:** no broad MutationObserver, speculative rebind interval, global pre-click mutation, global pointer interception, or delayed control ownership is allowed into Checkpoint 01.

## Overlay / pointer-event inventory

Known overlay/backdrop families include auth/welcome surfaces, fixed bottom actions, metal/theme/nature/dynamic/delight backgrounds, route/stop sheets, visual/photo/tool overlays, and generated scenery layers.

The legacy stability layer explicitly repairs pointer events for several of these systems, demonstrating that hit-testing became cross-module and defensive.

Checkpoint 01 will launch without optional overlays. Every later overlay must have one explicit owner, be absent when closed or provably non-hit-testing when decorative, and have a focused open/close/hit-test audit.

## Persistence / state restoration

Base `index.html` uses the `liferoute_v3` localStorage store for events, places and preferences. Additional feature modules maintain state for calendar view/provider state, clients, saved gap routes, home/location preferences, transport, tools/timers, themes, mileage, and other feature-specific settings.

Native Google Calendar refresh credentials remain in native secure storage/Keychain rather than browser localStorage. Preserve this boundary.

Migration policy:

- **Retain/migrate:** clients, saved places, home address/location preferences, manual schedule data, non-sensitive provider preferences when schema remains valid.
- **Review before migrate:** selected calendar view/date, route/gap ephemeral selections, tool state, mileage/session state.
- **Reset/quarantine:** auth-gate UI state, welcome/onboarding lock state, cosmetic runtime state, interaction-rebinding markers, stale overlay/navigation state, deprecated theme flags.
- Malformed legacy JSON must never block launch or taps.

## Cache / generated-state cleanup policy

Xcode `DerivedData`, `.xcarchive`, `.ipa`, `xcuserdata`, and related local artifacts are already ignored by `.gitignore`. CI uses fresh runners, so stale Xcode build cache is not considered the primary root cause of the v0.4 physical-device failure.

For v0.5.0 startup hygiene:

- clear WKWebView memory/disk cache and URL cache at the new functional-shell boundary when safe;
- do **not** clear `localStorage` wholesale because it contains useful user-entered product data;
- do not clear Keychain/OAuth credentials except through explicit disconnect/reset behavior;
- remove generated/prepared files from active startup ownership rather than trusting old generated output;
- reset deprecated runtime-only storage keys through explicit migration, not a blanket wipe.

## Native bridge inventory

`LifeRouteWebView.swift` is currently a large WKWebView coordinator. Stable/reusable capability candidates include Apple Calendar/EventKit, Google Calendar read-only OAuth and Keychain, route/place opening, MapKit route/search/location services, external-link handling, notifications, Live Activity, visual-analysis helpers, and native feedback helpers.

**Decision:** native services are migration candidates, not interaction owners. New SwiftUI/domain layers should call explicit services rather than route button taps through generalized WebView mutation/rebinding behavior.

## Feature-module classification

### Core / early migration candidates

- calendar normalization/provider read-only data
- Day / Week / Month domain calculations
- clients/client profiles
- saved places
- home/current location
- route times / transport mode / route opening
- Session Tools / RBT tools
- Resources
- ABA visual tools and timer domain logic

### Migrate later

- Live Day / Live Activity
- mileage tracking
- gap multi-stop optimization
- advanced store search/panels
- AI planning / ABA note generation / visual AI
- browser-only provider fallbacks not required by the native app

### Cosmetic chunks — preserve, inactive for functional TestFlight

- dark-blue/gold identity/base assets
- refined vector icons
- categorized Themes
- glass/material treatments
- button press visuals
- page transitions / spring motion
- haptics / interaction sounds
- nature/scenery/dynamic/fluid/living effects
- onboarding/welcome polish

### Legacy/quarantine

- auth-gate startup runtime
- interaction hotfix/reliability/finalize layers
- broad observer/rebinding systems
- global scroll/focus prototype overrides
- duplicate nav cleanup/portal/top-nav owners
- cosmetic modules that mutate functional navigation/state
- duplicate historical application trees as runtime/source-of-truth candidates

## Minimal v0.5.0 startup/runtime graph

Target for Checkpoint 01:

`LifeRouteApp`
→ native SwiftUI root
→ one explicit app navigation/state owner
→ minimal `Today / Schedule / Session Tools / Resources / Setup` destinations
→ semantic SwiftUI controls
→ direct launch, no username/PIN gate
→ no cosmetic runtime
→ no broad observers
→ no speculative rebinding timers
→ no global pointer/touch interception
→ explicit service interfaces for native calendar/location/routing capabilities
→ deterministic persistence boundary

Where a WebView is retained temporarily for a feature that has not yet been migrated, it must be isolated behind an explicit destination/service boundary and may not own app-level navigation.

## Checkpoint 00 conclusion

The v0.4.0 failure pattern is consistent with accumulated cross-module interaction ownership rather than a single missing tap handler. The rebuild will therefore quarantine the existing active interaction graph and migrate trusted domain/native capability into a substantially smaller native-first shell.
