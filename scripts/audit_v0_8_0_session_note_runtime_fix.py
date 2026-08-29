#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEW = (ROOT / "LifeRoute/AIClinicalToolsViews.swift").read_text(encoding="utf-8")
CORE = (ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift").read_text(encoding="utf-8")
PATCH = (ROOT / "scripts/patch_v0_8_0_session_note_runtime_fix.py").read_text(encoding="utf-8")
PREP = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")

checks = []


def check(name, condition):
    checks.append((name, bool(condition)))


states = [
    "case idle",
    "case checkingAvailability",
    "case generating",
    "case repairing",
    "case success",
    "case unavailable(String)",
    "case failed(String)",
    "case timedOut",
    "case cancelled",
]
check("explicit generation state machine", all(token in VIEW for token in states))
check("view owns one retained runtime model", "@StateObject private var runtime: AISessionNoteRuntimeModel" in VIEW)
check("loose generation booleans removed from note screen", "@State private var isGenerating" not in VIEW.split("struct AISessionPlanBuilderView", 1)[0])
check("active task and request race retained", "private var activeTask: Task<Void, Never>?" in VIEW and "private var activeRace: SessionNoteRequestRace?" in VIEW)
check("overlapping generation blocked", "guard !state.isActive else { return }" in VIEW)
check("stale completion guard uses request identity", "requestID == currentRequestID" in VIEW and "self.requestID == requestID" in VIEW)
check("privacy-safe runtime diagnostics expose phases without inputs", "category: \"SessionNoteRuntime\"" in VIEW and "bounded repair pass active" in VIEW and "narrative, privacy" not in VIEW)
check("navigation and lifecycle cancel intentionally", ".onDisappear" in VIEW and ".onChange(of: scenePhase)" in VIEW and VIEW.count("runtime.cancel()") >= 3)
check("request race cancels model and watchdog", "generationTask?.cancel()" in VIEW and "timeoutTask?.cancel()" in VIEW)
check("timeout is bounded", "timeoutSeconds: UInt64 = 75" in VIEW and "case timedOut" in VIEW)
check("repair pass is visible and resets its watchdog", "state = .repairing" in VIEW and "activeRace?.restartTimeout()" in VIEW)
check("availability is checked before generation", "state = .checkingAvailability" in VIEW and "await generator.availability()" in VIEW)
check("actual Foundation Models availability reasons exposed", all(token in CORE for token in [
    ".unavailable(.deviceNotEligible)",
    ".unavailable(.appleIntelligenceNotEnabled)",
    ".unavailable(.modelNotReady)",
]))
check(
    "production generator remains on-device and returns its generated draft",
    "FoundationModelSessionNoteGenerator" in VIEW
    and "return try await LifeRouteIntelligenceCore.generateABASessionNote(" in VIEW,
)
check("timed-out request cannot overlap a still-cancelling model session", "private var isBusy = false" in VIEW and "previous on-device model request is still cancelling" in VIEW)
check("generation progress crosses service boundary", "SessionNoteGenerationProgress" in CORE and "await progress(.generating)" in CORE and "await progress(.repairing)" in CORE)
check("successful draft updates only after nonempty result", "generatedNote = cleaned" in VIEW and "guard !cleaned.isEmpty" in VIEW)
check("failed regeneration does not erase previous draft", VIEW.split("struct AISessionPlanBuilderView", 1)[0].count("generatedNote = \"\"") == 1)
check("session inputs remain view-owned through failures", all(token in VIEW for token in [
    "@State private var selectedClientCode",
    "@State private var narrative",
    "@State private var selectedPhotoItem",
    "@State private var screenshotData",
]))
check("prominent accessible status and retry", "generationStatusCard" in VIEW and "Button(\"Try again\")" in VIEW and ".accessibilityLabel(\"Session note generation status\")" in VIEW)
check("user can cancel active generation", "Button(\"Cancel generation\")" in VIEW)
check("draft remains editable and copyable", "TextEditor(text: $runtime.generatedNote)" in VIEW and "UIPasteboard.general.string = runtime.generatedNote" in VIEW)
check("no programmatic scrolling introduced", "ScrollViewReader" not in VIEW.split("struct AISessionPlanBuilderView", 1)[0])
check("DEBUG fixture generator is release-isolated", "#if DEBUG" in VIEW and "SessionNoteFixtureGenerator" in VIEW)
fixture_modes = [
    "case success",
    "case delayedSuccess",
    "case unavailable",
    "case error",
    "case empty",
    "case timeout",
    "case cancellation",
    "case repair",
    "case regenerationFailure",
]
check("DEBUG fixtures cover required outcomes", all(token in VIEW for token in fixture_modes))
check("DEBUG fixture uses explicit launch argument", "-LifeRouteSessionNoteFixture" in VIEW)
check("Master ABA supplied-facts prompt remains intact", "using ONLY the session facts supplied below" in CORE)
check("Master ABA repair guard remains intact", "sessionNoteNeedsMasterABARepair" in CORE and "treatment plan" in CORE)
check("runtime patch is deterministic and idempotent", "VIEW_MARKER" in PATCH and "CORE_MARKER" in PATCH)
check("runtime patch runs after visual generator", PREP.index("patch_v0_8_0_session_note_runtime_fix.py") > PREP.index("patch_v0_8_0_aba_visual_generator_performance_hotfix.py"))
check("runtime audit wired", "python3 scripts/audit_v0_8_0_session_note_runtime_fix.py" in PREP)
check("post-repair Master ABA audit reruns", PREP.rindex("python3 scripts/audit_v0_8_0_master_aba_note.py") > PREP.index("patch_v0_8_0_session_note_runtime_fix.py"))
check("post-repair visual and protected audits rerun", all(PREP.rindex(token) > PREP.index("patch_v0_8_0_session_note_runtime_fix.py") for token in [
    "python3 scripts/audit_v0_8_0_aba_visual_generator_foundation.py",
    "python3 scripts/audit_v0_7_1_protected_regressions.py",
    "python3 scripts/audit_v0_5_0_performance_architecture.py",
    "python3 scripts/audit_v0_5_0_stability_architecture.py",
]))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.8.0 session-note runtime audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
