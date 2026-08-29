#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift"
text = PATH.read_text(encoding="utf-8")

if "v0.6.3 note context-window hotfix" not in text:
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

        // v0.6.3 note context-window hotfix:
        // Apple Foundation Models has a small on-device context budget. Keep the user's
        // actual session facts first, compact OCR aggressively, and keep saved client data
        // as short terminology-only context. This avoids the previous oversized static prompt.
        let boundedNarrative = String(cleanNarrative.prefix(5_200))
        let boundedOCR = String(recognized.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_600))
        let clientCode = client?.code ?? "General / no client"
        let clientContext = String(compactSessionNoteClientContext(client).prefix(500))

        let instructions = """
        Draft one professional ABA RBT session note using ONLY the session facts supplied below.

        REQUIRED WRITING STYLE:
        Use connected chronological RBT narrative paragraphs. Weave clearly supplied quantitative data into the narrative when present. Output only concise chronological prose paragraphs, usually 2–5. Start with setting/attendees when supplied. Keep interventions, prompting, client response, behaviors, transitions, reinforcement, and closing events in the order they occurred. Preserve exact supplied prompt levels and clear quantitative data. Use normal ABA terms such as pairing, NET, FCT, manding, waiting, transitions, redirection, reinforcement, and behaviors of concern when supported. Refer to the person as "the client," never use the saved client code as a name.

        Evidence priority: SESSION FACTS first; clear OCR data second; SAVED CLIENT CONTEXT is terminology only and never proves an event occurred. If OCR conflicts with explicit narrative facts, keep the narrative fact. A 0.00% behavior-reduction row may support "not observed/recorded" only when the narrative does not say that behavior occurred; never treat 0.00% as treatment failure.

        Do not invent targets, behaviors, prompt levels, interventions, attendees, locations, caregiver reports, frequencies, percentages, motives, progress claims, environmental descriptions, generalization, recommendations, outcomes, or future plans. No title, headings, bullets, SOAP/report sections, markdown, placeholders, data dump, disclaimer, or commentary. Return only the finished note.
        """

        let prompt = """
        CLIENT IDENTIFIER — context only: \(clientCode)
        SAVED CLIENT CONTEXT — terminology only: \(clientContext.isEmpty ? "none" : clientContext)

        SESSION FACTS:
        \(boundedNarrative.isEmpty ? "none" : boundedNarrative)

        SCREENSHOT OCR / DATA:
        \(boundedOCR.isEmpty ? "none" : boundedOCR)
        """

        let firstDraft = try await generate(instructions: instructions, prompt: prompt)
        guard sessionNoteNeedsNarrativeRepair(firstDraft) else {
            return firstDraft
        }

        // Retry with the same bounded facts and an even shorter format correction. Do not
        // resend the old giant master prompt or the rejected draft itself.
        let repairedDraft = try await generate(
            instructions: instructions + "\nFORMAT CORRECTION: plain narrative paragraphs only; no labels, headings, bullets, placeholders, or future-plan language.",
            prompt: prompt
        )

        guard !sessionNoteNeedsNarrativeRepair(repairedDraft) else {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute could not produce a clean narrative-only ABA note from this generation. Please regenerate from the same session facts."
            )
        }
        return repairedDraft
    }

    static func generateVisualScheduleDraft'''

    text, count = re.subn(pattern, lambda _match: replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("v0.6.3 note hotfix failed: could not replace ABA note generator")

    old = 'let response = try await session.respond(to: String(prompt.prefix(16_000)))'
    new = 'let response = try await session.respond(to: String(prompt.prefix(9_000)))'
    if text.count(old) != 1:
        raise SystemExit("v0.6.3 note hotfix failed: generic prompt cap marker missing")
    text = text.replace(old, new, 1)

    old_catch = '''            } catch let error as LifeRouteIntelligenceError {
                throw error
            } catch {
                throw LifeRouteIntelligenceError.generationFailed(error.localizedDescription)
            }'''
    new_catch = '''            } catch let error as LifeRouteIntelligenceError {
                throw error
            } catch {
                let lower = error.localizedDescription.lowercased()
                if lower.contains("context window") || lower.contains("context length") {
                    throw LifeRouteIntelligenceError.generationFailed(
                        "Apple Intelligence reported that the note input was too large. LifeRoute now compacts session-note requests automatically; if this still appears, shorten unusually long pasted facts or remove the screenshot and try again."
                    )
                }
                throw LifeRouteIntelligenceError.generationFailed(error.localizedDescription)
            }'''
    if text.count(old_catch) != 1:
        raise SystemExit("v0.6.3 note hotfix failed: generation error mapping marker missing")
    text = text.replace(old_catch, new_catch, 1)

    PATH.write_text(text, encoding="utf-8")

print("LifeRoute v0.6.3 session-note context-window hotfix applied: compact master instructions, bounded narrative/OCR/client context, 9k generic prompt cap, and clear context-overflow error mapping.")
