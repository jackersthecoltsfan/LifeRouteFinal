# Flexible-place route-context discovery — September 10, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-flexible-place-discovery`, branch `codex/flexible-place-route-context-discovery`, from exact clean donor `80f1bf8c6e95c3875d04f9999331761fa8757d5e`.
- Confirmed remaining seams: flexible `MKLocalSearch` had no gap-derived region, then discarded the complete result set with raw provider `prefix(4)` before any route-context comparison. Gap Filler exact routing already received the preceding and following itinerary-node addresses; Live Location did not replace those valid endpoints.
- Flexible search now receives one region centered on the shared anchor or endpoint midpoint, with a 20 km minimum span and 8 km padding beyond each distinct endpoint. The region remains a discovery hint.
- The complete returned MapKit result set is ranked cheaply by straight-line `origin -> option -> destination` distance. Only the best four reach the existing serial inbound/outbound directions, feasibility, and exact route-cost winner logic. Fixed locations, locationless suggestions, candidate/error/cancellation semantics, and the eight-candidate cap remain unchanged.
- Focused route-context checks pass 36 assertions, including same-anchor, later result outside provider prefix, distinct corridor, Live Location ON/OFF, exact-routing authority, no-fit/fixed/bounded/cancellation controls, and a synthetic 24-result physical-evidence shape. Timer D 44, Timer ABC 145, Planner A 47, Day Route 177, Calendar B 34, Calendar Edit 29, Regenerate Route 18, Core Product Repair 17, preparation, and full static validation pass.
- Dedicated native validation passed on `LifeRoute-Flexible-Context-20260910`, iPhone 17 Pro / iOS 26.5: the production-seam harness passed 36 assertions, an isolated-DerivedData Debug Simulator build succeeded, and the actual Today screen rendered without a LifeRoute crash. Physical iPhone acceptance remains required.
- Separate future requirement, deliberately not implemented: after inserting one Gap Filler, recompute the remaining usable gap and offer `Add another filler` when another task fits.

---

# Flexible-place route-aware selection — September 10, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-flexible-place-route-aware`, branch `codex/flexible-place-route-aware-selection`, from exact clean consolidated donor `fd8666690d13444d3804702362f91982e718929f`.
- Confirmed cause: `DayRoutePlanningCore` converted a flexible stored value into an `MKLocalSearch` query, accepted only `response.mapItems.first`, and routed only that result before applying the existing gap-fit contract.
- Flexible candidates now compare the first four provider-ordered results serially against the actual previous and next route anchors. Each option retains the existing task duration, route buffer, and gap-fit math; only feasible options compete, lowest inbound-plus-outbound travel wins, and provider order breaks route-cost ties within one second. The selected concrete MapKit address is retained for insertion into the day route.
- Fixed-location and locationless candidates, candidate order/cap/priority, Do-by deadlines, Planner A candidate-local recovery, cancellation/stale/global abort handling, Calendar B, Regenerate Route, Timer D, and Timer ABC remain unchanged. Recoverable failure of one flexible place option may continue to the next bounded option without creating a broader catch-all recovery rule.
- Focused FP1–FP10 plus the 24-result/poor-first evidence shape passed 20 assertions. Timer D 44, Timer ABC 145, Planner A 47, Day Route 177, Calendar B 34, Regenerate Route 18, Core Product Repair 17, canonical preparation, Simulator compilation, and a dedicated iOS 26.5 native harness/app-launch smoke passed. Physical iPhone acceptance remains pending; this task does not install the artifact.

---

# Stabilization consolidation — September 10, 2026

- Worktree: `/Users/brand/Documents/GitHub/LifeRouteFinal-stabilization-exit`; branch `codex/stabilization-exit-20260909`. Starts at frozen Timer D `325e2bc3f1f25b8846b26808faec4040c1cb09c6` and preserves Planner A `e9811a80963100f2821d11f210c08543cb4920c0`, Regenerate Route `171728565a800983fe4c7312c28df456f0b65d57`, and Calendar B `00f85d862a315555bed1db267de544715de70c29` in ancestry.
- Owner-reported physical authority: Timer D and Planner A ACCEPTED; Regenerate Route PHYSICAL FULL PASS / ACCEPTED. Do not reopen these accepted repairs or require repeated physical QA solely for consolidation.
- Planner A is active by default. A new pending preference scope prevents the earlier QA OFF preference from carrying forward. Pending/live scaffolding, explicit future QA overrides, candidate-local recovery, cancellation/stale/global aborts, and derived-cache safety remain.
- Calendar B is unchanged: PHYSICAL PARTIAL / IDENTITY EVIDENCE PENDING, `CALENDAR_B_DEFERRED_NO_EVIDENCE`. LiFe/SaLa collapsed physically; JaHe remains partial. No identity extension or event-specific matching is authorized here.
- The sole final artifact/validation receipt is `/Users/brand/Documents/LifeRouteCheckpoints/stabilization-exit-20260909/CONSOLIDATION_RECEIPT.md`; it records the final clean source SHA and signed payload hash. No installation, phone launch, CI, or release is part of this run.
- Remaining phone checks only: visible source SHA, basic launch/navigation, refresh both calendar providers, LiFe/SaLa remain collapsed, observe JaHe partial, and Calendar plus Today/day-route stability.

---

