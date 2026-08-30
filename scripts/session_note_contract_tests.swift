import Foundation

private enum FixtureError: Error {
    case unavailable
    case repairFailed
}

@main
private struct SessionNoteContractFixtureRunner {
    private static var assertionCount = 0

    static func main() async throws {
        try terminologyFixtures()
        try identityAndSanitizerFixtures()
        try dataFidelityFixtures()
        try multiScreenshotEvidenceFixtures()
        try savedContextIsNotEvidenceFixtures()
        try emptyEvidenceFixtures()
        try await pipelineFixtures()
        try await runtimeProtectionFixtures()
        print("Session Note executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func terminologyFixtures() throws {
        let source = "aba rbt bcba bcba-d bcaba lbs bht fct dtt dra dri dro drl ncr pecs aac fba bip bsp sib ioa irt vb-mapp ablls-r iep ifsp adl"
        let expected = "ABA RBT BCBA BCBA-D BCaBA LBS BHT FCT DTT DRA DRI DRO DRL NCR PECS AAC FBA BIP BSP SIB IOA IRT VB-MAPP ABLLS-R IEP IFSP ADL"
        try expect(ABATerminologyNormalizer.normalize(source) == expected, "high-confidence ABA terms normalize canonically")
        try expect(
            ABATerminologyNormalizer.normalize("The client played in the net outside.") == "The client played in the net outside.",
            "ambiguous normal-English net stays lowercase"
        )
        try expect(
            ABATerminologyNormalizer.normalize("The rbt implemented net teaching.") == "The RBT implemented NET teaching.",
            "NET normalizes only with ABA context"
        )
        try expect(
            ABATerminologyNormalizer.normalize("The package weighed 5 lbs. Lbs instructed rbt.") == "The package weighed 5 lbs. LBS instructed RBT.",
            "LBS role casing does not rewrite a weight unit"
        )
    }

    private static func identityAndSanitizerFixtures() throws {
        let packet = evidencePacket()
        try expect(!packet.modelPrompt(compaction: .standard).contains("JaHe"), "profile code never reaches the standard model prompt")
        try expect(!packet.modelPrompt(compaction: .compactRetry).contains("JaHe"), "profile code never reaches the compact model prompt")
        try expect(packet.modelPrompt(compaction: .compactRetry).contains(packet.typedFacts), "compact retry preserves the normalized typed facts")

        let unsafe = """
        **Session 1**
        - JaHe engaged in fct during play.
        - Lbs instructed rbt to use the supplied verbal prompt.

        Treatment Plan Continuation:** The rbt will continue implementing the established treatment plan during future sessions.
        """
        let sanitized = SessionNoteOutputSanitizer.sanitize(unsafe, scrubber: packet.scrubber)
        try expect(!sanitized.contains("JaHe"), "known client identifier is scrubbed from output")
        let additionalIdentifiers = SessionNoteOutputSanitizer.sanitize(
            "LiFe and J.H. worked with Brandon during the supplied activity.",
            scrubber: packet.scrubber
        )
        try expect(
            !additionalIdentifiers.contains("LiFe") && !additionalIdentifiers.contains("J.H.") && !additionalIdentifiers.contains("Brandon"),
            "client-code shapes, identifiable initials, and the known clinician identity are scrubbed"
        )
        try expect(!sanitized.contains("**") && !sanitized.contains("Session 1"), "markdown and heading scaffolding are removed")
        try expect(sanitized.contains("FCT") && sanitized.contains("LBS") && sanitized.contains("RBT"), "generated output receives ABA casing normalization")

        let unknownName = "Jane Smith observed the client during play. The client participated in play. The RBT will continue implementing the established treatment plan during future sessions."
        let unknownValidation = SessionNoteOutputValidator.validate(unknownName, evidence: packet)
        try expect(!unknownValidation.isAcceptable, "unknown likely personal names are rejected after sanitization")
        let novelTitleCase = "Novel Person was referenced during play. The client participated in play. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            !SessionNoteOutputValidator.validate(novelTitleCase, evidence: packet).isAcceptable,
            "a novel title-cased phrase cannot use the supplied-clinical-label exemption"
        )
    }

