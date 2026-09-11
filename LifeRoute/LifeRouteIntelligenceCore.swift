import Foundation
import OSLog
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS
// The contract runner compiles this exact declaration, together with the shared policy.
enum SessionNoteStageInstructions {
    static func instructions(for stage: SessionNotePipelineStage) -> String {
        let guidance: String
        switch stage {
        case .standardDraft: guidance = standardReconstruction
        case .compactDraft: guidance = compactReconstruction
        case .repair: guidance = repairReconstruction
        }
        return SessionNoteClinicalInstructions.sharedConstraints + "\n\n" + guidance
    }

    private static let standardReconstruction = """
    Reconstruct one editable professional ABA session narrative from the supplied evidence only. Treat the REQUIRED FACT LEDGER as rough factual source material, never as prose to clean up or preserve. Silently map every output statement to one or more F-IDs before drafting, without printing the IDs. Rebuild each supplied event by identifying its actor, clinical action, and explicitly supported place in the sequence; replace dictated fragments and conversational transitions with natural objective ABA documentation. Do not copy the source clause structure or repeatedly begin with “Then” or “After this.” For style only, “RBT began pairing and FCT then moved to transitions” can become “The RBT began with pairing and functional communication training (FCT), followed by transitions”; never add the example's events unless supplied. Reorder facts only when their own words establish time or before/after relationships; the displayed F-ID order is not chronology. Translate generic “work” only as instructional activities or a work period without inventing its content. Use the shared evidence-proportional paragraph guidance; never append a detached data section, missing-data statement, unsupported summary, or future-plan close.
    """

    private static let compactReconstruction = """
    Reconstruct natural evidence-bound prose using the shared evidence-proportional style guidance. Silently account for every F-ID, then rebuild rough facts by actor, clinical action, and explicitly supported sequence; F-ID order alone is not chronology. Do not copy source clause structure or conversational “Then/After this” chains. Translate generic work only as instructional activities or a work period without inventing content. Keep measurements in matching narrative sentences and omit absent categories entirely. Retain supplied conclusions and closing activities. Use periods and paragraphs at supported topic changes. Return plain narrative only, without IDs, a detached data list, unsupported summary, or future-plan close.
    """

    private static let repairReconstruction = """
    Re-create the professional ABA session narrative from the original evidence and correct only the listed validation issues. Silently account for every F-ID. Rebuild rough facts by supplied actor, clinical action, and explicitly supported chronology rather than copying source clauses or conversational transitions; F-ID order alone is not chronology. Translate generic work only as instructional activities or a work period without inventing content. Return only cohesive plain-text narrative using the shared evidence-proportional style guidance; do not append IDs, a detached data list, missing-data statement, unsupported summary, or future-plan close.
    """
}
// END SESSION NOTE PRODUCTION INSTRUCTIONS

enum LifeRouteIntelligenceError: LocalizedError {
    case unavailable
    case emptyInput
    case contextWindowExceeded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device Apple Intelligence is not available on this iPhone right now."
        case .emptyInput:
            return "Add session facts before asking LifeRoute to generate anything."
        case .contextWindowExceeded:
            return "Apple Intelligence could not fit the bounded session evidence into its on-device context. Your facts and previous draft were preserved."
        case .generationFailed(let message):
            return message.isEmpty ? "LifeRoute could not generate a response." : message
        }
    }
}

enum SessionNoteModelAvailability: Equatable {
    case available
    case unavailable(String)
}

enum SessionNoteGenerationProgress: Equatable {
    case generating
    case extracted(SessionNoteExtractionSummary)
    case compacting
    case repairing
}

// v0.8.0 session-note runtime availability
enum LifeRouteIntelligenceCore {
    private static let sessionNoteLogger = Logger(
        subsystem: "Com.Brandongood.LifeRoute",
        category: "SessionNotePipeline"
    )