# Root toolbar theme geometry — September 6, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-toolbar-theme-geometry`, branch `fix/root-toolbar-theme-geometry`, foundation HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. The complete 571-record theme donor fingerprint `7786a00dcbddce6f192549058f8e391d3d7576ad2ea1d2e488b469b014107571` was reconstructed with file bytes, modes, tracked changes, all required untracked files and logical index/staging verified before edits. The donor remains read-only. HEAD alone cannot recover this dirty successor.
- Reproduced on the donor-derived Simulator binary, including ordinary theme selection and Back: Royal Current's aspect-fill backdrop enlarged the shared foreground root from 860 to 951.184 points in the same 440 × 956-point window and shifted the toolbar by 45.592 points. The production correction makes foreground content own the layout proposal and places the existing backdrop/veil in its background. Theme art, renderers and styling are unchanged.
- Retained Phase 1M.1 accounting: the single root `safeAreaInset` owns system placement and scroll reservation; its bottom padding is the existing 10-point visual-clearance token. The physical bottom safe area is not added again. Five-root paging, nested navigation, timer suppression and timer top clearance retain their production code. Added only an opt-in DEBUG geometry observer and a native-frame regression script outside that production correction.
- Native evidence covers matched four-theme Setup frames, ordinary repeated theme/Back returns at a retained scroll offset, all five roots under Mountains Day/Night, eight finger-tracked root-boundary drags, bottom-content reachability, foreground return, presented timer Close/Back, keyboard dismissal, fresh landscape launches, accessibility-large text and the three accessibility appearance settings. Debug/Release Simulator builds and the focused root, theme/readability/catalog/migration, presentation, timer and canonical fast checks passed. All 32 choices, 12 CORE / 20 DYNAMIC and 72 persistent IDs/mappings remain unchanged.
- **Rotation qualification FAILED:** rotation after the ordinary theme/root/timer/keyboard sequence terminated the candidate with a UIKit navigation-bar ownership exception. One shorter original-donor theme-return/rotation control did not reproduce that same exception; it produced offscreen layout and paging-size warnings instead. Crash attribution is unresolved. Fresh landscape frame passes do not clear this failure. Alternate-size evidence is blocked by the existing iPhone Air Simulator's initial OS data-migration failure. No navigation rewrite or additional layout variant was attempted.
- STOP at the external frozen receipt: `/Users/brand/Documents/LifeRouteCheckpoints/toolbar-theme-geometry-20260906/ROOT_TOOLBAR_GEOMETRY_RECEIPT.md`. It contains the final full fingerprint, complete recovery/verifier, implementation-only diff, native/binary linkage, evidence matrix and remaining owner-review decisions. Included allowance was available; the earlier purchased-credit authorization was not reused. Brandon's phone was untouched; no physical installation, acceptance, commit, integration, CI or release occurred. Physical review requires a later explicitly approved installation after disposition of the failed rotation gate.

---

# Theme readability + CORE / DYNAMIC — September 6, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-theme-readability-core-dynamic`, branch `fix/theme-readability-core-dynamic`, foundation HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. Complete final-prose/no-photo donor fingerprint `f7e679d485c80407c245037f675e88b94b6c391ae445634d8522ddb4e40fd368` was reconstructed and verified before editing. Donor stays frozen; HEAD alone cannot recover this intentionally dirty successor.
- Shared foreground/native-appearance and accessibility-fill pairing correction; dark Core Arctic classification; separate native control tint and selected fill; subtle theme reflection on the retained selected material. Visible catalog is 12 CORE / 20 DYNAMIC. All 32 choices, 72 persistent raw IDs and legacy resolution, renderer cohorts, scene/effect/art mappings remain retained.
- Note prose/closing/no-photo QA remains PENDING as last reported by Brandon. Note generation, roles, closing, guards, attachments removal, timer/Orb/audio/haptics, root navigation and project/scheme were not changed. Shared appearance may affect their presentation and needs review.
- One worker; paid continuation authorized up to $10. Exact source, recovery, test/build results, native-capture limitations, balance observations and remaining review gates are in `/Users/brand/Documents/LifeRouteCheckpoints/theme-readability-core-dynamic-20260906/THEME_READABILITY_RECEIPT.md`. That external receipt is authoritative. Phone untouched. No installation, commit, push, CI, release or automatic next task.
- STOP frozen for review. Full composited native-control, picker and accessibility appearance is unverified; standalone ImageRenderer did not render glass-contained controls. This is not physical, app-wide regression or release acceptance.

---

# Phase 1AJ.8 user completion audio + cue-relative haptics — September 6, 2026

