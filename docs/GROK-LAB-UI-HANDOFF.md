# LifeRoute crystal-chrome handoff for Codex

**Paste this entire document into Codex.** Implement on a working branch from current `main`. Do not invent extra product work.

---

## 0. Mission

Land the accepted Grok-lab **presentation chrome** onto LifeRoute **main**.

This is a **UI-only** experiment. Brandon reviewed it in a Grok cloud sandbox and wants it on the iPhone app.

**Do not:**

- merge or rewrite living themes / Metal scenery / theme catalogs
- change routing, itinerary, calendar, tools, resources, or setup **behavior**
- add features
- trigger TestFlight / App Store / release
- copy anything from the Grok **web preview** (React/CSS). That was a demo. Native Swift is the product.

**Do:**

- apply the chrome language described below
- keep `scripts/validate_current.py` green
- update the one contract string that currently assumes navy text on gold-fill buttons
- stop when the iPhone chrome matches the spec

---

## 1. Provenance (do not guess)

| Item | Value |
|---|---|
| Repo | `jackersthecoltsfan/LifeRouteFinal` |
| Accepted main (experiment started from) | `f2b7082fec2fd4b7706605aa73a2e12247923339` |
| Grok sandbox branch | `sandbox/grok-lab-20260915` |
| Latest sandbox SHA | `09419161e6336a2915cec038037dc6a3f709c0b6` |
| Working rule | implement onto **current main**, not by force-pushing the sandbox |

Main may have moved since `f2b7082`. Rebase / cherry-apply the six files onto **today’s main**. Resolve conflicts in presentation files only.

Native source of truth on the sandbox:

```
LifeRoute/UI01Presentation.swift
LifeRoute/ScenicRoyalDesignSystem.swift
LifeRoute/ScenicRoyalComponents.swift
LifeRoute/ScenicRoyalResourceComponents.swift
LifeRoute/ScenicRoyalSetupComponents.swift
LifeRoute/V054TodayView.swift
```

Fetch and inspect:

```
git fetch origin sandbox/grok-lab-20260915
git diff f2b7082fec2fd4b7706605aa73a2e12247923339 09419161e6336a2915cec038037dc6a3f709c0b6 -- <those six files>
```

A format-patch of that range is attached as `crystal-chrome.patch` (4 commits). Prefer **replay onto current main**, then apply the **finish deltas** in §5. Do not take sandbox files blindly if main has moved in those paths.

---

## 2. What Brandon accepted (visual law)

Ranked intent, high → low:

1. bombastic  
2. distinctly LifeRoute branded  
3. sleek  
4. dramatic  
5a unique / 5b Apple-native liquid glass **as a starting point, then rejected as frosted**  
6 majestic · 7 sexy · 8 refined · 9 organic · 10 modern · 11 artistically mature · 12 professional

**Owner corrections after seeing builds (these override the first pass):**

| Rejected | Required instead |
|---|---|
| Solid molten-gold buttons | Crystal rim. Almost no fill. |
| Frosted / blurred liquid glass | **No blur of living themes.** Scenery stays sharp through controls. |
| Opaque navy glass | Very see-through. |
| Glass that ignored the selected theme | Rim/tint **washes with the living scene color** at very low opacity. |
| Fat, filled chrome | Thin, sleek, hairline instrument. |
| Filled selected dock blob | Gold **filament tick** under the selected root. |

**Hard split:**

- **Themes** own living scenery (Metal / catalog / images). Do not restyle theme assets, shaders, catalogs, or identity.
- **UI chrome** is LifeRoute: Didot wordmark, navy/gold/ivory, gold filament, crystal rims.
- Chrome **structure** never becomes rainforest-green buttons or canyon-orange type. Only the **glass wash / rim** may sample `theme.palette.backgroundTop` at ~2–3% fill and a thin theme stop in the rim gradient.

---

## 3. Target chrome language (implement this, not intermediates)

Think **watch crystal / instrument glass**, not iOS Control Center frost.

### Crystal control

