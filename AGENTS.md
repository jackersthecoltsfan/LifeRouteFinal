# LifeRoute Repository Instructions

## Repository authority

- This repository is the canonical source of truth for LifeRoute product code, architecture, documentation, build automation, and release configuration.
- Start continuity-sensitive work by reading `LIFEROUTE_HANDOFF.md` when it exists.
- Treat `APP_CREATION_PLAYBOOK.md`, `TESTFLIGHT_SETUP.md`, `GITHUB_ACTIONS_RUNBOOK.md`, and everything relevant in `ReusableAppWorkflow/` as canonical workflow sources. Read and follow them before changing build, CI, signing, GitHub Actions, release, or TestFlight behavior.
- Also consult `README.md`, `FEATURE_PLAN.md`, `INTEGRATIONS.md`, `SECURITY_NOTES.md`, and `APP_WORKFLOW_LIBRARY.md` when work touches their subject matter. Keep documentation consistent with implemented behavior.
- Follow the repository's established GitHub-to-TestFlight automation. Do not invent or introduce a separate release process unless the product owner explicitly requests a redesign.

## Product and collaboration model

- LifeRoute is a native iOS app built with SwiftUI. Preserve native iOS behavior and progressively favor well-structured native SwiftUI implementations.
- The current app also contains an established bundled WebView feature runtime and native JavaScript bridges. Inspect and understand that architecture before changing or migrating it; do not break or casually replace working behavior.
- The product owner will usually describe desired features, behavior, and appearance in normal language rather than implementation terms. Translate those requests into appropriate technical designs and implementations. Ask for a product decision only when a consequential ambiguity cannot be resolved safely from existing behavior, repository context, or a reversible sensible default.
- For significant visual or navigation changes, follow the playbook's fast cosmetic-preview/Figma guidance when a preview would materially reduce ambiguity or rework.

## LifeRoute control-center and execution-budget policy

- ChatGPT is the primary LifeRoute control center for architecture, implementation through connected GitHub, review, CI coordination, release decisions, visual evidence review, and project continuity.
- Minimize Codex usage. Use Codex when local Xcode/Simulator/native execution, local repository tooling, or another genuinely local-only capability materially improves confidence or speed. Do not spend Codex usage on repository browsing, ordinary edits, or analysis that ChatGPT/GitHub can perform directly.
- When the product owner identifies a temporary Codex-usage window, prioritize high-value native validation inside that window without transferring general project ownership away from ChatGPT.
- GitHub remains the committed-code and CI source of truth regardless of which tool performs a local validation pass.

## Before implementing changes

1. Read the current handoff and applicable canonical documentation and any more-specific instructions in scope.
2. Inspect the existing architecture and trace the relevant end-to-end behavior, including SwiftUI, native services, the quarantined WebView history, persistence, current semantic validation, and release preparation when applicable.
3. Check the working tree and preserve unrelated user changes.
4. Reuse existing models, services, components, bridge contracts, persistence mechanisms, and workflow infrastructure where appropriate.
5. Avoid unnecessarily rebuilding working functionality. Preserve existing behavior unless the requested change requires modifying it.
6. Identify privacy, permissions, external-service, migration, and backward-compatibility implications before coding.

## Engineering direction

- Prefer modern native SwiftUI and current Apple APIs, with availability checks and fallbacks where the deployment target requires them.
- Use clean, explicit state ownership and data flow. Keep view bodies focused on presentation and move substantial business logic out of views.
- Build reusable, accessible components with stable identity, narrow dependencies, and testable behavior.
- Maintain clear boundaries between UI, business/domain logic, app routing/navigation, calendar normalization, time-gap planning, location services, route calculation, recommendation/scoring logic, persistence, authentication, and external integrations.
- Prefer maintainable code and deliberate migrations over quick patches, duplicated state, global coupling, or fragile ordering dependencies.
- Follow native iOS conventions and accessibility expectations, including Dynamic Type, VoiceOver semantics, sufficient contrast, appropriate touch targets, reduced-motion behavior, and `Button` or other semantic controls for interaction.
- Keep UI responsive and performant. Avoid blocking the main actor, unnecessary state invalidation, heavy work in SwiftUI view bodies, unstable collection identity, and unbounded location/network work.
- Where legacy WebView functionality remains, preserve bridge compatibility and deterministic script ordering. New complexity should not deepen global JavaScript coupling when a clean native/domain boundary is practical.

## Product design direction

LifeRoute should feel:

- premium, sleek, intelligent, and streamlined;
- futuristic but professional;
- grounded in a dark-blue and gold core identity while supporting customizable themes;
- organized with strong information hierarchy;
- polished through purposeful animation and interaction without visual clutter.