- Candidate: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1aj8-custom-completion-audio`, branch `fix/feature3-phase1aj8-custom-completion-audio`, foundation HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. It began as an exact 567-record, byte/mode/status/patch-equivalent recovery of frozen AJ.6 fingerprint `313b9bede43a13c55b02968119ec3687f19066adeef6504c9cb59fe6444858b8`; AJ.6 remains read-only and unchanged.
- The user-provided `TIMER_SOUND_3s.wav` is retained as an unchanged asset-catalog Data Set source: SHA-256 `ddde780da9eb13cc1b7f00f0f7ba03d7f4bd50e8f480574078fd20092174e52b`, exactly 3.000 seconds, 44.1 kHz stereo 24-bit PCM. The existing completion AVAudioPlayerNode decodes that native PCM directly; the generated completion cue is removed. Project and scheme bytes are unchanged.
- One shared core completion event supplies the monotonic cue-start reference. The single shared embedded/full-screen presentation state schedules four cancellable completion impacts at 0.00, 0.96, 1.68, and 2.27 seconds, selected from the supplied waveform's separated strong attacks; intensities progress `0.70, 0.76, 0.84, 1.00`. A new session, reset, inactive presentation, Haptics Off, or stale session identity suppresses future impacts. Recurring ticks, countdown rate, final-15 policy/intensity, visual motion, navigation, and timer authority remain untouched.
- Final local evidence: supplied-WAV hash/property verification; 155 feedback, 513 native Orb-region, 25 V04-material, and 111 production core/presentation assertions; canonical fast validation; `git diff --check`; Xcode 26.6 Debug Simulator and signed generic-device builds. No physical device was installed. Felt music/haptic alignment, the exact perceived loudness, and audio behavior under actual device conditions remain Brandon's short review gate.
- Exact recovery/final fingerprint, build disposition, and no-install receipt: `/Users/brand/Documents/LifeRouteCheckpoints/phase1aj8-custom-completion-audio-20260906/PHASE_1AJ8_RECEIPT.md`. No commit, push, merge, CI, TestFlight, release, or additional phase is authorized.

---

# Phase 1AJ.6 haptic perceptibility / selected-beat alignment — September 6, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1aj6-haptic-sync-stretch`, branch `fix/feature3-phase1aj6-haptic-sync-stretch`, foundation HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. It began as an exact, 567-record byte/mode/status/patch-equivalent rehydration of frozen AJ.5 fingerprint `eca4a142097a9af62be6c229aa70f2f61c37d9e455f7cb1c06022774126e8bfa`; AJ.5 remains read-only and unchanged.
- Haptic timing trace: one shared scheduled beat carries the same monotonic `plannedUptime` to the presentation publisher and AVAudioPlayerNode host-time schedule. The urgency path computes its cancellable due-time delay from that same value, then rechecks active owner, preference, running state, and final-window eligibility at dispatch. No enqueue-versus-due-time or generation-cancellation defect was demonstrated, so no timing offset or independent haptic clock was added. DEBUG-only traces now record selected planned time and requested-time lateness; neither is tactile calibration.
- Perceptibility: retained the selected-beat subselection, 0.65–2.5 Hz cap, final-15 window, 0.35-second completion separation, Sound-OFF independence, cancellation paths, and distinct heavy completion. The existing soft generator’s range is narrowly raised from 0.42–0.90 to 0.50–0.95 in response to the verified physical report that the selected beats were present but too light. Physical feel and audio/haptic pairing remain Brandon’s review gate.
- Optional membrane stretch: deferred. The existing interior-only shader controls passed a bounded trial, but this host could not navigate the fresh Simulator launch to the timer fixture for a comparable required post-change still. The production Metal shader is restored byte-identical to AJ.5; no visual-motion change is retained.
- Final validation on final bytes: 200 Visual Timer feedback assertions, 513 native Orb-region assertions, 25 V04-material assertions, 109 presentation assertions, and 10 GPU deformation assertions passed; final shader metrics remain minimum Jacobian 0.23114839, maximum travel 45.347874, maximum frame step 2.0323524, rim peak 4.2000165. `git diff --check` and Xcode 26.6 / 17F113 Debug iPhone 17 Pro Simulator build passed. V04 SHA-256 remains `6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16`.
- The verified video exists under a renamed UUID filename and matches expected SHA-256 `e09cd8b741860bfd84aa7e1ea1f2998a47a35e7f6670e86d4b694c5fe5bbd8b1`; only a single thumbnail could be reviewed because the desktop capture stream failed. No video claim establishes tactile timing. No commit, push, merge, release, TestFlight, physical-device install, or acceptance occurred. Stop at `/Users/brand/Documents/LifeRouteCheckpoints/phase1aj6-haptic-sync-stretch-20260906/PHASE_1AJ6_RECEIPT.md` for Brandon’s physical review.

---

# Phase 1AJ.4 motion, beat alignment, menu and expansion — September 6, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1aj4-fluidity-sync-menu`, branch `fix/feature3-phase1aj4-fluidity-sync-menu`, foundation HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. Intentionally dirty; HEAD alone is insufficient. It began as a full byte/mode-equivalent rehydration of installed AJ.3 fingerprint `b13cdb57b37960f244a84eb2ccb9fab757cad4ee7b0fe089c750c89bdeed6dc0`; AJ.3 remains untouched.
- Reproduced cause: the material timeline continued updating while a stale captured activity callback left the motion driver with zero owners. Native trace reproduced elapsed/energy zero during embedded Running and inverted pause/resume registration. Activity now uses the delivered new value and live core state. No extra timer or display link was introduced.
- Beat/flow: the old envelope peaked 14% of an interval after its scheduled beat. Five stable beats in the second supplied phone recording measured roughly +200...218 ms from recorded audio onset to rim expansion crest. A continuous raised cosine now anticipates the next already-scheduled beat and crests on that planned instant; baseline crystal energy stays independent of the accent. This is not a measured post-repair speaker-to-photon result.
- Menu: compact Orb/time, unchanged duration presets/custom Stepper, one main Start, existing adjustments and readable compact preferences. Native zoom originates at the embedded readout on iOS 18+ using the existing cover; Reduce Motion and older systems use the system presentation fallback. No animation is applied to settled whole-Orb geometry. Existing X, timer instance, audio and haptic contracts remain.
- Validation: Xcode 26.6 (17F113) Simulator builds; 192 feedback, 512 region, 25 material, 99 presentation assertions; production shader support/Jacobian bounds, root-paging and canonical fast validation passed. Native evidence includes menu at ordinary/accessibility-large sizes, actual Close, silent five-minute state, pause/resume, adjustments, app-switcher return, orientation and Reduce Motion. A diagnostic minute scheduled 129 audio events, 21 final-window urgency haptics and one completion haptic, with zero dropped trace records. Ordinary no-argument launch video and final qualification are documented externally.
- Protected: `SessionToolsDomain.swift` (core/audio), Metal shader, V04 material, project and scheme bytes are unchanged from AJ.3. Phase 1K/1S ownership and amount math remain. No commits, source reconciliation, release or physical acceptance.
- STOP: safe phone stopping point and post-repair audible/visual physical review remain pending. The phone was reachable over localNetwork but still had AJ.3 running; no safe timer state was established. Exact frozen identity, recovery, signed-build disposition, video measurements and remaining gaps are authoritative in `/Users/brand/Documents/LifeRouteCheckpoints/phase1aj4-fluidity-sync-menu-20260906/PHASE_1AJ4_RECEIPT.md`. One implementation and its one evidence-driven preference-layout correction are used. Do not retune or start another phase automatically.

