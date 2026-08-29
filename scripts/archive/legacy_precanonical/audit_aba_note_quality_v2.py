from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ABA = (ROOT / "LifeRoute" / "Web" / "aba-ai-note-v1.js").read_text()

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

check("narrative is primary source", "SESSION NARRATIVE is the PRIMARY source of truth" in ABA)
check("screenshot data is supporting evidence", "CONFIRMED SCREENSHOT EVIDENCE is SUPPORTING quantitative evidence" in ABA)
check("saved profile remains context only", "SAVED PROFILE material is terminology/context only" in ABA)
check("narrative wins uncertain OCR matching", "preserve the narrative and omit the uncertain screenshot item" in ABA)
check("clinical ABA writing contract exists", "CLINICAL ABA WRITING STYLE" in ABA and "objective, observable, professional ABA/RBT documentation language" in ABA)
check("chronological narrative required", "Preserve chronological order" in ABA or "chronological narrative paragraphs" in ABA)
check("no generic filler", "Avoid vague filler" in ABA)
check("skill data integrated beside target", "Integrate skill data in the same paragraph/sentence as the matching skill" in ABA)
check("behavior counts integrated narratively", "Integrate behavior counts in the behavior paragraph" in ABA)
check("behavior counts are not converted to percentages", "Never convert behavior frequency/count data into a percentage" in ABA)
check("style exemplar is embedded", "EXAMPLE OF THE REQUIRED WRITING STYLE" in ABA and "The client demonstrated 66.67% correct manding" in ABA and "Two instances of mouthing objects were recorded" in ABA)
check("writer gets original narrative", "PRIMARY SESSION NARRATIVE:" in ABA)
check("grounded clinical editor always follows draft", '"aba-session-note-clinical-edit"' in ABA and "original sources again" in ABA.lower())
check("clinical editor can restore omitted supported facts", "Restore supported narrative events or matching quantitative data that the draft omitted" in ABA)
check("clinical editor removes unsupported facts", "Delete anything that is not supported" in ABA)
check("repair pass also receives original sources", "NARRATIVE:" in ABA and "CONFIRMED DATA:" in ABA and '"aba-session-note-repair"' in ABA)
check("note remains paragraph-only", "2-4 concise, cohesive, clinically worded ABA narrative paragraphs" in ABA)
check("note version upgraded", 'version: "2.0.0"' in ABA)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute ABA note quality audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit(1)
