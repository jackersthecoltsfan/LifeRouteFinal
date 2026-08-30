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
        try multiScreenshotEvidenceFixtures()
        try savedContextIsNotEvidenceFixtures()
        try emptyEvidenceFixtures()
        try realisticSyntheticSessionFixtures()
        try await pipelineFixtures()
        try await fallbackAndDiagnosticFixtures()
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
        try expect(unknownValidation.hardBlockerCodes.contains("SN-IDENTITY-002"), "unknown personal names receive a privacy-safe hard-blocker code")
        let leakedCode = "SyCl worked with the RBT. The client participated in play. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            SessionNoteOutputValidator.validate(leakedCode, evidence: packet).hardBlockerCodes.contains("SN-IDENTITY-003"),
            "a synthetic client-code shape that survives sanitization remains hard-blocked"
        )
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
            inventedValidation.issueCodes.contains("SN-EVIDENCE-001"),
            "a newly invented numeric value is rejected"
        )

        let countPacket = SessionNoteEvidencePacket.make(
            typedFacts: "The RBT recorded 3 occurrences of the supplied behavior of concern.",
            ocrEvidence: "[FREQUENCY/COUNT] supplied behavior of concern 3 occurrences",
            savedTerminologyContext: "targets: none | behaviors: none",
            profileCode: "SyCl"
        )
        let changedMeasurement = "The RBT recorded 3% accuracy for the supplied behavior of concern. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
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

        let inferredFunction = valid.replacingOccurrences(
            of: "The client participated in the supplied activities.",
            with: "The function was escape-maintained."
        )
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
            styleValidation.repairableIssues.contains(where: { $0.code == "SN-FORMAT-005" }),
            "a missing standard close is deterministically repairable"
        )
        try expect(
            styleValidation.repairableIssues.contains(where: { $0.code == "SN-FORMAT-008" }),
            "missing final punctuation is deterministically repairable"
        )

        let repetitive = "The client entered the home. The client greeted the RBT. The client joined the activity. The client completed the activity. The client left the table. The RBT will continue implementing the established treatment plan during future sessions."
        let repetitionValidation = SessionNoteOutputValidator.validate(repetitive, evidence: packet)
        try expect(repetitionValidation.isSafe, "repetitive sentence openings remain nonfatal")
        try expect(
            repetitionValidation.warnings.contains(where: { $0.code == "SN-QUALITY-003" }),
            "repetitive sentence openings are represented as a quality warning"
        )

        let invented = SessionNoteOutputValidator.validate(
            "The client completed 999 trials. The RBT will continue implementing the established treatment plan during future sessions.",
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
        let naturalParaphrase = "The client required redirection to return to work and later accessed outside play as reinforcement. The client participated in the supplied activity. The RBT will continue implementing the established treatment plan during future sessions."
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
        let supervisorParaphrase = "The LBS provided guidance to the RBT regarding the supplied skill-acquisition targets. The client participated in the supplied session. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            SessionNoteOutputValidator.validate(supervisorParaphrase, evidence: supervisorPacket).isSafe,
            "supervisor instruction and guidance are treated as the same narrow semantic category"
        )

        let observableReinforcement = "The client accessed outside time following work. The client participated in the supplied activity. The RBT will continue implementing the established treatment plan during future sessions."
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
            missingClose.hasSuffix(SessionNoteOutputSanitizer.continuationSentence),
            "the approved continuation close is appended deterministically"
        )
        try expect(missingCloseStages == [.standardDraft], "a missing exact close does not invoke model repair")

        var paraphrasedCloseStages: [SessionNotePipelineStage] = []
        let normalizedClose = try await SessionNoteGenerationPipeline.run(packet: packet) { stage in
            paraphrasedCloseStages.append(stage)
            return "At home, the client worked with the RBT. The client accessed outside time. The RBT will continue the treatment plan in future sessions."
        }
        try expect(
            normalizedClose.components(separatedBy: "continue implementing the established treatment plan").count == 2,
            "a paraphrased close is replaced by one canonical close"
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
        let mixedDraft = "The RBT recorded 3 occurrences of the supplied behavior of concern. The client completed Following Directions with 80% accuracy. The client completed Requesting Break in 4/5 trials using a verbal prompt, and Waiting lasted 6 minutes with a gestural prompt. The RBT will continue implementing the established treatment plan during future sessions."
        let mixedValidation = SessionNoteOutputValidator.validate(mixedDraft, evidence: mixedPacket)
        try expect(mixedValidation.isSafe, "mixed count, percentage, trial, duration, and prompt data validate together: \(mixedValidation.issueCodes)")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "3", kind: .count)), "mixed OCR retains count typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "80", kind: .percentage)), "mixed OCR retains percentage typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "4/5", kind: .trials)), "mixed OCR retains trial-ratio typing")
        try expect(mixedPacket.numericClaims.contains(SessionNoteNumericClaim(value: "6", kind: .duration)), "mixed OCR retains duration typing")
        try expect(mixedPacket.promptLevels.contains("verbal") && mixedPacket.promptLevels.contains("gestural"), "mixed OCR retains supplied prompting")
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
        let contextTarget = "The client completed Greeting Routine with the RBT. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
        let contextBehavior = "Property Destruction occurred during work. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            SessionNoteOutputValidator.validate(contextTarget, evidence: contextPacket).hardBlockerCodes.contains("SN-EVIDENCE-005"),
            "a context-only target cannot become a current-session event"
        )
        try expect(
            SessionNoteOutputValidator.validate(contextBehavior, evidence: contextPacket).hardBlockerCodes.contains("SN-EVIDENCE-005"),
            "a context-only behavior cannot become a current-session occurrence"
        )

        let internalState = "The client was frustrated during work. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            SessionNoteOutputValidator.validate(internalState, evidence: contextPacket).hardBlockerCodes.contains("SN-CLINICAL-002"),
            "an unsupported internal state remains hard-blocked"
        )
        let unsupportedSupervisor = "The BCBA observed the client during work. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
        try expect(
            SessionNoteOutputValidator.validate(unsupportedSupervisor, evidence: contextPacket).hardBlockerCodes.contains("SN-CLINICAL-008"),
            "invented supervisor involvement remains hard-blocked"
        )
        let unsupportedTreatmentChange = "The LBS updated the treatment plan during the session. The client participated in the session. The RBT will continue implementing the established treatment plan during future sessions."
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
            let draft = "The client practiced \(label) with the RBT. The client participated in the supplied activity. The RBT will continue implementing the established treatment plan during future sessions."
            try expect(
                !SessionNoteOutputValidator.validate(draft, evidence: packet).hardBlockerCodes.contains("SN-IDENTITY-002"),
                "supplied clinical label \(label) is not mistaken for a personal name"
            )
        }

        let cases: [(String, String, String)] = [
            (
                "At home, the caregiver was present while the RBT paired with the client. The client used full-sentence manding during FCT, waited, transitioned to table work after redirection, and earned outdoor play.",
                "During the home session, the caregiver remained present while the RBT paired with the client. The client used a full sentence to mand during FCT, waited during the supplied activity, returned to table work after redirection, and later accessed outdoor play. The RBT will continue implementing the established treatment plan during future sessions.",
                "home pairing, FCT, transitions, redirection, and outdoor reinforcement paraphrase"
            ),
            (
                "The client engaged in the supplied behavior of concern during a transition. The RBT redirected the client, and the client returned to work. The LBS instructed the RBT on skill-acquisition targets.",
                "A behavior of concern occurred during the transition. After the RBT redirected the client, the client resumed work. The LBS provided guidance to the RBT regarding the supplied skill-acquisition targets. The RBT will continue implementing the established treatment plan during future sessions.",
                "behavior occurrence and supervisor-guidance paraphrase"
            ),
            (
                "The caregiver was present. The client completed table work with the RBT, transitioned outside, and accessed outside time after work.",
                "With the caregiver present, the client participated in table work with the RBT and then transitioned outdoors. The client accessed outside time after completing the supplied work. The RBT will continue implementing the established treatment plan during future sessions.",
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

    private static func fallbackAndDiagnosticFixtures() async throws {
        let packet = evidencePacket()
        var stages: [SessionNotePipelineStage] = []
        var diagnostics: [SessionNotePipelineDiagnosticEvent] = []
        let fallback = try await SessionNoteGenerationPipeline.run(
            packet: packet,
            request: { stage in
                stages.append(stage)
                return "The client completed 999 trials. The client was frustrated."
            },
            diagnostic: { diagnostics.append($0) }
        )
        try expect(stages.count == 2, "an unsafe repaired draft receives no second model repair")
        try expect(!fallback.contains("999") && !fallback.lowercased().contains("frustrated"), "fallback excludes unsupported model claims")
        try expect(fallback.contains("3/5 trials"), "fallback preserves supported typed quantitative evidence")
        try expect(fallback.hasSuffix(SessionNoteOutputSanitizer.continuationSentence), "fallback appends the approved close")
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
            return "The client completed 999 trials. The client participated in the supplied activities. The RBT will continue implementing the established treatment plan during future sessions."
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
