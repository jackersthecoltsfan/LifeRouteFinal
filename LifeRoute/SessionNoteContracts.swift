import Foundation

enum SessionNoteRequestCompaction: Equatable {
    case standard
    case compactRetry
}

enum SessionNoteMeasurementKind: String, Equatable {
    case count
    case duration
    case latency
    case rate
    case trials
    case percentage
    case unknown
}

struct SessionNoteNumericClaim: Equatable {
    let value: String
    let kind: SessionNoteMeasurementKind
}

struct SessionNoteMeasurementEvidence: Equatable {
    let target: String
    let value: String
    let kind: SessionNoteMeasurementKind
    let promptLevels: Set<String>
    let sourceOrdinal: Int

    var promptLine: String {
        var components = [
            "Target: \(target)",
            "Type: \(kind.rawValue)",
            "Value: \(value)",
        ]
        if !promptLevels.isEmpty {
            components.append("Prompting: \(promptLevels.sorted().joined(separator: ", "))")
        }
        return components.joined(separator: " | ")
    }

    var numericClaim: SessionNoteNumericClaim? {
        SessionNoteEvidenceNormalizer.numericClaims(in: value).first
    }
}

enum SessionNoteOCRMeasurementExtractor {
    static func extract(from recognizedScreenshots: [String]) -> [SessionNoteMeasurementEvidence] {
        var measurements: [SessionNoteMeasurementEvidence] = []
        var seen = Set<String>()

        for (screenshotIndex, recognized) in recognizedScreenshots.prefix(6).enumerated() {
            let lines = recognized
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(whereSeparator: \.isNewline)
                .map {
                    String($0)
                        .replacingOccurrences(of: #"[\t ]+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }

            for (lineIndex, line) in lines.enumerated() {
                guard !isAdministrative(line),
                      let measurement = measurement(in: line) else { continue }

                let inlineTarget = targetCandidate(
                    from: line.replacingOccurrences(of: measurement.value, with: "")
                )
                let target = inlineTarget ?? precedingTarget(
                    before: lineIndex,
                    in: lines
                )
                guard let target else { continue }

                let promptLevels = SessionNoteEvidenceNormalizer.promptLevels(
                    in: [target, line].joined(separator: " ")
                )
                let evidence = SessionNoteMeasurementEvidence(
                    target: target,
                    value: measurement.value,
                    kind: measurement.kind,
                    promptLevels: promptLevels,
                    sourceOrdinal: screenshotIndex + 1
                )
                let key = [
                    target.lowercased(), measurement.kind.rawValue,
                    measurement.value.lowercased(), promptLevels.sorted().joined(separator: ","),
                ].joined(separator: "|")
                if seen.insert(key).inserted {
                    measurements.append(evidence)
                }
            }
        }

        return measurements
    }

    private static func measurement(in line: String) -> (value: String, kind: SessionNoteMeasurementKind)? {
        if line.range(of: #"(?i)\b(?:service|session)\s+duration\b"#, options: .regularExpression) != nil {
            return nil
        }

        let patterns: [(SessionNoteMeasurementKind, String)] = [
            (.percentage, #"(?i)(?<![A-Za-z0-9])\d+(?:\.\d+)?\s*%"#),
            (.trials, #"(?i)(?<![A-Za-z0-9])\d+\s*/\s*\d+(?:\s*(?:trials?|opportunities))?"#),
            (.rate, #"(?i)(?<![A-Za-z0-9])\d+(?:\.\d+)?\s*(?:per\s+(?:minute|hour|session)|/(?:min|hr))\b"#),
            (.latency, #"(?i)(?<![A-Za-z0-9])\d+(?:\.\d+)?\s*(?:seconds?|secs?|minutes?|mins?)\b(?=[^\n]*(?:latency|response time|time to respond|time to begin|initiation delay))"#),
            (.duration, #"(?i)(?<![A-Za-z0-9])\d+(?:\.\d+)?\s*(?:seconds?|secs?|minutes?|mins?|hours?|hrs?)\b"#),
            (.count, #"(?i)(?<![A-Za-z0-9])\d+(?:\.\d+)?\s*(?:occurrences?|instances?|events?|times?)\b"#),
        ]

        for (kind, pattern) in patterns {
            guard let range = line.range(of: pattern, options: .regularExpression) else { continue }
            let value = String(line[range])
                .replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value, kind)
        }
        return nil
    }

    private static func precedingTarget(before lineIndex: Int, in lines: [String]) -> String? {
        guard lineIndex > 0 else { return nil }
        for candidateIndex in stride(from: lineIndex - 1, through: max(0, lineIndex - 3), by: -1) {
            let candidate = lines[candidateIndex]
            if isAdministrative(candidate) { continue }
            if measurement(in: candidate) != nil { continue }
            if let target = targetCandidate(from: candidate) { return target }
        }
        return nil
    }

    private static func targetCandidate(from raw: String) -> String? {
        var candidate = raw
            .replacingOccurrences(of: #"^\s*\[[^\]]+\]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?i)\b(?:accuracy|percentage|percent|frequency|count|duration|latency|rate|trials?|opportunities|independent|independently|with\s+(?:an?\s+)?(?:verbal|gestural|visual|model|partial physical|full physical)\s+prompt)\b"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"[|:;=\-–—]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        candidate = candidate.replacingOccurrences(
            of: #"(?i)^(?:target|program|goal|behavior|behaviour|skill)\s+"#,
            with: "",
            options: .regularExpression
        )
        let lower = candidate.lowercased()
        let genericHeadings: Set<String> = [
            "data", "data collection", "skill acquisition data", "behavior data", "behaviour data",
            "targets", "programs", "goals", "behaviors", "behaviours", "results", "measurement",
        ]
        guard candidate.count >= 3,
              candidate.count <= 100,
              candidate.contains(where: \.isLetter),
              !candidate.contains(where: \.isNumber),
              !genericHeadings.contains(lower),
              !isAdministrative(candidate) else { return nil }
        return candidate
    }

    private static func isAdministrative(_ line: String) -> Bool {
        let lower = line.lowercased()
        let administrativeLabels = [
            "session date", "date of service", "service date", "start time", "end time",
            "clock in", "clock out", "provider id", "provider name", "therapist", "staff id",
            "client name", "member id", "authorization", "billing", "claim", "cpt",
            "appointment", "signature", "note status", "created at", "modified at",
            "session id", "service duration", "session duration",
        ]
        if administrativeLabels.contains(where: lower.contains) { return true }
        if line.range(of: #"(?<!\d)\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?!\d)"#, options: .regularExpression) != nil {
            return true
        }
        return line.range(
            of: #"(?i)(?<!\d)\d{1,2}:\d{2}\s*(?:am|pm)?(?!\d)"#,
            options: .regularExpression
        ) != nil
    }
}

enum SessionNoteValidationSeverity: String, Equatable {
    case hardBlocker
    case repairable
    case warning
}

enum SessionNoteValidationRepairability: String, Equatable {
    case deterministic
    case boundedModel
    case userEditable
    case none
}

enum SessionNoteValidationCategory: String, Equatable {
    case identityVerification
    case evidenceVerification
    case clinicalClaimVerification
    case formatNormalization
    case terminologyNormalization
    case quality
}

struct SessionNoteValidationIssue: Equatable {
    let code: String
    let severity: SessionNoteValidationSeverity
    let userSafeCategory: SessionNoteValidationCategory
    let repairability: SessionNoteValidationRepairability
    let repairInstruction: String
}

enum SessionNoteSupervisorAction: String, Hashable {
    case guidance
    case observation
    case modeling
    case feedback
    case treatmentModification
}

struct SessionNoteSupervisorClaim: Hashable {
    let role: String
    let action: SessionNoteSupervisorAction
}

struct SessionNoteEvidencePacket {
    let typedFacts: String
    let quantitativeOCR: String
    let structuredMeasurements: [SessionNoteMeasurementEvidence]
    let savedTerminologyContext: String
    let scrubber: SessionNoteIdentifierScrubber
    let numericClaims: [SessionNoteNumericClaim]
    let promptLevels: Set<String>
    let contextOnlyClinicalTerms: [String]
    let clinicalRoles: Set<String>
    let supervisorClaims: Set<SessionNoteSupervisorClaim>

    static func make(
        typedFacts: String,
        ocrEvidence: String,
        structuredMeasurements: [SessionNoteMeasurementEvidence] = [],
        savedTerminologyContext: String,
        profileCode: String?
    ) -> SessionNoteEvidencePacket {
        let source = [typedFacts, ocrEvidence, savedTerminologyContext]
            .joined(separator: "\n")
        let scrubber = SessionNoteIdentifierScrubber(
            profileCode: profileCode,
            sourceText: source
        )
        let normalizedFacts = SessionNoteEvidenceNormalizer.typedFacts(
            scrubber.scrub(typedFacts)
        )
        let normalizedMeasurements = structuredMeasurements.compactMap { measurement -> SessionNoteMeasurementEvidence? in
            let target = scrubber.scrub(measurement.target)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { return nil }
            return SessionNoteMeasurementEvidence(
                target: target,
                value: measurement.value,
                kind: measurement.kind,
                promptLevels: measurement.promptLevels,
                sourceOrdinal: measurement.sourceOrdinal
            )
        }
        let normalizedOCR = SessionNoteEvidenceNormalizer.quantitativeOCR(
            scrubber.scrub(ocrEvidence)
        )
        let normalizedContext = SessionNoteEvidenceNormalizer.savedContext(
            scrubber.scrub(savedTerminologyContext)
        )
        let factualEvidence = [
            normalizedFacts,
            normalizedOCR,
            normalizedMeasurements.map(\.promptLine).joined(separator: "\n"),
        ].joined(separator: "\n")

        return SessionNoteEvidencePacket(
            typedFacts: normalizedFacts,
            quantitativeOCR: normalizedOCR,
            structuredMeasurements: normalizedMeasurements,
            savedTerminologyContext: normalizedContext,
            scrubber: scrubber,
            numericClaims: SessionNoteEvidenceNormalizer.numericClaims(in: factualEvidence),
            promptLevels: SessionNoteEvidenceNormalizer.promptLevels(in: factualEvidence),
            contextOnlyClinicalTerms: SessionNoteEvidenceNormalizer.contextOnlyClinicalTerms(
                in: normalizedContext,
                excluding: factualEvidence
            ),
            clinicalRoles: SessionNoteEvidenceNormalizer.clinicalRoles(in: factualEvidence),
            supervisorClaims: SessionNoteEvidenceNormalizer.supervisorClaims(in: factualEvidence)
        )
    }

    func modelPrompt(compaction: SessionNoteRequestCompaction) -> String {
        let ocrLimit = compaction == .standard ? 1_600 : 900
        let context = compaction == .standard ? savedTerminologyContext : ""
        let measurementLines = structuredMeasurements
            .map(\.promptLine)
            .joined(separator: "\n")
        return """
        RAW FACTUAL SOURCE MATERIAL — reconstruct into professional ABA prose; do not preserve its wording or sentence structure:
        \(typedFacts.isEmpty ? "none" : String(typedFacts.prefix(5_200)))

        CLEAR CURRENT-SESSION MEASUREMENTS — integrate every entry and keep each target, type, value, unit, and prompt level associated exactly:
        \(measurementLines.isEmpty ? "none" : String(measurementLines.prefix(ocrLimit)))

        OTHER CLEAR QUANTITATIVE OCR — supporting evidence only; never use administrative screenshot content:
        \(quantitativeOCR.isEmpty ? "none" : String(quantitativeOCR.prefix(ocrLimit)))

        NEUTRAL TERMINOLOGY CONTEXT — never evidence that an event occurred:
        \(context.isEmpty ? "none" : String(context.prefix(280)))

        PROFESSIONAL RECONSTRUCTION REQUIREMENTS:
        - Do not copy conversational transitions or preserve the source clause structure.
        - Rebuild each event with its supplied actor in objective ABA documentation language. Express generic work only as instructional activities or a work period; do not invent its content.
        - Preserve the supplied event order instead of regrouping events by target. Connect the opening, transitions, later activities, behavior/intervention/outcome sequence, reinforcement, and collaboration chronologically when supplied.
        - Produce 2–4 cohesive narrative paragraphs. Integrate each measurement in the sentence about its matching target or behavior; never append a detached data list.
        - Close once with supported client participation and continued implementation of the established treatment plan.
        """
    }
}

enum SessionNotePipelineStage: Equatable {
    case standardDraft
    case compactDraft
    case repair([String])
}

enum SessionNoteFailureCategory: String, Equatable {
    case identityVerification
    case evidenceVerification
    case clinicalClaimVerification
    case professionalPresentation

    var userSafeLabel: String {
        switch self {
        case .identityVerification: return "Identity verification"
        case .evidenceVerification: return "Evidence verification"
        case .clinicalClaimVerification: return "Clinical claim verification"
        case .professionalPresentation: return "Professional presentation"
        }
    }
}

enum SessionNoteFallbackOutcome: String, Equatable {
    case succeeded
    case insufficientEvidence
    case unsafe
}

enum SessionNoteFinalOutcome: String, Equatable {
    case generated
    case repaired
    case fallback
    case rejected

    var isProfessionallyReady: Bool {
        self == .generated || self == .repaired
    }

    var userFacingStatusTitle: String {
        switch self {
        case .generated: return "Draft ready"
        case .repaired: return "Draft ready after review"
        case .fallback: return "Professional rewrite could not be completed"
        case .rejected: return "Generation failed"
        }
    }

    var userFacingStatusMessage: String {
        switch self {
        case .generated:
            return "The editable draft is visible below. Review every sentence before use."
        case .repaired:
            return "The editable draft passed one bounded professional reconstruction pass. Review every sentence before use."
        case .fallback:
            return "LifeRoute preserved an evidence-safe source draft, but it still requires professional editing before use."
        case .rejected:
            return "LifeRoute could not safely present a completed draft. Your facts, screenshots, and previous draft were preserved."
        }
    }
}

enum SessionNoteCandidatePass: String, Equatable {
    case initial
    case repair
}

struct SessionNoteCandidateDiagnostics: Equatable {
    let pass: SessionNoteCandidatePass
    let rawCharacterCount: Int
    let normalizedCharacterCount: Int
    let wordCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let sourceOverlapBasisPoints: Int
    let roughFragmentMatchCount: Int
    let structuredMeasurementCount: Int
    let missingStructuredMeasurementCount: Int
    let issueCodes: [String]
    let hardBlockerCodes: [String]
    let isProfessionallyReady: Bool

    static func make(
        pass: SessionNoteCandidatePass,
        rawDraft: String,
        normalizedDraft: String,
        validation: SessionNoteOutputValidation,
        evidence: SessionNoteEvidencePacket
    ) -> SessionNoteCandidateDiagnostics {
        let paragraphs = normalizedDraft
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return SessionNoteCandidateDiagnostics(
            pass: pass,
            rawCharacterCount: rawDraft.count,
            normalizedCharacterCount: normalizedDraft.count,
            wordCount: normalizedDraft.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count,
            sentenceCount: SessionNoteOutputSanitizer.splitSentences(normalizedDraft).count,
            paragraphCount: paragraphs.count,
            sourceOverlapBasisPoints: SessionNoteOutputValidator.sourceOverlapBasisPoints(
                normalizedDraft,
                evidence: evidence
            ),
            roughFragmentMatchCount: SessionNoteOutputValidator.roughFragmentMatchCount(in: normalizedDraft),
            structuredMeasurementCount: evidence.structuredMeasurements.count,
            missingStructuredMeasurementCount: SessionNoteOutputValidator.missingStructuredMeasurementCount(
                in: normalizedDraft,
                evidence: evidence
            ),
            issueCodes: validation.issueCodes,
            hardBlockerCodes: validation.hardBlockerCodes,
            isProfessionallyReady: validation.isProfessionallyReady
        )
    }
}

enum SessionNotePipelineDiagnosticEvent: Equatable {
    case initialIssueCodes([String])
    case deterministicRepairCodes([String])
    case remainingHardBlockerCodes([String])
    case candidateAssessment(SessionNoteCandidateDiagnostics)
    case repairAttempted([String])
    case repairPassIssueCodes([String])
    case fallback(SessionNoteFallbackOutcome)
    case finalOutcome(SessionNoteFinalOutcome)

    var privacySafeDescription: String {
        switch self {
        case .initialIssueCodes(let codes):
            return "initial issue codes: \(codes.joined(separator: ","))"
        case .deterministicRepairCodes(let codes):
            return "deterministic repair codes: \(codes.joined(separator: ","))"
        case .remainingHardBlockerCodes(let codes):
            return "remaining hard-blocker codes: \(codes.joined(separator: ","))"
        case .candidateAssessment(let diagnostics):
            return [
                "candidate",
                "pass=\(diagnostics.pass.rawValue)",
                "rawChars=\(diagnostics.rawCharacterCount)",
                "normalizedChars=\(diagnostics.normalizedCharacterCount)",
                "words=\(diagnostics.wordCount)",
                "sentences=\(diagnostics.sentenceCount)",
                "paragraphs=\(diagnostics.paragraphCount)",
                "sourceOverlapBP=\(diagnostics.sourceOverlapBasisPoints)",
                "roughFragments=\(diagnostics.roughFragmentMatchCount)",
                "measurements=\(diagnostics.structuredMeasurementCount)",
                "missingMeasurements=\(diagnostics.missingStructuredMeasurementCount)",
                "issues=\(diagnostics.issueCodes.joined(separator: ","))",
                "hardBlockers=\(diagnostics.hardBlockerCodes.joined(separator: ","))",
                "ready=\(diagnostics.isProfessionallyReady ? 1 : 0)",
            ].joined(separator: ";")
        case .repairAttempted(let codes):
            return "repairAttempted=\(codes.joined(separator: ","))"
        case .repairPassIssueCodes(let codes):
            return "repair-pass issue codes: \(codes.joined(separator: ","))"
        case .fallback(let outcome):
            return "fallback=\(outcome.rawValue)"
        case .finalOutcome(let outcome):
            return "final=\(outcome.rawValue)"
        }
    }
}

struct SessionNoteDiagnosticReceipt: Equatable {
    let events: [SessionNotePipelineDiagnosticEvent]

    var shareableText: String {
        let details = events.map(\.privacySafeDescription).joined(separator: " | ")
        return details.isEmpty ? "SN-DIAG-1 | no-events" : "SN-DIAG-1 | \(details)"
    }
}

struct SessionNoteGenerationResult: Equatable {
    let draft: String
    let outcome: SessionNoteFinalOutcome
    let issueCodes: [String]
    let diagnostics: SessionNoteDiagnosticReceipt

    init(
        draft: String,
        outcome: SessionNoteFinalOutcome,
        issueCodes: [String],
        diagnostics: SessionNoteDiagnosticReceipt = SessionNoteDiagnosticReceipt(events: [])
    ) {
        self.draft = draft
        self.outcome = outcome
        self.issueCodes = issueCodes
        self.diagnostics = diagnostics
    }
}

enum SessionNotePipelineEvent: Equatable {
    case compacting
    case repairing
}

enum SessionNotePipelineError: LocalizedError, Equatable {
    case contextTooLarge
    case rejected(SessionNoteFailureCategory)

    var errorDescription: String? {
        switch self {
        case .contextTooLarge:
            return "The bounded on-device request still exceeded the available context."
        case .rejected:
            return "The generated draft did not pass deterministic clinical validation."
        }
    }
}

enum SessionNoteGenerationPipeline {
    static func run(
        packet: SessionNoteEvidencePacket,
        request: @escaping (SessionNotePipelineStage) async throws -> String,
        progress: @escaping (SessionNotePipelineEvent) async -> Void = { _ in },
        diagnostic: @escaping (SessionNotePipelineDiagnosticEvent) -> Void = { _ in }
    ) async throws -> String {
        try await generate(
            packet: packet,
            request: request,
            progress: progress,
            diagnostic: diagnostic
        ).draft
    }

    static func generate(
        packet: SessionNoteEvidencePacket,
        request: @escaping (SessionNotePipelineStage) async throws -> String,
        progress: @escaping (SessionNotePipelineEvent) async -> Void = { _ in },
        diagnostic: @escaping (SessionNotePipelineDiagnosticEvent) -> Void = { _ in }
    ) async throws -> SessionNoteGenerationResult {
        var diagnosticEvents: [SessionNotePipelineDiagnosticEvent] = []
        func record(_ event: SessionNotePipelineDiagnosticEvent) {
            diagnosticEvents.append(event)
            diagnostic(event)
        }

        let firstRawDraft: String
        do {
            firstRawDraft = try await request(.standardDraft)
        } catch SessionNotePipelineError.contextTooLarge {
            await progress(.compacting)
            firstRawDraft = try await request(.compactDraft)
        }

        let firstSanitization = SessionNoteOutputSanitizer.sanitizeWithReport(
            firstRawDraft,
            scrubber: packet.scrubber
        )
        let firstValidation = SessionNoteOutputValidator.validate(firstSanitization.draft, evidence: packet)
        record(.initialIssueCodes(firstValidation.issueCodes))
        let firstRepair = SessionNoteDeterministicRepairer.repair(
            firstValidation.draft,
            validation: firstValidation,
            evidence: packet
        )
        record(.deterministicRepairCodes(
            Array(Set(firstSanitization.appliedIssueCodes + firstRepair.appliedIssueCodes)).sorted()
        ))
        let normalizedValidation = SessionNoteOutputValidator.validate(firstRepair.draft, evidence: packet)
        record(.remainingHardBlockerCodes(normalizedValidation.hardBlockerCodes))
        record(.candidateAssessment(SessionNoteCandidateDiagnostics.make(
            pass: .initial,
            rawDraft: firstRawDraft,
            normalizedDraft: firstRepair.draft,
            validation: normalizedValidation,
            evidence: packet
        )))
        if normalizedValidation.isProfessionallyReady {
            record(.finalOutcome(.generated))
            return SessionNoteGenerationResult(
                draft: normalizedValidation.draft,
                outcome: .generated,
                issueCodes: normalizedValidation.issueCodes,
                diagnostics: SessionNoteDiagnosticReceipt(events: diagnosticEvents)
            )
        }

        record(.repairAttempted(normalizedValidation.boundedModelRepairIssues.map(\.code).sorted()))
        await progress(.repairing)
        let repairedRawDraft = try await request(.repair(normalizedValidation.boundedModelRepairInstructions))
        let repairedSanitization = SessionNoteOutputSanitizer.sanitizeWithReport(
            repairedRawDraft,
            scrubber: packet.scrubber
        )
        let repairedInitialValidation = SessionNoteOutputValidator.validate(repairedSanitization.draft, evidence: packet)
        let repairedDeterministic = SessionNoteDeterministicRepairer.repair(
            repairedInitialValidation.draft,
            validation: repairedInitialValidation,
            evidence: packet
        )
        record(.deterministicRepairCodes(
            Array(Set(repairedSanitization.appliedIssueCodes + repairedDeterministic.appliedIssueCodes)).sorted()
        ))
        let repairedValidation = SessionNoteOutputValidator.validate(repairedDeterministic.draft, evidence: packet)
        record(.repairPassIssueCodes(repairedValidation.issueCodes))
        record(.candidateAssessment(SessionNoteCandidateDiagnostics.make(
            pass: .repair,
            rawDraft: repairedRawDraft,
            normalizedDraft: repairedDeterministic.draft,
            validation: repairedValidation,
            evidence: packet
        )))
        if repairedValidation.isProfessionallyReady {
            record(.finalOutcome(.repaired))
            return SessionNoteGenerationResult(
                draft: repairedValidation.draft,
                outcome: .repaired,
                issueCodes: repairedValidation.issueCodes,
                diagnostics: SessionNoteDiagnosticReceipt(events: diagnosticEvents)
            )
        }

        if let fallback = SessionNoteConservativeFallback.make(from: packet) {
            record(.fallback(.succeeded))
            record(.finalOutcome(.fallback))
            return SessionNoteGenerationResult(
                draft: fallback,
                outcome: .fallback,
                issueCodes: repairedValidation.issueCodes,
                diagnostics: SessionNoteDiagnosticReceipt(events: diagnosticEvents)
            )
        }

        let fallbackOutcome: SessionNoteFallbackOutcome = packet.typedFacts.isEmpty ? .insufficientEvidence : .unsafe
        record(.fallback(fallbackOutcome))
        record(.finalOutcome(.rejected))
        throw SessionNotePipelineError.rejected(repairedValidation.primaryFailureCategory)
    }
}

enum SessionNoteRequestRaceError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Apple Intelligence did not finish this generation step in time. Your session facts and any previous draft are still here."
    }
}

final class SessionNoteRequestRace<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private let timeoutNanoseconds: UInt64
    private var continuation: CheckedContinuation<Value, Error>?
    private var generationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var timeoutGeneration = 0
    private var isFinished = false

    init(timeoutSeconds: UInt64) {
        timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }

    init(timeoutNanoseconds: UInt64) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func run(operation: @escaping () async throws -> Value) async throws -> Value {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if isFinished {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                lock.unlock()

                restartTimeout()
                let task = Task {
                    do {
                        resolve(.success(try await operation()))
                    } catch {
                        resolve(.failure(error))
                    }
                }
                installGenerationTask(task)
            }
        }, onCancel: {
            self.cancel()
        })
    }

    func restartTimeout() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        timeoutGeneration += 1
        let generation = timeoutGeneration
        let previous = timeoutTask
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.timeoutNanoseconds ?? 0)
            } catch {
                return
            }
            self?.timeoutFired(generation: generation)
        }
        timeoutTask = task
        lock.unlock()
        previous?.cancel()
    }

    func cancel() {
        resolve(.failure(CancellationError()))
    }

    private func installGenerationTask(_ task: Task<Void, Never>) {
        lock.lock()
        if isFinished {
            lock.unlock()
            task.cancel()
            return
        }
        generationTask = task
        lock.unlock()
    }

    private func timeoutFired(generation: Int) {
        lock.lock()
        let isCurrent = !isFinished && generation == timeoutGeneration
        lock.unlock()
        if isCurrent {
            resolve(.failure(SessionNoteRequestRaceError.timedOut))
        }
    }

    private func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        self.continuation = nil
        let generationTask = self.generationTask
        let timeoutTask = self.timeoutTask
        self.generationTask = nil
        self.timeoutTask = nil
        lock.unlock()

        generationTask?.cancel()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
    }
}