- iOS 26: `.glassEffect(.clear.tint(theme.palette.backgroundTop.opacity(0.02…0.03)), in: .capsule)`
- Overlay a **0.4–0.45pt** rim:

  `white 0.40 → theme.backgroundTop 0.22 → goldLight 0.28…0.35`  
  topLeading → bottomTrailing

- Pre-iOS 26: `shade.opacity(0.03)` fill + same rim. **No** `.ultraThinMaterial` (it frosts the scene).
- Reduce Transparency / increased contrast: keep existing **opaque royal capsule** fallback:

  `content.background(UI01Material.royal, in: Capsule())`

  `validate_current.py` requires that exact string.

- Primary actions (`UI01GoldButtonStyle`): silver/ivory label, not navy-on-gold. Compact minHeight 44, regular 48. Thin padding.
- Secondary / compact segmented controls use the same crystal owner (`UI01CompactControlSurface`).

### Brand

- LifeRoute wordmark: Didot, `branded: true, metallic: true` → `UI01Material.goldGradient` (not silver).
- Operational titles (`Today`, `Calendar`, …) stay silver system/Didot as today — **do not** gold every heading.
- Under the wordmark: `UI01BrandFilament` — capsule **56 × 1 pt** (thin), gold gradient, **no glyph shadow**. A very small gold glow on the filament itself is optional; do not shadow lettering.
- `UI01Hairline` may be a fading gold filament (not a flat silver rule).

### Dock

- Selected root: **no filled pill**.
- Gold filament tick (~12 × 1 pt) under the label.
- Icon slightly brighter when selected (`goldLight`); label ivory.
- Unselected: secondary mist.
- The **bar** itself is one crystal capsule (`UI01CompactControlSurface` already wraps `LifeRouteRootPagingToolbar`).

### Trail

- Gold gradient stroke with a faint wider gold halo stroke is acceptable (route identity).
- Nodes stay small. Active node may have a tight gold glow. Do not thicken into jewelry blobs.

### Reading planes / groups

- Keep `UI01ReadingPlane` behavior and the exact accessibility opacity contract (`reduceTransparency || contrast == .increased ? 1 : 0.94`).
- Stroke may pick up a goldLight stop. Do not add blur, masks, or glyph shadows.

---

## 4. File-level recipe

### `LifeRoute/UI01Presentation.swift` (primary)

From sandbox, keep:

- richer `goldGradient` (light → gold → shade)
- `UI01MarbleText.metallic`
- `UI01BrandFilament`
- gold `UI01Hairline`
- crystal `UI01CompactControlSurface` + `LiquidPrimaryGlass`
- silver labels on primary buttons
- crystal `UI01SelectionSurface` (no solid gold fill)
- thinner `UI01GoldButtonStyle` metrics
- trail halo stroke
- dock: **replace** the current selected white fill (`Color.white.opacity(0.28)`) with the filament tick described in §3. Sandbox still has the filled selected chip — that is **not** the accepted end state.

Omit unused `UI01Material.moltenGold` unless you actually paint with it. Dead token, do not ship.

**Do not** put `.shadow(` / `Canvas` / `.mask(` inside `struct UI01MarbleText` … `enum UI01TextRole`. Validator slices that region.

### Headers (wordmark + filament only)

- `ScenicRoyalComponents.swift` → `ScenicRoyalScreenHeader`
- `ScenicRoyalResourceComponents.swift` → `ScenicRoyalResourceHeader`
- `ScenicRoyalSetupComponents.swift` → `ScenicRoyalSetupHeader`
- `V054TodayView.swift` → Today command header (`LifeRoute` + filament + `Today`)

Pattern:

```swift
UI01MarbleText(title: "LifeRoute", size: 25, relativeTo: .title2, branded: true, metallic: true)
UI01BrandFilament()
```

Do not change header copy, layout logic, or live-location actions.

### `ScenicRoyalDesignSystem.swift`

Gold tokens only:

```
brandGold       rgb(0.95, 0.73, 0.26)
brandGoldBright rgb(1.00, 0.88, 0.55)
```

Do not retune content-day / content-night reading colors.

---

## 5. Finish deltas vs sandbox `0941916`

Apply after cherry-picking the six files:

