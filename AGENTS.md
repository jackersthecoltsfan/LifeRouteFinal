# LifeRoute Repository Instructions

## Repository authority

- This repository is the canonical source of truth for LifeRoute product code, architecture, documentation, build automation, and release configuration.
- Treat `APP_CREATION_PLAYBOOK.md`, `TESTFLIGHT_SETUP.md`, and everything relevant in `ReusableAppWorkflow/` as canonical workflow sources. Read and follow them before changing build, CI, signing, GitHub Actions, release, or TestFlight behavior.
- Also consult `README.md`, `FEATURE_PLAN.md`, `INTEGRATIONS.md`, `SECURITY_NOTES.md`, and `APP_WORKFLOW_LIBRARY.md` when work touches their subject matter. Keep documentation consistent with implemented behavior.
- Follow the repository's established GitHub-to-TestFlight automation. Do not invent or introduce a separate release process unless the product owner explicitly requests a redesign.

## Product and collaboration model

- LifeRoute is a native iOS app built with SwiftUI. Preserve native iOS behavior and progressively favor well-structured native SwiftUI implementations.
- The current app also contains an established bundled WebView feature runtime and native JavaScript bridges. Inspect and understand that architecture before changing or migrating it; do not break or casually replace working behavior.
- The product owner will usually describe desired features, behavior, and appearance in normal language rather than implementation terms. Translate those requests into appropriate technical designs and implementations. Ask for a product decision only when a consequential ambiguity cannot be resolved safely from existing behavior, repository context, or a reversible sensible default.
- For significant visual or navigation changes, follow the playbook's fast cosmetic-preview/Figma guidance when a preview would materially reduce ambiguity or rework.

## Before implementing changes

1. Read the applicable canonical documentation and any more-specific instructions in scope.
2. Inspect the existing architecture and trace the relevant end-to-end behavior, including SwiftUI, native services, the WebView bridge/runtime, persistence, generated patches, audits, and release preparation when applicable.
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

- `scripts/prepare_build.sh` is the deterministic preparation and preflight entry point shared by preview, iOS CI, and TestFlight. Keep it safe to run repeatedly and ensure the prepared source represents the code that is actually built.
- Feature patch scripts and audits are part of the current architecture. If a source file is generated or patched during preparation, update the authoritative input and the related patch/audit contracts together; do not make a change that is silently overwritten during preparation.
- Keep CI and TestFlight aligned with the canonical workflow. Respect release-control tags and latest-validated-`main` safeguards described in the workflow documentation.
- Do not push, release, dispatch workflows, or change external systems unless the user's request authorizes that action.

## Verification and handoff

- After meaningful code changes, run the available deterministic preparation/build checks and relevant tests or audits in proportion to the change.
- Inspect resulting diffs and generated output for regressions. Fix problems caused by the change before handing off.
- For iOS changes, run an available compile/build check when the local environment supports it. Report clearly when Xcode, Simulator, signing, a physical device, provider credentials, or another external dependency prevents local verification.
- Add or update focused automated tests or deterministic audits for important new behavior. Do not rely only on marker/substring checks when executable unit, integration, or UI tests are practical.
- For larger changes, summarize what changed, what was tested, any remaining risks, and recommended next steps.

## Security and privacy

- Never expose or commit secrets, credentials, API keys, private certificates, private keys, access tokens, refresh tokens, or private user information.
- App Store Connect credentials belong in GitHub Actions Secrets. Native credential material belongs in Keychain or another approved secure store; privileged provider credentials must not be embedded in WebView JavaScript or browser storage.
- Keep calendar/provider access least-privileged and read-only unless an approved feature explicitly requires more access.
- Minimize collection, persistence, logging, and analytics of calendar, location, client, schedule, and other sensitive user data. Do not log provider payloads or personally identifying information.
- Treat public OAuth client identifiers separately from secrets, but still avoid copying configuration into unrelated files.