    private static func dataFidelityFixtures() throws {
        let packet = evidencePacket()
        let valid = validDraft()
        try expect(SessionNoteOutputValidator.validate(valid, evidence: packet).isAcceptable, "supported numbers and prompt levels validate")

        let inventedNumber = valid.replacingOccurrences(of: "3/5", with: "47%")
        let inventedValidation = SessionNoteOutputValidator.validate(inventedNumber, evidence: packet)
        try expect(
            inventedValidation.issues.contains(where: { $0.contains("47") }),
            "a newly invented numeric value is rejected"
        )

        let changedMeasurement = valid.replacingOccurrences(of: "3/5 trials", with: "3% accuracy")
        let changedValidation = SessionNoteOutputValidator.validate(changedMeasurement, evidence: packet)
        try expect(
            changedValidation.issues.contains(where: { $0.contains("measurement type") || $0.contains("3") }),
            "trial data cannot silently become percentage data"
        )

        let inventedPrompt = valid.replacingOccurrences(of: "independently", with: "with a full physical prompt")
        let promptValidation = SessionNoteOutputValidator.validate(inventedPrompt, evidence: packet)
        try expect(
            promptValidation.issues.contains(where: { $0.contains("full physical") }),
            "an unsupplied prompt level is rejected"
        )

        let inferredFunction = valid.replacingOccurrences(
            of: "The client participated in the supplied activities.",
            with: "The function was escape-maintained."
        )
        try expect(
            SessionNoteOutputValidator.validate(inferredFunction, evidence: packet).issues.contains(where: { $0.contains("behavioral function") }),
            "an unsupplied behavioral function is rejected"
        )
    }

    private static func multiScreenshotEvidenceFixtures() throws {
        let packet = multiScreenshotEvidencePacket()
        let valid = validMultiScreenshotDraft()
        let validation = SessionNoteOutputValidator.validate(valid, evidence: packet)
        try expect(
            validation.isAcceptable,
            "a selected synthetic client with two OCR sources and supported ABA data validates: \(validation.issues)"
        )
        try expect(
            !packet.numericClaims.contains(where: { $0.value == "1" || $0.value == "2" }),
            "screenshot source ordinals never become clinical numeric evidence"
        )
        try expect(
            packet.numericClaims.contains(SessionNoteNumericClaim(value: "3", kind: .count)),
            "the supplied count keeps its measurement kind across screenshot boundaries"
        )
        try expect(
            packet.numericClaims.contains(SessionNoteNumericClaim(value: "80", kind: .percentage)),
            "the supplied percentage keeps its measurement kind across screenshot boundaries"
        )

        let inventedNumber = valid.replacingOccurrences(of: "3 occurrences", with: "2 occurrences")
        try expect(
            SessionNoteOutputValidator.validate(inventedNumber, evidence: packet).issues.contains(where: { $0.contains("2") }),
            "an attachment ordinal cannot authorize an unsupported numeric clinical claim"
        )

        let suppliedPrompt = SessionNoteOutputValidator.validate(valid, evidence: packet)
        try expect(suppliedPrompt.isAcceptable, "a supplied verbal prompt level remains allowed")
        let fabricatedPrompt = valid.replacingOccurrences(of: "a verbal prompt", with: "a full physical prompt")
        try expect(
            SessionNoteOutputValidator.validate(fabricatedPrompt, evidence: packet).issues.contains(where: { $0.contains("full physical") }),
            "a fabricated prompt level remains rejected in the multi-screenshot path"
        )
    }

