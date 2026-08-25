from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ABA = ROOT / "LifeRoute" / "Web" / "aba-ai-note-v1.js"

text = ABA.read_text()

start = '        const prompt = `You are LifeRoute\'s ABA session-note writer.'
end = '        generatedText = draft ? normalizeGeneratedNote(draft, code) : "";'
start_i = text.find(start)
end_i = text.find(end, start_i)

if start_i < 0 or end_i < 0:
    if "SOURCE PRIORITY — this is mandatory" in text and "aba-session-note-clinical-edit" in text:
        print("ABA note quality v2 already applied.")
        raise SystemExit(0)
    raise SystemExit("ABA note quality v2: prompt region markers missing")

replacement = r'''        const styleExemplar = `EXAMPLE OF THE REQUIRED WRITING STYLE
Example narrative facts: RBT met with the client at the client's home with grandmother and BCBA present. RBT and BCBA paired with the client and targeted FCT using prompting to support choice-board communication. BCBA modeled skill-acquisition procedures for RBT. Later, RBT and BCBA transitioned the client outside to target transitions and additional manding using ASL and the choice board. The client used the swing, transitioned to chalk, and required redirection when transitioning back inside. Several instances of vocal protest were observed. RBT informed BCBA because vocal protest was not currently included as a behavior of concern.
Example confirmed data: Manding 66.67% correct; Responding to Name 33.33% correct; Social Interaction 100% correct; Transitions 40% correct; Refusal 0 occurrences; Bite 0 occurrences; Mouthing on Objects 2 occurrences.

Example finished note:
ABCD Session Note

RBT met with the client at the client's home with the client's grandmother and BCBA present. RBT and BCBA began the session with pairing and FCT opportunities, using prompting procedures to support the client in communicating through her choice board. The BCBA also modeled skill-acquisition procedures for the RBT. The client demonstrated 66.67% correct manding across opportunities and 33.33% correct responding to name. Social interaction remained a strength during the session, with the client demonstrating 100% correct responding for the social interaction target.

Partway through the session, the RBT and BCBA transitioned the client outside to target transitions and create additional manding opportunities using ASL and the choice board. The client accessed the swing before transitioning to chalk play. The client later transitioned back inside with the RBT and BCBA and required redirection to complete the transition. Overall, the client demonstrated 40% correct responding for transitions.

Two instances of mouthing objects were recorded during the session. No instances of refusal or biting were observed. The client also engaged in several instances of vocal protest; however, vocal protest was not currently included as a behavior of concern in the supplied session information. The RBT informed the BCBA of these observations for review.`;

        const prompt = `You are LifeRoute's ABA session-note writer. Transform the user's informal session narrative plus confirmed session data into a clinically worded, organized RBT session note. The note should read like professional ABA documentation written by a strong human documentation assistant, not like a generic AI summary.

SOURCE PRIORITY — this is mandatory:
1. The SESSION NARRATIVE is the PRIMARY source of truth for what happened, chronological order, setting, attendees, activities, prompting, transitions, observed behavior, and supervisor/caregiver communication.
2. CONFIRMED SCREENSHOT EVIDENCE is SUPPORTING quantitative evidence. Match each percentage or count to the narrative target/behavior it belongs with and weave it into that part of the narrative.
3. SAVED PROFILE material is terminology/context only. It is never evidence that something happened during this session.
4. If narrative and screenshot evidence conflict or cannot be confidently matched, preserve the narrative and omit the uncertain screenshot item rather than guessing.

OUTPUT FORMAT:
- First line exactly: ${title}
- Then a blank line.
- Then 2-4 cohesive chronological narrative paragraphs.
- No bullets, tables, SOAP fields, lists, template fields, placeholders, markdown bolding, or separate data section.
- Do not create Objective, Activities, Observations, Interventions, Feedback, Percent Correct, Generalization, or Baseline headings.

CLINICAL ABA WRITING STYLE:
- Write in objective, observable, professional ABA/RBT documentation language.
- Use “RBT,” “BCBA,” and “the client” rather than the technician's personal name.
- Open naturally with the setting and attendees when those facts are supplied.
- Describe what the RBT/BCBA targeted or implemented, what the client did, what support was required, and how transitions/behavior occurred.
- Prefer precise documentation verbs such as targeted, prompted, modeled, transitioned, required redirection, demonstrated, engaged in, recorded, observed, and informed when supported by the facts.
- Preserve appropriate supplied ABA terminology such as pairing, FCT, manding, ASL, NET, choice board, prompting, reinforcement, transitions, and behaviors of concern.
- Keep the note clinically worded but readable. Do not make it sound like a treatment plan, evaluation, diagnostic report, or academic paper.
- Do not claim improvement, progress, compliance, regulation, function, intent, mastery, effectiveness, or treatment response unless the supplied session facts explicitly support that statement.
- Avoid vague filler such as “worked on goals,” “had a good session,” “participated well,” or “interventions were effective” unless the narrative provides concrete evidence.

DATA INTEGRATION:
- Integrate skill data in the same paragraph/sentence as the matching skill. Example: “The client demonstrated 66.67% correct manding across opportunities.”
- Integrate behavior counts in the behavior paragraph. Example: “Two instances of mouthing objects were recorded.”
- For a confirmed zero behavior count, write naturally: “No instances of refusal were observed.”
- Never create a raw data list.
- Never convert behavior frequency/count data into a percentage.
- Do not force screenshot data into the note if it cannot be confidently matched to the narrative or a clearly named target.
- Ignore OCR junk such as repeated provider names, repeated Intervention rows, Generalization/Baseline headings, duplicate lines, and placeholders.

FACTUAL SAFETY:
- Do not invent frequencies, percentages, prompt levels, interventions, targets, behaviors, caregiver statements, locations, attendees, clinical interpretations, functions, or billing facts.
- Do not state that a saved target or behavior occurred unless the narrative or confirmed data demonstrates it.
- If screenshot OCR is unclear, omit it.
- If the narrative reports an observed behavior that is not currently tracked as a behavior of concern, preserve that distinction only when the narrative actually states it.

${styleExemplar}

NOW WRITE THIS SESSION NOTE.
Client code: ${code || "not specified"}
Saved targets — context only: ${targets.slice(0, 18).join("; ") || "none"}
Saved behaviors — context only: ${behaviors.slice(0, 18).join("; ") || "none"}
Saved communication/FCT — context only: ${communication || "none"}

PRIMARY SESSION NARRATIVE:
${narrative || "none"}

CONFIRMED SCREENSHOT EVIDENCE AFTER LOCAL OCR CLEANUP:
${evidence || "none"}

Return only the finished note.`;

        let result = await window.LifeRouteAI?.request?.("aba-session-note", prompt, { timeoutMs: 12000 });
        let draft = result?.success && result.text ? cleanGenerated(result.text) : "";

        // Always run a grounded editorial pass when a first draft exists. The editor
        // receives the original sources again, so it can restore supported facts/data
        // the first pass omitted while deleting anything the first pass invented.
        if (draft) {
          const clinicalEditPrompt = `You are the final clinical editor for an ABA RBT session note. Rebuild the draft into the exact LifeRoute narrative style using the ORIGINAL SOURCES below as the authority.

Your job is not merely to polish wording. Cross-check every sentence against the primary narrative and confirmed data. Restore supported narrative events or matching quantitative data that the draft omitted. Delete anything that is not supported. Preserve chronological order.

REQUIRED FINAL FORM:
- First line exactly: ${title}
- Blank line
- 2-4 concise, cohesive, clinically worded ABA narrative paragraphs
- No bullets, lists, templates, SOAP fields, placeholders, markdown, or data block
- Narrative is primary; screenshot data only quantifies matching targets/behaviors
- Saved profile is context only
- Objective and observable language only; no diagnosis, mentalistic inference, behavior function, invented response to treatment, or billing claims
- Naturally integrate percentages/counts beside the relevant target or behavior
- Use professional ABA terms where they were actually supplied

${styleExemplar}

PRIMARY SESSION NARRATIVE:
${narrative || "none"}

CONFIRMED SCREENSHOT EVIDENCE:
${evidence || "none"}

SAVED CONTEXT ONLY:
Targets: ${targets.slice(0, 18).join("; ") || "none"}
Behaviors: ${behaviors.slice(0, 18).join("; ") || "none"}
Communication/FCT: ${communication || "none"}

FIRST DRAFT TO CHECK AND REBUILD:
${draft.slice(0, 6000)}

Return only the corrected finished note.`;
          const edited = await window.LifeRouteAI?.request?.("aba-session-note-clinical-edit", clinicalEditPrompt, { timeoutMs: 12000 });
          if (edited?.success && edited.text) draft = cleanGenerated(edited.text);
        }

        // Last-resort structural repair if the editor still emitted template debris.
        if (draft && draftNeedsRepair(draft)) {
          const repairPrompt = `Using only the source facts below, rewrite this into ${title} followed by 2-4 clinical ABA narrative paragraphs. Remove all headings except the title, bullets, placeholders, raw data blocks, repeated OCR/provider noise, and unsupported claims. Keep narrative chronology and weave matching quantitative data naturally into the relevant sentences.\n\nNARRATIVE:\n${narrative || "none"}\n\nCONFIRMED DATA:\n${evidence || "none"}\n\nDRAFT:\n${draft.slice(0, 6000)}\n\nReturn only the finished note.`;
          const repaired = await window.LifeRouteAI?.request?.("aba-session-note-repair", repairPrompt, { timeoutMs: 9000 });
          if (repaired?.success && repaired.text) draft = cleanGenerated(repaired.text);
        }

'''

text = text[:start_i] + replacement + text[end_i:]
text = text.replace('version: "1.1.0"', 'version: "2.0.0"')
ABA.write_text(text)

print("LifeRoute ABA note quality v2 applied: narrative-primary writer + grounded clinical editor + style exemplar.")
