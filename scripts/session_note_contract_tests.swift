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
        try severityClassificationFixtures()
        try semanticParaphraseFixtures()
        try await deterministicFormattingFixtures()
        try structuredOCRMeasurementFixtures()
        try multiScreenshotEvidenceFixtures()
        try savedContextIsNotEvidenceFixtures()
        try emptyEvidenceFixtures()
        try realisticSyntheticSessionFixtures()
        try await professionalReconstructionFixtures()
        try await professionalPresentationRegressionFixtures()
        try await pipelineFixtures()
        try await fallbackAndDiagnosticFixtures()
        try await runtimeProtectionFixtures()
        let existingAssertions = assertionCount
        try expect(existingAssertions == 162, "all original 162 assertions executed before added coverage")
        try instructionParityFixtures()
        try extractionStatusFixtures()
        try await inputBoundaryFixtures()
        try await outputBoundaryFixtures()
        try await boundaryDraftPreservationFixtures()
        try await proseFidelityFixtures()
        let donorAssertions = assertionCount
        try expect(donorAssertions == 472, "all 472 frozen donor assertions executed unchanged")
        try await finalProseAndClosingFixtures()
        print("Frozen donor assertions: \(donorAssertions); new final-prose assertions: \(assertionCount - donorAssertions).")
        print("Original assertions: \(existingAssertions); added assertions: \(assertionCount - existingAssertions).")
        precondition(
            assertionCount >= 162,
            "Session Note regression floor requires at least 162 assertions; found \(assertionCount)."
        )
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
        try expect(!(try packet.modelPrompt(compaction: .standard)).contains("JaHe"), "profile code never reaches the standard model prompt")
        try expect(!(try packet.modelPrompt(compaction: .compactRetry)).contains("JaHe"), "profile code never reaches the compact model prompt")
        try expect((try packet.modelPrompt(compaction: .compactRetry)).contains(packet.typedFacts), "compact retry preserves the normalized typed facts")

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

        let unknownName = "Jane Smith observed the client during play. The client participated in play."
        let unknownValidation = SessionNoteOutputValidator.validate(unknownName, evidence: packet)
        try expect(!unknownValidation.isAcceptable, "unknown likely personal names are rejected after sanitization")
        try expect(unknownValidation.hardBlockerCodes.contains("SN-IDENTITY-002"), "unknown personal names receive a privacy-safe hard-blocker code")
        let leakedCode = "SyCl worked with the RBT. The client participated in play."
        try expect(
            SessionNoteOutputValidator.validate(leakedCode, evidence: packet).hardBlockerCodes.contains("SN-IDENTITY-003"),
            "a synthetic client-code shape that survives sanitization remains hard-blocked"
        )
        let novelTitleCase = "Novel Person was referenced during play. The client participated in play."
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
            inventedValidation.issueCodes.contains("SN-EVIDENCE-001"),
            "a newly invented numeric value is rejected"
        )

        let countPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT recorded 3 occurrences of the supplied behavior of concern.",
            ocrEvidence: "[FREQUENCY/COUNT] supplied behavior of concern 3 occurrences",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let changedMeasurement = "The RBT recorded 3% accuracy for the supplied behavior of concern. The client participated in the session."
        let changedValidation = SessionNoteOutputValidator.validate(changedMeasurement, evidence: countPacket)
        try expect(
            changedValidation.issueCodes.contains("SN-EVIDENCE-002"),
            "trial data cannot silently become percentage data"
        )

        let inventedPrompt = valid.replacingOccurrences(of: "independently", with: "with a full physical prompt")
        let promptValidation = SessionNoteOutputValidator.validate(inventedPrompt, evidence: packet)
        try expect(
            promptValidation.issueCodes.contains("SN-EVIDENCE-003"),
            "an unsupplied prompt level is rejected"
        )

        let inferredFunction = valid + " The function was escape-maintained."
        try expect(
            SessionNoteOutputValidator.validate(inferredFunction, evidence: packet).issueCodes.contains("SN-CLINICAL-001"),
            "an unsupplied behavioral function is rejected"
        )
    }

    private static func severityClassificationFixtures() throws {
        let packet = evidencePacket()
        let styleOnly = "The client worked with the RBT during the supplied activity"
        let styleValidation = SessionNoteOutputValidator.validate(styleOnly, evidence: packet)
        try expect(styleValidation.hardBlockers.isEmpty, "format-only issues are not hard blockers")
        try expect(
            !styleValidation.issueCodes.contains("SN-FORMAT-005"),
            "a missing future-plan close is not a formatting defect"
        )
        try expect(
            styleValidation.repairableIssues.contains(where: { $0.code == "SN-FORMAT-008" }),
            "missing final punctuation is deterministically repairable"
        )

        let repetitive = "The client entered the home. The client greeted the RBT. The client joined the activity. The client completed the activity. The client left the table."
        let repetitionValidation = SessionNoteOutputValidator.validate(repetitive, evidence: packet)
        try expect(repetitionValidation.isSafe, "repetitive sentence openings remain nonfatal")
        try expect(
            repetitionValidation.warnings.contains(where: { $0.code == "SN-QUALITY-003" }),
            "repetitive sentence openings are represented as a quality warning"
        )

        let invented = SessionNoteOutputValidator.validate(
            "The client completed 999 trials.",
            evidence: packet
        )
        try expect(
            invented.hardBlockers.contains(where: {
                $0.code == "SN-EVIDENCE-001" && $0.severity == .hardBlocker && $0.repairability == .boundedModel
            }),
            "unsupported numeric evidence remains a model-repairable hard blocker"
        )
        try expect(
            invented.issueCodes.allSatisfy { !$0.contains("999") },
            "privacy-safe diagnostic codes contain no claim values"
        )
    }

    private static func semanticParaphraseFixtures() throws {
        let reinforcementPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT redirected the client to work, and the client earned outside time.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let naturalParaphrase = "The client required redirection to return to work and later accessed outside play as reinforcement. "
        try expect(
            SessionNoteOutputValidator.validate(naturalParaphrase, evidence: reinforcementPacket).isSafe,
            "observable redirection and reinforcement-access paraphrases pass when supplied"
        )

        let supervisorPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The LBS instructed the RBT on skill-acquisition targets.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: skill-acquisition targets | behaviors: none",
            profileCode: "SyCl"
        )
        let supervisorParaphrase = "The LBS provided guidance to the RBT regarding the supplied skill-acquisition targets. "
        try expect(
            SessionNoteOutputValidator.validate(supervisorParaphrase, evidence: supervisorPacket).isSafe,
            "supervisor instruction and guidance are treated as the same narrow semantic category"
        )

        let observableReinforcement = "The client accessed outside time following work. "
        try expect(
            SessionNoteOutputValidator.validate(observableReinforcement, evidence: reinforcementPacket).isSafe,
            "observable reinforcement access is allowed"
        )
        let effectivenessClaim = observableReinforcement.replacingOccurrences(
            of: "The client accessed outside time following work.",
            with: "Reinforcement was effective."
        )
        try expect(
            SessionNoteOutputValidator.validate(effectivenessClaim, evidence: reinforcementPacket).hardBlockerCodes.contains("SN-CLINICAL-007"),
            "an unsupported reinforcement-effectiveness conclusion remains blocked"
        )
    }

    private static func deterministicFormattingFixtures() async throws {
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: "At home, the client worked with the RBT. The client transitioned to table work and later accessed outside time.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )

        var missingCloseStages: [SessionNotePipelineStage] = []
        let missingClose = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
            missingCloseStages.append(stage)
            return "At home, the client worked with the RBT. The client transitioned to table work and later accessed outside time."
        }
        try expect(
            !missingClose.contains("treatment plan"),
            "a faithful draft receives no unsupported continuation close"
        )
        try expect(missingCloseStages == [.standardDraft], "a missing exact close does not invoke model repair")

        var paraphrasedCloseStages: [SessionNotePipelineStage] = []
        let normalizedClose = try await SessionNoteGenerationPipeline.run(packet: boundaryPacket(packet.typedFacts + " The RBT will continue the treatment plan in future sessions.")) { stage in
            paraphrasedCloseStages.append(stage)
            return "At home, the client worked with the RBT. The client accessed outside time. The RBT will continue the treatment plan in future sessions."
        }
        try expect(
            normalizedClose.hasSuffix("The RBT will continue the treatment plan in future sessions."),
            "an explicitly supplied plan retains its wording without a manufactured canonical close"
        )
        try expect(paraphrasedCloseStages == [.standardDraft], "close normalization uses no AI retry")

        let longSafeParagraph = [
            "At home, the client worked with the RBT during pairing and functional communication activities while the caregiver remained present and observed the supplied routine.",
            "The client transitioned from play to the table after the RBT provided the supplied redirection and then participated in the documented table-work activity.",
            "The client returned to the play area, completed the supplied waiting activity, and accessed outside time after finishing the documented work.",
            "The client later transitioned indoors with the RBT and participated in the final supplied activity while the caregiver remained present.",
            "The client completed the documented session sequence with the RBT and caregiver present throughout the home-session activities."
        ].joined(separator: " ")
        let longPacket = SessionNoteEvidencePacket.make(
            typedFacts: longSafeParagraph,
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        var longStages: [SessionNotePipelineStage] = []
        let reflowed = try await SessionNoteGenerationPipeline.run(packet: longPacket) { stage in
            longStages.append(stage)
            return longSafeParagraph
        }
        try expect(reflowed.contains("\n\n"), "one oversized safe paragraph is reflowed deterministically")
        try expect(longStages == [.standardDraft], "paragraph reflow does not invoke model repair")

        var markdownStages: [SessionNotePipelineStage] = []
        let markdown = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
            markdownStages.append(stage)
            return "## Session Note\n- At home, the client worked with the RBT.\n- The client accessed outside time."
        }
        try expect(!markdown.contains("#") && !markdown.contains("- At"), "headings and Markdown lists are stripped")
        try expect(markdownStages == [.standardDraft], "Markdown cleanup does not invoke model repair")

        let genericRolePacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT worked with the client during the supplied activity.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let genericValidation = SessionNoteOutputValidator.validate(
            "The clinician worked with the client during the supplied activity.",
            evidence: genericRolePacket
        )
        let genericRepair = SessionNoteDeterministicRepairer.repair(
            genericValidation.draft,
            validation: genericValidation,
            evidence: genericRolePacket
        )
        try expect(genericRepair.draft.contains("the RBT"), "an unambiguous generic role is normalized deterministically")
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
            SessionNoteOutputValidator.validate(inventedNumber, evidence: packet).issueCodes.contains("SN-EVIDENCE-001"),
            "an attachment ordinal cannot authorize an unsupported numeric clinical claim"
        )

        let suppliedPrompt = SessionNoteOutputValidator.validate(valid, evidence: packet)
        try expect(suppliedPrompt.isAcceptable, "a supplied verbal prompt level remains allowed")
        let fabricatedPrompt = valid.replacingOccurrences(of: "a verbal prompt", with: "a full physical prompt")
        try expect(
            SessionNoteOutputValidator.validate(fabricatedPrompt, evidence: packet).issueCodes.contains("SN-EVIDENCE-003"),
            "a fabricated prompt level remains rejected in the multi-screenshot path"
        )

        let mixedPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT recorded 3 occurrences of a supplied behavior of concern. Following Directions was completed with 80% accuracy. Requesting Break occurred in 4/5 trials using a verbal prompt. Waiting lasted 6 minutes with a gestural prompt.",
            ocrEvidence: "SCREENSHOT 1:\n[FREQUENCY/COUNT] behavior of concern 3 occurrences\n\nSCREENSHOT 2:\n[PERCENTAGE] Following Directions 80% accuracy\n\nSCREENSHOT 3:\n[TRIAL-BASED, INDEPENDENT/PROMPTED] Requesting Break 4/5 trials; verbal prompt\n\nSCREENSHOT 4:\n[DURATION, INDEPENDENT/PROMPTED] Waiting duration 6 minutes; gestural prompt",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let mixedDraft = "The RBT recorded 3 occurrences of the supplied behavior of concern. The client completed Following Directions with 80% accuracy. The client completed Requesting Break in 4/5 trials using a verbal prompt, and Waiting lasted 6 minutes with a gestural prompt."
        let mixedValidation = SessionNoteOutputValidator.validate(mixedDraft, evidence: mixedPacket)
        try expect(mixedValidation.isSafe, "mixed count, percentage, trial, duration, and prompt data validate together: \(mixedValidation.issueCodes)")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "3", kind: .count)), "mixed OCR retains count typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "80", kind: .percentage)), "mixed OCR retains percentage typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "4/5", kind: .trials)), "mixed OCR retains trial-ratio typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "6", kind: .duration)), "mixed OCR retains duration typing")
        try expect(mixedPacket.promptLevels.contains("verbal") && mixedPacket.promptLevels.contains("gestural"), "mixed OCR retains supplied prompting")
    }

    private static func structuredOCRMeasurementFixtures() throws {
        let legacyPhysicalPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The client practiced Following Directions with the RBT.",
            ocrEvidence: "[AMBIGUOUS OCR] Following Directions\n[PERCENTAGE] 80%",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        try expect(
            legacyPhysicalPacket.quantitativeOCR.contains("Following Directions") &&
            legacyPhysicalPacket.quantitativeOCR.contains("80%"),
            "the legacy split-line physical OCR shape retains its target/value association"
        )

        let measurements = SessionNoteOCRMeasurementExtractor.extract(from: [
            """
            Skill Acquisition Data
            Following Directions
            80%
            Requesting Break
            4/5 trials with a verbal prompt
            Waiting
            6 minutes
            Behavior Data
            Aggression
            3 occurrences
            Greeting Response
            5 seconds latency
            Mand Requests
            2 per minute
            Session Date
            08/29/2026
            Start Time
            9:00 AM
            Provider ID
            12345
            """
        ])

        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Following Directions",
                value: "80%",
                kind: .percentage,
                promptLevels: [],
                sourceOrdinal: 1
            )),
            "a target label on the line before a percentage remains associated with that percentage"
        )
        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Requesting Break",
                value: "4/5 trials",
                kind: .trials,
                promptLevels: ["verbal"],
                sourceOrdinal: 1
            )),
            "trial data and its prompt level remain associated with the preceding target label"
        )
        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Waiting",
                value: "6 minutes",
                kind: .duration,
                promptLevels: [],
                sourceOrdinal: 1
            )),
            "duration data remains associated with the preceding target label"
        )
        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Aggression",
                value: "3 occurrences",
                kind: .count,
                promptLevels: [],
                sourceOrdinal: 1
            )),
            "frequency data remains associated with the preceding behavior label"
        )
        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Greeting Response",
                value: "5 seconds",
                kind: .latency,
                promptLevels: [],
                sourceOrdinal: 1
            )),
            "latency data remains associated with the preceding target label"
        )
        try expect(
            measurements.contains(SessionNoteMeasurementEvidence(
                target: "Mand Requests",
                value: "2 per minute",
                kind: .rate,
                promptLevels: [],
                sourceOrdinal: 1
            )),
            "rate data remains associated with the preceding target label"
        )
        try expect(
            measurements.allSatisfy {
                !$0.target.localizedCaseInsensitiveContains("session date") &&
                !$0.target.localizedCaseInsensitiveContains("start time") &&
                !$0.target.localizedCaseInsensitiveContains("provider") &&
                !$0.value.contains("08/29/2026") &&
                !$0.value.contains("9:00") &&
                !$0.value.contains("12345")
            },
            "administrative dates, times, and provider identifiers never become clinical measurements"
        )
    }

    private static func savedContextIsNotEvidenceFixtures() throws {
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: "At home, SyCl practiced requesting a break with the RBT.",
            ocrEvidence: "SCREENSHOT 1:\n[TRIAL-BASED] Requesting a break 4/5 trials",
            savedTerminologyContext: "targets: Greeting Routine | behaviors: Property Destruction | communication: none | prompting/reinforcement: none",
            profileCode: "SyCl"
        )
        let unsupportedContextClaim = "At home, the client practiced requesting a break with the RBT in 4/5 trials. Property Destruction occurred during the activity."
        let validation = SessionNoteOutputValidator.validate(unsupportedContextClaim, evidence: packet)
        try expect(
            validation.issueCodes.contains("SN-EVIDENCE-005"),
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

    private static func realisticSyntheticSessionFixtures() throws {
        let contextPacket = SessionNoteEvidencePacket.make(
            typedFacts: "At home, the client practiced Functional Communication and Waiting Program with the RBT. The caregiver was present.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: Greeting Routine | behaviors: Property Destruction",
            profileCode: "SyCl"
        )
        let contextTarget = "The client completed Greeting Routine with the RBT. The client participated in the session."
        let contextBehavior = "Property Destruction occurred during work. The client participated in the session."
        try expect(
            SessionNoteOutputValidator.validate(contextTarget, evidence: contextPacket).hardBlockerCodes.contains("SN-EVIDENCE-005"),
            "a context-only target cannot become a current-session event"
        )
        try expect(
            SessionNoteOutputValidator.validate(contextBehavior, evidence: contextPacket).hardBlockerCodes.contains("SN-EVIDENCE-005"),
            "a context-only behavior cannot become a current-session occurrence"
        )

        let internalState = "The client was frustrated during work. The client participated in the session."
        try expect(
            SessionNoteOutputValidator.validate(internalState, evidence: contextPacket).hardBlockerCodes.contains("SN-CLINICAL-002"),
            "an unsupported internal state remains hard-blocked"
        )
        let unsupportedSupervisor = "The BCBA observed the client during work. The client participated in the session."
        try expect(
            SessionNoteOutputValidator.validate(unsupportedSupervisor, evidence: contextPacket).hardBlockerCodes.contains("SN-CLINICAL-008"),
            "invented supervisor involvement remains hard-blocked"
        )
        let unsupportedTreatmentChange = "The LBS updated the treatment plan during the session. The client participated in the session."
        try expect(
            SessionNoteOutputValidator.validate(unsupportedTreatmentChange, evidence: contextPacket).hardBlockerCodes.contains("SN-CLINICAL-005"),
            "an unsupported treatment modification remains hard-blocked"
        )

        let suppliedLabels = [
            "Following Directions", "Functional Communication", "Choice Board", "Visual Schedule",
            "Waiting Program", "Requesting Break", "Tolerating Denied Access",
        ]
        for label in suppliedLabels {
            let packet = SessionNoteEvidencePacket.make(
                typedFacts: "The client practiced \(label) with the RBT.",
                ocrEvidence: "",
                savedTerminologyContext: "targets: none | behaviors: none",
                profileCode: "SyCl"
            )
            let draft = "The client practiced \(label) with the RBT. "
            try expect(
                !SessionNoteOutputValidator.validate(draft, evidence: packet).hardBlockerCodes.contains("SN-IDENTITY-002"),
                "supplied clinical label \(label) is not mistaken for a personal name"
            )
        }

        let cases: [(String, String, String)] = [
            (
                "At home, the caregiver was present while the RBT paired with the client. The client used full-sentence manding during FCT, waited, transitioned to table work after redirection, and earned outdoor play.",
                "During the home session, the caregiver remained present while the RBT paired with the client. The client used a full sentence to mand during FCT, waited during the supplied activity, returned to table work after redirection, and later accessed outdoor play.",
                "home pairing, FCT, transitions, redirection, and outdoor reinforcement paraphrase"
            ),
            (
                "The client engaged in the supplied behavior of concern during a transition. The RBT redirected the client, and the client returned to work. The LBS instructed the RBT on skill-acquisition targets.",
                "A behavior of concern occurred during the transition. After the RBT redirected the client, the client resumed work. The LBS provided guidance to the RBT regarding the supplied skill-acquisition targets.",
                "behavior occurrence and supervisor-guidance paraphrase"
            ),
            (
                "The caregiver was present. The client completed table work with the RBT, transitioned outside, and accessed outside time after work.",
                "With the caregiver present, the client completed table work with the RBT and then transitioned outdoors. The client accessed outside time after completing the supplied work.",
                "caregiver, work, transition, and reinforcement-access paraphrase"
            ),
        ]
        for (typedFacts, draft, description) in cases {
            let packet = SessionNoteEvidencePacket.make(
                typedFacts: typedFacts,
                ocrEvidence: "",
                savedTerminologyContext: "targets: none | behaviors: none",
                profileCode: "SyCl"
            )
            let validation = SessionNoteOutputValidator.validate(draft, evidence: packet)
            try expect(validation.isSafe, "realistic synthetic \(description) remains safe: \(validation.issueCodes)")
        }
    }

    private static func professionalReconstructionFixtures() async throws {
        let roughFacts = "home session client's mother there. started with play. rbt ran following directions then requesting break after transition. aggression happened and rbt redirected client back to work. client finished work and got outside time."
        let measurements = SessionNoteOCRMeasurementExtractor.extract(from: [
            """
            Following Directions
            80%
            Requesting Break
            4/5 trials with a verbal prompt
            Aggression
            3 occurrences
            Session Date
            08/29/2026
            """
        ])
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: roughFacts,
            ocrEvidence: "",
            structuredMeasurements: measurements,
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let standardPrompt = (try packet.modelPrompt(compaction: .standard))
        let compactPrompt = (try packet.modelPrompt(compaction: .compactRetry))
        try expect(
            standardPrompt.contains("RAW FACTUAL SOURCE MATERIAL") && standardPrompt.contains("reconstruct"),
            "the normal prompt treats rough typed facts as facts to reconstruct rather than prose to preserve"
        )
        try expect(
            standardPrompt.contains("PROFESSIONAL RECONSTRUCTION REQUIREMENTS") &&
            standardPrompt.contains("Do not copy conversational transitions or preserve the source clause structure") &&
            standardPrompt.contains("generic work only as instructional activities or a work period"),
            "the evidence prompt gives the on-device model concrete anti-copy reconstruction rules"
        )
        try expect(
            standardPrompt.contains("Target: Following Directions | Type: percentage | Value: 80%") &&
            standardPrompt.contains("Target: Requesting Break | Type: trials | Value: 4/5 trials | Prompting: verbal") &&
            standardPrompt.contains("Target: Aggression | Type: count | Value: 3 occurrences"),
            "the prompt presents clear measurements as explicit target/type/value associations"
        )
        try expect(
            standardPrompt.components(separatedBy: "Target: Following Directions | Type: percentage | Value: 80%").count == 2,
            "each structured measurement appears once in the model prompt"
        )
        try expect(
            compactPrompt.contains("Target: Following Directions | Type: percentage | Value: 80%") &&
            !compactPrompt.contains("08/29/2026"),
            "the bounded compact retry preserves structured clinical measurements and excludes administrative OCR"
        )

        let professionalDraft = """
        During the home session, the client's mother was present while the RBT began with play-based activities. The client then transitioned to skill-acquisition work, completing Following Directions with 80% accuracy and Requesting Break in 4/5 trials with a verbal prompt.

        The client engaged in Aggression 3 times during work. Following redirection from the RBT, the client returned to the activity, completed the supplied work, and accessed outside time.
        """
        let validation = SessionNoteOutputValidator.validate(professionalDraft, evidence: packet)
        try expect(
            validation.isSafe,
            "a substantially reconstructed professional note with exact target/value/type associations remains safe: \(validation.issueCodes)"
        )

        let omittedMeasurement = professionalDraft.replacingOccurrences(
            of: " and Requesting Break in 4/5 trials with a verbal prompt",
            with: ""
        )
        let omittedValidation = SessionNoteOutputValidator.validate(omittedMeasurement, evidence: packet)
        try expect(
            omittedValidation.hardBlockerCodes.contains("SN-EVIDENCE-006"),
            "omitting a clear structured screenshot measurement triggers the existing bounded repair path"
        )
        let omittedDiagnostics = SessionNoteCandidateDiagnostics.make(
            pass: .initial,
            rawDraft: omittedMeasurement,
            normalizedDraft: omittedMeasurement,
            validation: omittedValidation,
            evidence: packet
        )
        try expect(
            omittedDiagnostics.structuredMeasurementCount == 3 &&
            omittedDiagnostics.missingStructuredMeasurementCount == 1,
            "candidate diagnostics distinguish supplied and missing structured measurements"
        )
        try expect(
            SessionNoteDiagnosticReceipt(events: [.candidateAssessment(omittedDiagnostics)])
                .shareableText.contains("missingMeasurements=1") &&
            !SessionNoteDiagnosticReceipt(events: [.candidateAssessment(omittedDiagnostics)])
                .shareableText.contains("Requesting Break"),
            "structured-measurement rejection diagnostics expose counts and codes without target text"
        )

        var stages: [SessionNotePipelineStage] = []
        let generated = try await SessionNoteGenerationPipeline.generate(packet: packet) { stage in
            stages.append(stage)
            return professionalDraft
        }
        try expect(generated.draft == professionalDraft, "the physical before/after quality case returns professional reconstructed prose")
        try expect(generated.outcome == .generated, "a professional first-pass rewrite retains generated provenance")
        try expect(stages == [.standardDraft], "a complete professional draft uses no additional AI retry")
        try expect(
            generated.diagnostics.events.contains(where: {
                guard case .candidateAssessment(let details) = $0 else { return false }
                return details.pass == .initial && details.isProfessionallyReady
            }),
            "professional first-pass success records a ready initial candidate assessment"
        )
        try expect(
            !generated.diagnostics.events.contains(where: {
                if case .repairAttempted = $0 { return true }
                return false
            }) && generated.diagnostics.shareableText.contains("final=generated"),
            "professional first-pass success records final provenance without a repair attempt"
        )

        var fallbackRequests = 0
        var fallbackCategory: SessionNoteFailureCategory?
        do {
            _ = try await SessionNoteGenerationPipeline.generate(packet: packet) { _ in
                fallbackRequests += 1
                return "The client completed 999 trials and was frustrated."
            }
            throw FixtureError.repairFailed
        } catch SessionNotePipelineError.rejected(let category) {
            fallbackCategory = category
        }
        try expect(fallbackRequests == 2, "structured-measurement failures remain bounded to one model repair")
        try expect(fallbackCategory == .evidenceVerification, "structured measurements fail closed rather than being silently dropped from fallback")
    }

    private static func fallbackAndDiagnosticFixtures() async throws {
        let packet = evidencePacket()
        var stages: [SessionNotePipelineStage] = []
        var diagnostics: [SessionNotePipelineDiagnosticEvent] = []
        let fallback = try await SessionNoteGenerationPipeline.generate(
            packet: packet,
            request: { stage in
                stages.append(stage)
                return "The client completed 999 trials. The client was frustrated."
            },
            diagnostic: { diagnostics.append($0) }
        )
        try expect(stages.count == 2, "an unsafe repaired draft receives no second model repair")
        try expect(fallback.outcome == .fallback, "conservative source preservation returns explicit fallback provenance")
        try expect(!fallback.outcome.isProfessionallyReady, "fallback provenance never qualifies as a professionally ready draft")
        try expect(
            fallback.outcome.userFacingStatusTitle == "Professional rewrite could not be completed" &&
            fallback.outcome.userFacingStatusTitle != "Draft ready",
            "fallback UI status cannot report ordinary success"
        )
        try expect(!fallback.draft.contains("999") && !fallback.draft.lowercased().contains("frustrated"), "fallback excludes unsupported model claims")
        try expect(fallback.draft.contains("3/5 trials"), "fallback preserves supported typed quantitative evidence")
        try expect(!fallback.draft.contains("treatment plan"), "fallback does not manufacture a future plan")
        try expect(diagnostics.contains(.fallback(.succeeded)), "fallback success is recorded with a privacy-safe diagnostic")
        try expect(diagnostics.contains(.finalOutcome(.fallback)), "fallback is recorded as the final outcome")
        try expect(
            diagnostics.map(\.privacySafeDescription).allSatisfy { !$0.contains("999") && !$0.contains("JaHe") },
            "diagnostic events contain codes and outcomes rather than clinical content or identifiers"
        )

        let insufficientPacket = SessionNoteEvidencePacket.make(
            typedFacts: "",
            ocrEvidence: "SCREENSHOT 1:\n[FREQUENCY/COUNT] supplied behavior 3 occurrences",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        var terminalRequests = 0
        var terminalDiagnostics: [SessionNotePipelineDiagnosticEvent] = []
        var terminalCategory: SessionNoteFailureCategory?
        do {
            _ = try await SessionNoteGenerationPipeline.run(
                packet: insufficientPacket,
                request: { _ in
                    terminalRequests += 1
                    return "The client completed 999 trials."
                },
                diagnostic: { terminalDiagnostics.append($0) }
            )
            throw FixtureError.repairFailed
        } catch SessionNotePipelineError.rejected(let category) {
            terminalCategory = category
        }
        try expect(terminalRequests == 2, "fallback-impossible flow still performs at most one model repair")
        try expect(terminalCategory == .evidenceVerification, "terminal rejection reports a safe evidence category")
        try expect(terminalDiagnostics.contains(.fallback(.insufficientEvidence)), "insufficient fallback evidence is diagnosed safely")
        try expect(terminalDiagnostics.contains(.finalOutcome(.rejected)), "terminal rejection is recorded without note content")
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
        let emptyFallback = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
            emptyRequests += 1
            return ""
        }
        try expect(emptyRequests == 2, "empty output receives only one bounded repair request")
        try expect(emptyFallback.contains("3/5 trials"), "empty repaired output falls back to supported typed facts")

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

        var persistentUnsupportedRequests = 0
        let persistentFallback = try await SessionNoteGenerationPipeline.run(packet: packet) { _ in
            persistentUnsupportedRequests += 1
            return "The client completed 999 trials. "
        }
        try expect(!persistentFallback.contains("999"), "a persistent hard blocker is excluded by conservative fallback")
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

    private static func professionalPresentationRegressionFixtures() async throws {
        let physicalFacts = """
        RBT met at clients home. Present: RBT, LBS, grandma, mom, dad, brother, brother BHT. RBT began with pairing outside and working on FCT and full sentence manding and more time manding. Then transitioned client inside for work, had him wait, then back outside for more play. LBS and RBT then transitioned client inside and did work, then indoor cooperative play, then more work at which point client engaged in elopement and took many redirections to attend to the work. After this client earned his preferred outside time. LBS also instructed RBT on skill acquisition targets including new programs implemented.
        """
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: physicalFacts,
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let nearCopy = """
        RBT met at client's home. Present were RBT, LBS, grandma, mom, dad, brother, and brother BHT. RBT began with pairing outside and working on FCT and full sentence manding and more time manding. Then transitioned client inside for work, had him wait, then back outside for more play.

        LBS and RBT then transitioned client inside and did work, then indoor cooperative play, then more work at which point client engaged in elopement and took many redirections to attend to the work. After this client earned his preferred outside time. LBS also instructed RBT on skill acquisition targets, including new programs implemented.
        """

        let validation = SessionNoteOutputValidator.validate(nearCopy, evidence: packet)
        try expect(validation.isSafe, "the physical near-copy remains evidence-safe rather than becoming a fabrication blocker")
        try expect(
            validation.repairableIssues.contains(where: { $0.code == "SN-QUALITY-004" }),
            "the physical near-copy is presentation-repairable and cannot qualify as professionally ready"
        )

        let fragmentDraft = """
        The RBT met with the client in the client's home while family members and the LBS were present. The session began with outdoor pairing and FCT targets. The RBT then did work with the client, had him wait, and returned outdoors for play.

        During a later instructional period, the client engaged in elopement and took many redirections to attend to the work before earning preferred outdoor time. The LBS instructed the RBT regarding skill-acquisition targets and newly implemented programs.
        """
        let fragmentValidation = SessionNoteOutputValidator.validate(fragmentDraft, evidence: packet)
        try expect(fragmentValidation.isSafe, "rough dictation fragments remain presentation defects rather than clinical blockers")
        try expect(
            fragmentValidation.repairableIssues.contains(where: { $0.code == "SN-QUALITY-005" }),
            "obvious rough dictation fragments require the bounded professional reconstruction pass"
        )

        var stages: [SessionNotePipelineStage] = []
        let result = try await SessionNoteGenerationPipeline.generate(packet: packet) { stage in
            stages.append(stage)
            switch stage {
            case .standardDraft:
                return nearCopy
            case .repair:
                return "The RBT met with the client in the client's home. The RBT began with pairing outdoors and targeted FCT through full-sentence manding and requests for additional time. The RBT then transitioned the client indoors for instructional activities and targeted waiting before returning outdoors for additional play.\n\nDuring a later instructional period, the client engaged in elopement and required multiple redirections to return to the task before earning preferred outdoor time. The LBS also instructed the RBT regarding skill-acquisition targets, including newly implemented programs. "
            case .compactDraft:
                throw FixtureError.repairFailed
            }
        }
        let repairInstructions: [String]
        if stages.count == 2, stages.first == .standardDraft,
           case .repair(let instructions) = stages.last {
            repairInstructions = instructions
        } else {
            repairInstructions = []
        }
        try expect(stages.count == 2, "the physical near-copy receives exactly one bounded professional reconstruction pass")
        try expect(
            repairInstructions.contains(where: { $0.contains("Reconstruct the note from the original evidence") }),
            "the bounded pass receives the professional reconstruction issue rather than only safety blockers"
        )
        try expect(result.outcome == .repaired, "the successful bounded reconstruction retains repaired provenance")

        var degradedStages: [SessionNotePipelineStage] = []
        var degradedDiagnostics: [SessionNotePipelineDiagnosticEvent] = []
        let degraded = try await SessionNoteGenerationPipeline.generate(
            packet: packet,
            request: { stage in
                degradedStages.append(stage)
                return nearCopy
            },
            diagnostic: { degradedDiagnostics.append($0) }
        )
        try expect(degradedStages.count == 2, "a still-poor repair stops after the single bounded reconstruction pass")
        try expect(degraded.outcome == .fallback, "a still-poor safe repair becomes explicit degraded fallback provenance")
        try expect(!degraded.outcome.isProfessionallyReady, "a still-poor repair cannot become ordinary Draft ready")
        let candidateDiagnostics = degradedDiagnostics.compactMap { event -> SessionNoteCandidateDiagnostics? in
            guard case .candidateAssessment(let diagnostics) = event else { return nil }
            return diagnostics
        }
        try expect(
            candidateDiagnostics.map(\.pass) == [.initial, .repair],
            "diagnostics distinguish the initial and bounded-repair model candidates"
        )
        try expect(
            candidateDiagnostics.allSatisfy {
                $0.rawCharacterCount > 0 && $0.normalizedCharacterCount > 0 &&
                $0.wordCount > 0 && $0.sentenceCount > 0 && $0.paragraphCount > 0
            },
            "candidate diagnostics record structural metrics without retaining prose"
        )
        try expect(
            candidateDiagnostics.allSatisfy {
                $0.sourceOverlapBasisPoints >= 4_500 &&
                $0.roughFragmentMatchCount > 0 &&
                $0.issueCodes.contains("SN-QUALITY-004") &&
                $0.issueCodes.contains("SN-QUALITY-005") &&
                !$0.isProfessionallyReady
            },
            "near-copy diagnostics preserve the exact professional-quality reasons for both passes"
        )
        try expect(
            degradedDiagnostics.contains(.repairAttempted(["SN-QUALITY-004", "SN-QUALITY-005"])),
            "diagnostics explicitly record the single bounded repair attempt and its reason codes"
        )
        try expect(
            degraded.diagnostics.events == degradedDiagnostics,
            "the returned result preserves the complete diagnostic provenance that produced the visible fallback"
        )
        try expect(
            degraded.diagnostics.shareableText.contains("SN-DIAG-1") &&
            degraded.diagnostics.shareableText.contains("pass=initial") &&
            degraded.diagnostics.shareableText.contains("pass=repair") &&
            degraded.diagnostics.shareableText.contains("final=fallback") &&
            !degraded.diagnostics.shareableText.contains("grandma") &&
            !degraded.diagnostics.shareableText.contains("elopement") &&
            !degraded.diagnostics.shareableText.contains("SyCl"),
            "the shareable diagnostic receipt contains metrics, reason codes, and final provenance but no narrative or identifiers"
        )

        let shortPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT paired with the client outdoors.",
            ocrEvidence: "",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: nil
        )
        let shortDraft = "The RBT paired with the client outdoors."
        try expect(
            SessionNoteOutputValidator.validate(shortDraft, evidence: shortPacket).isProfessionallyReady,
            "short factual input is not penalized when there is little legitimate paraphrasing opportunity"
        )

        let physicalMeasurements = SessionNoteOCRMeasurementExtractor.extract(from: [
            """
            Full-Sentence Manding
            80%
            Waiting
            4/5 trials with a verbal prompt
            Session Date
            08/29/2026
            Provider ID
            12345
            """
        ])
        let measuredPacket = SessionNoteEvidencePacket.make(
            typedFacts: physicalFacts,
            ocrEvidence: "",
            structuredMeasurements: physicalMeasurements,
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let physicalDraft = """
        The RBT met with the client in the client's home. Present during the session were the RBT, LBS, grandmother, mother, father, brother, and the brother's BHT. The session began with pairing outdoors while the RBT targeted FCT through Full Sentence Manding at 80% accuracy and requests for additional time. The RBT then transitioned the client indoors for instructional activities, targeted Waiting in 4/5 trials with a verbal prompt, and transitioned the client back outdoors for additional play and reinforcement.

        The LBS and RBT later transitioned the client indoors for additional instructional activities, followed by cooperative play and another instructional period. During the later work period, the client engaged in elopement and required multiple redirections to return to and attend to the task. Following re-engagement, the client earned preferred outdoor time. The LBS also provided instruction to the RBT regarding skill-acquisition targets, including newly implemented programs.


        """
        let physicalValidation = SessionNoteOutputValidator.validate(physicalDraft, evidence: measuredPacket)
        try expect(physicalValidation.isProfessionallyReady, "the complete physical-input synthetic professional rewrite passes safety and presentation gates: \(physicalValidation.issueCodes)")
        let physicalLower = physicalDraft.lowercased()
        try expect(
            physicalLower.contains("client's home") && physicalLower.contains("grandmother") && physicalLower.contains("brother's bht"),
            "the professional rewrite retains the supplied location and people present"
        )
        try expect(
            physicalLower.contains("pairing outdoors") && physicalLower.contains("fct") &&
            physicalLower.contains("full sentence manding") && physicalLower.contains("requests for additional time"),
            "pairing, FCT, full-sentence manding, and more-time manding remain represented"
        )
        try expect(physicalLower.contains("waiting in 4/5 trials with a verbal prompt"), "waiting keeps its exact screenshot prompt association")
        try expect(physicalLower.contains("cooperative play"), "indoor cooperative play remains represented")
        try expect(
            physicalLower.contains("elopement") && physicalLower.contains("multiple redirections") &&
            physicalLower.contains("return to and attend to the task"),
            "elopement, intervention, and observable re-engagement remain objective and complete"
        )
        try expect(physicalLower.contains("earned preferred outdoor time"), "earned preferred outside time remains represented as reinforcement")
        try expect(
            physicalLower.contains("lbs also provided instruction") && physicalLower.contains("newly implemented programs"),
            "supplied LBS instruction and newly implemented programs remain represented"
        )
        try expect(
            physicalLower.contains("full sentence manding at 80% accuracy") &&
            physicalLower.contains("waiting in 4/5 trials with a verbal prompt"),
            "clear screenshot measurements remain beside their matching targets"
        )
        try expect(!physicalDraft.contains("08/29/2026") && !physicalDraft.contains("12345"), "administrative screenshot data remains excluded")
        try expect(
            !physicalLower.contains("full physical prompt") && !physicalLower.contains("escape-maintained") &&
            !physicalLower.contains("recommend") && !physicalLower.contains("effective"),
            "the rewrite adds no prompt level, function, recommendation, or effectiveness conclusion"
        )
        try expect(
            physicalDraft.range(of: "pairing outdoors")!.lowerBound < physicalDraft.range(of: "transitioned the client indoors")!.lowerBound &&
            physicalDraft.range(of: "cooperative play")!.lowerBound < physicalDraft.range(of: "engaged in elopement")!.lowerBound &&
            physicalDraft.range(of: "engaged in elopement")!.lowerBound < physicalDraft.range(of: "earned preferred outdoor time")!.lowerBound,
            "the professional narrative preserves the supplied event chronology"
        )
        try expect(
            !physicalDraft.contains("Then transitioned client") && !physicalDraft.contains("After this client") &&
            !physicalDraft.contains("working on FCT and full sentence manding"),
            "the professional rewrite does not lightly copy the demonstrated raw conversational structures"
        )
        try expect(physicalDraft.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n\n").count == 2, "the professional rewrite uses two supported paragraphs without a filler close")
    }

    private static func runtimeProtectionFixtures() async throws {
        let race = SessionNoteRequestRace<String>(timeoutNanoseconds: 5_000_000)
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


    private static let allNoteStages: [SessionNotePipelineStage] = [.standardDraft, .compactDraft, .repair(["synthetic issue"])]

    private static func instructionParityFixtures() throws {
        for stage in allNoteStages {
            let actual = SessionNoteStageInstructions.instructions(for: stage)
            try expect(actual.hasPrefix(SessionNoteClinicalInstructions.sharedConstraints + "\n\n"), "production stage composes the exact shared constraints: \(stage)")
            for requirement in ["person-first", "role-based identity", "chronology", "caregiver reports", "target association", "measurement type", "numeric value", "unit", "prompt level", "attribution", "exactly once", "administrative", "context only"] {
                try expect(actual.contains(requirement), "actual production \(stage) preserves \(requirement)")
            }
            for prohibited in ["function", "intent", "emotion", "cause", "progress", "training", "supervision", "treatment changes", "recommendations", "effectiveness", "causal relationships"] {
                try expect(actual.contains(prohibited), "actual production \(stage) preserves prohibited inference class \(prohibited)")
            }
        }
        try expect(SessionNoteStageInstructions.instructions(for: .repair([])).contains("correct only the listed validation issues"), "repair retains bounded correction guidance")
        try expect(SessionNoteStageInstructions.instructions(for: .standardDraft).contains("For style only"), "standard retains its reconstruction example")
        try expect(SessionNoteStageInstructions.instructions(for: .compactDraft).contains("plain narrative only"), "compact retains its concise style guidance")
    }

    private static func extractionStatusFixtures() throws {
        let independent = SessionNoteOCRMeasurementExtractor.extract(from: ["Waiting 4/5 trials independently"])
        try expect(independent == [SessionNoteMeasurementEvidence(target: "Waiting", value: "4/5 trials", kind: .trials, promptLevels: ["independent"], sourceOrdinal: 1)], "independently retains the exact measurement prompt-level association read by Vision")
        try expect(SessionNoteEvidenceNormalizer.promptLevels(in: "independence") == [], "related nouns do not imply an independent prompt level")
        let clear = SessionNoteRecognizedScreenshot.bounded("Following Directions 80% with a verbal prompt")
        let unreadable = SessionNoteRecognizedScreenshot.bounded("unreadable synthetic data image")
        for (images, expectedMeasurements, expectedEmpty) in [
            ([clear], 1, 0), ([clear, unreadable], 1, 1), ([unreadable], 0, 1), ([clear, clear], 1, 0),
        ] {
            let measurements = SessionNoteOCRMeasurementExtractor.extract(from: images.map(\.text))
            let summary = SessionNoteExtractionSummary.make(screenshots: images, measurements: measurements)
            try expect(summary.measurementCount == expectedMeasurements, "extraction summary counts distinct measurements")
            try expect(summary.attachmentsWithoutReadableMeasurements == expectedEmpty, "summary counts unreadable attachments before deduplication")
            try expect(summary.message.contains("Check every image") && summary.message.contains("does not mean"), "partial extraction is never represented as absence of source measurements")
            try expect(!summary.message.localizedCaseInsensitiveContains("extraction complete"), "no successful extraction claims completeness")
        }
        let longOCR = String(repeating: "a", count: 12_000) + "\nFollowing Directions 80%"
        let bounded = SessionNoteRecognizedScreenshot.bounded(longOCR)
        try expect(bounded.text.isEmpty && bounded.exceededTextLimit, "OCR overflow is flagged before any prefix extraction")
        let summary = SessionNoteExtractionSummary.make(screenshots: [clear, bounded], measurements: SessionNoteOCRMeasurementExtractor.extract(from: [clear.text]))
        try expect(summary.attachmentsExceedingTextLimit == 1 && summary.message.contains("text-reading limit"), "OCR overflow remains visible alongside successfully extracted values")
        try expect(SessionNoteRecognizedScreenshot.bounded(String(repeating: "a", count: 12_000)).exceededTextLimit == false, "exact OCR bound remains admitted")
        try expect(SessionNoteOCRMeasurementExtractor.extract(from: Array(repeating: clear.text, count: 7)).allSatisfy { $0.sourceOrdinal <= 6 }, "extractor retains the six-attachment bound")
    }

    private static func boundaryPacket(_ facts: String, measurements: [SessionNoteMeasurementEvidence] = [], ocr: String = "") -> SessionNoteEvidencePacket {
        SessionNoteEvidencePacket.make(typedFacts: facts, ocrEvidence: ocr, structuredMeasurements: measurements, savedTerminologyContext: "", profileCode: nil)
    }

    private static func nearBoundaryFacts(count: Int) -> String {
        let tail = "The client returned the blue folder to the caregiver."
        let opening = "The client practiced with the RBT. "
        let remainder = count - tail.count
        return String((String(repeating: opening, count: count / opening.count + 1)).prefix(remainder - 1)) + " " + tail
    }

    private static func inputBoundaryFixtures() async throws {
        let tail = "The client returned the blue folder to the caregiver."
        for count in [5_199, 5_200, 5_201, 5_600] {
            let original = nearBoundaryFacts(count: count)
            let packet = boundaryPacket(original)
            try expect(original.count == count && packet.typedFacts.hasSuffix(tail), "full normalized tail retained at \(count) characters")
            for stage in allNoteStages {
                do {
                    let prompt = try packet.modelPrompt(compaction: stage.compaction)
                    try expect(count <= 5_200 && prompt.contains(tail), "admitted \(stage) prompt preserves designated tail")
                } catch SessionNoteBoundaryError.typedFactsOverLimit(let actual) {
                    try expect(count > 5_200 && actual == count, "\(stage) reports overflow without shortening source")
                }
            }
            if count > 5_200 {
                var calls = 0
                do {
                    _ = try await SessionNoteGenerationPipeline.generate(packet: packet) { _ in calls += 1; return validDraft() }
                    throw FixtureError.repairFailed
                } catch SessionNoteBoundaryError.typedFactsOverLimit {
                    try expect(calls == 0 && original.hasSuffix(tail), "over-limit facts never enter a model request and original tail remains")
                }
            } else {
                for desiredStage in allNoteStages {
                    let result = try await SessionNoteGenerationPipeline.generate(packet: packet) { stage in
                        if desiredStage == .compactDraft && stage == .standardDraft { throw SessionNotePipelineError.contextTooLarge }
                        if case .repair = desiredStage, stage == .standardDraft { return "The client completed 999 trials." }
                        return "The RBT presented instructional activities to the client. The client returned the blue folder to the caregiver."
                    }
                    try expect(result.draft.contains(tail), "\(desiredStage) output preserves the fixture-designated nonnumeric tail")
                    try expect(result.completeness == .reviewRequired, "preserved fixture facts still do not certify universal semantic completeness")
                }
            }
        }
        // Repeated spaces may normalize away, but the original input boundary still applies.
        let whitespaceOverflow = boundaryPacket(String(repeating: " ", count: 5_201) + tail)
        do { _ = try whitespaceOverflow.modelPrompt(compaction: .standard); throw FixtureError.repairFailed }
        catch SessionNoteBoundaryError.typedFactsOverLimit { try expect(true, "overflow is checked before normalization shrinks the source") }

        func measurements(_ count: Int) -> [SessionNoteMeasurementEvidence] {
            (0..<count).map { index in
                SessionNoteMeasurementEvidence(target: "waiting " + String(UnicodeScalar(97 + index)!), value: "80%", kind: .percentage, promptLevels: ["verbal"], sourceOrdinal: 1)
            }
        }
        for count in [3, 12, 24] {
            let records = measurements(count)
            let packet = boundaryPacket("The RBT recorded waiting measurements.", measurements: records)
            let sectionLength = records.map(\.promptLine).joined(separator: "\n").count
            try expect(packet.structuredMeasurements == records, "all target/value/type/unit/prompt records retained before section bounds")
            for stage in allNoteStages {
                let limit = stage.compaction == .standard ? 1_600 : 900
                do {
                    let prompt = try packet.modelPrompt(compaction: stage.compaction)
                    try expect(sectionLength <= limit, "only a complete fitting section is admitted")
                    for record in records { try expect(prompt.components(separatedBy: record.promptLine).count == 2, "\(stage) includes each exact measurement association once") }
                } catch SessionNoteBoundaryError.measurementSectionOverLimit(let actualLimit) {
                    try expect(sectionLength > limit && actualLimit == limit, "\(stage) rejects section overflow, including the final record")
                }
            }
            if sectionLength > 900 && sectionLength <= 1_600 {
                for desiredStage in [SessionNotePipelineStage.compactDraft, .repair([])] {
                    var calls = 0
                    do {
                        _ = try await SessionNoteGenerationPipeline.generate(packet: packet) { stage in
                            calls += 1
                            if desiredStage == .compactDraft { throw SessionNotePipelineError.contextTooLarge }
                            return "The client completed 999 trials."
                        }
                        throw FixtureError.repairFailed
                    } catch SessionNoteBoundaryError.measurementSectionOverLimit(let limit) {
                        try expect(calls == 1 && limit == 900, "compact/repair overflow rejects before a second model call")
                    }
                }
            }
        }
        for length in [900, 901, 1_600, 1_601] {
            let record = SessionNoteMeasurementEvidence(target: "waiting", value: "80%", kind: .percentage, promptLevels: [], sourceOrdinal: 1)
            let padding = length - record.promptLine.count
            let exact = SessionNoteMeasurementEvidence(target: record.target + String(repeating: "a", count: padding), value: record.value, kind: record.kind, promptLevels: [], sourceOrdinal: 1)
            let packet = boundaryPacket("The RBT recorded waiting.", measurements: [exact])
            for stage in allNoteStages {
                let limit = stage.compaction == .standard ? 1_600 : 900
                do { _ = try packet.modelPrompt(compaction: stage.compaction); try expect(length <= limit, "exact \(length)-character measurement section admitted only within budget") }
                catch SessionNoteBoundaryError.measurementSectionOverLimit { try expect(length > limit, "one character beyond measurement budget is explicit") }
            }
        }
        let ocr = (0..<40).map { "waiting target \($0) 80% with a verbal prompt" }.joined(separator: "\n")
        let legacyPacket = boundaryPacket("The RBT recorded waiting.", ocr: ocr)
        try expect(legacyPacket.quantitativeOCR.contains("target 39"), "legacy quantitative normalization retains the final measurement before bounds")
        for stage in allNoteStages {
            do { _ = try legacyPacket.modelPrompt(compaction: stage.compaction); throw FixtureError.repairFailed }
            catch SessionNoteBoundaryError.quantitativeSectionOverLimit { try expect(true, "legacy quantitative section overflow is explicit through \(stage)") }
        }
    }

    private static func outputBoundaryFixtures() async throws {
        for desiredStage in allNoteStages {
            for raw in [String(repeating: "x", count: 7_999) + ".", "The client participated. The RBT supported the client during"] {
                var calls = 0
                do {
                    _ = try await SessionNoteGenerationPipeline.generate(packet: evidencePacket()) { stage in
                        calls += 1
                        if desiredStage == .compactDraft && stage == .standardDraft { throw SessionNotePipelineError.contextTooLarge }
                        if case .repair = desiredStage, stage == .standardDraft { return "The client completed 999 trials." }
                        return raw
                    }
                    throw FixtureError.repairFailed
                } catch let error as SessionNoteBoundaryError {
                    try expect(error == (raw.count >= 8_000 ? .outputCharacterLimit : .unfinishedOutput), "\(desiredStage) rejects raw cap/partial clause before period repair")
                    try expect(calls == (desiredStage == .standardDraft ? 1 : 2), "incomplete output causes no additional model retry")
                }
            }
        }
        try SessionNoteOutputBoundary.validate(String(repeating: "x", count: 7_998) + ".")
        try expect(true, "7999 characters do not falsely assert the explicit 8000 cap")
        let packet = boundaryPacket("The RBT presented an instructional activity, and the client participated. The client returned the blue folder to the caregiver.")
        let omitted = try await SessionNoteGenerationPipeline.generate(packet: packet) { _ in
            "The RBT presented an instructional activity, and the client participated."
        }
        try expect(omitted.completeness == .reviewRequired && omitted.completeness.message.contains("may be incomplete"), "known nonnumeric omission weakness remains explicitly unverified, never falsely certified by a keyword detector")
    }

    private static func boundaryDraftPreservationFixtures() async throws {
        let original = nearBoundaryFacts(count: 5_600)
        let previous = "Previous professionally edited synthetic draft."
        for failure in [SessionNoteBoundaryError.typedFactsOverLimit(5_600), .outputCharacterLimit, .unfinishedOutput] {
            var ledger = SessionNoteDraftLedger(draft: previous)
            let id = UUID()
            ledger.begin(requestID: id, preserving: previous)
            do {
                _ = try await SessionNoteGenerationPipeline.generate(packet: evidencePacket()) { _ in throw failure }
                throw FixtureError.repairFailed
            } catch is SessionNoteBoundaryError { ledger.finish(requestID: id) }
            try expect(ledger.draft == previous && original == nearBoundaryFacts(count: 5_600), "bounded failure preserves complete original and previous draft")
            try expect(!ledger.accept("Late replacement", for: id), "late output cannot replace prior draft after bounded failure")
        }
        var ledger = SessionNoteDraftLedger(draft: previous)
        let id = UUID()
        ledger.begin(requestID: id, preserving: previous)
        let race = SessionNoteRequestRace<String>(timeoutSeconds: 5)
        let task = Task { try await race.run { try await Task.sleep(nanoseconds: 5_000_000_000); return "Late draft" } }
        race.cancel()
        do { _ = try await task.value; throw FixtureError.repairFailed }
        catch is CancellationError { ledger.finish(requestID: id) }
        try expect(ledger.draft == previous && !ledger.isCurrent(id), "cancelling a second request preserves prior edited draft and closes ownership")
    }


    private static func proseFidelityFixtures() async throws {
        let sparse = "RBT met at clients home\n\nRBT, client, and mom present\n\nRBT began with pairing and FCT then moved to transitions.\n\nClient responded well"
        let captured = "The RBT, client, and mom met at the client's home. The RBT began with pairing and functional communication training. Then, the RBT moved to transitions. The client responded well.\n\nThe client was engaged in the FCT and transitioning activities.\n\nThe RBT continued the session.\n\nThe client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
        // Authored references / model doubles, not FoundationModels quality evidence.
        let concise = "The RBT met with the client at the client's home, with the client's mother present. The session began with pairing and functional communication training (FCT), followed by transitions. The client responded well."
        let packet = boundaryPacket(sparse)
        let bad = SessionNoteOutputValidator.validate(captured, evidence: packet)
        try expect(bad.hardBlockerCodes.contains("SN-CLINICAL-009") && bad.hardBlockerCodes.contains("SN-CLINICAL-010"), "captured unsupported engagement, participation and future plan are blocked")
        try expect(bad.boundedModelRepairInstructions.contains(where: { $0.contains("engagement or participation") }), "deduplicated issue code retains both engagement and participation repair guidance")
        let deterministic = SessionNoteDeterministicRepairer.repair(captured, validation: bad, evidence: packet)
        try expect(!deterministic.draft.contains("The RBT continued the session."), "exact standalone padding is removed")
        try expect(deterministic.draft.contains("pairing") && deterministic.draft.contains("responded well"), "padding removal retains supported activity and response")
        try expect(!SessionNoteOutputValidator.validate(deterministic.draft, evidence: packet).isSafe, "mixed unsupported claims are not silently accepted after formatting repair")
        for stage in allNoteStages {
            let instructions = SessionNoteStageInstructions.instructions(for: stage)
            try expect(instructions.contains("no minimum word, sentence, or paragraph count") && !instructions.contains("2–4"), "all production stages share evidence-proportional length: \(stage)")
            try expect(instructions.contains("future plans") && instructions.contains("qualifications and attribution"), "all production stages preserve fidelity guidance: \(stage)")
            let prompt = try packet.modelPrompt(compaction: stage.compaction)
            try expect(prompt.contains("concise single paragraph is acceptable") && !prompt.contains("Close once"), "packet instructions agree with production stage: \(stage)")
        }
        for reference in [concise, "The client responded well."] {
            let facts = reference == concise ? packet : boundaryPacket("Client responded well")
            let v = SessionNoteOutputValidator.validate(reference, evidence: facts)
            try expect(v.isProfessionallyReady && !v.issueCodes.contains("SN-QUALITY-002"), "faithful short or single-sentence prose is not penalized for length")
            var calls = 0
            let result = try await SessionNoteGenerationPipeline.generate(packet: facts) { _ in calls += 1; return reference }
            try expect(calls == 1 && result.outcome == .generated && result.draft == reference, "concise draft passes unchanged without padding or repair")
            try expect(result.completeness == .reviewRequired, "concise draft still requires professional completeness review")
        }
        for persistent in [false, true] {
            var calls = 0
            let result = try await SessionNoteGenerationPipeline.generate(packet: packet) { stage in
                calls += 1
                if case .repair = stage { return persistent ? captured : concise }
                return captured
            }
            try expect(calls == 2, "captured unsafe output receives exactly one bounded model repair")
            try expect(result.outcome == (persistent ? .fallback : .repaired), "persistent unsafe model output retains fallback provenance")
            for forbidden in ["was engaged", "participated", "treatment plan", "continued the session"] {
                try expect(!result.draft.contains(forbidden), "final sparse result excludes unsupported \(forbidden)")
            }
            for fact in ["home", "pairing", "FCT", "transitions", "responded well"] {
                try expect(result.draft.contains(fact), "final sparse result retains \(fact)")
            }
            try expect(result.draft.contains(persistent ? "mom" : "mother"), "caregiver presence is retained")
            try expect(result.completeness == .reviewRequired, "repair and fallback remain review-required")
        }
        let traps: [(String, String)] = [
            ("The client was engaged in the activities.", "SN-CLINICAL-009"),
            ("The client participated throughout the session.", "SN-CLINICAL-009"),
            ("The RBT will continue implementing the established treatment plan during future sessions.", "SN-CLINICAL-010"),
            ("The RBT followed the treatment plan.", "SN-CLINICAL-010"),
            ("The RBT provided reinforcement.", "SN-CLINICAL-011"),
            ("The RBT provided praise.", "SN-CLINICAL-011"),
            ("The client made progress.", "SN-CLINICAL-003"),
            ("The client responded well because the RBT provided reinforcement.", "SN-CLINICAL-012"),
            ("The client transitioned successfully.", "SN-CLINICAL-013"),
        ]
        for (claim, code) in traps {
            try expect(SessionNoteOutputValidator.validate(concise + " " + claim, evidence: packet).hardBlockerCodes.contains(code), "unsupported addition is rejected: \(claim)")
            let supported = boundaryPacket(sparse + "\n" + claim)
            let v = SessionNoteOutputValidator.validate(concise + " " + claim, evidence: supported)
            try expect(v.isSafe, "explicit positive counterpart is retained: \(claim), \(v.issueCodes)")
            let repair = SessionNoteDeterministicRepairer.repair(v.draft, validation: v, evidence: supported)
            try expect(repair.draft.contains(claim), "repair preserves explicit clinical detail: \(claim)")
        }
        let qualified = "The client's mother reported that the client was engaged briefly during reading."
        let q = boundaryPacket(sparse + "\n" + qualified)
        try expect(SessionNoteOutputValidator.validate(concise + " " + qualified, evidence: q).isSafe, "qualified caregiver report is preserved")
        try expect(!SessionNoteOutputValidator.validate(concise + " The client was engaged throughout the session.", evidence: q).isSafe, "brief engagement does not license engagement throughout the session")
        let explicitContinuation = boundaryPacket("The RBT continued the session.")
        let cv = SessionNoteOutputValidator.validate(explicitContinuation.typedFacts, evidence: explicitContinuation)
        try expect(SessionNoteDeterministicRepairer.repair(cv.draft, validation: cv, evidence: explicitContinuation).draft == cv.draft, "explicitly supplied continuation is not removed as filler")

        let normal = "The RBT met with the client at home with the client's mother present. Pairing with blocks came first, followed by functional communication training (FCT). The client requested a break in 4/5 trials with a verbal prompt. The RBT provided praise after the requests. The client then moved to a puzzle, paused when asked to put it away, and put it away after the RBT repeated the instruction. The client's mother reported that the client had slept poorly. The session ended with reading; the client selected a book."
        var normalCalls = 0
        let normalResult = try await SessionNoteGenerationPipeline.generate(packet: boundaryPacket(normal)) { _ in normalCalls += 1; return normal }
        try expect(normalCalls == 1 && normalResult.draft.replacingOccurrences(of: "\n\n", with: " ") == normal, "normal synthetic session preserves chronology, prompting, reinforcement, observable response and report attribution")
        let measurements = SessionNoteOCRMeasurementExtractor.extract(from: ["Requesting Break 4/5 trials with a verbal prompt\nFollowing Directions 80% accuracy\nWaiting duration 2 minutes"])
        let detail = "At home, the RBT and client began with blocks. Requesting Break was recorded at 4/5 trials with a verbal prompt. Following Directions was recorded at 80% accuracy. Waiting duration was 2 minutes. " + ["The client sorted the red cards.", "The client placed the toy car on the shelf.", "The RBT presented a picture book.", "The client selected the animal page.", "The client pointed to the horse.", "The RBT put the book on the table.", "The client selected a puzzle.", "The client put the corner piece in the puzzle.", "The client's mother reported that the client read at home yesterday.", "The client returned the blue folder to the caregiver."].joined(separator: " ")
        let dp = SessionNoteEvidencePacket.make(typedFacts: detail, ocrEvidence: "", structuredMeasurements: measurements, savedTerminologyContext: "", profileCode: nil)
        let dv = SessionNoteOutputValidator.validate(detail, evidence: dp)
        try expect(measurements.count == 3 && dv.isProfessionallyReady, "detailed within-limit narrative retains three exact measurement associations")
        let dr = SessionNoteDeterministicRepairer.repair(detail, validation: dv, evidence: dp)
        for fact in ["4/5 trials with a verbal prompt", "80% accuracy", "2 minutes", "reported", "blue folder"] {
            try expect(dr.draft.components(separatedBy: fact).count == 2, "detailed repair preserves each designated fact exactly once: \(fact)")
        }
        let omitted = detail.replacingOccurrences(of: "The client returned the blue folder to the caregiver.", with: "")
        try expect(SessionNoteOutputValidator.validate(omitted, evidence: dp).isProfessionallyReady, "known limitation: unmeasured tail omission is not certified by the existing validator; reviewRequired remains necessary")
    }


    private static func finalProseAndClosingFixtures() async throws {
        // Literal product contract is independent of the production sentence constant.
        let action = "will continue to maintain pairing and rapport with the client, implement skill acquisition and behavior reduction protocols as written, and consult the supervising clinician regarding any questions, concerns, or barriers to progress."
        for (credential, role) in [
            ("RBT", SessionNoteWriterRole.rbt), (" registered behavior technician ", .rbt),
            ("bht", .bht), ("Behavioral Health Technician", .bht),
            (" BT\n", .bt), ("Behavior Technician", .bt),
            ("ABA   Therapist", .abaTherapist), ("Applied Behavior Analysis Therapist", .abaTherapist),
        ] {
            try expect(try SessionNoteWriterRole.resolve(profileCredential: credential) == role,
                       "explicit saved credential resolves without narrative inference: \(credential)")
        }
        for unknown in ["", " ", "123456", "RBT-123456", "BCBA", "RBT / BHT", "former RBT", "RBT trainee", "The RBT met the client.", "RBT\nBT"] {
            do {
                _ = try SessionNoteWriterRole.resolve(profileCredential: unknown)
                throw FixtureError.repairFailed
            } catch SessionNoteBoundaryError.writerRoleRequired {
                try expect(true, "blank, ID-only, unsupported or ambiguous credential cannot invent a role")
            }
        }
        try expect(SessionNoteBoundaryError.writerRoleRequired.statusTitle == "Writer role required"
                   && SessionNoteBoundaryError.writerRoleRequired.diagnosticCode == "writerRoleRequired",
                   "missing role uses the existing blocked-status and privacy-safe diagnostic path")

        let sparse = "RBT met at clients home\n\nRBT, client, and mom present\n\nRBT began with pairing and FCT then moved to transitions.\n\nClient responded well"
        let sparseBody = "The RBT met with the client at the client's home with the client's mother present. Pairing and functional communication training (FCT) preceded transitions, and the client responded well."
        let sparsePacket = boundaryPacket(sparse)
        for role in SessionNoteWriterRole.allCases {
            var calls = 0
            let note = try await SessionNoteGenerationPipeline.generateNote(packet: sparsePacket, writerRole: role) { _ in
                calls += 1; return sparseBody
            }
            let close = "\(role.rawValue) \(action)"
            try expect(note.draft == sparseBody + "\n\n" + close && calls == 1,
                       "short accepted body stays concise; exact profile-role closing is appended once: \(role)")
            try expect(note.draft.components(separatedBy: action).count == 2 && note.draft.hasSuffix(close),
                       "authorized close occurs exactly once as the final sentence")
            try expect(note.completeness == .reviewRequired && note.outcome == .generated,
                       "closed note remains editable review-required generated output")
            try expect(ABATerminologyNormalizer.normalize(ABATerminologyNormalizer.normalize(note.draft)) == note.draft,
                       "repeated editor terminology normalization preserves exact close without accumulation")
            let suppliedClose = boundaryPacket(sparse + "\n" + close)
            try expect(SessionNoteOutputValidator.validate(note.draft, evidence: suppliedClose)
                .hardBlockerCodes.contains("SN-CLINICAL-014"),
                       "even a supplied exact close is forbidden inside model-generated body")
        }

        // Representative synthetic reconstruction of the facts Brandon supplied in
        // physical review, not a verbatim recovered narrative or actual model sample.
        let normalFacts = "Session at client's home. RBT, client, dad, mom, brother, grandma and health aide present. Began pairing and functional manding. Outside play, then transition inside. Community outing to Family Dollar to practice transitions and community skills. Client tantrum related to waiting for candy. RBT redirected client successfully. Outside free play used as reinforcement."
        let normalBody = """
        The RBT met with the client at the client's home. The client's father, mother, brother, and grandmother were present, along with a health aide. The session began with pairing and functional manding activities.

        Outside play followed the initial pairing and functional manding activities, and the client then transitioned inside. The session also included a community outing to Family Dollar to practice transitions and community skills.

        The client exhibited a tantrum related to waiting for candy. The RBT successfully redirected the client. Outside free play was used as reinforcement.
        """
        let normalPacket = boundaryPacket(normalFacts)
        var normalCalls = 0
        let normal = try await SessionNoteGenerationPipeline.generateNote(packet: normalPacket, writerRole: .rbt) { _ in
            normalCalls += 1; return normalBody
        }
        let body = normal.draft.components(separatedBy: "\n\nRBT " + action)[0]
        try expect(normalCalls == 1 && normal.outcome == .generated, "representative fuller authored prose passes the actual body pipeline in one model-double call")
        try expect(body.split(whereSeparator: \.isWhitespace).count > normalFacts.split(whereSeparator: \.isWhitespace).count,
                   "normal fixture develops rough evidence beyond direct bullet-to-sentence conversion")
        let paragraphs = body.components(separatedBy: "\n\n")
        try expect(paragraphs.count > 1 && paragraphs.allSatisfy { SessionNoteOutputSanitizer.splitSentences($0).count >= 2 },
                   "rich fixture preserves substantive related body paragraphs; no runtime paragraph minimum")
        for fact in ["client's home", "RBT", "father", "mother", "brother", "grandmother", "health aide", "functional manding", "Family Dollar", "community skills", "tantrum related to waiting for candy", "successfully redirected", "free play was used as reinforcement"] {
            try expect(body.contains(fact), "normal fixture retains supplied evidence: \(fact)")
        }
        let ordered = ["session began", "Outside play", "transitioned inside", "Family Dollar", "tantrum", "redirected", "free play"]
        let positions = ordered.compactMap { body.range(of: $0)?.lowerBound }
        try expect(positions.count == ordered.count && positions == positions.sorted(), "normal body preserves supplied event chronology")
        try expect(SessionNoteOutputValidator.validate(body, evidence: normalPacket).isSafe,
                   "normal body passes evidence and clinical checks independently of its closing")
        for unsupported in ["prompt", "praise", "improved", "independently", "engaged", "participated", "session continued", "will continue"] {
            try expect(!body.lowercased().contains(unsupported), "normal authored body contains no unsupported \(unsupported)")
        }
        try expect(normal.draft.hasSuffix("RBT " + action) && normal.draft.components(separatedBy: action).count == 2,
                   "normal result has one exact deterministic final close")

        let unsupportedPlan = sparseBody + " The RBT will introduce new targets during future sessions."
        try expect(!SessionNoteOutputValidator.validate(unsupportedPlan, evidence: sparsePacket).isSafe,
                   "unsupported model-authored future plan remains blocked")
        for mode in ["repair", "fallback", "compact"] {
            var calls = 0
            let note = try await SessionNoteGenerationPipeline.generateNote(packet: sparsePacket, writerRole: .bht) { stage in
                calls += 1
                switch stage {
                case .standardDraft where mode == "compact": throw SessionNotePipelineError.contextTooLarge
                case .standardDraft: return unsupportedPlan
                case .repair where mode == "fallback": return unsupportedPlan
                default: return sparseBody
                }
            }
            let outcome: SessionNoteFinalOutcome = mode == "fallback" ? .fallback : (mode == "compact" ? .generated : .repaired)
            try expect(calls == 2 && note.outcome == outcome, "bounded \(mode) preserves original attempt budget and truthful outcome")
            try expect(note.draft.hasSuffix("BHT " + action) && note.draft.components(separatedBy: action).count == 2,
                       "\(mode) adds the profile close once after accepting the body")
            try expect(!note.draft.contains("new targets") && note.completeness == .reviewRequired,
                       "\(mode) cannot preserve unsupported model plans or waive professional review")
        }

        // Regression: a closing would supply punctuation, but must never be appended
        // to hide an unfinished raw body, in any model stage.
        let unfinished = "The RBT worked with the client during"
        try SessionNoteOutputBoundary.validate(unfinished + "\n\nRBT " + action)
        for mode in ["standard", "compact", "repair"] {
            var calls = 0
            do {
                _ = try await SessionNoteGenerationPipeline.generateNote(packet: sparsePacket, writerRole: .rbt) { stage in
                    calls += 1
                    if case .standardDraft = stage, mode == "compact" { throw SessionNotePipelineError.contextTooLarge }
                    if case .standardDraft = stage, mode == "repair" { return unsupportedPlan }
                    return unfinished
                }
                throw FixtureError.repairFailed
            } catch SessionNoteBoundaryError.unfinishedOutput {
                try expect(calls == (mode == "standard" ? 1 : 2), "unfinished \(mode) body rejects BEFORE deterministic close can supply punctuation")
            }
        }
        for modelClosing in ["RBT " + action, "ABA Therapist " + action.replacingOccurrences(of: " ", with: "\n")] {
            let raw = unfinished + "\n\n" + modelClosing
            try expect(SessionNoteOutputValidator.validate(raw, evidence: sparsePacket).hardBlockerCodes.contains("SN-CLINICAL-014"),
                       "model-supplied close cannot legitimize an incomplete preceding body")
            let sanitized = SessionNoteOutputSanitizer.sanitize(raw, scrubber: sparsePacket.scrubber)
            let formatted = SessionNoteDeterministicRepairer.repair(
                sanitized, validation: SessionNoteOutputValidator.validate(sanitized, evidence: sparsePacket), evidence: sparsePacket
            )
            try expect(SessionNoteOutputValidator.validate(formatted.draft, evidence: sparsePacket).hardBlockerCodes.contains("SN-CLINICAL-014"),
                       "model close stays blocked after clinician-to-role and punctuation formatting")
            var calls = 0
            let recovered = try await SessionNoteGenerationPipeline.generateNote(packet: sparsePacket, writerRole: .bt) { _ in
                calls += 1; return calls == 1 ? raw : sparseBody
            }
            try expect(calls == 2 && recovered.outcome == .repaired && !recovered.draft.contains(unfinished)
                       && recovered.draft.components(separatedBy: action).count == 2,
                       "repair replaces contaminated body; it cannot duplicate or authorize its model-authored close")
        }

        var ledger = SessionNoteDraftLedger(draft: normal.draft)
        for role in [SessionNoteWriterRole.bt, .abaTherapist, .rbt] {
            let edited = ledger.draft.replacingOccurrences(of: "met with", with: "worked with")
            let id = UUID(); ledger.begin(requestID: id, preserving: edited)
            let fresh = try await SessionNoteGenerationPipeline.generateNote(packet: sparsePacket, writerRole: role) { _ in sparseBody }
            try expect(ledger.accept(fresh.draft, for: id), "current regenerated note replaces edited prior draft")
            ledger.finish(requestID: id)
            try expect(ledger.draft.hasSuffix("\(role.rawValue) " + action)
                       && ledger.draft.components(separatedBy: action).count == 2,
                       "regeneration with a different profile role replaces rather than accumulates closings")
        }
        for stage in allNoteStages {
            let instructions = SessionNoteStageInstructions.instructions(for: stage)
            for property in ["substantive paragraphs", "community work", "meaningfully connect", "no minimum word, sentence, or paragraph count", "BODY only", "after body acceptance"] {
                try expect(instructions.contains(property), "production \(stage) shares fuller evidence-locked body policy: \(property)")
            }
        }
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
        "At home, the client worked with the RBT and LBS on FCT. The client responded independently in 3/5 trials, and the client's mother reported that the transition occurred."
    }

    private static func validMultiScreenshotDraft() -> String {
        "At home, the client worked with the RBT on Following Directions. The RBT recorded 3 occurrences of the supplied behavior of concern during the opening activity. Following the transition to table work, the client completed Following Directions with 80% accuracy using a verbal prompt."
    }

    private static func expect(
        _ condition: @autoclosure () throws -> Bool,
        _ message: String
    ) throws {
        assertionCount += 1
        guard try condition() else {
            throw NSError(
                domain: "SessionNoteContractFixtures",
                code: assertionCount,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