---

# Phase 1AJ.3 runtime pulse, audio, haptics, and Close repair — September 6, 2026

- Successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1aj3-runtime-pulse-audio-close-haptics`, branch `fix/feature3-phase1aj3-runtime-pulse-audio-close-haptics`, HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. It began as a byte/mode-equivalent rehydration of the final intentional dirty AJ.2 state; the AJ.2 source remains read-only at full fingerprint `5b782aa4ae8e9067bedc24f9ca5fbc24e7c2e320ac74f0205b14b1ac1b6aabde`.
- Root cause: the normal 30 Hz Orb timeline was live, but AJ.2 filtered all shared beat events below 2.5 Hz, its beat deformation was sub-perceptual and interior-only, and the rim was explicitly locked. Full-screen auto-hide also removed Close from visibility and hit testing, leaving the screen-wide reveal control as the active target.
- Repair: every duration-aware beat now reaches presentation and enabled audio from Start; the stable 180-minute curve, 0.72...7 Hz law, shared short queue, generation cancellation, and late-skip behavior remain. The continuous internal field now gives all three tethered forms stronger baseline and beat deformation, liquid geometry/caustics participate, and a bounded geometric rim band reaches 4.2 pt without moving the presentation or creating a brightness strobe. Reduce Motion still selects the exact static frame.
- Final-15 haptics use the existing timer-haptics preference and a stateful subsampler of the shared beat, not a second clock: 0.65...2.5 Hz target, 0.28...0.82 intensity, active-screen ownership, generation cancellation, and at least 0.35 seconds reserved before the distinct completion haptic. Pause, reset, background/inactive, and +15 out-of-window paths cancel pending work; -15 entry re-arms it.
- Close is now always visible/reachable while action controls auto-hide. It synchronizes the presentation binding and calls native dismiss. A real Simulator accessibility tap returned from 0:30 full screen to the same running embedded timer at 0:22 without reopening.
- Fresh gates: 192 feedback, 505 native region, 25 V04, 99 presentation, and 10 production-shader GPU assertions passed; root-paging, canonical fast validation, `git diff --check`, and Xcode 26.6 (17F113) Debug Simulator build passed. Same-condition 0.25-second video analysis measured median interior RGB delta 6.71 -> 9.12 and rim delta 1.43 -> 19.62 from AJ.2 to AJ.3. Runtime instrumentation measured a 0.731-Hz early start, monotonic acceleration, escalating final-window haptics, and one completion haptic.
- Exact recovery, native evidence, installation status, and Brandon's short physical-audition checklist live in `/Users/brand/Documents/LifeRouteCheckpoints/phase1aj3-runtime-pulse-audio-close-haptics-20260906/`. The authorized replacement install is performed only after the final frozen fingerprint and signed-device build gates; the external receipt is authoritative for its result. Visual, audible, and tactile product acceptance remain Brandon's gate.

---

# Phase 1AJ timer layout + shared exponential pulse cadence — September 5, 2026

- **PHASE 1AJ PRESENTATION AND VISUAL CADENCE READY — NATIVE VALIDATED; BRANDON REVIEW PENDING.** This is worker validation only. Phase 1AI.1's reported physical install remains on Brandon's iPhone; Phase 1AJ was not installed on a physical device, and no physical-motion acceptance verdict exists.
- Candidate: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1aj-timer-layout-urgency`, branch `feat/feature3-phase1aj-timer-layout-urgency`, HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. It is intentionally dirty; HEAD alone does not reproduce it.
- Source authority: the frozen Phase 1AI.1 working state was rehydrated in a named successor after exact branch/HEAD/fingerprint, staging, V04 material, project/scheme, file-record, and source-preservation checks. The Phase 1AI.1 source remains read-only and unchanged. Phase 1AI.2–1AI.4 remain negative untethering evidence and were not used.
- Layout proposal: embedded presentation now leads with Orb/readout, then primary timer controls, duration, and feedback. Full screen keeps one adaptive portrait/landscape implementation and moves Close into a dedicated top safe-area inset. Duration, feedback, full-screen preference, Start/Resume/Add minute/±15/Reset semantics, shared timer instance, and Tools → Visual Timer ownership remain intact.
- “Ticks” resolved: the production core already had a recurring audible pulse loop driven by the established exponential urgency mapping (`k = 4.0`, `0.72...4.20 Hz`); it was not merely the one-second readout. That same loop now publishes one authoritative presentation beat whether Sound is on or off, and enabled audio consumes the same event one-to-one. Start/completion tones and completion haptics are unchanged. No new audio mode, haptic cadence, or final-15-second coordinator was added.
- One shared Orb presentation driver accumulates active monotonic time and follows authoritative beat index/interval events. Embedded/full-screen overlap cannot create a second clock. Duplicate/stale beats are ignored; a skipped beat advances to the newest event without replay. Pause/resume preserves the pending beat interval, ±15 does not reset phase, and inactive/offscreen/background/Reduce Motion/ready/completed states stop the high-frequency callback path.
- The common pulse appears only as bounded internal crystal pressure, liquid-local caustic/sheen energy, and an interior radial refraction light. It does not scale the Orb, move the shell, typography, controls, scenery, or liquid amount. Phase 1AI.1 organic motion, Phase 1K scalar area, Phase 1S region ownership, `VisualTimerCore` countdown/deadline authority, the iOS 16 static-crystal fallback, and the accepted V04 PNG SHA-256 `6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16` are preserved.
- Fresh validation: 761 timer/cadence/presentation/native-region/material assertions, 32 visual-activity assertions, 8 GPU assertions over 17,968,014 production-shader samples, fast canonical validation, root-paging contract, and an Xcode 26.6 (17F113) Debug iOS 26.5 Simulator build passed. Native evidence covers embedded/full-screen portrait, accessibility-large portrait, supported landscape, matched day/night 98/50/5/0 regions, and normal-speed early/middle/late cadence clips. Zero cleanliness is sampled at five shared-pulse phases. One non-repeatable extracted-frame artifact was followed by 13 clean exact adjacent samples.
- Performance boundary: normal-speed clip packet timing was recorded, but an 8-second Time Profiler attachment stalled during finalization and the partial trace is invalid. Simulator evidence does not establish physical smoothness, thermal behavior, audio, haptics, or final visual acceptance. Inherited Phase 1AH readability and jitter reports are not declared fixed.
- Exact receipt, recovery, implementation-only diff, source-preservation proof, tests, and review evidence: `/Users/brand/Documents/LifeRouteCheckpoints/phase1aj-timer-layout-urgency-20260905/PHASE_1AJ_RECEIPT.md`. The bounded three-group owner plan is `PHYSICAL_QA_HANDOFF.md` there. Next decision: Brandon reviews the Phase 1AJ layout and early/middle/late pulse behavior before any install or next phase.