1. **Dock selected state** — filament tick, transparent background, no white fill chip.
2. **Filament thickness** — 1 pt, not 2 pt. Drop the 6 pt gold shadow if it reads as a blob on device.
3. **Do not restore blur.** If iOS 26 `.clear` still frosts too much on device, drop to rim-only (`shade.opacity(0.03)` + stroke) rather than `.regular` or material.
4. **Theme wash** samples `theme.palette.backgroundTop` only. Do not sample accent, do not recolor Didot, do not recolor dock icons per theme.

---

## 6. Contracts you must keep / one you must update

Run:

```
python3 scripts/validate_current.py fast
```

and the theme readability contract test.

**Keep exactly:**

- `content.background(UI01Material.royal, in: Capsule())` inside `UI01CompactControlSurface`
- `accessibilityReduceTransparency` on compact controls
- `struct UI01ReadingPlane` with `reduceTransparency || contrast == .increased ? 1 : 0.94`
- Today still contains `UI01MarbleText(title: "LifeRoute"`, `UI01MarbleText(title: "Today"`, `UI01TrailRow(`, `.buttonStyle(UI01GoldButtonStyle(`, `"Generate Full Day"`
- Didot only via `branded`
- no `.shadow(` / `Canvas` / `.mask(` in the MarbleText lettering slice
- ScenicRoyalMaterials liquid-glass boundary unchanged
- five-root toolbar, permanent root pager, theme catalog, Image Generation, itinerary — untouched

**Update this assert** in `scripts/run_theme_readability_contract_tests.py` (around the `UI01GoldButtonStyle` block):

```
# old (assumes molten gold fill + navy ink)
assert 'enabled ? UI01Material.navy : UI01Material.secondary' in button

# new (crystal glass + ivory ink)
assert 'enabled ? UI01Material.silver : UI01Material.secondary' in button
```

If other string contracts fail because of crystal chrome, fix **presentation to satisfy the contract’s intent** (accessibility fallback, no nested glass on reading planes) rather than deleting contracts.

---

## 7. Out of scope (do not touch)

- `LifeRouteApp.swift` theme/Metal/scenery
- Image Generation prompts, boards, visual supports
- itinerary generation, calendar data, timers
- `ScenicRoyalMaterials.swift` surface-role machine (unless a compile error forces a one-line fix)
- web / React / CSS from the Grok preview
- version, bundle id, TestFlight, release notes
- main-branch force push

---

## 8. Suggested git path

```
git checkout main
git pull
git checkout -b ui/crystal-chrome-from-grok-lab
git cherry-pick 632e363 89f7099 59cd6e6 0941916
# or: git apply crystal-chrome.patch
# then apply §5 finish deltas
python3 scripts/validate_current.py fast
```

If cherry-pick conflicts, take **ours for non-presentation files**, and merge **chrome-only** hunks in the six files.

Commit message suggestion:

```
Present LifeRoute chrome as thin theme-tinted crystal.

Wordmark stays Didot gold with a filament. Controls are clear
rims so living scenery stays sharp. Themes are not restyled.
```

---

## 9. Device acceptance (Brandon)

On a physical iPhone, with Reduce Transparency **off**:

1. Ocean Day — water stays **sharp** through Generate Full Day and the dock. Rim is a thin gold + teal hairline, not a frosted slab.
2. Setup → Rainforest Day → back to Today — foliage stays sharp; rim wash goes green; wordmark stays gold.
3. Canyon / Arctic — same: scene sharp, rim hue follows scene, chrome structure unchanged.
4. Dock — selected root is a gold tick, not a filled blob.
5. Buttons feel thin and Apple-native, still obviously LifeRoute.
6. Reduce Transparency ON — royal opaque fallback, no broken contrast.

If the scene blurs, the build is wrong. If buttons go solid gold, the build is wrong. If rainforest restyles the wordmark or page titles, the build is wrong.

---

## 10. Stop condition

When the six presentation files + the one contract string are on a PR-ready branch from current main, validators pass, and the device checklist in §9 holds: **stop**. Do not pick a follow-up experiment.
