import Foundation
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

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
            return "Apple Intelligence could not fit the bounded session evidence into its on-device context. Your facts, screenshots, and previous draft were preserved."
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
    case compacting
    case repairing
}

// v0.8.0 session-note runtime availability
enum LifeRouteIntelligenceCore {
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

    // v0.8.0 follow-up session-note refinement:
    // Typed narrative remains primary; up to six screenshot OCR streams are supplemental.
    private static func recognizeSessionNoteScreenshots(_ imageDataItems: [Data]) async -> [String] {
        let limitedItems = Array(imageDataItems.prefix(6))
        return await withTaskGroup(of: (Int, String).self, returning: [String].self) { group in
            for (index, data) in limitedItems.enumerated() {
                group.addTask {
                    (index, await recognizeText(in: data))
                }
            }

            var indexedResults: [(Int, String)] = []
            for await result in group {
                indexedResults.append(result)
            }
            return indexedResults
                .sorted { $0.0 < $1.0 }
                .map { $0.1.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    private static func formattedSessionNoteScreenshotEvidence(_ recognizedScreenshots: [String]) -> String {
        let blocks = recognizedScreenshots.prefix(6).enumerated().map { screenshotIndex, recognized in
            let compactLines = recognized
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var taggedLines: [String] = []
            var lineIndex = 0
            while lineIndex < compactLines.count, taggedLines.count < 12 {
                var line = String(compactLines[lineIndex].prefix(180))
                let tags = sessionNoteEvidenceTags(for: line)
                if !line.contains(where: \.isNumber),
                   tags != ["AMBIGUOUS OCR"],
                   compactLines.indices.contains(lineIndex + 1),
                   compactLines[lineIndex + 1].contains(where: \.isNumber) {
                    line += " " + String(compactLines[lineIndex + 1].prefix(80))
                    lineIndex += 1
                }
                taggedLines.append("[\(tags.joined(separator: ", "))] \(line)")
                lineIndex += 1
            }

            let body = taggedLines.isEmpty ? "No clear OCR text." : taggedLines.joined(separator: "\n")
            return "SCREENSHOT \(screenshotIndex + 1):\n\(String(body.prefix(400)))"
        }
        return String(blocks.joined(separator: "\n\n").prefix(2_800))
    }

    private static func sessionNoteEvidenceTags(for line: String) -> [String] {
        let lower = line.lowercased()
        func matches(_ pattern: String) -> Bool {
            lower.range(of: pattern, options: .regularExpression) != nil
        }

        var tags: [String] = []
        if matches(#"\b(latency|time to respond|response time|time to begin|initiation delay)\b"#) {
            tags.append("LATENCY")
        }
        if matches(#"\b(rate|per minute|per hour|per session)\b|/(min|hr)\b"#) {
            tags.append("RATE")
        }
        if matches(#"\b(trials?|opportunities|correct out of)\b|\b\d+\s*/\s*\d+\b"#) {
            tags.append("TRIAL-BASED")
        }
        if lower.contains("%") || matches(#"\b(percent|percentage|accuracy)\b"#) {
            tags.append("PERCENTAGE")
        }
        if matches(#"\b(frequency|count|occurrences?|instances?|events?)\b"#) {
            tags.append("FREQUENCY/COUNT")
        }
        if matches(#"\bduration\b"#) || (
            tags.contains("LATENCY") == false &&
            tags.contains("RATE") == false &&
            matches(#"\b\d+(\.\d+)?\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)\b"#)
        ) {
            tags.append("DURATION")
        }
        if matches(#"\b(independent|independently|prompted|prompting|verbal prompt|gestural prompt|visual prompt|model prompt|partial physical|full physical)\b"#) {
            tags.append("INDEPENDENT/PROMPTED")
        }
        return tags.isEmpty ? ["AMBIGUOUS OCR"] : tags
    }

    static func generateABASessionNote(
        narrative: String,
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void = { _ in }
    ) async throws -> String {
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizedScreenshots = await recognizeSessionNoteScreenshots(screenshotDataItems)

        guard !cleanNarrative.isEmpty || recognizedScreenshots.contains(where: { !$0.isEmpty }) else {
            throw LifeRouteIntelligenceError.emptyInput
        }

        let packet = SessionNoteEvidencePacket.make(
            typedFacts: cleanNarrative,
            ocrEvidence: formattedSessionNoteScreenshotEvidence(recognizedScreenshots),
            savedTerminologyContext: compactSessionNoteClientContext(client),
            profileCode: client?.code
        )

        await progress(.generating)
        do {
            return try await SessionNoteGenerationPipeline.run(
                packet: packet,
                request: { stage in
                    switch stage {
                    case .standardDraft:
                        return try await requestSessionNoteDraft(
                            packet: packet,
                            compaction: .standard,
                            instructions: sessionNoteDraftInstructions
                        )
                    case .compactDraft:
                        return try await requestSessionNoteDraft(
                            packet: packet,
                            compaction: .compactRetry,
                            instructions: sessionNoteCompactDraftInstructions
                        )
                    case .repair(let issues):
                        let repairPrompt = packet.modelPrompt(compaction: .compactRetry) + """

                        DETERMINISTIC VALIDATION ISSUES TO CORRECT:
                        \(issues.prefix(8).map { "- \($0)" }.joined(separator: "\n"))
                        """
                        return try await generate(
                            instructions: sessionNoteRepairInstructions,
                            prompt: repairPrompt,
                            maximumResponseTokens: 900
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
                }
            )
        } catch SessionNotePipelineError.contextTooLarge {
            throw LifeRouteIntelligenceError.contextWindowExceeded
        } catch SessionNotePipelineError.rejected {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute rejected the generated draft because it could not verify identity, evidence, and clinical-format safeguards. Your facts, screenshots, and previous draft were preserved."
            )
        } catch LifeRouteIntelligenceError.contextWindowExceeded {
            throw LifeRouteIntelligenceError.contextWindowExceeded
        }
    }

    private static let sessionNoteDraftInstructions = """
    Draft one editable ABA session note from the supplied evidence only. Write objective, person-first, third-person, chronological natural prose in generally 2–4 cohesive paragraphs without padding sparse facts. Use role identifiers only: the client, RBT, LBS, BCBA, BHT, and caregiver relationship roles. Preserve every supplied measurement type, unit, numeric value, prompt level, attribution, intervention, reinforcement, and observable response exactly. Include a behavior of concern only when evidence says it occurred; never infer function, intent, emotion, cause, progress, training, supervision, or treatment changes. Say “behaviors of concern.” End with a factual participation/response summary and that the RBT will continue implementing the established treatment plan during future sessions. Return narrative paragraphs only—no title, headings, lists, markdown, data section, template language, disclaimer, or commentary.
    """

    private static let sessionNoteCompactDraftInstructions = """
    Write an objective third-person ABA session note from evidence only, in 2–4 natural chronological paragraphs. Use roles only, preserve exact data and prompting, retain caregiver attribution, never infer or add clinical facts, say “behaviors of concern,” and close with supplied participation plus continued implementation of the established treatment plan. Return plain narrative only.
    """

    private static let sessionNoteRepairInstructions = """
    Re-create the ABA session note from the original evidence and correct only the listed validation issues. Use role-only identity, objective third-person chronological prose, exact supplied measurement types and prompt levels, attributed caregiver reports, and “behaviors of concern.” Do not add, infer, or reinterpret facts. Return only 2–4 cohesive plain-text narrative paragraphs with the required factual participation summary and established-treatment-plan continuation.
    """

    private static func requestSessionNoteDraft(
        packet: SessionNoteEvidencePacket,
        compaction: SessionNoteRequestCompaction,
        instructions: String
    ) async throws -> String {
        try await generate(
            instructions: instructions,
            prompt: packet.modelPrompt(compaction: compaction),
            maximumResponseTokens: 900
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
        maximumResponseTokens: Int? = nil
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
                return String(text.prefix(8_000))
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
