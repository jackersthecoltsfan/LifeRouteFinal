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
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?
    ) async throws -> String {
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizedScreenshots = await recognizeSessionNoteScreenshots(screenshotDataItems)

        guard !cleanNarrative.isEmpty || recognizedScreenshots.contains(where: { !$0.isEmpty }) else {
            throw LifeRouteIntelligenceError.emptyInput
        }

        let clinicianNeutralNarrative = cleanNarrative.replacingOccurrences(
            of: "Brandon Good",
            with: "RBT",
            options: [.caseInsensitive]
        )
        // v0.6.3 note context-window hotfix:
        // Apple Foundation Models has a small on-device context budget. Keep the user's
        // actual session facts first, compact OCR aggressively, and keep saved client data
        // as short terminology-only context. This avoids the previous oversized static prompt.
        let boundedNarrative = String(clinicianNeutralNarrative.prefix(5_200))
        let boundedOCR = formattedSessionNoteScreenshotEvidence(recognizedScreenshots)
        let clientCode = client?.code ?? "General / no client"
        let clientContext = String(
            compactSessionNoteClientContext(client)
                .replacingOccurrences(of: "Brandon Good", with: "RBT", options: [.caseInsensitive])
                .prefix(500)
        )

        let instructions = """
        Draft one professional ABA session note using only the session facts supplied below.

        REQUIRED WRITING STYLE:
        Write natural, objective, person-first clinical prose appropriate for high-quality ABA and insurance documentation. Use approximately 2–4 concise cohesive paragraphs; do not pad a sparse session. Refer to the clinician only as "the RBT" or "RBT." Never use a personal clinician or profile name in the note body. Convert rough shorthand into connected chronological prose without adding facts. Start with location/people present when supplied, then describe what the RBT implemented, the client's observable response, the exact prompting provided, reinforcement delivered, skill acquisition, transitions, and behaviors where they actually occurred. Build a cohesive clinical narrative rather than a list: link each supplied intervention to the corresponding client response, prompting, reinforcement, and observable outcome, and use concise transitions between session events.

        Evidence priority: SESSION FACTS first; clear OCR data second; SAVED CLIENT CONTEXT is terminology only and never proves an event occurred. If OCR conflicts with explicit narrative facts, keep the narrative fact. Keep every measurement in its supplied type and unit; never flatten unlike data into generic percentages or convert counts, frequency, duration, latency, rate, trials, independent responses, or prompted responses into another type. Percentage data may describe skill accuracy, opportunities, or success only when the target label supports that meaning. Frequency/count data describes the supplied number of instances or events. Duration describes how long an event or response lasted. Latency describes the supplied time before a response or initiation. Rate preserves the supplied events-per-unit. Trial data preserves the supplied correct/total or trial-based form. Independent and prompted responding remain distinct, including exact prompt levels when present. OCR evidence is grouped by screenshot and tagged by likely measurement type. Treat an [AMBIGUOUS OCR] tag as uncertain; omit it unless the surrounding label and value make the meaning clear. Integrate clear values naturally beside the matching target or behavior; never create a separate data dump.

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

        let firstDraft = sanitizedSessionNoteDraft(
            try await generate(instructions: instructions, prompt: prompt)
        )
        guard sessionNoteNeedsMasterABARepair(firstDraft) else {
            return firstDraft
        }

        // Retry with the same bounded facts and an even shorter format correction. Do not
        // resend the old giant master prompt or the rejected draft itself.
        let repairedDraft = sanitizedSessionNoteDraft(try await generate(
            instructions: instructions + "\nFORMAT CORRECTION: plain narrative paragraphs only; no labels, headings, bullets, placeholders, or future-plan language.",
            prompt: prompt
        ))

        guard !sessionNoteNeedsMasterABARepair(repairedDraft) else {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute could not produce a clean Master ABA session note from this generation. Please regenerate from the same session facts."
            )
        }

        // v0.8.1 session-note repair: preserve a usable sanitized note when the bounded repair pass is substantively good.
        let cleanedRepairedDraft = sanitizedSessionNoteDraft(repairedDraft)
        guard !cleanedRepairedDraft.isEmpty else {
            throw LifeRouteIntelligenceError.generationFailed(
                "LifeRoute could not produce a clean Master ABA session note from this generation. Please regenerate from the same session facts."
            )
        }
        return cleanedRepairedDraft
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

    private static func sanitizedSessionNoteDraft(_ draft: String) -> String {
        let nameScrubbed = draft.replacingOccurrences(
            of: "Brandon Good",
            with: "the RBT",
            options: [.caseInsensitive]
        )

        let headingPrefixes = [
            "session narrative note",
            "date:",
            "location:",
            "participants:",
            "setting:",
            "session overview:",
            "behavior data:",
            "generalization:",
            "assessment:",
            "plan:",
            "conclusion:",
        ]

        let cleanedLines = nameScrubbed
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> String? in
                var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                while let first = line.first, "•-*–—".contains(first) {
                    line.removeFirst()
                    line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard !line.isEmpty else { return nil }

                let lower = line.lowercased()
                if headingPrefixes.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
                    return nil
                }
                return line
            }

        return cleanedLines
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func sessionNoteNeedsMasterABARepair(_ value: String) -> Bool {
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

        if lower.contains("brandon good") {
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
                let response = try await session.respond(to: String(prompt.prefix(9_000)))
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    throw LifeRouteIntelligenceError.generationFailed("")
                }
                return String(text.prefix(8_000))
            } catch let error as LifeRouteIntelligenceError {
                throw error
            } catch {
                let lower = error.localizedDescription.lowercased()
                if lower.contains("context window") || lower.contains("context length") {
                    throw LifeRouteIntelligenceError.generationFailed(
                        "Apple Intelligence reported that the note input was too large. LifeRoute now compacts session-note requests automatically; if this still appears, shorten unusually long pasted facts or remove the screenshot and try again."
                    )
                }
                throw LifeRouteIntelligenceError.generationFailed(error.localizedDescription)
            }
        }
        #endif

        throw LifeRouteIntelligenceError.unavailable
    }
}