The Phase 1AI.1 and earlier sections below are historical. Their accepted foundations and pending physical caveats remain preserved.

---

# Phase 1AI.1 living Orb motion — September 5, 2026

- **PHASE 1AI.1 LIVING ORB MOTION READY — AWAITING BRANDON VIDEO REVIEW.** Product motion acceptance and physical performance remain pending. No phone install, commit, push, merge, hosted CI or release occurred.
- Candidate: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1ai1-living-orb-motion`, branch `feat/feature3-phase1ai1-living-orb-motion`, HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. Intentionally dirty: HEAD alone does not reproduce it.
- The complete frozen Phase 1AI source was reproduced before edits: 550 tracked + 14 visible-untracked file records, modes and logical Git artifacts matched. Source fingerprint `debe43946b117424d8e39be682c95af6c84844aa2befabb28dff24c74c984cf1` matched the requested authority. Source remains untouched; successor starting fingerprint `1741db051d33d50b10a149629c134b893106d22b69f0fe2bfac99ee388927872`.
- Stronger motion: one existing gated 30 Hz material schedule now drives a continuous interior warp of the single accepted V04 raster plus the native liquid. Rear breathing, diagonal flow and foreground counter-response have distinct related rhythms. The shader locks coordinates outside radius 144, preserving the shell/fringe. Liquid waves, shading travel, meniscus sheen and clipped caustics are substantially larger/faster; urgency adds energy and faster harmonics without changing countdown speed.
- Two passes used. Early pass-one clips were inspected at 340 px. A denser surface test then exposed contact-side overbend; pass two limits the Bezier control hull to the circular well using a common coefficient factor, preserving area and tangent continuity without reducing crystal or optical motion. No further tuning is authorized by this run.
- Preserved: V04 PNG SHA-256 `6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16`; timer domain, Phase 1K scalar solver, full-screen/presentation/controls, roots/themes/scenery, lifecycle gate and protected scheme bytes. Phase 1S remains the only region constructor. Xcode project delta is only four entries adding `VisualTimerOrbMotion.metal` to the app source target.
- Validation: preparation, final completed-slice full validation (1,226 executable assertions), eight additional GPU assertions over 17,968,014 production shader samples across its common cycle, and Xcode 26.6 Debug Simulator build passed. Strong wave surfaces retain 0.1 percentage-point raster area tolerance and native partition/clip tests. All 14 bright/dark 98/75/50/25/10/5/0 pairs have zero changed pixels outside the well; empty pairs are identical. Native pause/resume, ±15, close/reopen, background/foreground, natural completion, and actual Reduce Motion checks are captured.
- Compatibility: crystal deformation uses iOS 17+ SwiftUI shaders; iOS 16 retains accepted static crystal with stronger Canvas liquid. Physical smoothness/thermal behavior and Brandon's subjective motion acceptance remain unverified. Hidden cadence is verified by the unchanged gate, one paused schedule and clock/source contracts, not per-view runtime frame counters. Cross-build Reduce Motion pixels were not identical; asset/geometry preservation and the current freeze are verified, not pixel parity with an older capture.
- Receipt, final fingerprint, recovery, tests and videos: `/Users/brand/Documents/LifeRouteCheckpoints/phase1ai1-living-orb-motion-20260905/PHASE_1AI1_RECEIPT.md`. Review player: `review/REVIEW.html`; primary clips: `review/final-matrix/day-50.mp4` and `review/final-matrix/night-10.mp4`. Simulator is left ready at 5:00, with no motion/static/auto-start override, Reduce Motion restored OFF.

The Phase 1AI and earlier sections below are historical. Their former tuning gates are superseded only by the bounded Phase 1AI.1 authorization above.

---

# Phase 1AI Orb motion — September 5, 2026

- Candidate: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1ai-orb-animation`, branch `codex/feature3-phase1ai-orb-animation`, HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. Intentionally uncommitted; HEAD alone does not reproduce the candidate.
- Authority: Brandon explicitly accepted the Phase 1AH full-screen source for this task. Its worktree remains untouched, fingerprint `96011e416be6ae9eabe3b1d085946ae115759422c09e1d63671f807b894edceb`. The successor began with all 564 file records, modes, and logical Git state reproduced; starting fingerprint `de4eaabbd8d962c2ced366cc32f11b2eda26386da9fda7cecac1d156bdd9a91a`.
- Implemented: subtle actual liquid-surface deformation, slow internal shading and caustic drift, localized meniscus sheen, and bounded progress-linked intensity. One 30 Hz maximum animation schedule updates only the liquid Canvas; typography retains the existing one-second cadence. Monotonic presentation time freezes on pause, disappearance, and inactivity; Reduce Motion uses the accepted static surface while the core continues to supply countdown/progress.
- `VisualTimerCore`, Phase 1K scalar mapping, full-screen layout, controls, presentation state, Xcode project/scheme, themes and V04 bytes are preserved. Phase 1S `VisualTimerOrbRegions` remains the only region constructor: an additive default-still motion input changes paired cubic control points with zero total signed area, shared by liquid, unsubmerged/restoration, meniscus and caustic clipping. V04 PNG SHA-256 remains `6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16`.
- Validation: preparation, all STANDARD components (resumed at corrected static-only source assertions), 319 new motion assertions, existing timer/presentation/material/region contracts, and a Debug iPhone Simulator build. Native bright/dark 98/75/50/25/10/5/0 pairs and two motion clips are saved. Exact validation and lifecycle evidence, current fingerprint, implementation-only diff, complete dirty recovery and pending review checks are in the external receipt.
- Gate: coherent implementation ready for Brandon's motion review; final calmness, motion visibility, visual/physical acceptance and physical performance remain owner review. Do not tune further, integrate, commit, push, or install on a physical device without new direction. This task installed only on the existing Simulator.
- Receipt: `/Users/brand/Documents/LifeRouteCheckpoints/phase1ai-orb-animation-20260905/PHASE_1AI_RECEIPT.md`. Review checklist: `BRANDON_REVIEW.md` in that directory.

