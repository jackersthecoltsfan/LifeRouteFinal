# App Creation → TestFlight Playbook

This is the canonical streamlined workflow for building future iOS apps using the LifeRoute system as the reusable base.

## Goal

For normal app development, Brandon should mainly do three things:

1. Describe what he wants built or changed.
2. Test the resulting build on his iPhone through TestFlight.
3. Report what works, what feels wrong, or what should change next.

CI, regression auditing, simulator compilation, build numbering, Apple signing, IPA export, TestFlight upload, and first-line build-failure repair should be automated wherever possible.

---

## Recommended tool roles

### ChatGPT project/master chat
Use for product thinking, feature decisions, requirements, prioritization, release decisions, and maintaining the project narrative. A clean chat can resume by reading this playbook and the repository.

### GitHub — installed/connected
Source of truth for code and workflow state. ChatGPT/Codex can inspect code, make targeted repository edits, inspect CI/TestFlight jobs and logs, and verify release results.

### Figma — installed/connected
Use for significant UI/UX work when a visual design pass will prevent back-and-forth. The iOS workflow can move in either direction: Figma → SwiftUI implementation or SwiftUI → Figma documentation/design refinement. Skip Figma for tiny UI changes that are faster to implement directly.

### SwiftUI Expert — installed
Use during SwiftUI implementation/review for current APIs, state management, view composition, accessibility, and performance guidance.

### Build iOS Apps — installed; best used in Codex
Use for code-heavy implementation, Simulator launch/debugging, screenshots/logs, SwiftUI refactors, performance investigation, App Intents, and other native iOS work.

### Codex TestFlight Release — installed
Use as a reusable release pattern for iOS build-number management, archive/export/upload, App Store Connect API authentication, TestFlight metadata, and verification.

### Sentry — optional, not currently installed
Recommended once TestFlight testing becomes broader or the app is nearing public release. It can reduce manual debugging by surfacing real crashes/errors from testers instead of relying only on screenshots and descriptions.

### Codex Security — optional, not currently installed
Useful as an extra pre-release security review for apps that begin handling accounts, sensitive data, payments, or more external services. It is not required for every small LifeRoute iteration.

---

## Phase 1 — Idea and product definition

### Brandon does
- Describe the app idea in normal language.
- State the main problem it should solve.
- Call out any must-have features, strong visual preferences, privacy constraints, or integrations he already knows he wants.
- Make product choices only when there are genuine tradeoffs that cannot be safely inferred.

### ChatGPT/Codex does
- Turn the idea into a compact product brief.
- Identify the MVP, later features, required Apple capabilities, external APIs, privacy implications, and likely costs.
- Reuse proven LifeRoute architecture/workflows rather than rebuilding CI/release infrastructure from scratch.
- Avoid unnecessary questions; choose sensible defaults when the decision is reversible.

### Figma decision
Use Figma when the app needs a strong visual identity, multiple new screens, a design system, or user approval before implementation. Skip it for straightforward/native screens and small refinements.

---

## Phase 2 — One-time setup for a new app

These are the main steps that still require Brandon because of account, legal, security, or permission boundaries.

### Brandon does
1. **Create the new GitHub repository** if a repository does not already exist. The current GitHub connector can work extensively inside repositories but does not expose normal repository creation as part of this workflow.
2. **Create/confirm the app in Apple Developer / App Store Connect**:
   - choose/confirm the app name,
   - create the primary bundle identifier,
   - create extra identifiers for extensions such as Live Activities/widgets when needed,
   - create the App Store Connect app record.
