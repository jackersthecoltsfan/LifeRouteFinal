#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = (ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift").read_text(encoding="utf-8")
PREP = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

check("v0.8.0 Master ABA marker materialized", "v0.8.0 master ABA session-note parity" in SWIFT)
check("single ABA note generator remains", SWIFT.count("static func generateABASessionNote(") == 1)
check("2-4 paragraph contract", "approximately 2–4 concise cohesive paragraphs" in SWIFT and "Return only 2–4 cohesive chronological paragraphs" in SWIFT)
check("legacy 3-5 paragraph contract removed", "3–5 cohesive paragraphs" not in SWIFT)
check("insurance documentation style", "appropriate for insurance documentation" in SWIFT)
check("objective person-first language", "natural, objective, person-first clinical prose" in SWIFT)
check("behaviors of concern terminology", "Say \"behaviors of concern,\" never \"maladaptive behaviors.\"" in SWIFT)
check("maladaptive-output repair guard", "lower.contains(\"maladaptive behavior\")" in SWIFT)
check("chronology required", "Preserve chronological order" in SWIFT)
check("exact prompt-level fidelity", "Preserve every explicitly supplied prompting level exactly" in SWIFT and "Never upgrade, downgrade, or invent a prompt" in SWIFT)
check("reinforcement effectiveness grounded", "describe its observable effectiveness only when the facts support that outcome" in SWIFT)
check("occurrence-only behavior rule", "Include a behavior of concern only when" in SWIFT and "Do not mention absent/zero behaviors" in SWIFT)
check("legacy zero-behavior inference removed", "acceptable to state that the behavior was not observed/recorded" not in SWIFT)
check("ABC behavior contract", "antecedent, observable behavior, intervention(s), and outcome" in SWIFT and "omit that element rather than inventing it" in SWIFT)
check("no inferred function or intent", "Never infer function, intent, emotion, motivation, or cause" in SWIFT)
check("narrative primary evidence", "SESSION FACTS are the primary source of truth" in SWIFT)
check("OCR supporting evidence", "SCREENSHOT OCR / DATA is supporting quantitative evidence" in SWIFT)
check("saved profile context only", "SAVED CLIENT CONTEXT is terminology/context only and never proves" in SWIFT)
check("narrative wins OCR conflict", "preserve the narrative fact and omit uncertain OCR" in SWIFT)
check("data integrated beside target", "Integrate clear percentages, frequencies, and other values naturally beside the matching target/behavior" in SWIFT)
check("behavior counts never converted to percentages", "Never convert behavior frequency/count data into a percentage" in SWIFT)
check("caregiver collaboration contract", "caregiver coaching/modeling/education" in SWIFT and "prompt fading" in SWIFT)
check("BCBA LBS collaboration contract", "BCBA/LBS collaboration" in SWIFT and "protocol modifications" in SWIFT)
check("no invented collaboration", "Do not invent caregiver training, supervisor involvement" in SWIFT)
check("treatment-plan closing required", "continue implementing the established treatment plan during future sessions" in SWIFT)
check("legacy no-future-plan rule removed", "Do not add a generic future plan" not in SWIFT and "NO statements such as \"the RBT will continue\"" not in SWIFT)
check("closing repair guard", "if !lower.contains(\"treatment plan\")" in SWIFT)
check("medical necessity supported not asserted", "Support medical necessity through concrete documentation" in SWIFT and "do not make an unsupported declaration" in SWIFT)
check("no fabrication boundary", "Do not fabricate targets, behaviors, antecedents, prompt levels, interventions" in SWIFT)
check("client code remains context only", "the saved client code is context only and is not a name" in SWIFT)
check("narrative context bounded", "cleanNarrative.prefix(5_200)" in SWIFT)
check("OCR context bounded", "prefix(1_700)" in SWIFT)
check("client context bounded", "compactSessionNoteClientContext(client).prefix(550)" in SWIFT)
check("repair regenerates from original evidence", "Re-create the note from the original evidence" in SWIFT and "prompt: prompt" in SWIFT)
check("plain narrative output only", "No title, headings, bullets, numbering, tables, SOAP/report sections" in SWIFT)
check("existing narrative format guard retained", "private static func sessionNoteNeedsNarrativeRepair" in SWIFT)
check("Master ABA repair guard added", "private static func sessionNoteNeedsMasterABARepair" in SWIFT)
check("single Master ABA repair guard remains", SWIFT.count("private static func sessionNoteNeedsMasterABARepair") == 1)
check("on-device 9k context cap preserved", "session.respond(to: String(prompt.prefix(9_000)))" in SWIFT)
check("deterministic patch wired", "python3 scripts/patch_v0_8_0_master_aba_note.py" in PREP)
check("v0.8.0 audit wired", "python3 scripts/audit_v0_8_0_master_aba_note.py" in PREP)
check("protected post-note regressions wired", all(token in PREP for token in [
    "python3 scripts/audit_v0_5_0_functional_shell.py",
    "python3 scripts/audit_v0_5_0_core_navigation.py",
    "python3 scripts/audit_v0_5_0_calendar_core.py",
    "python3 scripts/audit_v0_5_0_routing_location_core.py",
    "python3 scripts/audit_v0_5_0_clients_core.py",
    "python3 scripts/audit_v0_5_0_stability_architecture.py",
    "python3 scripts/audit_v0_7_1_protected_regressions.py",
]))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.8.0 Master ABA note audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Failed checks: " + "; ".join(failed))