struct SessionNoteDraftLedger {
    private(set) var draft: String
    private(set) var activeRequestID: UUID?

    init(draft: String = "") {
        self.draft = draft
    }

    mutating func begin(requestID: UUID, preserving currentDraft: String) {
        draft = currentDraft
        activeRequestID = requestID
    }

    func isCurrent(_ requestID: UUID) -> Bool {
        activeRequestID == requestID
    }

    mutating func accept(_ candidate: String, for requestID: UUID) -> Bool {
        guard isCurrent(requestID) else { return false }
        let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        draft = cleaned
        return true
    }

    mutating func finish(requestID: UUID) {
        guard isCurrent(requestID) else { return }
        activeRequestID = nil
    }
}

enum ABATerminologyNormalizer {
    private static let canonicalTerms = [
        "BCBA-D", "VB-MAPP", "ABLLS-R", "BCaBA", "BCBA", "PECS", "IFSP",
        "ABA", "RBT", "LBS", "BHT", "FCT", "DTT", "DRA", "DRI", "DRO",
        "DRL", "NCR", "AAC", "FBA", "BIP", "BSP", "SIB", "IOA", "IRT",
        "IEP", "ADL",
    ]

    private static let ambiguousTerms = ["NET", "ABC", "SD", "MO", "EO", "AO", "FA", "FR", "VR", "FI", "VI"]

