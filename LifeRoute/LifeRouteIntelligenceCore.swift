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
        Produce ONE finished professional ABA/RBT session note using ONLY facts actually supplied in SESSION FACTS and clearly readable SCREENSHOT DATA below.

        OUTPUT CONTRACT — THIS OVERRIDES GENERIC REPORT FORMATTING:
        - Return only 2–5 cohesive prose paragraphs in chronological order.
        - Do NOT use Markdown headings, a title, section labels, bullets, numbered lists, tables, or field labels.
        - Do NOT output sections such as Date, Location, Participants, Setting, Session Overview, Behavior Data, Generalization, Assessment, Plan, or Conclusion.
        - Do NOT output placeholders such as [Insert Date], [Insert Location], [Insert RBT Name], or any other bracketed missing information.
        - A strong opening is direct and factual: identify the session location and people present only when supplied, then describe how the session began.
        - Describe pairing, NET, FCT/manding, skill acquisition, prompting, transitions, reinforcement, behavior events, environmental constraints, and session closure only when those details were supplied.
        - Keep related events and their corresponding data in the same paragraph and move through the session as it happened.
        - Weave quantitative data naturally into the relevant event. Never create a separate data dump or "Behavior Data" section.
        - Preserve meaningful supplied details. Do not replace concrete events with vague summaries.

        ZERO-DATA RULES:
        - Never interpret a zero value as evidence that a behavior "needs work," worsened, or occurred.
        - If screenshot data clearly represents occurrence/frequency of a behavior and clearly shows zero occurrences, it may be written objectively as "No instances of [behavior] were observed/recorded during the session."
        - If a skill-acquisition measure is 0% correct, report only the supplied 0% correct responding when relevant; do not reinterpret it as absence of the behavior or as a clinical conclusion.
        - If the meaning of a zero or percentage is ambiguous, omit the interpretation rather than guessing.

        HARD FACTUAL BOUNDARIES:
        - Use objective, observable clinical language.
        - Do not invent frequencies, percentages, prompt levels, interventions, targets, behaviors, attendees, caregiver statements, locations, motivations, outcomes, progress, regression, treatment efficacy, or future plans.
        - Do not add generic filler such as "the environment was conducive to learning," "highlighting the need for additional strategies," "showed positive progress," "support the client's overall development," or "the RBT reflected on future interventions" unless those exact facts were supplied.
        - Do not claim a behavior occurred merely because it appears in the saved client profile.
        - Saved client information is terminology CONTEXT ONLY, never evidence that an event happened in this session.
        - If OCR text is unclear, ambiguous, duplicated, or cannot be confidently tied to the supplied session facts, omit it.
        - Do not infer internal states or use mentalistic language.
        - Do not add recommendations, treatment changes, caregiver training, or plans for the next session unless explicitly supplied.

        STYLE TARGET:
        - Write like a human RBT's finalized narrative documentation: concise, objective, connected, and chronological.
        - Prefer natural wording such as "RBT began the session by...", "Throughout the session...", "One instance of refusal was recorded...", "Toward the end of the session...", and "As the session came to a close..." when supported by the facts.
        - Refer to the client consistently as "the client" in the narrative unless the supplied facts make another neutral phrasing clearer.
        - Use ABA terminology supplied by the user accurately, including NET, FCT, manding, reinforcement, prompting, redirection, and transitions.

        CLIENT: \(clientCode)
        SAVED TARGETS — terminology context only: \(targets)
        SAVED BEHAVIORS — terminology context only: \(behaviors)
        SAVED COMMUNICATION/FCT CONTEXT — terminology context only: \(communication)
        SAVED PROMPTING/REINFORCEMENT CONTEXT — terminology context only: \(prompting)

        SESSION FACTS:
        \(cleanNarrative.isEmpty ? "none" : cleanNarrative)

        SCREENSHOT DATA / OCR:
        \(recognized.isEmpty ? "none" : recognized)
        """

        return try await generate(
            instructions: "You are LifeRoute's factual ABA documentation assistant. Return only a cohesive chronological RBT session-note narrative with no headings, labels, placeholders, bullets, data sections, generic clinical filler, recommendations, or fabricated facts. Integrate only clearly supported quantitative data into the events where it belongs. Treat zero behavior-occurrence data as no observed/recorded instances when its meaning is clear, never as evidence that the behavior needs work.",
            prompt: prompt
        )
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