The Phase 1AH and older entries below are historical; their earlier stop gates do not supersede this explicitly authorized Phase 1AI implementation.

---

# Phase 1AH full-screen Visual Timer — September 5, 2026

- Current candidate: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1ah-fullscreen-timer`, branch `feat/feature3-phase1ah-fullscreen-timer`, HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`. Intentionally dirty and uncommitted; HEAD alone does not reproduce this candidate.
- Authority: Brandon accepted Phase 1AG V04 and the completed Phase 1O.1 checklist, 29 P / 0 F / 0 N / 0 conflicts. The accepted Phase 1AG source remains read-only. Its source fingerprint is `94a41bc6c9999e2b7dfd1d35d4fa38bf1ced80d54941895eb01145c18ab1bc00`; the acceptance records live in `/Users/brand/Documents/LifeRouteCheckpoints/phase1ag-v04-static-integration-20260905/physical-acceptance/`.
- This successor began with all 550 tracked and 12 visible-untracked source records reproduced, with empty staging and verified byte/mode equivalence. New work adds an accessible manual full-screen control, fixed accessible Close, and “Open timer full screen when started” beside existing timer feedback preferences. The preference defaults OFF when unset and persists only the user's choice.
- The SwiftUI `fullScreenCover` observes the same `SessionToolsCore.timer` object. UI-owned presentation state handles explicit-Start opening and one completion-haptic subscription; audio and countdown authority remain in the unchanged `VisualTimerCore`. Shared readout/action components preserve the accepted embedded rendering. Opening and closing have no timer-domain side effects; Resume, adjustments, foregrounding, and re-entry do not automatically present.
- The full-screen view uses the actual selected theme, existing visual-activity suspension, uniform accepted-canvas scaling, a landscape layout, and scrollable accessibility controls with Close outside the scroll area. V04 runtime PNG SHA-256 remains `6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16`. The complete snapshot/renderer block, domain, Phase 1K/1S regions, project/scheme, theme, root-paging, and toolbar foundations retain source bytes.
- Validation: current STANDARD passed 895 executable assertions, including 79 new production-code presentation assertions, plus existing root/toolbar, Today-route, and theme-thumbnail contracts. Xcode 26.6 (17F113) Debug iPhone Simulator build passed. Native evidence includes all 14 bright/dark fill states, actual deadline continuity, preference persistence, pause/resume/adjust/reset/completion, background/foreground, both landscape orientations, largest accessibility text size, smaller iPhone layout, five-root buttons, live theme return, and actual system Reduce Motion opening/closing. Physical audio/haptics and finger-tracked drag/hold/reversal are unverified; the available CUA drag did not establish a page gesture. No navigation-bar crash was observed; no historical crash-fix claim is made.
- Exact final status, build/test logs, native images, frozen fingerprint, implementation-only diff, complete dirty-state recovery, and source-preservation proof: `/Users/brand/Documents/LifeRouteCheckpoints/phase1ah-fullscreen-timer-20260905/PHASE_1AH_RECEIPT.md`. New physical checks are in that directory's `PHYSICAL_QA_HANDOFF.md`; all are untested until Brandon performs them.
- Stop at the Phase 1AH receipt. No physical installation occurred. Separate authorization is required for a signed install of the exact frozen dirty candidate. No commits, pushes, merges, hosted CI, release, new artwork, timer-duration changes, or custom Orb motion are authorized here.

The Phase 1S and older entries below are historical context. Their old acceptance and next-feature gates do not supersede the accepted Phase 1AG baseline or this scoped Phase 1AH handoff.

---

# Phase 1S compositor correction — September 4, 2026

