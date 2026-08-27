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
        let screenshotText = screenshotData.map { data in
            Task { await recognizeText(in: data) }
        }
        let recognized = await screenshotText?.value ?? ""

        guard !cleanNarrative.isEmpty || !recognized.isEmpty else {
            throw LifeRouteIntelligenceError.emptyInput
        }

        let clientCode = client?.code ?? "General / no client"
        let targets = client?.currentTargets.joined(separator: "; ") ?? "none"
        let behaviors = client?.behaviorsOfConcern.joined(separator: "; ") ?? "none"
        let communication = client?.communicationNotes ?? "none"
        let prompting = client?.promptingNotes ?? "none"

        let prompt = """
        Draft one concise professional ABA session note in cohesive paragraphs using ONLY the session facts supplied below.

        HARD RULES:
        - Use objective, observable language.
        - Do not invent frequencies, percentages, prompt levels, interventions, targets, behaviors, attendees, caregiver statements, locations, clinical interpretations, billing facts, or outcomes.
        - Saved client information is CONTEXT ONLY. Do not claim a saved target or behavior occurred unless the narrative or screenshot data explicitly demonstrates it.
        - If OCR text is unclear or ambiguous, omit it.
        - Integrate quantitative data naturally when it is clearly supplied.
        - Avoid mentalistic language.
        - Return only the finished session-note text. Do not add a heading, disclaimer, SOAP labels, or commentary.

        CLIENT: \(clientCode)
        SAVED TARGETS — context only: \(targets)
        SAVED BEHAVIORS — context only: \(behaviors)
        SAVED COMMUNICATION/FCT CONTEXT — context only: \(communication)
        SAVED PROMPTING/REINFORCEMENT CONTEXT — context only: \(prompting)

        SESSION NARRATIVE:
        \(cleanNarrative.isEmpty ? "none" : cleanNarrative)

        SCREENSHOT OCR / DATA:
        \(recognized.isEmpty ? "none" : recognized)
        """

        return try await generate(
            instructions: "You are LifeRoute's factual ABA documentation assistant. You MUST obey the supplied-facts-only rule and never fabricate clinical details.",
            prompt: prompt
        )
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

        let prompt = """
        Build a practical proposed ABA session flow lasting about \(boundedMinutes) minutes from the clinician-approved information below.

        The plan should ACTUALLY ORGANIZE THE SESSION instead of repeating the input. Create a sensible sequence of time blocks with approximate minutes, balancing pairing/rapport, natural-environment opportunities, skill-acquisition work, transitions, reinforcement/movement breaks, and wrap-up when those ideas fit the supplied targets and context.

        HARD CLINICAL BOUNDARIES:
        - Do not invent treatment targets, behavior protocols, prompting procedures, reinforcement schedules, diagnoses, restrictions, or clinical instructions.
        - Use only the approved targets, known reinforcers, and saved context below as constraints.
        - You may organize and sequence supplied priorities, but never create a new intervention.
        - If the inputs do not justify a specific clinical procedure, keep that block general (for example, "work on approved targets in NET").
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
        ADDITIONAL SESSION CONTEXT: \(additionalContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "none" : additionalContext)
        """

        return try await generate(
            instructions: "You are LifeRoute's session-planning assistant for an RBT. Organize only supervisor-approved information; never invent treatment procedures.",
            prompt: prompt
        )
    }

    private static func generate(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
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