    static func normalize(_ value: String) -> String {
        let weightPlaceholder = "LIFEROUTEWEIGHTUNITPOUNDS"
        var result = value.replacingOccurrences(
            of: #"(?i)(\d(?:[\d.,]*))(\s*)lbs\b"#,
            with: "$1$2\(weightPlaceholder)",
            options: .regularExpression
        )
        for term in canonicalTerms {
            result = replaceToken(term, in: result) { _, _ in
                return term
            }
        }

        for term in ambiguousTerms {
            result = replaceToken(term, in: result) { match, context in
                guard match != term else { return match }
                return Self.hasABAContext(for: term, context: context) ? term : match
            }
        }
        return result.replacingOccurrences(of: weightPlaceholder, with: "lbs")
    }

    private static func replaceToken(
        _ canonical: String,
        in value: String,
        transform: (String, String) -> String
    ) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: canonical)
        let pattern = "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let source = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return value }

        var output = value
        for match in matches.reversed() {
            guard let range = Range(match.range, in: output) else { continue }
            let lowerBound = output.index(range.lowerBound, offsetBy: -min(45, output.distance(from: output.startIndex, to: range.lowerBound)))
            let upperBound = output.index(range.upperBound, offsetBy: min(45, output.distance(from: range.upperBound, to: output.endIndex)))
            let context = String(output[lowerBound..<upperBound])
            let replacement = transform(String(output[range]), context)
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    private static func hasABAContext(for term: String, context: String) -> Bool {
        let lower = context.lowercased()
        switch term {
        case "NET":
            return lower.range(
                of: #"natural environment (teaching|training)|\b(during|implemented|used|teaching|training|session|targets?|opportunities)\s+net\b|\bnet\s+(teaching|training|session|targets?|opportunities)\b"#,
                options: .regularExpression
            ) != nil
        case "ABC":
            return lower.range(
                of: #"\babc\s+(data|recording|sequence|chart)|\b(antecedent|behavior|behaviour)[, /-]+(behavior|behaviour|consequence)"#,
                options: .regularExpression
            ) != nil
        case "SD":
            return lower.range(
                of: #"discriminative stimulus|\bsd\s+(was|is|presentation|instruction|trial)|\b(presented|delivered)\s+(the\s+)?sd\b"#,
                options: .regularExpression
            ) != nil
        case "MO", "EO", "AO":
            return lower.range(
                of: #"\b(motivating|establishing|abolishing) operation|\b(mo|eo|ao)\s+(was|is|assessment|condition)\b"#,
                options: .regularExpression
            ) != nil
        case "FA":
            return lower.range(
                of: #"functional analysis|\bfa\s+(session|condition|data|assessment)\b"#,
                options: .regularExpression
            ) != nil
        case "FR", "VR", "FI", "VI":
            return lower.range(
                of: #"\b(fr|vr|fi|vi)\s*-?\s*\d+\b|\b(fr|vr|fi|vi)\s+(schedule|reinforcement)\b"#,
                options: .regularExpression
            ) != nil
        default:
            return false
        }
    }
}