- Current successor: `/Users/brand/Documents/GitHub/LifeRouteFinal-feature3-phase1s-orb-compositor-correction`.
- Branch: `fix/feature3-phase1s-orb-compositor-semantics`; HEAD `097b2c22cbd1eb62b54c5361a8d9ededb561f3d2`, intentionally dirty; no commit or push.
- Started as the exact dirty Phase 1R candidate. The Phase 1R source worktree is frozen and unchanged. Inherited project/scheme drift and Orb asset bytes are preserved.
- Corrected native arc-side ownership through `VisualTimerOrbRegions`: one area-preserving curved meniscus defines lower liquid and upper unsubmerged regions, shared by body, restoration, and liquid-local clipping. The Phase 1K scalar solver and timer/deadline authority are unchanged.
- Passed: existing 151 timer assertions, 154 native region/wiring/raster/SwiftUI mask and clip assertions, preparation/Fast checks, root paging/deep toolbar contracts, Xcode 26.6 Debug iPhone 17 Pro Simulator build.
- Captured all dark/bright 98/75/50/25/10/5/0 states with existing Phase 1R materials and weights. Lower-reservoir semantics now read correctly; crystal identity/depth and caustic quality remain below the binding target/master. No material rebalance or asset derivation was performed.
- **PHASE 1S COMPOSITOR CORRECTED — STATIC MATERIAL GATE STILL FAILED.** Selected conclusion: **B. PHASE 1R ASSETS STILL MATERIALLY INADEQUATE — RETURN TO MATERIAL ARCHITECTURE.**
- Exact receipt, patches, source/successor fingerprints, masks, logs, and visual sheets: `/Users/brand/Documents/LifeRouteCheckpoints/phase1s-orb-compositor-correction-20260904-132112/PHASE_1S_RECEIPT.md`.
- Stop here. No physical acceptance, motion, full-screen, later Feature 3 work, release, or hosted CI. Phase 1M/1N acceptance and Phase 1O.1 physical-QA-pending status are unchanged.

The older handoff below is retained as historical context; it does not supersede this dirty Phase 1S state.

---

# LifeRoute current engineering handoff

## Current authority

- Build 123 / `f9c2b13c4c8c7c19c67e3f118176635ea8576808` remains the last fully accepted physical TestFlight baseline.
- Build 124 functional continuation baseline: `3ccbcc275c72297650fd4140664498fe95957149`.
- Build 125 candidate branch: `fix/build125-visual-foundation-performance`.
- Isolated worktree: `/Users/brand/Documents/GitHub/LifeRouteFinal-build125-visual-foundation-performance`.
- Stop point: `BUILD 125 VISUAL FOUNDATION + PERFORMANCE IMPLEMENTATION CHECKPOINT`.

Do not merge this branch, dispatch TestFlight, change signing/version/build
numbers, or create a shipping archive without separate owner authorization.

## Build 126 day-glass readability repair

- Isolated repair branch: `fix/build126-day-glass-readability`.
- Exact baseline: `c5d676c85058396cdf674f0cced2109e19b3ec8d`.
- Shared major-group glass remains `Glass.clear`; dark/night scenery keeps the
  calibrated `0.044` neutral underlay, while classified bright/day scenery uses
  a bounded `0.16` readability underlay.
- Focused contracts, preparation, fast/full validation, Debug/Release
  Simulator builds, canonical Simulator smoke, and Glass Lab bright/dark
  capture passed. Physical iPhone A/B readability acceptance remains open.

## Build 126 Terra candidate

- Branch: `exp/build126-terra-shell-performance`, based on
  `0aa161c3b8edcb15dc69c0da9dc03f7c6e4f33fd`.
- iOS 26+ now uses a native five-root `TabView` (`Today`, `Calendar`,
  `Tools`, `Resources`, `Setup`) with system safe-area and Liquid Glass tab-bar
  ownership. The pre-iOS-26 page shell and `ScenicRoyalToolbar` are retained as
  an availability-gated fallback; the native path does not use page style, the
  custom root toolbar inset, stock-tab hiding, or custom tab-bar appearance.
- `LifeRouteVisualActivityCoordinator` owns reference-counted ambient
  suspension. A foreground screen acquires a UUID in `onAppear` and releases
  it in `onDisappear`; the root environment becomes deterministic static while
  any request remains. Build 126's Theme Center work should use that API rather
  than add another global flag.
- DEBUG-only `-LifeRouteVisualActivityMode` supports `full`, `frozen`,
  `sceneryOnly`, `dynamicOnly`, and `noEffects` for same-device capture.
  DEBUG signposts cover root selection, post-selection settling, and suspension
  changes. Release omits the launch argument and signpost labels.
- Runtime verification booted iPhone 17 Pro / iOS 26.5. The five native roots
  completed five full Today → Calendar → Tools → Resources → Setup → Today
  cycles without a page-style sideways root movement, neighboring-root
  exposure, duplicate tab bar, or black root. A deep Visual Timer navigation
  path survived a URL-driven switch to Today and a return to Tools; native root
  tab bars are visible, while the deep destination deliberately hides its tab
  bar. DEBUG Royal Current modes (`full`, `frozen`, `sceneryOnly`,
  `dynamicOnly`, and `noEffects`) completed the same root/scroll sequence;
  Simulator observation did not establish a material smoothness difference.
- Native iOS 26 UIKit container host backgrounds were initially opaque black
  over the shared Royal Current environment. The Terra-local fix clears only
  those host fills after creation; it does not alter native tab/nav layout or
  appearance. Focused revalidation and a fresh candidate commit are required.
  No physical iPhone was connected.

## Build 125 checkpoint

- `V054ContentView` remains the sole bottom-toolbar layout owner. Its existing
  bottom safe-area inset now uses one canonical 10-point visual-clearance token
  instead of the previous 2-point bottom padding; no offsets or device-specific
  exceptions were introduced.
- `LifeRouteOrdinaryGlassPolicy` remains the canonical ordinary-surface owner
  for ambient, card, readability, and toolbar roles. The material modifier now
  distinguishes one ordinary container from nested ordinary content: the
  container owns the thin fill, highlight, outline, and shadow, while nested
  rows retain only a subtle outline and do not add another fill or shadow.