Use consistent design tokens and reusable components rather than isolated styling. Respect accessibility settings and avoid sacrificing clarity, legibility, or performance for visual effects.

## Dynamic and context-aware roadmap

- Evolve LifeRoute toward a coherent, dynamic planning system rather than a collection of disconnected features.
- Important capabilities include intelligent calendar-gap planning, current-location awareness, saved places and preferences, route-aware recommendations, and future AI-assisted planning.
- Keep provider calendar data normalized behind shared domain models. Provider behavior is read-only unless the product owner explicitly changes that scope.
- Recommendations should eventually be explainable, testable, and based on explicit inputs such as time available, route duration, distance, stop duration, opening hours, transport mode, current context, saved preferences, and confidence/freshness.
- Treat AI as an assistive layer over trustworthy deterministic data and actions. Provide safe fallbacks and never make core planning depend solely on opaque or unavailable AI output.

## Existing build and release architecture

- Checked-in `LifeRoute/`, `LifeRouteLiveActivityWidget/`, and `LifeRoute.xcodeproj/` are the canonical v0.8.3 shipping source. Never reconstruct current development by replaying archived v0.x patches.
- `scripts/prepare_build.sh` is a deterministic, idempotent validation-only preflight. Change canonical source directly and update `validate_fast.sh` or `validate_full.sh` when a current semantic invariant changes.
- Files under `scripts/archive/` and `docs/archive/` are archaeology only. They must not execute in normal development, pull-request, main, Pages, or release paths.
- Keep CI and TestFlight aligned with the canonical workflow. Ordinary pushes never authorize or upload a release by themselves.
- The product owner has granted ChatGPT standing authorization to initiate one TestFlight physical-validation release in any rolling 60-minute window when the current checkpoint is meaningfully worth testing and prerequisite validation/release-state checks have passed.
- A second or additional TestFlight initiation inside the same rolling 60-minute window requires explicit owner authorization. Explicit owner authorization may also direct a specific TestFlight run at any time.
- Every assistant-initiated TestFlight must remain exact-SHA guarded, must not overlap an unresolved prior upload state, and must still satisfy the repository's release-equivalent validation requirements. The once-per-hour authorization is permission to release when sensible, not permission to bypass safety gates.
- Do not push, release, dispatch workflows, or change external systems outside the standing permissions above or another explicit user authorization.

## GitHub Actions reliability

- Before attempting to repair queued/stuck Actions, check official GitHub service status and follow `GITHUB_ACTIONS_RUNBOOK.md`.
- Do not create commits merely to wake an upstream-degraded Actions queue.
- During an active GitHub Actions incident, keep workflow-hardening/diagnostic edits on a non-`main` branch and avoid generating replacement runs.
- When GitHub is operational, use normal cancellation once and force-cancel only for a run that still meets the documented zombie criteria. Do not loop cancellation requests.
- Keep expensive macOS work narrowly triggered and avoid duplicating current semantic validation unnecessarily.
- The assistant TestFlight bridge should require already-completed successful validation and fail fast rather than holding a runner while polling CI.

## Verification and handoff

- After meaningful code changes, run the available deterministic preparation/build checks and relevant tests or audits in proportion to the change.
- Inspect resulting diffs and generated output for regressions. Fix problems caused by the change before handing off.
- For iOS changes, run an available compile/build check when the local environment supports it. Report clearly when Xcode, Simulator, signing, a physical device, provider credentials, or another external dependency prevents local verification.
- Add or update focused automated tests or deterministic audits for important new behavior. Do not rely only on marker/substring checks when executable unit, integration, or UI tests are practical.
- For larger changes, summarize what changed, what was tested, any remaining risks, and recommended next steps.
- Refresh `LIFEROUTE_HANDOFF.md` after major milestones, release-state changes, material workflow changes, or concluded troubleshooting incidents. Keep it compact and do not include secrets or unrelated personal data.
- Proactively recommend a new LifeRoute chat when the context-pressure signals in `LIFEROUTE_HANDOFF.md` appear. Update the handoff first, then give the short restart prompt instead of asking the user to reconstruct project history.

## Security and privacy

- Never expose or commit secrets, credentials, API keys, private certificates, private keys, access tokens, refresh tokens, or private user information.
- App Store Connect credentials belong in GitHub Actions Secrets. Native credential material belongs in Keychain or another approved secure store; privileged provider credentials must not be embedded in WebView JavaScript or browser storage.
- Keep calendar/provider access least-privileged and read-only unless an approved feature explicitly requires more access.
- Minimize collection, persistence, logging, and analytics of calendar, location, client, schedule, and other sensitive user data. Do not log provider payloads or personally identifying information.
- Treat public OAuth client identifiers separately from secrets, but still avoid copying configuration into unrelated files.