struct SessionNoteIdentifierScrubber {
    private struct Rule: Equatable {
        let identifier: String
        let replacement: String
    }

    private let rules: [Rule]

    init(profileCode: String?, sourceText: String) {
        var discovered = [
            Rule(identifier: "Brandon Good", replacement: "the RBT"),
            Rule(identifier: "Brandon", replacement: "the RBT"),
        ]

        if let profileCode {
            let code = profileCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if code.count >= 3 {
                discovered.append(Rule(identifier: code, replacement: "the client"))
                let letters = code.filter(\.isLetter)
                if letters.count >= 4 {
                    let first = letters.first.map(String.init) ?? ""
                    let midpoint = letters.index(letters.startIndex, offsetBy: min(2, letters.count - 1))
                    let last = String(letters[midpoint])
                    discovered.append(Rule(identifier: "\(first).\(last).", replacement: "the client"))
                    discovered.append(Rule(identifier: "\(first). \(last).", replacement: "the client"))
                }
            }
        }

        discovered.append(contentsOf: Self.inferredRules(from: sourceText))
        var seen = Set<String>()
        self.rules = discovered
            .filter { !$0.identifier.isEmpty && seen.insert($0.identifier.lowercased()).inserted }
            .sorted { $0.identifier.count > $1.identifier.count }
    }

    var forbiddenIdentifiers: [String] {
        rules.map(\.identifier)
    }

    func scrub(_ value: String) -> String {
        var output = value
        for rule in rules {
            output = Self.replaceIdentifier(rule, in: output)
        }

        // Saved client codes use alternating title-case pairs (for example, JaHe).
        // Scrub the shape even when a pasted code does not match the selected profile.
        output = Self.replacing(
            pattern: #"(?<![A-Za-z0-9])[A-Z][a-z][A-Z][a-z](?![A-Za-z0-9])"#,
            in: output,
            with: "the client"
        )
        output = Self.replacing(
            pattern: #"(?<![A-Za-z0-9])[A-Z]\.[ ]?[A-Z]\.(?![A-Za-z0-9])"#,
            in: output,
            with: "the client"
        )

        let cleanups: [(String, String)] = [
            (#"(?i)\b(?:the\s+)?client\s+the\s+client\b"#, "the client"),
            (#"(?i)\b(?:the\s+)?RBT\s+the\s+RBT\b"#, "the RBT"),
            (#"(?i)\b(?:the\s+)?LBS\s+the\s+LBS\b"#, "the LBS"),
            (#"(?i)\b(?:the\s+)?BCBA\s+the\s+BCBA\b"#, "the BCBA"),
            (#"(?i)\bclient\s+the\s+client\b"#, "the client"),
        ]
        for (pattern, replacement) in cleanups {
            output = Self.replacing(pattern: pattern, in: output, with: replacement)
        }
        return output
    }

    func survivingIdentifier(in value: String) -> String? {
        rules.first { rule in
            value.range(
                of: "(?i)(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: rule.identifier))(?![A-Za-z0-9])",
                options: .regularExpression
            ) != nil
        }?.identifier
    }

    private static func inferredRules(from source: String) -> [Rule] {
        let rolePattern = #"\b(the\s+)?(client|RBT|LBS|BCBA|BHT|clinician|caregiver|client's mother|client's father|client's grandmother|client's brother)\s+(?:named\s+)?([A-Z][a-z]{1,}(?:\s+[A-Z][a-z]{1,})?)\b"#
        guard let regex = try? NSRegularExpression(pattern: rolePattern) else { return [] }
        let nsSource = source as NSString
        let ignoredWords: Set<String> = [
            "implemented", "provided", "observed", "reported", "modeled", "modelled",
            "instructed", "used", "began", "continued", "met", "arrived", "presented",
        ]
        return regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length)).compactMap { match in
            guard match.numberOfRanges > 3,
                  match.range(at: 2).location != NSNotFound,
                  match.range(at: 3).location != NSNotFound else { return nil }
            let role = nsSource.substring(with: match.range(at: 2)).lowercased()
            let name = nsSource.substring(with: match.range(at: 3))
            guard !ignoredWords.contains(name.lowercased()) else { return nil }
            let replacement: String
            if role.contains("client") && !role.contains("mother") && !role.contains("father") && !role.contains("grandmother") && !role.contains("brother") {
                replacement = "the client"
            } else if role == "rbt" || role == "clinician" {
                replacement = "the RBT"
            } else if role == "lbs" {
                replacement = "the LBS"
            } else if role == "bcba" {
                replacement = "the BCBA"
            } else if role == "bht" {
                replacement = "the BHT"
            } else if role.contains("mother") {
                replacement = "the client's mother"
            } else if role.contains("father") {
                replacement = "the client's father"
            } else if role.contains("grandmother") {
                replacement = "the client's grandmother"
            } else if role.contains("brother") {
                replacement = "the client's brother"
            } else {
                replacement = "the caregiver"
            }
            return Rule(identifier: name, replacement: replacement)
        }
    }

    private static func replaceIdentifier(_ rule: Rule, in value: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: rule.identifier)
        let pattern = "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        return replacing(pattern: pattern, in: value, with: rule.replacement)
    }

    private static func replacing(pattern: String, in value: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        return regex.stringByReplacingMatches(
            in: value,
            range: NSRange(location: 0, length: (value as NSString).length),
            withTemplate: replacement
        )
    }
}

enum SessionNoteEvidenceNormalizer {
    static func typedFacts(_ value: String) -> String {
        let normalized = normalizeLines(value, removeAmbiguousOCR: false)
        return String(ABATerminologyNormalizer.normalize(normalized).prefix(5_200))
    }

    static func quantitativeOCR(_ value: String) -> String {
        let lines = normalizeLines(
            retainingLegacySplitLineAssociations(in: value),
            removeAmbiguousOCR: true
        )
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { line in
                line.contains(where: \.isNumber) && !isStructuralOCRHeading(line)
            }
        return String(lines.joined(separator: "\n").prefix(1_600))
    }

    private static func retainingLegacySplitLineAssociations(in value: String) -> String {
        let lines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
        var output: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let target = line.replacingOccurrences(
                of: #"(?i)^\s*\[AMBIGUOUS OCR\]\s*"#,
                with: "",
                options: .regularExpression
            )
            let isAmbiguousTargetLine = target != line &&
                target.contains(where: \.isLetter) &&
                !target.contains(where: \.isNumber) &&
                target.range(
                    of: #"(?i)\b(?:session date|date of service|service date|start time|end time|provider|therapist|client name|member id|authorization|billing|claim|appointment|signature)\b"#,
                    options: .regularExpression
                ) == nil

            if isAmbiguousTargetLine, lines.indices.contains(index + 1) {
                let next = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                let isTaggedMeasurement = next.contains(where: \.isNumber) && next.range(
                    of: #"(?i)^\s*\[(?:[^\]]*(?:PERCENTAGE|TRIAL-BASED|FREQUENCY/COUNT|DURATION|LATENCY|RATE)[^\]]*)\]"#,
                    options: .regularExpression
                ) != nil
                if isTaggedMeasurement {
                    output.append("Target: \(target) | \(next)")
                    index += 2
                    continue
                }
            }

            output.append(line)
            index += 1
        }
        return output.joined(separator: "\n")
    }

    static func savedContext(_ value: String) -> String {
        String(normalizeLines(value, removeAmbiguousOCR: true).prefix(280))
    }

    static func numericClaims(in value: String) -> [SessionNoteNumericClaim] {
        let pattern = #"(?<![A-Za-z0-9])\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: source.length))
        return matches.enumerated().map { index, match in
            let raw = source.substring(with: match.range)
            var contextStart = max(0, match.range.location - 48)
            var contextEnd = min(source.length, NSMaxRange(match.range) + 48)

            if index > 0 {
                let previousEnd = NSMaxRange(matches[index - 1].range)
                if previousEnd < match.range.location {
                    let midpoint = previousEnd + ((match.range.location - previousEnd) / 2)
                    contextStart = max(contextStart, midpoint)
                }
            }
            if matches.indices.contains(index + 1) {
                let currentEnd = NSMaxRange(match.range)
                let nextStart = matches[index + 1].range.location
                if currentEnd < nextStart {
                    let midpoint = currentEnd + ((nextStart - currentEnd) / 2)
                    contextEnd = min(contextEnd, midpoint)
                }
            }

            let context = source.substring(with: NSRange(location: contextStart, length: contextEnd - contextStart))
            return SessionNoteNumericClaim(
                value: raw.replacingOccurrences(of: " ", with: ""),
                kind: measurementKind(for: raw, context: context)
            )
        }
    }

    static func promptLevels(in value: String) -> Set<String> {
        let lower = value.lowercased()
        let levels = ["independent", "gestural", "verbal", "visual", "model", "partial physical", "full physical"]
        return Set(levels.filter { level in
            lower.range(
                of: "(?<![A-Za-z])\(NSRegularExpression.escapedPattern(for: level))(?![A-Za-z])",
                options: .regularExpression
            ) != nil
        })
    }

    static func contextOnlyClinicalTerms(in savedContext: String, excluding factualEvidence: String) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []
        for section in savedContext.components(separatedBy: "|") {
            let parts = section.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let label = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard label == "targets" || label == "behaviors" else { continue }
            for rawTerm in parts[1].components(separatedBy: ";") {
                let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = term.lowercased()
                guard term.count >= 3,
                      key != "none",
                      seen.insert(key).inserted,
                      !containsClinicalTerm(term, in: factualEvidence) else { continue }
                terms.append(term)
            }
        }
        return terms
    }