3. **Add the four Apple GitHub Actions secrets to the new repository**:
   - `APPLE_TEAM_ID`
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_PRIVATE_KEY`
4. Handle any Apple legal agreements, developer-program renewal/payment, two-factor authentication, or account-verification prompts that Apple requires.
5. Install/open TestFlight on the iPhone and accept any tester invitation/Apple prompt if needed.

### Important reuse
- The App Store Connect API key can generally be reused for future apps when its permissions cover those apps; a new `.p8` key should not be created for every release.
- Routine releases should not require downloading `.p8`/`.p12` files again.
- Routine releases should not require PC-side certificate work.

### ChatGPT/Codex does
- Bootstrap the reusable LifeRoute workflow pack for the new repository.
- Configure the project/scheme/bundle IDs in the workflow templates.
- Build the app skeleton and features.
- Create/maintain `scripts/prepare_build.sh` and project-specific audits.
- Set up CI, automatic TestFlight handoff, signing cleanup, and release artifacts.

---

## Phase 3 — Design and implementation

### Brandon does
- For large visual changes: review a Figma design or screenshot when asked and say what he likes/does not like.
- For normal feature changes: simply describe the desired behavior.

### ChatGPT/Codex does
- Implement the feature.
- Use Figma ↔ SwiftUI handoff when it materially reduces ambiguity.
- Use native SwiftUI/iOS patterns where appropriate.
- Add/update tests and deterministic audit checks for critical behavior.
- Commit changes to GitHub.

Brandon should not need to manually copy generated source files between ChatGPT, GitHub, Xcode, and TestFlight during the normal workflow.

---

## Phase 4 — Automatic validation and release

For release-eligible changes on `main`, the intended chain is automatic:

1. GitHub checks out the source.
2. `scripts/prepare_build.sh` creates the exact prepared app used by release builds.
3. Full regression audits run.
4. The app builds for the iOS Simulator with signing disabled.
5. Only the latest successfully validated `main` commit is eligible for automatic promotion.
6. The TestFlight workflow prepares and audits the release again.
7. Apple credentials and bundle IDs are validated.
8. Xcode archives the real-device Release build.
9. The signed IPA is exported.
10. The IPA uploads to App Store Connect/TestFlight.
11. A short-lived IPA artifact is saved for debugging/recovery.
12. Temporary Apple signing assets created by the ephemeral runner are cleaned up.

### Release-control tags
The assistant/build process manages these when needed:

- `[no-testflight]` — run validation but do not create a TestFlight build.
- `[web-only]` — preview/web-only change; do not create a TestFlight build.
- No tag — a passing current `main` commit is eligible for automatic TestFlight promotion.

Brandon should not have to decide or type these tags during normal development.

---

## Phase 5 — Automatic failure handling

The LifeRoute pattern includes a condition-watch repair policy:

1. Healthy or legitimately in-progress builds stay quiet.
2. On failure, inspect the actual failing job/step/logs.
3. Make one targeted repair: `auto-repair 1/2`.
4. If the replacement chain still fails, make one more evidence-based repair: `auto-repair 2/2`.
5. If it still fails after attempt 2, stop changing code and escalate the exact error plus both attempted fixes.
6. If a repair succeeds and reaches TestFlight, report that success briefly.

This removes the manual step of Brandon noticing a red GitHub build, copying the error, and asking ChatGPT to debug it in ordinary cases.

---

## Phase 6 — TestFlight testing

### Brandon does
1. Open TestFlight when the new build becomes available.
2. Tap **Update** / **Install**.
3. Use the app normally on the real iPhone.
4. Tell ChatGPT what is broken, confusing, ugly, slow, or missing; screenshots are useful for visual problems.

### ChatGPT/Codex does
- Trace the issue to code/workflow/runtime behavior.
- Use Simulator debugging and logs when appropriate.
- Patch the problem.
- Let the automated CI → TestFlight chain repeat.

This real-device testing step remains intentionally human because feel, usefulness, permissions, device behavior, and UX quality cannot be fully replaced by CI.

---

## Optional next-level improvements

### Add Sentry when testing expands
Use Sentry when manual bug reports become a bottleneck. It can surface crashes/errors directly and make tester feedback much more actionable.

### Add Codex Security before broader/public distribution
Use for additional codebase/security review, especially after introducing authentication, sensitive data, backend services, or payments.

### Keep project management lightweight
Do not add extra task-management tools merely because they exist. For a solo/small project, the master ChatGPT project, GitHub repository/issues, and this playbook are usually enough. Add Notion/Linear/ClickUp only when coordination overhead actually appears.

---

## The shortest possible normal LifeRoute loop

**Brandon:** “Change/add X.”

**ChatGPT/Codex:** design if needed → implement → commit → audit/build automatically → TestFlight automatically → verify upload.

**Brandon:** install/update in TestFlight → test → report feedback.

Repeat.

---

## What Brandon should NOT have to do each iteration

- Re-explain the GitHub/TestFlight architecture.
- Manually upload source files to GitHub.
- Open Xcode just to produce a build.
- Download fresh signing keys/certificates.
- Create a new certificate for each update.
- Increment build numbers manually.
- Run the iOS CI workflow manually.
- Trigger TestFlight manually after CI passes.
- Read build logs before the automatic repair layer has had a chance to handle the failure.
- Recreate prior design/workflow decisions from memory.

---

## Clean-chat handoff

Start the next project chat with:

> Continue LifeRoute from the repository. Treat `APP_CREATION_PLAYBOOK.md`, `TESTFLIGHT_SETUP.md`, and `ReusableAppWorkflow/` as the canonical workflow sources. Use the streamlined workflow: I describe product changes, you handle implementation/audits/GitHub/release automation, and I handle only the manual steps the playbook assigns to me.