    private static func savedContextIsNotEvidenceFixtures() throws {
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: "At home, SyCl practiced requesting a break with the RBT.",
            ocrEvidence: "SCREENSHOT 1:\n[TRIAL-BASED] Requesting a break 4/5 trials",
            savedTerminologyContext: "targets: Greeting Routine | behaviors: Property Destruction | communication: none | prompting/reinforcement: none",
            profileCode: "SyCl"
        )
        let unsupportedContextClaim = "At home, the client practiced requesting a break with the RBT in 4/5 trials. Property Destruction occurred during the activity.\n\nThe client participated in the supplied activity. The RBT will continue implementing the established treatment plan during future sessions."
        let validation = SessionNoteOutputValidator.validate(unsupportedContextClaim, evidence: packet)
        try expect(
            validation.issues.contains(where: { $0.contains("saved target or behavior") }),
            "a saved target or behavior remains terminology context and cannot prove session occurrence"
        )
    }

    private static func emptyEvidenceFixtures() throws {
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: "",
            ocrEvidence: "SCREENSHOT 1:\n[AMBIGUOUS OCR] No clear OCR text.\nSCREENSHOT 2:\n[AMBIGUOUS OCR] unreadable",
            savedTerminologyContext: "targets: Greeting Routine | behaviors: none",
            profileCode: "SyCl"
        )
        try expect(packet.typedFacts.isEmpty, "empty typed facts stay empty")
        try expect(packet.quantitativeOCR.isEmpty, "unreadable OCR and source ordinals do not become factual evidence")
        try expect(packet.numericClaims.isEmpty, "empty or unreadable evidence has no supported numeric claims")
    }

    private static func pipelineFixtures() async throws {
        let packet = evidencePacket()

        var normalStages: [SessionNotePipelineStage] = []
        let normal = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
            normalStages.append(stage)
            return validDraft()
        }
        try expect(normal == validDraft(), "normal success returns the validated draft")
        try expect(normalStages == [.standardDraft], "normal success uses one model request")

        let delayed = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
            try await Task.sleep(nanoseconds: 5_000_000)
            return validDraft()
        }
        try expect(delayed == validDraft(), "delayed success remains valid")

        var unavailablePropagated = false
        do {
            _ = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
                throw FixtureError.unavailable
            }
            throw FixtureError.repairFailed
        } catch FixtureError.unavailable {
            unavailablePropagated = true
        }
        try expect(unavailablePropagated, "unavailable model failure propagates safely")

        var emptyRequests = 0
        do {
            _ = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
                emptyRequests += 1
                return ""
            }
            throw FixtureError.repairFailed
        } catch SessionNotePipelineError.rejected {
            try expect(emptyRequests == 2, "empty response receives one bounded repair and then fails safely")
        }

        var repairStages: [SessionNotePipelineStage] = []
        let repaired = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
            repairStages.append(stage)
            switch stage {
            case .standardDraft:
                return "The client completed 999 trials."
            case .repair:
                return validDraft()
            case .compactDraft:
                throw FixtureError.repairFailed
            }
        }
        try expect(repaired == validDraft(), "unsafe first draft is replaced by one validated repair")
        try expect(repairStages.count == 2, "repair-required flow is bounded to two requests")

        var repairFailurePropagated = false
        do {
            _ = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
                if case .standardDraft = stage { return "The client completed 999 trials." }
                throw FixtureError.repairFailed
            }
            throw FixtureError.repairFailed
        } catch FixtureError.repairFailed {
            repairFailurePropagated = true
        }
        try expect(repairFailurePropagated, "bounded repair failure propagates without another loop")

        var persistentUnsupportedRejected = false
        var persistentUnsupportedRequests = 0
        do {
            _ = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
                persistentUnsupportedRequests += 1
                return "The client completed 999 trials. The client participated in the supplied activities. The RBT will continue implementing the established treatment plan during future sessions."
            }
            throw FixtureError.repairFailed
        } catch SessionNotePipelineError.rejected {
            persistentUnsupportedRejected = true
        }
        try expect(persistentUnsupportedRejected, "a genuinely unsupported claim remaining after repair reaches terminal rejection")
        try expect(persistentUnsupportedRequests == 2, "persistent unsupported content still receives only one bounded repair pass")

        var compactStages: [SessionNotePipelineStage] = []
        var compactEvents: [SessionNotePipelineEvent] = []
        let compactSuccess = try await SessionNoteGenerationPipeline.run(
            packet: packet,
            request: { stage in
                compactStages.append(stage)
                if stage == .standardDraft { throw SessionNotePipelineError.contextTooLarge }
                return validDraft()
            },
            progress: { compactEvents.append($0) }
        )
        try expect(compactSuccess == validDraft(), "context-too-large first request retries successfully")
        try expect(compactStages == [.standardDraft, .compactDraft], "context retry occurs exactly once")
        try expect(compactEvents == [.compacting], "context retry reports its bounded compaction state")

        var contextFailureRequests = 0
        do {
            _ = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
                contextFailureRequests += 1
                throw SessionNotePipelineError.contextTooLarge
            }
            throw FixtureError.repairFailed
        } catch SessionNotePipelineError.contextTooLarge {
            try expect(contextFailureRequests == 2, "two context failures stop after the compact retry")
        }

        let cancellationTask = Task {
            try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return validDraft()
            }
        }
        cancellationTask.cancel()
        do {
            _ = try await cancellationTask.value
            throw FixtureError.repairFailed
        } catch is CancellationError {
            assertionCount += 1
        }
    }

    private static func runtimeProtectionFixtures() async throws {
        let race = SessionNoteRequestRace(timeoutNanoseconds: 5_000_000)
        var timedOut = false
        do {
            _ = try await race.run {
                try await Task.sleep(nanoseconds: 250_000_000)
                return validDraft()
            }
        } catch is SessionNoteRequestRaceError {
            timedOut = true
        }
        try expect(timedOut, "timeout fixture reaches the safe terminal timeout")

        let firstRequestID = UUID()
        let secondRequestID = UUID()
        var ledger = SessionNoteDraftLedger(draft: "Reviewed previous draft")
        ledger.begin(requestID: firstRequestID, preserving: ledger.draft)
        ledger.finish(requestID: firstRequestID)
        try expect(ledger.draft == "Reviewed previous draft", "failed request preserves the previous generated draft")

        ledger.begin(requestID: firstRequestID, preserving: ledger.draft)
        ledger.begin(requestID: secondRequestID, preserving: ledger.draft)
        try expect(!ledger.accept("Stale replacement", for: firstRequestID), "stale request output is rejected")
        try expect(ledger.draft == "Reviewed previous draft", "stale request cannot overwrite the previous draft")
        try expect(ledger.accept(validDraft(), for: secondRequestID), "current request output remains acceptable")
    }

    private static func evidencePacket() -> SessionNoteEvidencePacket {
        SessionNoteEvidencePacket.make(
            typedFacts: "At home, JaHe worked with the rbt and lbs on fct. The client responded independently in 3/5 trials. The client's mother reported that the transition occurred.",
            ocrEvidence: "[TRIAL-BASED, INDEPENDENT/PROMPTED] FCT 3/5 trials",
            savedTerminologyContext: "targets: fct; transitions | prompting/reinforcement: verbal prompt",
            profileCode: "JaHe"
        )
    }

    private static func multiScreenshotEvidencePacket() -> SessionNoteEvidencePacket {
        SessionNoteEvidencePacket.make(
            typedFacts: "At home, SyCl worked with the RBT on Following Directions. The RBT recorded 3 occurrences of the supplied behavior of concern. The client completed Following Directions with 80% accuracy using a verbal prompt.",
            ocrEvidence: "SCREENSHOT 1:\n[FREQUENCY/COUNT] supplied behavior of concern 3 occurrences\n\nSCREENSHOT 2:\n[PERCENTAGE, INDEPENDENT/PROMPTED] Following Directions 80% accuracy; verbal prompt",
            savedTerminologyContext: "targets: Greeting Routine | behaviors: Waiting Behavior | communication: request a break | prompting/reinforcement: praise",
            profileCode: "SyCl"
        )
    }

    private static func validDraft() -> String {
        "At home, the client worked with the RBT and LBS on FCT. The client responded independently in 3/5 trials, and the client's mother reported that the transition occurred.\n\nThe client participated in the supplied activities. The RBT will continue implementing the established treatment plan during future sessions."
    }

    private static func validMultiScreenshotDraft() -> String {
        "At home, the client worked with the RBT on Following Directions. The RBT recorded 3 occurrences of the supplied behavior of concern during the opening activity. Following the transition to table work, the client completed Following Directions with 80% accuracy using a verbal prompt.\n\nThe client participated in the supplied activities. The RBT will continue implementing the established treatment plan during future sessions."
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        assertionCount += 1
        guard condition() else {
            throw NSError(
                domain: "SessionNoteContractFixtures",
                code: assertionCount,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