    static func containsClinicalTerm(_ term: String, in value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        return value.range(
            of: "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])",
            options: .regularExpression
        ) != nil
    }

    static func clinicalRoles(in value: String) -> Set<String> {
        let roles = ["RBT", "LBS", "BCBA", "BHT"]
        return Set(roles.filter { containsClinicalTerm($0, in: value) })
    }

    static func supervisorClaims(in value: String) -> Set<SessionNoteSupervisorClaim> {
        let patterns: [(SessionNoteSupervisorAction, String)] = [
            (.guidance, #"(?:instructed|provided guidance|guided|directed)"#),
            (.observation, #"(?:observed|supervised|was present)"#),
            (.modeling, #"(?:modeled|modelled|demonstrated)"#),
            (.feedback, #"(?:provided|gave)\s+feedback"#),
            (.treatmentModification, #"(?:modified|changed|updated)\s+(?:the\s+)?(?:treatment plan|protocol|program|prompting)"#),
        ]
        let source = value as NSString
        var claims = Set<SessionNoteSupervisorClaim>()
        for (action, verbPattern) in patterns {
            let pattern = #"(?i)\b(BCBA|LBS)\b[^.!?]{0,100}\b"# + verbPattern + #"\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: value, range: NSRange(location: 0, length: source.length)) {
                guard match.numberOfRanges > 1 else { continue }
                claims.insert(SessionNoteSupervisorClaim(
                    role: source.substring(with: match.range(at: 1)).uppercased(),
                    action: action
                ))
            }
        }
        return claims
    }

    private static func normalizeLines(_ value: String, removeAmbiguousOCR: Bool) -> String {
        let canonicalNewlines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var seen = Set<String>()
        var output: [String] = []
        for raw in canonicalNewlines.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw
                .replacingOccurrences(of: #"[\t ]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                if output.last?.isEmpty == false { output.append("") }
                continue
            }
            if removeAmbiguousOCR && line.localizedCaseInsensitiveContains("AMBIGUOUS OCR") {
                continue
            }
            let key = line.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(line)
        }
        return output.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isStructuralOCRHeading(_ line: String) -> Bool {
        line.range(
            of: #"(?i)^(?:screenshot|image|source)\s+\d+\s*:$"#,
            options: .regularExpression
        ) != nil
    }

    private static func measurementKind(for rawValue: String, context: String) -> SessionNoteMeasurementKind {
        let lower = context.lowercased()
        if lower.contains("%") || lower.range(of: #"\b(percent|percentage|accuracy)\b"#, options: .regularExpression) != nil {
            return .percentage
        }
        if rawValue.contains("/") || lower.range(of: #"\b(trials?|opportunities|correct out of)\b"#, options: .regularExpression) != nil {
            return .trials
        }
        if lower.range(of: #"\b(rate|per minute|per hour|per session)\b|/(min|hr)\b"#, options: .regularExpression) != nil {
            return .rate
        }
        if lower.range(of: #"\b(latency|time to respond|response time|time to begin|initiation delay)\b"#, options: .regularExpression) != nil {
            return .latency
        }
        if lower.range(of: #"\b(duration|seconds?|secs?|minutes?|mins?|hours?|hrs?)\b"#, options: .regularExpression) != nil {
            return .duration
        }
        if lower.range(of: #"\b(frequency|count|occurrences?|instances?|events?|times?)\b"#, options: .regularExpression) != nil {
            return .count
        }
        return .unknown
    }
}

struct SessionNoteOutputValidation {
    let draft: String
    let issues: [SessionNoteValidationIssue]

    var hardBlockers: [SessionNoteValidationIssue] {
        issues.filter { $0.severity == .hardBlocker }
    }

    var repairableIssues: [SessionNoteValidationIssue] {
        issues.filter { $0.severity == .repairable }
    }

    var warnings: [SessionNoteValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    var issueCodes: [String] { issues.map(\.code).sorted() }
    var hardBlockerCodes: [String] { hardBlockers.map(\.code).sorted() }
    var hardBlockerRepairInstructions: [String] {
        hardBlockers.map(\.repairInstruction)
    }
    var boundedModelRepairIssues: [SessionNoteValidationIssue] {
        issues.filter { $0.repairability == .boundedModel }
    }
    var boundedModelRepairInstructions: [String] {
        boundedModelRepairIssues.map(\.repairInstruction)
    }
    var isSafe: Bool { hardBlockers.isEmpty }
    var isProfessionallyReady: Bool {
        isSafe && !boundedModelRepairIssues.contains(where: { $0.userSafeCategory == .quality })
    }
    var isAcceptable: Bool { isProfessionallyReady }

    var primaryFailureCategory: SessionNoteFailureCategory {
        if hardBlockers.contains(where: { $0.userSafeCategory == .identityVerification }) {
            return .identityVerification
        }
        if hardBlockers.contains(where: { $0.userSafeCategory == .evidenceVerification }) {
            return .evidenceVerification
        }
        if boundedModelRepairIssues.contains(where: { $0.userSafeCategory == .quality }) {
            return .professionalPresentation
        }
        return .clinicalClaimVerification
    }
}

struct SessionNoteDeterministicRepairResult {
    let draft: String
    let appliedIssueCodes: [String]
}

enum SessionNoteOutputSanitizer {
    static let continuationSentence = "The RBT will continue implementing the established treatment plan during future sessions."

    static func sanitize(_ value: String, scrubber: SessionNoteIdentifierScrubber) -> String {
        sanitizeWithReport(value, scrubber: scrubber).draft
    }

    static func sanitizeWithReport(
        _ value: String,
        scrubber: SessionNoteIdentifierScrubber
    ) -> SessionNoteDeterministicRepairResult {
        var repairs: [String] = []
        var cleaned = scrubber.scrub(value)
        if cleaned != value { repairs.append("SN-IDENTITY-REDACTED") }

        let beforeMarkdown = cleaned
        cleaned = cleaned
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
        if cleaned != beforeMarkdown { repairs.append("SN-FORMAT-001") }

        let beforeTerminology = cleaned
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\bmaladaptive\s+behaviou?rs?\b"#,
            with: "behaviors of concern",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\bclient'?s?\s+mom\b"#,
            with: "client's mother",
            options: .regularExpression
        )
        if cleaned != beforeTerminology { repairs.append("SN-TERMINOLOGY-001") }

        let roleNormalizations: [(String, String)] = [
            (#"(?i)\bthe\s+registered behavior technician\b|\bregistered behavior technician\b"#, "the RBT"),
            (#"(?i)\bthe\s+board certified behavior analyst\b|\bboard certified behavior analyst\b"#, "the BCBA"),
            (#"(?i)\bthe\s+licensed behavior specialist\b|\blicensed behavior specialist\b"#, "the LBS"),
        ]
        let beforeRoleNormalization = cleaned
        for (pattern, replacement) in roleNormalizations {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        if cleaned != beforeRoleNormalization { repairs.append("SN-TERMINOLOGY-002") }

        var paragraphs: [String] = []
        var current: [String] = []
        for raw in cleaned.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flush(&current, into: &paragraphs)
                continue
            }
            let beforeHeadingMarkdown = line
            line = line.replacingOccurrences(
                of: #"^\s*#{1,6}\s*"#,
                with: "",
                options: .regularExpression
            )
            if line != beforeHeadingMarkdown { repairs.append("SN-FORMAT-001") }
            let beforeList = line
            line = line.replacingOccurrences(
                of: #"^\s*(?:#{1,6}\s*)?(?:[-*•–—]\s+|\d+[.)]\s+)"#,
                with: "",
                options: .regularExpression
            )
            if line != beforeList { repairs.append("SN-FORMAT-004") }
            guard let content = contentRemovingHeading(from: line) else {
                repairs.append("SN-FORMAT-002")
                continue
            }
            if content != line { repairs.append("SN-FORMAT-003") }
            var narrativeContent = content.replacingOccurrences(
                of: #"^[A-Z][A-Za-z /&-]{2,40}:\s*"#,
                with: "",
                options: .regularExpression
            )
            if narrativeContent != content { repairs.append("SN-FORMAT-003") }
            narrativeContent = narrativeContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !narrativeContent.isEmpty else { continue }
            current.append(narrativeContent)
        }
        flush(&current, into: &paragraphs)

        paragraphs = paragraphs
            .map { ABATerminologyNormalizer.normalize(normalizeSentenceSpacing($0)) }
            .filter { !$0.isEmpty }

        return SessionNoteDeterministicRepairResult(
            draft: paragraphs.joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            appliedIssueCodes: Array(Set(repairs)).sorted()
        )
    }

    private static func contentRemovingHeading(from value: String) -> String? {
        let headingOnly = #"(?i)^(?:session\s*\d+|session note|session narrative note|treatment plan continuation|session overview|behavior data|data|generalization|assessment|plan|conclusion)\s*:?[\s*]*$"#
        if value.range(of: headingOnly, options: .regularExpression) != nil { return nil }

        let headingPrefix = #"(?i)^(?:#{1,6}\s*)?(?:session\s*\d+|session note|session narrative note|treatment plan continuation|session overview|behavior data|data|generalization|assessment|plan|conclusion)\s*:\s*"#
        let stripped = value.replacingOccurrences(of: headingPrefix, with: "", options: .regularExpression)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flush(_ current: inout [String], into paragraphs: inout [String]) {
        guard !current.isEmpty else { return }
        let paragraph = current.joined(separator: " ")
        if !paragraph.isEmpty { paragraphs.append(paragraph) }
        current.removeAll(keepingCapacity: true)
    }

    private static func normalizeSentenceSpacing(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[\t ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;!?])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ensureTerminalPunctuation(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return trimmed + "."
    }

    static func reflow(_ paragraphs: [String]) -> [String] {
        var result = paragraphs.flatMap { paragraph -> [String] in
            let sentences = splitSentences(paragraph)
            guard sentences.count >= 4, paragraph.count > 520 else { return [paragraph] }
            let midpoint = Int(ceil(Double(sentences.count) / 2.0))
            return [
                sentences[..<midpoint].joined(separator: " "),
                sentences[midpoint...].joined(separator: " "),
            ]
        }

        while result.count > 4 {
            let tail = result.removeLast()
            result[result.count - 1] += " " + tail
        }
        return result
    }

    static func splitSentences(_ value: String) -> [String] {
        value
            .components(separatedBy: try! NSRegularExpression(pattern: #"(?<=[.!?])\s+"#))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum SessionNoteDeterministicRepairer {
    static func repair(
        _ value: String,
        validation: SessionNoteOutputValidation,
        evidence: SessionNoteEvidencePacket
    ) -> SessionNoteDeterministicRepairResult {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SessionNoteDeterministicRepairResult(draft: "", appliedIssueCodes: [])
        }

        var repaired = value
        var repairs: [String] = []

        if validation.issueCodes.contains("SN-FORMAT-009") {
            let filtered = SessionNoteOutputSanitizer.splitSentences(repaired)
                .filter { sentence in
                    let lower = sentence.lowercased()
                    return ![
                        "this note was generated", "as an ai", "insert client",
                        "session narrative note", "data section:",
                    ].contains(where: lower.contains)
                }
                .joined(separator: " ")
            if filtered != repaired { repairs.append("SN-FORMAT-009") }
            repaired = filtered
        }

        if validation.issueCodes.contains("SN-TERMINOLOGY-001") {
            let normalized = repaired.replacingOccurrences(
                of: #"(?i)\bmaladaptive\s+behaviou?rs?\b"#,
                with: "behaviors of concern",
                options: .regularExpression
            )
            if normalized != repaired { repairs.append("SN-TERMINOLOGY-001") }
            repaired = normalized
        }

        if validation.issueCodes.contains("SN-TERMINOLOGY-002"), evidence.clinicalRoles.count == 1,
           let role = evidence.clinicalRoles.first {
            let normalized = repaired.replacingOccurrences(
                of: #"(?i)\b(?:the\s+)?(?:clinician|therapist|provider)\b"#,
                with: "the \(role)",
                options: .regularExpression
            )
            if normalized != repaired { repairs.append("SN-TERMINOLOGY-002") }
            repaired = normalized
        }

        let beforeParagraphs = repaired
        var paragraphs = repaired
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        paragraphs = SessionNoteOutputSanitizer.reflow(paragraphs)
        repaired = paragraphs.joined(separator: "\n\n")
        if repaired != beforeParagraphs {
            if validation.issueCodes.contains("SN-FORMAT-006") { repairs.append("SN-FORMAT-006") }
            if validation.issueCodes.contains("SN-FORMAT-007") { repairs.append("SN-FORMAT-007") }
        }

        let beforeClose = repaired
        repaired = normalizeContinuationClose(in: repaired)
        if repaired != beforeClose { repairs.append("SN-FORMAT-005") }

        let beforePunctuation = repaired
        repaired = repaired
            .components(separatedBy: "\n\n")
            .map(SessionNoteOutputSanitizer.ensureTerminalPunctuation)
            .joined(separator: "\n\n")
        if repaired != beforePunctuation { repairs.append("SN-FORMAT-008") }

        return SessionNoteDeterministicRepairResult(
            draft: repaired.trimmingCharacters(in: .whitespacesAndNewlines),
            appliedIssueCodes: Array(Set(repairs)).sorted()
        )
    }

    private static func normalizeContinuationClose(in value: String) -> String {
        var paragraphs = value
            .components(separatedBy: "\n\n")
            .map { paragraph in
                SessionNoteOutputSanitizer.splitSentences(paragraph)
                    .filter { !isContinuationClose($0) }
                    .joined(separator: " ")
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return "" }
        paragraphs[paragraphs.count - 1] = SessionNoteOutputSanitizer.ensureTerminalPunctuation(
            paragraphs.last ?? ""
        ) + " " + SessionNoteOutputSanitizer.continuationSentence
        return paragraphs.joined(separator: "\n\n")
    }

    private static func isContinuationClose(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        return lower.contains("continu") && (
            lower.contains("treatment plan") || lower.contains("future session")
        )
    }
}

enum SessionNoteConservativeFallback {
    static func make(from evidence: SessionNoteEvidencePacket) -> String? {
        guard evidence.structuredMeasurements.isEmpty else { return nil }
        let facts = evidence.typedFacts.trimmingCharacters(in: .whitespacesAndNewlines)
        guard facts.count >= 20,
              facts.split(whereSeparator: \.isWhitespace).count >= 4,
              facts.range(
                of: #"(?i)\b(client|RBT|LBS|BCBA|BHT|caregiver|mother|father|grandmother|brother)\b"#,
                options: .regularExpression
              ) != nil else { return nil }

        let sanitized = SessionNoteOutputSanitizer.sanitize(facts, scrubber: evidence.scrubber)
        let initial = SessionNoteOutputValidator.validate(
            sanitized,
            evidence: evidence,
            requireStructuredMeasurementCoverage: false
        )
        let repaired = SessionNoteDeterministicRepairer.repair(
            initial.draft,
            validation: initial,
            evidence: evidence
        )
        let final = SessionNoteOutputValidator.validate(
            repaired.draft,
            evidence: evidence,
            requireStructuredMeasurementCoverage: false
        )
        return final.isSafe ? final.draft : nil
    }
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        let range = NSRange(location: 0, length: (self as NSString).length)
        var result: [String] = []
        var cursor = 0
        for match in regex.matches(in: self, range: range) {
            let length = match.range.location - cursor
            result.append((self as NSString).substring(with: NSRange(location: cursor, length: length)))
            cursor = NSMaxRange(match.range)
        }
        result.append((self as NSString).substring(from: cursor))
        return result
    }
}

enum SessionNoteOutputValidator {
    static func validate(
        _ draft: String,
        evidence: SessionNoteEvidencePacket,
        requireStructuredMeasurementCoverage: Bool = true
    ) -> SessionNoteOutputValidation {
        var issues: [SessionNoteValidationIssue] = []
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()

        if cleaned.isEmpty {
            issues.append(issue(
                "SN-EVIDENCE-000", .hardBlocker, .evidenceVerification, .boundedModel,
                "Return a nonempty note grounded only in the supplied session evidence."
            ))
        }
        if evidence.scrubber.survivingIdentifier(in: cleaned) != nil {
            issues.append(issue(
                "SN-IDENTITY-001", .hardBlocker, .identityVerification, .boundedModel,
                "Remove every personal or profile identifier and use role identifiers only."
            ))
        }
        if containsLikelyPersonalName(in: cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-IDENTITY-002", .hardBlocker, .identityVerification, .boundedModel,
                "Remove the likely personal name and use a supported role identifier."
            ))
        }
        if containsIdentifierShape(in: cleaned) {
            issues.append(issue(
                "SN-IDENTITY-003", .hardBlocker, .identityVerification, .boundedModel,
                "Remove client-code and identifiable-initial patterns."
            ))
        }
        if lower.contains("**") || lower.contains("```") || lower.range(of: #"(?m)^\s*#{1,6}\s+"#, options: .regularExpression) != nil {
            issues.append(issue(
                "SN-FORMAT-001", .repairable, .formatNormalization, .deterministic,
                "Remove Markdown markers."
            ))
        }
        if lower.range(
            of: #"(?im)^\s*(session\s*\d+|session note|treatment plan continuation|assessment|plan|conclusion)\s*:"#,
            options: .regularExpression
        ) != nil {
            issues.append(issue(
                "SN-FORMAT-002", .repairable, .formatNormalization, .deterministic,
                "Remove headings while retaining their supported narrative content."
            ))
        }
        if cleaned.range(
            of: #"(?m)^\s*[A-Z][A-Za-z /&-]{2,40}:\s*"#,
            options: .regularExpression
        ) != nil {
            issues.append(issue(
                "SN-FORMAT-003", .repairable, .formatNormalization, .deterministic,
                "Remove heading-like scaffolding."
            ))
        }
        if lower.range(of: #"(?m)^\s*(?:[-*•–—]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil {
            issues.append(issue(
                "SN-FORMAT-004", .repairable, .formatNormalization, .deterministic,
                "Convert list scaffolding to narrative prose."
            ))
        }
        if lower.contains("maladaptive behavior") || lower.contains("maladaptive behaviour") {
            issues.append(issue(
                "SN-TERMINOLOGY-001", .repairable, .terminologyNormalization, .deterministic,
                "Use behaviors of concern terminology."
            ))
        }
        if lower.range(of: #"(?<![A-Za-z])(i|we|my|our)(?![A-Za-z])"#, options: .regularExpression) != nil {
            issues.append(issue(
                "SN-QUALITY-001", .warning, .quality, .userEditable,
                "Prefer consistently third-person wording."
            ))
        }
        if lower.range(of: #"\b(clinician|therapist|provider)\b"#, options: .regularExpression) != nil {
            let isUnambiguous = evidence.clinicalRoles.count == 1
            issues.append(issue(
                "SN-TERMINOLOGY-002",
                isUnambiguous ? .repairable : .warning,
                .terminologyNormalization,
                isUnambiguous ? .deterministic : .userEditable,
                "Use a supplied ABA role instead of a generic clinician label when the role is established."
            ))
        }
        if !lower.contains("continue implementing the established treatment plan during future sessions") {
            issues.append(issue(
                "SN-FORMAT-005", .repairable, .formatNormalization, .deterministic,
                "Append the approved treatment-plan continuation sentence."
            ))
        }

        let paragraphs = cleaned.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if paragraphs.count > 4 {
            issues.append(issue(
                "SN-FORMAT-006", .repairable, .formatNormalization, .deterministic,
                "Reflow the narrative to no more than four readable paragraphs."
            ))
        }
        if paragraphs.count == 1,
           SessionNoteOutputSanitizer.splitSentences(cleaned).count >= 4,
           cleaned.count > 520 {
            issues.append(issue(
                "SN-FORMAT-007", .repairable, .formatNormalization, .deterministic,
                "Reflow the oversized paragraph into readable narrative groups."
            ))
        }
        if let last = cleaned.last, !".!?".contains(last) {
            issues.append(issue(
                "SN-FORMAT-008", .repairable, .formatNormalization, .deterministic,
                "Add final punctuation."
            ))
        }
        let sentences = SessionNoteOutputSanitizer.splitSentences(cleaned)
        if sentences.count < 2 || !lower.contains("client") {
            issues.append(issue(
                "SN-QUALITY-002", .warning, .quality, .userEditable,
                "Prefer a supplied client participation or observable-response summary."
            ))
        }

        let outputClaims = SessionNoteEvidenceNormalizer.numericClaims(in: cleaned)
        for claim in outputClaims {
            let candidates = evidence.numericClaims.filter { $0.value == claim.value }
            if candidates.isEmpty {
                issues.append(issue(
                    "SN-EVIDENCE-001", .hardBlocker, .evidenceVerification, .boundedModel,
                    "Remove every numeric value not present in the supplied facts or clear OCR."
                ))
            } else if claim.kind != .unknown,
                      !candidates.contains(where: { $0.kind == claim.kind || $0.kind == .unknown }) {
                issues.append(issue(
                    "SN-EVIDENCE-002", .hardBlocker, .evidenceVerification, .boundedModel,
                    "Restore each supplied numeric value to its original measurement type."
                ))
            }
        }

        if requireStructuredMeasurementCoverage,
           missingStructuredMeasurementCount(in: cleaned, evidence: evidence) > 0 {
            issues.append(issue(
                "SN-EVIDENCE-006", .hardBlocker, .evidenceVerification, .boundedModel,
                "Include every clear current-session screenshot measurement with its supplied target, measurement type, value, unit, and prompt level."
            ))
        }

        let outputPromptLevels = SessionNoteEvidenceNormalizer.promptLevels(in: cleaned)
        if !outputPromptLevels.subtracting(evidence.promptLevels).isEmpty {
            issues.append(issue(
                "SN-EVIDENCE-003", .hardBlocker, .evidenceVerification, .boundedModel,
                "Remove prompt levels that were not supplied in the evidence."
            ))
        }

        let unsupportedAbsence = lower.range(
            of: #"\b(did not occur|no behaviors? of concern occurred|zero instances)\b"#,
            options: .regularExpression
        ) != nil
        let factsSupportAbsence = evidence.typedFacts.lowercased().range(
            of: #"\b(did not occur|no behaviors? of concern occurred|zero instances|0 occurrences|0 instances)\b"#,
            options: .regularExpression
        ) != nil
        if unsupportedAbsence && !factsSupportAbsence {
            issues.append(issue(
                "SN-EVIDENCE-004", .hardBlocker, .evidenceVerification, .boundedModel,
                "Remove unsupported claims that a behavior did not occur."
            ))
        }

        if evidence.contextOnlyClinicalTerms.contains(where: {
            SessionNoteEvidenceNormalizer.containsClinicalTerm($0, in: cleaned)
        }) {
            issues.append(issue(
                "SN-EVIDENCE-005", .hardBlocker, .evidenceVerification, .boundedModel,
                "Remove saved-context-only targets or behaviors that lack current-session evidence."
            ))
        }

        issues.append(contentsOf: unsupportedClinicalClaims(in: cleaned, evidence: evidence))

        let unsupportedSupervisorClaims = SessionNoteEvidenceNormalizer.supervisorClaims(in: cleaned)
            .subtracting(evidence.supervisorClaims)
        if !unsupportedSupervisorClaims.isEmpty {
            issues.append(issue(
                "SN-CLINICAL-008", .hardBlocker, .clinicalClaimVerification, .boundedModel,
                "Remove supervisor involvement not supported by the current-session evidence."
            ))
        }

        if hasObviousTemplateLanguage(lower) {
            issues.append(issue(
                "SN-FORMAT-009", .repairable, .formatNormalization, .deterministic,
                "Remove obvious template or model scaffolding."
            ))
        }
        if hasRepetitiveOpenings(cleaned) {
            issues.append(issue(
                "SN-QUALITY-003", .warning, .quality, .userEditable,
                "Vary repetitive sentence openings when editing the draft."
            ))
        }
        if hasSubstantialSourceCopying(cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-QUALITY-004", .repairable, .quality, .boundedModel,
                "Reconstruct the note from the original evidence using professional, objective, chronological ABA prose rather than preserving rough source wording or clause structure."
            ))
        }
        if hasRoughDictationFragments(cleaned) {
            issues.append(issue(
                "SN-QUALITY-005", .repairable, .quality, .boundedModel,
                "Replace rough dictation fragments, vague conversational work wording, and pronoun-first phrasing with objective person-first ABA documentation without adding facts."
            ))
        }

        var issuesByCode: [String: SessionNoteValidationIssue] = [:]
        for item in issues { issuesByCode[item.code] = item }
        return SessionNoteOutputValidation(
            draft: cleaned,
            issues: issuesByCode.values.sorted { $0.code < $1.code }
        )
    }

    private static func issue(
        _ code: String,
        _ severity: SessionNoteValidationSeverity,
        _ category: SessionNoteValidationCategory,
        _ repairability: SessionNoteValidationRepairability,
        _ repairInstruction: String
    ) -> SessionNoteValidationIssue {
        SessionNoteValidationIssue(
            code: code,
            severity: severity,
            userSafeCategory: category,
            repairability: repairability,
            repairInstruction: repairInstruction
        )
    }

    private static func containsStructuredMeasurement(
        _ measurement: SessionNoteMeasurementEvidence,
        in value: String
    ) -> Bool {
        guard let requiredClaim = measurement.numericClaim else { return false }
        let targetPattern = "(?i)(?<![A-Za-z0-9])" +
            NSRegularExpression.escapedPattern(for: measurement.target) +
            "(?![A-Za-z0-9])"

        return SessionNoteOutputSanitizer.splitSentences(value).contains { sentence in
            guard sentence.range(of: targetPattern, options: .regularExpression) != nil else {
                return false
            }
            let claims = SessionNoteEvidenceNormalizer.numericClaims(in: sentence)
            let hasClaim = claims.contains {
                $0.value == requiredClaim.value &&
                ($0.kind == requiredClaim.kind || $0.kind == .unknown)
            }
            guard hasClaim else { return false }
            let suppliedPrompts = measurement.promptLevels
            let outputPrompts = SessionNoteEvidenceNormalizer.promptLevels(in: sentence)
            return suppliedPrompts.isSubset(of: outputPrompts)
        }
    }

    static func missingStructuredMeasurementCount(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Int {
        evidence.structuredMeasurements.filter {
            !containsStructuredMeasurement($0, in: value)
        }.count
    }

    private static func containsLikelyPersonalName(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Bool {
        let pattern = #"\b[A-Z][a-z]{1,}\s+[A-Z][a-z]{1,}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let nsValue = value as NSString
        let factualEvidence = [evidence.typedFacts, evidence.quantitativeOCR].joined(separator: "\n")
        let allowed: Set<String> = [
            "The RBT", "The LBS", "The BCBA", "The BHT", "The Client",
            "Visual Schedule", "Choice Board", "First Then", "Apple Intelligence",
            "Treatment Plan",
        ]
        return regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length)).contains { match in
            let candidate = nsValue.substring(with: match.range)
            guard !allowed.contains(candidate) else { return false }

            let escaped = NSRegularExpression.escapedPattern(for: candidate)
            let personPatterns = [
                #"(?i)\b(?:client|caregiver|mother|father|grandmother|brother|RBT|LBS|BCBA|BHT|clinician)\s+(?:named\s+)?"#
                    + escaped + #"\b"#,
                #"(?i)\b"# + escaped
                    + #"(?:'s)?\s+(?:observed|reported|stated|said|worked|met|arrived|provided|instructed|implemented|modeled|modelled|prompted|redirected|reinforced|assisted|supported|joined|participated|responded|presented)\b"#,
                #"(?i)\b"# + escaped + #"\s+was\s+present\b"#,
                #"(?i)\b"# + escaped + #"'s\b"#,
            ]
            if personPatterns.contains(where: { candidatePattern in
                value.range(of: candidatePattern, options: .regularExpression) != nil
            }) {
                return true
            }
            return !SessionNoteEvidenceNormalizer.containsClinicalTerm(candidate, in: factualEvidence)
        }
    }

    private static func containsIdentifierShape(in value: String) -> Bool {
        value.range(
            of: #"(?<![A-Za-z0-9])(?:[A-Z][a-z][A-Z][a-z]|[A-Z]\.[ ]?[A-Z]\.)(?![A-Za-z0-9])"#,
            options: .regularExpression
        ) != nil
    }

    private static func hasObviousTemplateLanguage(_ lower: String) -> Bool {
        [
            "session 1", "treatment plan continuation:", "this note was generated",
            "as an ai", "insert client", "session narrative note", "data section:",
        ].contains(where: lower.contains)
    }

    private static func unsupportedClinicalClaims(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> [SessionNoteValidationIssue] {
        let supplied = [evidence.typedFacts, evidence.quantitativeOCR]
            .joined(separator: "\n")
        let patterns: [(String, String, String)] = [
            ("SN-CLINICAL-001", #"(?i)\b(function (?:was|is)|maintained by|attention[- ]seeking|escape[- ]maintained)\b"#, "Remove the unsupported behavioral-function conclusion."),
            ("SN-CLINICAL-002", #"(?i)\b(wanted|felt|was upset|was happy|was frustrated|was unmotivated)\b"#, "Remove the unsupported internal-state inference."),
            ("SN-CLINICAL-003", #"(?i)\b(made progress|demonstrated progress|improved|demonstrated improvement|regressed)\b"#, "Remove the unsupported progress conclusion."),
            ("SN-CLINICAL-004", #"(?i)\b(caregiver training|trained the caregiver|educated the caregiver)\b"#, "Remove unsupported caregiver-training claims."),
            ("SN-CLINICAL-005", #"(?i)\b(?:modified|changed|updated)\s+(?:the\s+)?(?:treatment plan|protocol|program|prompting)|\bnew\s+(?:targets?|programs?)\b"#, "Remove unsupported treatment or programming changes."),
            ("SN-CLINICAL-006", #"(?i)\brecommend(?:ed|ation|ations)?\b"#, "Remove recommendations that were not supplied."),
            ("SN-CLINICAL-007", #"(?i)\b(reinforcement (?:was|proved) effective|responded (?:well|positively) to (?:the )?reinforcement)\b"#, "Remove unsupported conclusions about reinforcement effectiveness."),
        ]
        return patterns.compactMap { code, pattern, instruction in
            let outputContains = value.range(of: pattern, options: .regularExpression) != nil
            let evidenceContains = supplied.range(of: pattern, options: .regularExpression) != nil
            return outputContains && !evidenceContains
                ? issue(code, .hardBlocker, .clinicalClaimVerification, .boundedModel, instruction)
                : nil
        }
    }

    private static func hasRepetitiveOpenings(_ value: String) -> Bool {
        let sentences = SessionNoteOutputSanitizer.splitSentences(value)
        guard sentences.count >= 5 else { return false }
        var counts: [String: Int] = [:]
        for sentence in sentences {
            let words = sentence
                .lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .prefix(2)
            guard words.count == 2 else { continue }
            counts[words.joined(separator: " "), default: 0] += 1
        }
        return counts.values.max().map { $0 >= 4 } ?? false
    }

    private static func hasSubstantialSourceCopying(
        _ value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Bool {
        let sourceTokens = comparisonTokens(in: evidence.typedFacts)
        guard sourceTokens.count >= 40,
              hasRoughSourceStructure(evidence.typedFacts) else { return false }
        let candidateWithoutClose = value.replacingOccurrences(
            of: SessionNoteOutputSanitizer.continuationSentence,
            with: "",
            options: [.caseInsensitive]
        )
        guard comparisonTokens(in: candidateWithoutClose).count >= 30 else { return false }

        return sourceOverlapBasisPoints(value, evidence: evidence) >= 4_500
    }

    static func sourceOverlapBasisPoints(
        _ value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Int {
        let sourceTokens = comparisonTokens(in: evidence.typedFacts)

        let candidateWithoutClose = value.replacingOccurrences(
            of: SessionNoteOutputSanitizer.continuationSentence,
            with: "",
            options: [.caseInsensitive]
        )
        let candidateTokens = comparisonTokens(in: candidateWithoutClose)

        let windowSize = 5
        guard sourceTokens.count >= windowSize, candidateTokens.count >= windowSize else { return 0 }
        let sourceWindows = Set((0...(sourceTokens.count - windowSize)).map {
            sourceTokens[$0..<($0 + windowSize)].joined(separator: " ")
        })
        let candidateWindows = (0...(candidateTokens.count - windowSize)).map {
            candidateTokens[$0..<($0 + windowSize)].joined(separator: " ")
        }
        let copiedWindowCount = candidateWindows.reduce(into: 0) { count, window in
            if sourceWindows.contains(window) { count += 1 }
        }
        return Int((Double(copiedWindowCount) / Double(candidateWindows.count) * 10_000).rounded())
    }

    private static func hasRoughSourceStructure(_ value: String) -> Bool {
        let patterns = [
            #"(?i)\bpresent\s*:"#,
            #"(?i)\bhad\s+(?:him|her|them|the\s+client)\b"#,
            #"(?i)\b(?:did|doing)\s+(?:more\s+)?work\b"#,
            #"(?i)\bafter\s+this\b"#,
            #"(?i)\b(?:took|needed)\s+(?:many|multiple|several)\s+redirections\b"#,
        ]
        if patterns.contains(where: { value.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }
        let transitionRegex = try? NSRegularExpression(pattern: #"(?i)\bthen\b"#)
        let range = NSRange(location: 0, length: (value as NSString).length)
        let transitionCount = transitionRegex?.numberOfMatches(in: value, range: range) ?? 0
        return transitionCount >= 3
    }

    private static func hasRoughDictationFragments(_ value: String) -> Bool {
        roughFragmentMatchCount(in: value) > 0
    }

    static func roughFragmentMatchCount(in value: String) -> Int {
        [
            #"(?i)\b(?:did|doing)\s+(?:more\s+)?work\b"#,
            #"(?i)\bhad\s+(?:him|her|them|the\s+client)\s+(?:wait|work)\b"#,
            #"(?i)\b(?:took|needed)\s+(?:many|multiple|several)\s+redirections\b"#,
            #"(?i)\bworking\s+on\b"#,
            #"(?i)\bmore\s+time\s+manding\b"#,
        ].reduce(into: 0) { count, pattern in
            if value.range(of: pattern, options: .regularExpression) != nil {
                count += 1
            }
        }
    }

    private static func comparisonTokens(in value: String) -> [String] {
        value
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}
