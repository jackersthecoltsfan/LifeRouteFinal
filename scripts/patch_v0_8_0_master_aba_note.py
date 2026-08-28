#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift"
text = PATH.read_text(encoding="utf-8")

MARKER = "v0.8.0 master ABA session-note parity"

if MARKER not in text:
    pattern = r'''    static func generateABASessionNote\(\n        narrative: String,\n        screenshotData: Data\?,\n        client: LifeRouteClientProfile\?\n    \) async throws -> String \{.*?\n    \}\n\n    static func generateVisualScheduleDraft'''

    replacement = r'''    static func generateABASessionNote(
        narrative: String,
        screenshotData: Data?,
        client: LifeRouteClientProfile?
    ) async throws -> String {
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        var recognized = ""
        if let screenshotData {
            recognized = await recognizeText(in: screenshotData)
        }

        guard !cleanNarrative.isEmpty || !recognized.isEmpty else {
            throw LifeRouteIntelligenceError.emptyInput
        }

        // v0.8.0 master ABA session-note parity:
        // Keep the user's chronology and direct facts dominant, preserve exact prompt/data details,
        // and fit the complete Master ABA contract inside the on-device model's constrained context.
        let boundedNarrative = String(cleanNarrative.prefix(5_200))
        let boundedOCR = String(recognized.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_700))
        let clientCode = client?.code ?? "General / no client"
        let clientContext = String(compactSessionNoteClientContext(client).prefix(550))

        let instructions = """
        Create one professional ABA session note from the supplied session evidence. Match the user's Master ABA Session Note standard.

        WRITING CONTRACT
        - Write natural, objective, person-first clinical prose appropriate for insurance documentation. Use approximately 2–4 concise cohesive paragraphs; do not pad a sparse session.
        - Preserve chronological order. Start with location/people present when supplied, then describe what the RBT did, the client's observable response, prompting, reinforcement, skill acquisition, transitions, and behaviors where they actually occurred.
        - Use professional ABA terminology when supported, including FCT, manding, waiting, accepting denied access/alternatives, following directions, choice making, visual schedules, PECS/choice boards, toileting, matching, play, imitation, social skills, table instruction, NET, pairing, and transitions.
        - Say "behaviors of concern," never "maladaptive behaviors." Avoid mentalistic or speculative language.
        - Preserve every explicitly supplied prompting level exactly: independent, gestural, verbal, visual, model, partial physical, full physical, or another supplied level. Never upgrade, downgrade, or invent a prompt.
        - Identify reinforcement that was actually delivered and describe its observable effectiveness only when the facts support that outcome.
        - Avoid repetitive sentence structure. The note should sound individualized to this session rather than copied from a template.

        BEHAVIOR / ABC CONTRACT
        - Include a behavior of concern only when the session narrative or clear quantitative data shows that it occurred. Do not mention absent/zero behaviors merely because a 0.00% row exists.
        - For each behavior that occurred, integrate the supplied antecedent, observable behavior, intervention(s), and outcome in chronological prose. If one ABC element was not supplied, omit that element rather than inventing it.
        - Never infer function, intent, emotion, motivation, or cause unless it was directly supplied as an observable/caregiver-reported fact.

        DATA CONTRACT
        - SESSION FACTS are the primary source of truth. Clear SCREENSHOT OCR / DATA is supporting quantitative evidence. SAVED CLIENT CONTEXT is terminology/context only and never proves that an event occurred.
        - Integrate clear percentages, frequencies, and other values naturally beside the matching target/behavior; never create a separate data dump.
        - If OCR conflicts with an explicit narrative fact, preserve the narrative fact and omit uncertain OCR rather than overwriting the user's account.
        - Describe successful or lower-performing skills objectively when clear data supports it, without inventing explanations or unsupported progress claims.
        - Never convert behavior frequency/count data into a percentage.

        COLLABORATION CONTRACT
        - If supplied, integrate caregiver coaching/modeling/education such as PECS, reinforcement, prompt fading, visual schedules, transition strategies, or behavior-management support.
        - If supplied, integrate BCBA/LBS collaboration such as programming updates, modeled interventions, feedback, protocol modifications, or skill demonstrations.
        - Do not invent caregiver training, supervisor involvement, programming changes, recommendations, or collaboration that was not supplied.

        CLOSING / MEDICAL-NECESSITY CONTRACT
        - End with a brief professional conclusion summarizing the client's participation/response using only supplied facts, followed by a concise statement that the RBT will continue implementing the established treatment plan during future sessions.
        - That generic treatment-plan continuation is required and is not permission to invent new goals, recommendations, protocols, outcomes, or future procedures.
        - Support medical necessity through concrete documentation of treatment targets, RBT intervention, prompting, reinforcement, behavior response, data, and supervision when present; do not make an unsupported declaration that services were medically necessary.

        HARD BOUNDARIES
        - Do not fabricate targets, behaviors, antecedents, prompt levels, interventions, attendees, locations, caregiver reports, frequencies, percentages, reinforcement, outcomes, clinical interpretations, diagnoses, billing facts, environmental descriptions, progress/generalization claims, or recommendations.
        - Use "the client" in the prose; the saved client code is context only and is not a name.
        - No title, headings, bullets, numbering, tables, SOAP/report sections, markdown, placeholders, data section, preface, disclaimer, or commentary. Return only the finished narrative paragraphs.
        """

        let prompt = """
        CLIENT IDENTIFIER — context only: \(clientCode)
        SAVED CLIENT CONTEXT — terminology only: \(clientContext.isEmpty ? "none" : clientContext)

        SESSION FACTS — primary evidence:
        \(boundedNarrative.isEmpty ? "none" : boundedNarrative)

        SCREENSHOT OCR / DATA — supporting evidence only:
        \(boundedOCR.isEmpty ? "none" : boundedOCR)
        """

        let firstDraft = try await generate(instructions: instructions, prompt: prompt)
        guard sessionNoteNeedsMasterABARepair(firstDraft) else {
            return firstDraft
        }

        let repairedDraft = try await generate(
            instructions: instructions + """

            FORMAT / CLINICAL CORRECTION:
            Re-create the note from the original evidence. Return only 2–4 cohesive chronological paragraphs. Use "behaviors of concern," preserve exact supplied prompts/data, mention only behaviors that occurred, keep supplied ABC details linked, include supplied caregiver/BCBA/LBS collaboration, and end with a brief participation summary plus continuation of the established treatment plan. Do not invent any missing fact.
            """,
            prompt: prompt
        )

        guard !sessionNoteNeedsMasterABARepair(repairedDraft) else {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute could not produce a clean Master ABA session note from this generation. Please regenerate from the same session facts."
            )
        }
        return repairedDraft
    }

    static func generateVisualScheduleDraft'''

    text, count = re.subn(pattern, lambda _match: replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("v0.8.0 Master ABA patch failed: could not replace ABA note generator")

    helper_anchor = '''    private static func sessionNoteNeedsNarrativeRepair(_ value: String) -> Bool {'''
    helper = r'''    private static func sessionNoteNeedsMasterABARepair(_ value: String) -> Bool {
        if sessionNoteNeedsNarrativeRepair(value) {
            return true
        }

        let lower = value.lowercased()
        if lower.contains("maladaptive behavior") || lower.contains("maladaptive behaviours") {
            return true
        }

        // The Master ABA contract requires a brief treatment-plan continuation close.
        if !lower.contains("treatment plan") {
            return true
        }

        return false
    }

'''
    if text.count(helper_anchor) != 1:
        raise SystemExit("v0.8.0 Master ABA patch failed: narrative repair helper anchor missing")
    text = text.replace(helper_anchor, helper + helper_anchor, 1)

    PATH.write_text(text, encoding="utf-8")

print(
    "LifeRoute v0.8.0 Master ABA session-note parity applied: 2–4 paragraph insurance-ready clinical narrative, "
    "strict evidence priority, exact prompting/data fidelity, occurrence-only behavior reporting with supplied ABC details, "
    "reinforcement/caregiver/supervisor integration, no fabrication, and required treatment-plan continuation close."
)