    static func sessionNoteModelAvailability() -> SessionNoteModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable("Apple Intelligence is not supported on this iPhone.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Turn on Apple Intelligence in Settings, then return to LifeRoute and try again.")
            case .unavailable(.modelNotReady):
                return .unavailable("Apple Intelligence is still preparing its on-device model. Keep the iPhone connected to power and Wi-Fi, then try again later.")
            @unknown default:
                return .unavailable("Apple Intelligence is not available on this iPhone right now.")
            }
        }
        #endif
        return .unavailable("AI Session Note requires an Apple Intelligence-capable iPhone running iOS 26 or later.")
    }

    static func recognizeText(in imageData: Data) async -> SessionNoteRecognizedScreenshot {
        guard !imageData.isEmpty else { return .bounded("") }

        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                let recognized = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                return .bounded(recognized)
            } catch {
                return .bounded("")
            }
        }.value
    }

    static func generateABASessionNote(
        narrative: String,
        writerRole: SessionNoteWriterRole,
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void = { _ in }
    ) async throws -> SessionNoteGenerationResult {
        try Task.checkCancellation()
        try SessionNoteInputBounds.validateTypedFacts(characterCount: narrative.count)
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNarrative.isEmpty else { throw LifeRouteIntelligenceError.emptyInput }

        let packet = SessionNoteEvidencePacket.make(
            typedFacts: cleanNarrative,
            ocrEvidence: "",
            savedTerminologyContext: compactSessionNoteClientContext(client),
            profileCode: client?.code
        )

        await progress(.generating)
        do {
            let result = try await SessionNoteGenerationPipeline.generateNote(
                packet: packet,
                writerRole: writerRole,
                request: { stage in
                    switch stage {
                    case .standardDraft:
                        return try await requestSessionNoteDraft(
                            packet: packet,
                            compaction: .standard,
                            instructions: SessionNoteStageInstructions.instructions(for: .standardDraft)
                        )
                    case .compactDraft:
                        return try await requestSessionNoteDraft(
                            packet: packet,
                            compaction: .compactRetry,
                            instructions: SessionNoteStageInstructions.instructions(for: .compactDraft)
                        )
                    case .repair(let issues):
                        let repairPrompt = try packet.modelPrompt(compaction: .compactRetry) + """

                        DETERMINISTIC VALIDATION ISSUES TO CORRECT:
                        \(issues.prefix(8).map { "- \($0)" }.joined(separator: "\n"))
                        """
                        return try await generate(
                            instructions: SessionNoteStageInstructions.instructions(for: stage),
                            prompt: repairPrompt,
                            maximumResponseTokens: 900,
                            isSessionNote: true
                        )
                    }
                },
                progress: { event in
                    switch event {
                    case .compacting:
                        await progress(.compacting)
                    case .repairing:
                        await progress(.repairing)
                    }
                },
                diagnostic: { event in
                    sessionNoteLogger.notice(
                        "Session-note diagnostic: \(event.privacySafeDescription, privacy: .public)"
                    )
                }
            )
            return result
        } catch SessionNotePipelineError.contextTooLarge {
            throw LifeRouteIntelligenceError.contextWindowExceeded
        } catch SessionNotePipelineError.rejected(let category) {
            let message: String
            switch category {
            case .identityVerification:
                message = "LifeRoute could not safely verify that the generated draft used role-based identifiers only. Your facts and previous draft were preserved. Category: \(category.userSafeLabel)."
            case .evidenceVerification:
                message = "LifeRoute could not safely verify one or more session-data claims in the generated draft. Your facts and previous draft were preserved. Category: \(category.userSafeLabel)."
            case .clinicalClaimVerification:
                message = "LifeRoute could not safely verify one or more clinical claims in the generated draft. Your facts and previous draft were preserved. Category: \(category.userSafeLabel)."
            case .professionalPresentation:
                message = "LifeRoute could not complete a professional rewrite from the supplied evidence. Your facts and previous draft were preserved."
            }
            throw LifeRouteIntelligenceError.generationFailed(
                message
            )
        } catch LifeRouteIntelligenceError.contextWindowExceeded {
            throw LifeRouteIntelligenceError.contextWindowExceeded
        }
    }

    private static func requestSessionNoteDraft(
        packet: SessionNoteEvidencePacket,
        compaction: SessionNoteRequestCompaction,
        instructions: String
    ) async throws -> String {
        try await generate(
            instructions: instructions,
            prompt: packet.modelPrompt(compaction: compaction),
            maximumResponseTokens: 900,
            isSessionNote: true
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

    private static func compactSessionNoteClientContext(_ client: LifeRouteClientProfile?) -> String {
        guard let client else { return "none" }

        func compactList(_ values: [String], limit: Int) -> String {
            let cleaned = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return "none" }
            return cleaned.prefix(limit).joined(separator: "; ")
        }

        func compactText(_ value: String, limit: Int) -> String {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return "none" }
            return String(clean.prefix(limit))
        }

        let summary = [
            "targets: \(compactList(client.currentTargets, limit: 5))",
            "behaviors: \(compactList(client.behaviorsOfConcern, limit: 5))",
            "communication: \(compactText(client.communicationNotes, limit: 180))",
            "prompting/reinforcement: \(compactText(client.promptingNotes, limit: 180))",
        ].joined(separator: " | ")

        // Saved profile data is terminology context only. Keep it small so selecting a client
        // cannot crowd the user's actual session facts out of Apple's on-device model window.
        return String(summary.prefix(720))
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

    private static func generate(
        instructions: String,
        prompt: String,
        maximumResponseTokens: Int? = nil,
        isSessionNote: Bool = false
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw LifeRouteIntelligenceError.unavailable
            }

            do {
                let session = LanguageModelSession(instructions: instructions)
                let options = GenerationOptions(maximumResponseTokens: maximumResponseTokens)
                let response = try await session.respond(to: prompt, options: options)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    throw LifeRouteIntelligenceError.generationFailed("")
                }
                if isSessionNote {
                    // Response has no finish-reason field. Inspect before clipping/sanitization;
                    // the result contract explicitly leaves semantic completeness unverified.
                    try SessionNoteOutputBoundary.validate(response.content)
                    return text
                }
                return String(text.prefix(8_000))
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as SessionNoteBoundaryError {
                throw error
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize(_) {
                throw SessionNotePipelineError.contextTooLarge
            } catch let error as LifeRouteIntelligenceError {
                throw error
            } catch {
                let lower = error.localizedDescription.lowercased()
                if lower.contains("context window") || lower.contains("context length") || lower.contains("context size") {
                    throw SessionNotePipelineError.contextTooLarge
                }
                throw LifeRouteIntelligenceError.generationFailed(error.localizedDescription)
            }
        }
        #endif

        throw LifeRouteIntelligenceError.unavailable
    }
}