- Selected and intentional focal controls retain native Regular glass.
  Unselected Calendar date chips now use the ordinary ambient recipe; the
  selected chip keeps native selected-control emphasis.
- The scenery base remains fixed-camera and existing localized effects remain
  unchanged. No navigation, state, caching, animation, or scenery performance
  refactor was retained because a controlled warmed same-device process-sample
  A/B showed no meaningful CPU-side delta.

## Validation checkpoint

- Preparation, fast validation, and full validation passed.
- Day Route: `177` assertions.
- Calendar Edit: `29` assertions.
- Session Note: `162` assertions.
- Visual Timer feedback: `119` assertions.
- Runtime Feedback: `32` assertions.
- Scenery Effects: `54` assertions.
- Fresh Debug and Release Simulator builds passed for the app plus embedded
  Live Activity extension.
- Canonical Simulator smoke passed on iPhone 17 Pro / iOS 26.5 across all five
  roots, Visual Timer, day/night scenery fixtures, reduced motion, and the
  ordinary-glass Today fixture.
- Focused visual QA covered bright and dark canyon scenery, populated Today and
  Calendar roots, tab transitions, scroll gestures, a deep Calendar editor,
  iPhone 17 Pro, and iPhone 17e. No black-background regression was observed.
- No crash report, fatal assertion, or `UINavigationBar` regression was found.
  Build output retained only the known no-AppIntents metadata notice and signed
  embedded-binary copy notice; Simulator logs retained launch-metric delivery
  and one audio-plugin factory diagnostic without a crash.
- Shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

## Remaining physical QA

- Confirm toolbar clearance, safe-area balance, and unobscured content on a
  physical Dynamic Island iPhone and another available iPhone size.
- Judge perceived tab/scroll smoothness on physical hardware; Simulator A/B did
  not reproduce a meaningful app CPU hotspot, so no speculative performance
  rewrite was retained.
- Confirm thin ordinary glass, nested-row transparency, text readability, and
  selected-control emphasis over representative bright and dark scenery.
- Reconfirm Generate Full Day, Start Route, calendar editing/deletion,
  stale-route invalidation, virtual-event routing, Live Location, Live Day,
  route buffer, Maps provider selection, Session Note, and timer behavior.

## Deliberate non-work

- No timer redesign/audio work, Session Note work, calendar/routing features,
  provider writing, scenery assets, animated-camera changes, navigation rewrite,
  release workflow, signing, version, or build-number changes.
- No broad cleanup or module extraction was performed.
- No TestFlight dispatch or main-branch merge belongs to this checkpoint.

## Build 126 integrated local candidate

- Integration branch: `fix/build126-visual-foundation-repair`.
- Exact common base: `0aa161c3b8edcb15dc69c0da9dc03f7c6e4f33fd`.
- Retained Terra candidate: `8a5137b6697c2c4f93374aad16a9b3727cc6fc64`.
- Retained Luna candidate: `c169150de80071de5a481cff4fb00e83a1d78d86`.
- The only worker overlaps were this handoff and `scripts/validate_current.py`;
  the validator was reconciled to enforce both architectures. There was no
  project-file or asset overlap.
- Theme Center visibility now calls the root-owned, reference-counted
  `LifeRouteVisualActivityCoordinator`. Its private Theme Center request is
  idempotent across repeated appear/disappear callbacks and is covered by
  executable open/close-cycle contracts.
- The Foundation semantic-role contract is the production SwiftUI role type,
  preventing a duplicate test-only vocabulary from drifting. Old ordinary
  depth machinery is absent.
- Today inherits the intended hierarchy through shared components. Calendar
  received the bounded remaining migration: agenda events are passive rows
  under one day/week major-group surface. Tools tiles are semantic controls
  inside their existing glass-effect container and no longer own card shadows.
- Resources, Setup, and Theme Center retain Luna's explicit migration. Theme
  Center catalogs use static thumbnails for all 12 core, 8 Dynamic, and 12
  scenery themes; catalog source contains no live renderer path.
- The native iOS 26 five-tab shell, transparent UIKit host repair, five
  independent paths, deep tab suppression/restoration, programmatic root
  selection, and Visual Timer-under-Tools ownership are retained. Integrated
  Simulator root cycling and screenshots showed no opaque black host surface.
- Fast and full validation passed. Executable totals were Day Route 177,
  Calendar Edit 29, Session Note 162, Visual Timer 119, Runtime Feedback 32,
  Visual Activity 32, and Scenery Effects 54: 605 assertions total.
- Fresh signing-disabled Debug and Release iOS 26.5 Simulator builds passed.
  The warning audit found one known no-AppIntents metadata notice and zero
  unexpected compiler warnings.
- The canonical iPhone 17 Pro smoke matrix passed all five roots, Visual Timer,
  all 12 day/night scenery fixtures, Royal Current motion/reduced-motion, and
  ordinary glass over bright scenery. Theme Center open/scroll/select/close
  passed; two visible frames were byte-identical while suspended, while frames
  after close diverged as ambient motion resumed. Repeated open/close cycles did
  not leak a suspension request in the executable contract.
- `scripts/run_visual_activity_contract_tests.sh` is executable. The protected
  shared scheme SHA-256 remains
  `4b47ab85e3841de3202b4c0bdfed9540435ea2fbff5aeedb87ea095895105429`.

### Remaining physical-only acceptance

- No physical iPhone was connected. Perceived tab/scroll smoothness, DEBUG
  renderer-mode A/B attribution, Dynamic Island clearance, representative
  device-size layout, glass/readability judgment over bright and dark scenery,
  and the complete route/calendar/location/Session Note/timer physical matrix
  remain unclaimed.
- The production environment renderer is unchanged; no Simulator evidence
  justified a speculative GPU/renderer rewrite.
