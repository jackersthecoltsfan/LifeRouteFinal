import Foundation
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

enum LifeRouteIntelligenceError: LocalizedError {
    case unavailable
    case emptyInput
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device Apple Intelligence is not available on this iPhone right now."
        case .emptyInput:
            return "Add session facts before asking LifeRoute to generate anything."
        case .generationFailed(let message):
            return message.isEmpty ? "LifeRoute could not generate a response." : message
        }
    }
}

enum LifeRouteIntelligenceCore {
    static func recognizeText(in imageData: Data) async -> String {
        guard !imageData.isEmpty else { return "" }

        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                return observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .prefix(12_000)
                    .description
            } catch {
                return ""
            }
        }.value
    }

    static func generateABASessionNote(
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

        let clientCode = client?.code ?? "General / no client"
        let targets = client?.currentTargets.joined(separator: "; ") ?? "none"
        let behaviors = client?.behaviorsOfConcern.joined(separator: "; ") ?? "none"
        let communication = client?.communicationNotes ?? "none"
        let prompting = client?.promptingNotes ?? "none"

        let prompt = """
        Write one polished professional ABA session note as a cohesive chronological narrative using ONLY the session facts supplied below.

        REQUIRED WRITING STYLE:
        - The finished note should read like a human RBT wrote it directly after session, in the same concise chronological narrative style used for professional ABA session documentation.
        - When enough information exists, use about 3–5 cohesive paragraphs. A shorter session may use fewer paragraphs. Never pad the note just to reach a paragraph count.
        - Begin with where the RBT met with the client and who was present when those facts are actually supplied. Move naturally through the session in chronological order, then close with the final activity/transition and overall response only when those facts were supplied.
        - Use "the client" rather than treating the ABA-style client code as the client's name. The saved code is an identifier/context key, not permission to write it as a personal name throughout the note.
        - Keep related events together. Pairing, NET, FCT/manding, prompting, transitions, reinforcement, behavior events, and closing activities should appear where they occurred rather than in detached sections.
        - Weave clearly supplied quantitative data into the relevant sentence or event. Do not isolate data into a separate section, table, bullet list, or final data dump.
        - Prefer direct RBT documentation language such as "RBT began by...", "Throughout the session...", "RBT provided...", "The client demonstrated...", "Following this...", and "Toward the end of the session..." when those constructions fit the supplied facts.
        - Keep the prose objective, readable, clinically appropriate, and connected. Do not turn routine facts into broad interpretations.

        TARGET NARRATIVE FLOW WHEN THE FACTS SUPPORT IT:
        - Paragraph 1: setting/participants and how the session began, including pairing/FCT/NET or the first activity.
        - Paragraph 2: skill-acquisition work, prompting, client responding, and relevant quantitative target data.
        - Paragraph 3: behavior/transition events, redirection or other supplied intervention, and behavior data when relevant.
        - Paragraph 4: later reinforcement/activity work, final transition/activity, and the supplied overall response to intervention.
        - This is a flow guide, not a template. Omit any part that is not supported by the supplied facts.

        DATA / EVIDENCE PRIORITY:
        - The user's typed/pasted SESSION NARRATIVE is the primary source of what happened.
        - Clear SCREENSHOT OCR / DATA may supplement the narrative with recorded target/behavior values when the label and value are unambiguous.
        - Saved client information is terminology/context only and never proves an event occurred.
        - If a narrative fact and a compact OCR summary appear to conflict, preserve the explicit narrative event and do not erase it because of a summary metric.
        - A behavior-reduction metric of 0.00% is never evidence that treatment failed, that a behavior "still needs work," or that treatment was unsuccessful.
        - For an unambiguous behavior-reduction row such as biting or mouthing at 0.00%, and only when no supplied narrative fact says that behavior occurred, it is acceptable to state that the behavior was not observed/recorded during the session. Do not make that inference for skill-acquisition percentages.
        - If the narrative explicitly says a behavior occurred (for example, one refusal event), describe that event even if a related reduction row shows 0.00%; never convert an explicitly supplied event into "no behavior observed."
        - Do not dump raw OCR text into the note. Translate only clear, supported data into readable narrative prose.

        PROHIBITED OUTPUT SHAPES AND CONTENT:
        - NO title or heading such as "Session Narrative Note."
        - NO Markdown headings, bold labels, bullets, numbered lists, tables, SOAP sections, or report sections.
        - NO labels such as Date, Location, Participants, Setting, Session Overview, Behavior Data, Generalization, Assessment, Plan, or Conclusion.
        - NO placeholders such as "[Insert Date]", "[Insert Location]", or "[Insert RBT Name]". If a detail was not supplied, simply omit it.
        - NO invented environmental descriptions such as saying the environment was conducive to learning, calm, structured, distracting, or well-equipped unless the user explicitly supplied that fact.
        - NO invented progress/generalization conclusions, treatment-effect claims, motivation claims, clinical interpretations, caregiver recommendations, or future-treatment plans.
        - NO statements such as "the RBT will continue," "there is still work to be done," "plans for future interventions," or equivalent future-plan language unless the user explicitly supplied that plan as a session fact.
        - NO fabricated frequencies, percentages, prompt levels, interventions, targets, behaviors, attendees, caregiver statements, locations, billing facts, or outcomes.
        - Avoid mentalistic language. Use objective, observable descriptions.
        - Return ONLY the finished narrative paragraphs. No preface, disclaimer, heading, explanation, or closing commentary.

        CLIENT IDENTIFIER — context only: \(clientCode)
        SAVED TARGETS — context only: \(targets)
        SAVED BEHAVIORS — context only: \(behaviors)
        SAVED COMMUNICATION/FCT CONTEXT — context only: \(communication)
        SAVED PROMPTING/REINFORCEMENT CONTEXT — context only: \(prompting)

        SESSION NARRATIVE:
        \(cleanNarrative.isEmpty ? "none" : cleanNarrative)

        SCREENSHOT OCR / DATA:
        \(recognized.isEmpty ? "none" : recognized)
        """

        let instructions = """
        You are LifeRoute's factual ABA documentation assistant. Write only cohesive chronological RBT narrative paragraphs from supplied facts. Never use report headings, placeholders, bullets, future plans, invented interpretations, or unsupported clinical details. Treat explicit session narrative facts as primary evidence and integrate only clear supporting data.
        """

        let firstDraft = try await generate(instructions: instructions, prompt: prompt)
        guard sessionNoteNeedsNarrativeRepair(firstDraft) else {
            return firstDraft
        }

        let repairPrompt = """
        \(prompt)

        FORMAT CORRECTION — the prior generation shape was rejected:
        - Start over from the supplied SESSION NARRATIVE and clear OCR data; do not reuse or preserve wording from any rejected draft.
        - Return only plain narrative paragraphs with no title, section labels, markdown, bullets, placeholders, or future-plan language.
        - Keep explicit session events in chronological order and integrate supported percentages/frequencies into the sentences where those targets or behaviors are discussed.
        - Use "the client" rather than the client identifier as a personal name.
        - Do not infer that 0.00% behavior-reduction data means failure or lack of progress. Respect explicit narrative behavior events first.
        - Omit every environmental, progress, generalization, recommendation, and treatment-planning claim that was not explicitly supplied.
        """

        let repairedDraft = try await generate(
            instructions: "LifeRoute rejected the prior output format. Produce only a factual, chronological ABA narrative note in plain paragraphs. No headings, labels, markdown, placeholders, lists, invented interpretations, or future plans are allowed.",
            prompt: repairPrompt
        )

        guard !sessionNoteNeedsNarrativeRepair(repairedDraft) else {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute could not produce a clean narrative-only ABA note from this generation. Please regenerate from the same session facts."
            )
        }
        return repairedDraft
    }

    static func generateVisualScheduleDraft(
        description: String,
        client: LifeRouteClientProfile?
    ) async throws -> [String] {
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDescription.isEmpty else { throw LifeRouteIntelligenceError.emptyInput }

        let clientCode = client?.code ?? "General / no client"
        let communication = client?.communicationNotes ?? "none"

        let prompt = """
        Turn the user's requested routine into a simple visual schedule that can be shown one step at a time.

        RULES:
        - Preserve the user's intended order whenever an order is supplied.
        - Return between 2 and 12 short, concrete, observable steps.
        - Each step should usually be 1–6 words and understandable as a visual-card label.
        - Split compound actions only when doing so makes the sequence clearer.
        - Do not add treatment targets, prompting procedures, behavior protocols, diagnoses, consequences, reinforcement schedules, or other clinical instructions that the user did not supply.
        - Saved client context is terminology context only; do not invent client-specific actions from it.
        - Return ONLY one step per line. No numbering, bullets, heading, explanation, or closing sentence.

        CLIENT: \(clientCode)
        SAVED COMMUNICATION CONTEXT — terminology only: \(communication)

        ROUTINE / REQUEST:
        \(cleanDescription)
        """

        let generatedText = try await generate(
            instructions: "You create concise, concrete visual-schedule labels from the user's supplied routine without inventing clinical procedures.",
            prompt: prompt
        )

        let steps = generatedText
            .split(whereSeparator: \.isNewline)
            .map { sanitizeVisualScheduleLine(String($0)) }
            .filter { !$0.isEmpty }

        guard !steps.isEmpty else {
            throw LifeRouteIntelligenceError.generationFailed("LifeRoute could not create visual-schedule steps from that description.")
        }
        return Array(steps.prefix(12))
    }

    static func generateSessionPlan(
        client: LifeRouteClientProfile?,
        durationMinutes: Int,
        targets: [String],
        reinforcers: [String],
        additionalContext: String
    ) async throws -> String {
        guard !targets.isEmpty else { throw SessionToolsCoreError.noTargets }

        let boundedMinutes = max(15, min(480, durationMinutes))
        let clientCode = client?.code ?? "General / no client"
        let communication = client?.communicationNotes ?? "none"
        let prompting = client?.promptingNotes ?? "none"
        let caregiver = client?.caregiverNotes ?? "none"
        let clinical = client?.clinicalNotes ?? "none"
        let behaviors = client?.behaviorsOfConcern.joined(separator: "; ") ?? "none"
        let cleanAdditionalContext = additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)

        let prompt = """
        Build a practical proposed ABA session flow lasting about \(boundedMinutes) minutes from the clinician-approved information below.

        The plan should ACTUALLY ORGANIZE THE SESSION instead of repeating the input. Create a sensible sequence of time blocks with approximate minutes, balancing pairing/rapport, natural-environment opportunities, skill-acquisition work, transitions, reinforcement/movement breaks, and wrap-up when those ideas fit the supplied targets and context.

        HARD CLINICAL BOUNDARIES:
        - Do not invent treatment targets, behavior protocols, prompting procedures, reinforcement schedules, diagnoses, restrictions, or clinical instructions.
        - Use only the approved targets, known reinforcers, and saved context below as constraints.
        - You may organize and sequence supplied priorities, but never create a new intervention.
        - If the inputs do not justify a specific clinical procedure, keep that block general, for example: "work on approved targets in NET."
        - Include approximate time ranges that add up close to the requested duration.
        - Make the output immediately usable as a session outline.
        - Return concise plain text with one block per line in this format: "0–15 min — Pairing / setup: ..."
        - End with one short "Flex:" line describing where the RBT can shift time based on client responding while staying within the supervisor-approved plan.

        CLIENT: \(clientCode)
        DURATION: \(boundedMinutes) minutes
        APPROVED TARGETS: \(targets.joined(separator: "; "))
        KNOWN REINFORCERS / PREFERRED ACTIVITIES: \(reinforcers.isEmpty ? "none supplied" : reinforcers.joined(separator: "; "))
        BEHAVIORS OF CONCERN — context only: \(behaviors)
        COMMUNICATION/FCT CONTEXT: \(communication)
        PROMPTING/REINFORCEMENT CONTEXT: \(prompting)
        CAREGIVER/SETTING CONTEXT: \(caregiver)
        OTHER CLINICAL CONTEXT: \(clinical)
        ADDITIONAL SESSION CONTEXT: \(cleanAdditionalContext.isEmpty ? "none" : cleanAdditionalContext)
        """

        return try await generate(
            instructions: "You are LifeRoute's session-planning assistant for an RBT. Organize only supervisor-approved information and never invent treatment procedures.",
            prompt: prompt
        )
    }

    private static func sanitizeVisualScheduleLine(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = cleaned.first, "•-*–—".contains(first) {
            cleaned.removeFirst()
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let separatorIndex = cleaned.firstIndex(where: { $0 == "." || $0 == ")" }),
           cleaned[..<separatorIndex].allSatisfy(\.isNumber) {
            cleaned = String(cleaned[cleaned.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(cleaned.prefix(90))
    }

    private static func sessionNoteNeedsNarrativeRepair(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return true }

        let lower = cleaned.lowercased()
        let forbiddenTokens = [
            "###",
            "**",
            "[insert ",
            "session narrative note",
            "\ndate:",
            "\nlocation:",
            "\nparticipants:",
            "\nsetting:",
            "\nsession overview:",
            "\nbehavior data:",
            "\ngeneralization:",
            "\nassessment:",
            "\nplan:",
            "\nconclusion:",
        ]
        if forbiddenTokens.contains(where: lower.contains) {
            return true
        }

        let lines = cleaned.split(whereSeparator: \.isNewline)
        if lines.contains(where: { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return line.hasPrefix("- ") || line.hasPrefix("• ")
        }) {
            return true
        }

        return false
    }

    private static func generate(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw LifeRouteIntelligenceError.unavailable
            }

            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: String(prompt.prefix(16_000)))
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    throw LifeRouteIntelligenceError.generationFailed("")
                }
                return String(text.prefix(8_000))
            } catch let error as LifeRouteIntelligenceError {
                throw error
            } catch {
                throw LifeRouteIntelligenceError.generationFailed(error.localizedDescription)
            }
        }
        #endif

        throw LifeRouteIntelligenceError.unavailable
    }
}
