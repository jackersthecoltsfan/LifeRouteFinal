import Foundation
import FoundationModels

private struct FactProbe {
    let id: String
    let alternatives: [String]
}

private struct NarrativeEvaluationCase {
    let id: String
    let caseClass: String
    let facts: String
    let factProbes: [FactProbe]
    let explicitOrder: [FactProbe]
    let ambiguousOrder: Bool
    let exactValues: [String]
    let duplicateProbe: FactProbe?
    let caseForbiddenPatterns: [(String, String)]
    let sparse: Bool
}

private struct EvaluationRecord: Codable {
    var modelPasses: [EvaluationModelPass]? = nil
    let id: String
    let caseClass: String
    let outcome: String
    let output: String
    let supportedFactsPresent: [String]
    let supportedFactsOmitted: [String]
    let factRecallNumerator: Int
    let factRecallDenominator: Int
    let guardedUnsupportedClaims: [String]
    let boundedFactPrecisionNumerator: Int
    let boundedFactPrecisionDenominator: Int
    let explicitChronologyPreserved: Bool?
    let falseChronologyMarkers: [String]
    let roleAttributionPreserved: Bool?
    let quantitativeValuesPresent: [String]
    let quantitativeValuesMissing: [String]
    let duplicateMentionCount: Int?
    let paragraphCount: Int
    let sentenceCount: Int
    let mechanicalTransitionCount: Int
    let plainNarrative: Bool
    let error: String?
}

private struct EvaluationModelPass: Codable {
    let stage: String
    let output: String
    let issueCodes: [String]
}

private struct EvaluationReport: Codable {
    let provider: String
    let modelAvailability: String
    let generatedAt: String
    let records: [EvaluationRecord]
}

private enum SessionNoteNarrativeCorpus {
    static let cases: [NarrativeEvaluationCase] = [
        NarrativeEvaluationCase(
            id: "K", caseClass: "RICH ABA WITH SUPERVISOR OBSERVATION AND CONCLUSION",
            facts: """
            The session took place at home with the client, mother, sibling, RBT, and BCBA present.
            The mother reported that the client slept poorly.
            At the beginning, the RBT used bubbles and blocks for pairing.
            The BCBA modelled functional communication training using the client's AAC device to request a break.
            The RBT provided gestural prompts for break requests.
            After pairing, the RBT supported the transition to table activities with a visual schedule.
            The client engaged in hand biting twice. The RBT blocked hand biting and offered a chew tube.
            The RBT raised the observation of repeated swallowing to the BCBA.
            The session ended with free play and pairing. The RBT concluded that the client continued to need gestural prompts for break requests.
            """,
            factProbes: [probe("K01", "home"), probe("K02", "mother"), probe("K03", "sibling"), probe("K04", "BCBA"),
                         probe("K05", "sleep", "slept"), probe("K06", "bubbles", "bubble"), probe("K07", "blocks", "block"),
                         probe("K08", "AAC", "augmentative"), probe("K09", "gestural"), probe("K10", "visual schedule"),
                         probe("K11", "table"), probe("K12", "hand biting", "biting"), probe("K13", "twice", "two", "2"),
                         probe("K14", "chew tube"), probe("K15", "swallowing"), probe("K16", "free play"),
                         probe("K17", "concluded", "conclusion", "assessment")],
            explicitOrder: [], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [("invented progress", #"(?i)\b(?:made progress|improved|independently|transitioned successfully)\b"#)], sparse: false
        ),
        NarrativeEvaluationCase(
            id: "S", caseClass: "REPORTED ASSAULT AND INJURY WITHOUT UNSAFE REQUEST",
            facts: """
            The session occurred at home with the client, mother, and RBT present.
            The mother reported that the client was assaulted by a peer before the session and had a bruise on the left arm.
            The RBT observed the client request a break using an AAC device.
            The RBT provided gestural prompts during a puzzle activity.
            The client completed the puzzle with gestural prompts.
            The session ended with quiet play.
            """,
            factProbes: [probe("S1", "mother"), probe("S2", "reported"), probe("S3", "assault"), probe("S4", "bruise"), probe("S5", "left arm"), probe("S6", "AAC"), probe("S7", "gestural"), probe("S8", "quiet play")],
            explicitOrder: [], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: false
        ),
        NarrativeEvaluationCase(
            id: "A", caseClass: "SPARSE",
            facts: """
            The session occurred at the client's home.
            The client's grandmother was present.
            The RBT used bubble play for pairing.
            The client transitioned to the table.
            The session ended when the client returned a blue folder to the grandmother.
            """,
            factProbes: [
                probe("A1", "home"), probe("A2", "grandmother", "caregiver"),
                probe("A3", "bubble"), probe("A4", "table"), probe("A5", "blue folder"),
            ], explicitOrder: [], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "B", caseClass: "CLEAR CHRONOLOGY",
            facts: """
            First, the client completed a red puzzle with the RBT.
            Then the client transitioned to the snack table.
            After snack, the client requested a break with a picture card.
            Toward the end of the session, the client placed a coat by the door.
            """,
            factProbes: [
                probe("B1", "red puzzle"), probe("B2", "snack table"),
                probe("B3", "picture card"), probe("B4", "coat"),
            ], explicitOrder: [
                probe("B1", "red puzzle"), probe("B2", "snack table"),
                probe("B3", "picture card"), probe("B4", "coat"),
            ], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: false
        ),
        NarrativeEvaluationCase(
            id: "C", caseClass: "DISORDERED INPUT WITH RECOVERABLE SEQUENCE",
            facts: """
            Toward the end of the session, the client gave a yellow book to the caregiver.
            After moving from the porch to the kitchen, the client completed matching cards.
            At the beginning of the session, the RBT used bubbles for pairing on the porch.
            Before completing the matching cards, the client requested water using speech.
            """,
            factProbes: [
                probe("C1", "bubbles"), probe("C2", "water"),
                probe("C3", "matching cards"), probe("C4", "yellow book"),
            ], explicitOrder: [
                probe("C1", "bubbles"), probe("C2", "water"),
                probe("C3", "matching cards"), probe("C4", "yellow book"),
            ], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: false
        ),
        NarrativeEvaluationCase(
            id: "D", caseClass: "AMBIGUOUS ORDER",
            facts: """
            The client sorted orange tokens.
            The RBT practiced shoe tying with the client.
            A caregiver was present.
            The client placed a silver cup on the counter.
            """,
            factProbes: [
                probe("D1", "orange tokens"), probe("D2", "shoe tying", "tying shoes"),
                probe("D3", "caregiver"), probe("D4", "silver cup"),
            ], explicitOrder: [], ambiguousOrder: true, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: false
        ),
        NarrativeEvaluationCase(
            id: "E", caseClass: "CAREGIVER REPORT",
            facts: """
            The client's father reported that the client ate breakfast before the session.
            During the session, the RBT observed the client request crayons.
            The client's father remained present.
            """,
            factProbes: [
                probe("E1", "father", "caregiver"), probe("E2", "breakfast"),
                probe("E3", "crayons"), probe("E4", "present"),
            ], explicitOrder: [], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "F", caseClass: "BEHAVIOR + INTERVENTION",
            facts: """
            During a puzzle activity, the client pushed the puzzle box from the table.
            The RBT redirected the client to place the box on a shelf.
            The client placed the box on the shelf.
            """,
            factProbes: [
                probe("F1", "puzzle box"), probe("F2", "redirect"), probe("F3", "shelf"),
            ], explicitOrder: [], ambiguousOrder: false, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [
                ("invented antecedent", #"(?i)\b(?:demand|denied access|attention)\b"#),
                ("invented reinforcer", #"(?i)\b(?:praise|token|reward|reinforc)\w*\b"#),
            ], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "G", caseClass: "QUANTITATIVE DATA",
            facts: """
            The RBT targeted Requesting Help.
            The client responded independently in 3/4 trials.
            The RBT recorded two instances of hand flapping lasting 2 minutes total.
            """,
            factProbes: [
                probe("G1", "requesting help"), probe("G2", "independent"),
                probe("G3", "hand flapping"), probe("G4", "instances"),
            ], explicitOrder: [], ambiguousOrder: false, exactValues: ["3/4", "2", "2 minutes"],
            duplicateProbe: nil, caseForbiddenPatterns: [], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "H", caseClass: "DUPLICATE / REDUNDANT FACT",
            facts: """
            The RBT used a visual schedule for the transition to an art activity.
            The RBT used a visual schedule for the transition to an art activity.
            The client entered the art room.
            """,
            factProbes: [probe("H1", "visual schedule"), probe("H2", "art")],
            explicitOrder: [], ambiguousOrder: false, exactValues: [],
            duplicateProbe: probe("H-DUP", "visual schedule"), caseForbiddenPatterns: [], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "I", caseClass: "NEGATIVE CONTROL",
            facts: """
            The client left the seat during a reading activity.
            A caregiver was present.
            """,
            factProbes: [probe("I1", "left the seat"), probe("I2", "reading"), probe("I3", "caregiver")],
            explicitOrder: [], ambiguousOrder: true, exactValues: [], duplicateProbe: nil,
            caseForbiddenPatterns: [
                ("invented intervention", #"(?i)\b(?:redirect|prompt|reinforc|praise|guided? back|visual schedule)\w*\b"#),
                ("invented outcome", #"(?i)\b(?:returned to (?:the )?seat|completed the activity|resumed reading|complied|calmed)\b"#),
            ], sparse: true
        ),
        NarrativeEvaluationCase(
            id: "J", caseClass: "RICH SESSION",
            facts: """
            The session took place in the client's home with the client's mother present.
            The client's mother reported that the client slept for 7 hours.
            At the beginning of the session, the RBT used train play for pairing.
            Following train play, the client transitioned to the kitchen and requested juice using a picture card.
            During a sorting activity, the RBT targeted Following Directions, and the client responded independently in 4/5 trials.
            The client pushed the sorting bin from the table. The RBT redirected the client to return the bin, and the client returned it to the table.
            Later in the session, the client participated in chalk play on the patio.
            Toward the end of the session, the client placed a green notebook in a backpack and said goodbye to the mother.
            """,
            factProbes: [
                probe("J1", "home"), probe("J2", "mother"), probe("J3", "7 hours"),
                probe("J4", "train"), probe("J5", "kitchen"), probe("J6", "picture card"),
                probe("J7", "following directions"), probe("J8", "4/5"), probe("J9", "sorting bin"),
                probe("J10", "redirect"), probe("J11", "chalk"), probe("J12", "patio"),
                probe("J13", "green notebook"), probe("J14", "backpack"), probe("J15", "goodbye"),
            ], explicitOrder: [
                probe("J4", "train"), probe("J5", "kitchen"), probe("J7", "following directions"),
                probe("J11", "chalk"), probe("J13", "green notebook"),
            ], ambiguousOrder: false, exactValues: ["7", "7 hours", "4/5"], duplicateProbe: nil,
            caseForbiddenPatterns: [], sparse: false
        ),
    ]

    private static func probe(_ id: String, _ alternatives: String...) -> FactProbe {
        FactProbe(id: id, alternatives: alternatives)
    }
}

private enum NarrativeEvaluator {
    private static let guardedFamilies: [(String, String)] = [
        ("pairing", #"(?i)\b(?:pairing|rapport building|built rapport)\b"#),
        ("prompting", #"(?i)\b(?:prompt(?:ed|ing|s)?|verbal cue|gestural cue|physical guidance)\b"#),
        ("redirection", #"(?i)\b(?:redirect(?:ed|ing|s)?|guided? back)\b"#),
        ("reinforcement", #"(?i)\b(?:reinforc\w*|prais\w*|reward\w*|token board)\b"#),
        ("visual support", #"(?i)\b(?:visual schedule|first[ -]then|picture card)\b"#),
        ("caregiver report", #"(?i)\b(?:reported|stated|shared that|according to)\b"#),
        ("independence", #"(?i)\b(?:independent|independently|without assistance)\b"#),
        ("progress", #"(?i)\b(?:(?:made|demonstrated|showed)\s+progress|improv\w*|regress\w*)\b"#),
        ("effectiveness", #"(?i)\b(?:effective|successfully|responded well)\b"#),
        ("future plan", #"(?i)\b(?:future session|next session|treatment plan|will continue)\b"#),
        ("missing data", #"(?i)\b(?:no|unrecorded|unavailable)\s+(?:current-session\s+)?(?:measurements?|data|outcomes?)\b"#),
        ("unsupported temporal or location scope", #"(?i)\b(?:while|where|throughout|as (?:the )?(?:client|RBT|caregiver|mother|father|grandmother))\b"#),
        ("internal fact ID", #"(?i)(?<![A-Za-z0-9])F\d{2,3}(?![A-Za-z0-9])"#),
    ]

    private static let falseChronologyPatterns: [(String, String)] = [
        ("beginning", #"(?i)\b(?:at|in) the beginning\b"#),
        ("after", #"(?i)\bafter(?:ward| this)?\b"#),
        ("following", #"(?i)\bfollowing (?:this|the|that)\b"#),
        ("then", #"(?i)\bthen\b"#),
        ("later", #"(?i)\blater (?:in|during) the session\b"#),
        ("ending", #"(?i)\b(?:toward|near) the end\b"#),
    ]

    static func evaluate(_ item: NarrativeEvaluationCase, result: SessionNoteGenerationResult) -> EvaluationRecord {
        let output = result.draft
        let present = item.factProbes.filter { contains($0, in: output) }.map(\.id)
        let omitted = item.factProbes.filter { !contains($0, in: output) }.map(\.id)

        var unsupported: [String] = []
        for (label, pattern) in guardedFamilies where matches(pattern, in: output) && !matches(pattern, in: item.facts) {
            unsupported.append(label)
        }
        for (label, pattern) in item.caseForbiddenPatterns where matches(pattern, in: output) {
            unsupported.append(label)
        }
        unsupported = Array(Set(unsupported)).sorted()

        let orderPreserved: Bool?
        if item.explicitOrder.isEmpty {
            orderPreserved = nil
        } else {
            orderPreserved = explicitChronologyIsPreserved(item, in: output)
        }

        let falseChronology = item.ambiguousOrder
            ? falseChronologyPatterns.filter { matches($0.1, in: output) }.map(\.0)
            : []
        let quantitiesPresent = item.exactValues.filter { exactToken($0, appearsIn: output) }
        let quantitiesMissing = item.exactValues.filter { !exactToken($0, appearsIn: output) }
        let duplicateCount = item.duplicateProbe.map { mentionCount(of: $0, in: output) }
        let paragraphs = output.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sentences = SessionNoteOutputSanitizer.splitSentences(output)
        let mechanicalTransitions = matchesCount(
            #"(?i)(?:^|[.!?]\s+)(?:then|after this|the (?:RBT|client) then)\b"#,
            in: output
        )
        let plainNarrative = !output.contains(";") && !matches(#"(?m)^\s*(?:[-*•]|\d+[.)]|#{1,6}\s)"#, in: output)
        let roleAttribution: Bool?
        if item.id == "E" || item.id == "J" {
            let reportingRole = item.id == "E" ? "father" : "mother"
            let reportedSubject = item.id == "E" ? "breakfast" : "7 hours"
            roleAttribution = sentences.contains { sentence in
                sentence.localizedCaseInsensitiveContains(reportingRole) &&
                sentence.localizedCaseInsensitiveContains(reportedSubject) &&
                matches(#"(?i)\b(?:reported|stated|shared)\b"#, in: sentence)
            }
        } else {
            roleAttribution = nil
        }

        return EvaluationRecord(
            id: item.id, caseClass: item.caseClass, outcome: result.outcome.rawValue, output: output,
            supportedFactsPresent: present, supportedFactsOmitted: omitted,
            factRecallNumerator: present.count, factRecallDenominator: item.factProbes.count,
            guardedUnsupportedClaims: unsupported,
            boundedFactPrecisionNumerator: present.count,
            boundedFactPrecisionDenominator: present.count + unsupported.count,
            explicitChronologyPreserved: orderPreserved,
            falseChronologyMarkers: falseChronology,
            roleAttributionPreserved: roleAttribution,
            quantitativeValuesPresent: quantitiesPresent, quantitativeValuesMissing: quantitiesMissing,
            duplicateMentionCount: duplicateCount, paragraphCount: paragraphs.count,
            sentenceCount: sentences.count, mechanicalTransitionCount: mechanicalTransitions,
            plainNarrative: plainNarrative, error: nil
        )
    }

    static func failure(_ item: NarrativeEvaluationCase, error: Error) -> EvaluationRecord {
        EvaluationRecord(
            id: item.id, caseClass: item.caseClass, outcome: "error", output: "",
            supportedFactsPresent: [], supportedFactsOmitted: item.factProbes.map(\.id),
            factRecallNumerator: 0, factRecallDenominator: item.factProbes.count,
            guardedUnsupportedClaims: [], boundedFactPrecisionNumerator: 0,
            boundedFactPrecisionDenominator: 0, explicitChronologyPreserved: nil,
            falseChronologyMarkers: [], roleAttributionPreserved: nil,
            quantitativeValuesPresent: [], quantitativeValuesMissing: item.exactValues,
            duplicateMentionCount: nil, paragraphCount: 0, sentenceCount: 0,
            mechanicalTransitionCount: 0, plainNarrative: false,
            error: String(describing: error)
        )
    }

    private static func contains(_ probe: FactProbe, in output: String) -> Bool {
        probe.alternatives.contains { output.localizedCaseInsensitiveContains($0) }
    }

    private static func firstLocation(of probe: FactProbe, in output: String) -> Int? {
        probe.alternatives.compactMap { alternative in
            output.range(of: alternative, options: .caseInsensitive).map {
                output.distance(from: output.startIndex, to: $0.lowerBound)
            }
        }.min()
    }

    private static func explicitChronologyIsPreserved(
        _ item: NarrativeEvaluationCase,
        in output: String
    ) -> Bool {
        let locations = item.explicitOrder.compactMap { firstLocation(of: $0, in: output) }
        if locations.count == item.explicitOrder.count,
           zip(locations, locations.dropFirst()).allSatisfy(<) {
            return true
        }
        guard item.id == "C" else { return false }
        let sentences = SessionNoteOutputSanitizer.splitSentences(output)
        let waterBeforeMatching = sentences.contains { sentence in
            sentence.localizedCaseInsensitiveContains("water") &&
                sentence.localizedCaseInsensitiveContains("matching cards") &&
                matches(#"(?i)\bbefore\b"#, in: sentence)
        }
        guard waterBeforeMatching,
              let bubbles = output.range(of: "bubbles", options: .caseInsensitive)?.lowerBound,
              let water = output.range(of: "water", options: .caseInsensitive)?.lowerBound,
              let yellowBook = output.range(of: "yellow book", options: .caseInsensitive)?.lowerBound else {
            return false
        }
        return bubbles < water && water < yellowBook
    }

    private static func mentionCount(of probe: FactProbe, in output: String) -> Int {
        probe.alternatives.map { alternative in
            matchesCount(NSRegularExpression.escapedPattern(for: alternative), in: output)
        }.max() ?? 0
    }

    private static func exactToken(_ value: String, appearsIn output: String) -> Bool {
        matches("(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: value) + "(?![A-Za-z0-9])", in: output)
    }

    private static func matches(_ pattern: String, in value: String) -> Bool {
        matchesCount(pattern, in: value) > 0
    }

    private static func matchesCount(_ pattern: String, in value: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: value, range: NSRange(location: 0, length: (value as NSString).length))
    }
}

@main
private struct SessionNoteNarrativeEvaluationMain {
    static func main() async throws {
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            throw NSError(domain: "SessionNoteNarrativeEvaluation", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "SystemLanguageModel unavailable: \(availability)"
            ])
        }

        let selectedIDs: Set<String>?
        if let caseIndex = CommandLine.arguments.firstIndex(of: "--case"),
           CommandLine.arguments.indices.contains(caseIndex + 1) {
            selectedIDs = Set(
                CommandLine.arguments[caseIndex + 1]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                    .filter { !$0.isEmpty }
            )
        } else {
            selectedIDs = nil
        }
        let evaluationCases = SessionNoteNarrativeCorpus.cases.filter { item in
            selectedIDs?.contains(item.id) ?? true
        }
        guard !evaluationCases.isEmpty else {
            throw NSError(domain: "SessionNoteNarrativeEvaluation", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No matching synthetic evaluation cases."
            ])
        }

        if let replayIndex = CommandLine.arguments.firstIndex(of: "--replay"),
           CommandLine.arguments.indices.contains(replayIndex + 1) {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[replayIndex + 1]))
            let previous = try JSONDecoder().decode(EvaluationReport.self, from: data)
            var rows: [[String: Any]] = []
            for record in previous.records where record.error == nil {
                guard let item = evaluationCases.first(where: { $0.id == record.id }) else { continue }
                let packet = SessionNoteEvidencePacket.make(typedFacts: item.facts, ocrEvidence: "", savedTerminologyContext: "", profileCode: nil)
                let replayDraft = CommandLine.arguments.contains("--replay-initial")
                    ? (record.modelPasses?.first?.output ?? record.output) : record.output
                let sanitized = SessionNoteOutputSanitizer.sanitize(replayDraft, scrubber: packet.scrubber)
                let initial = SessionNoteOutputValidator.validate(sanitized, evidence: packet, requireMaterialCoverage: true)
                let repaired = SessionNoteDeterministicRepairer.repair(sanitized, validation: initial, evidence: packet)
                let final = SessionNoteOutputValidator.validate(repaired.draft, evidence: packet, requireMaterialCoverage: true)
                rows.append(["id": item.id, "originalOutcome": record.outcome, "output": repaired.draft,
                             "professionallyReady": final.isProfessionallyReady, "safe": final.isSafe,
                             "issueCodes": final.issueCodes,
                             "missingFactIDs": SessionNoteMaterialCoverage.assess(repaired.draft, evidence: packet).missingFactIDs,
                             "paragraphs": repaired.draft.components(separatedBy: "\n\n").count])
            }
            let output = try JSONSerialization.data(withJSONObject: ["mode": "Captured synthetic output replay through current deterministic contracts; no model requests", "records": rows], options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(output)
            return
        }

        var records: [EvaluationRecord] = []
        for item in evaluationCases {
            var passes: [EvaluationModelPass] = []
            let packet = SessionNoteEvidencePacket.make(
                typedFacts: item.facts,
                ocrEvidence: "",
                savedTerminologyContext: "",
                profileCode: nil
            )
            do {
                let result = try await SessionNoteGenerationPipeline.generateNote(
                    packet: packet,
                    writerRole: .rbt
                ) { stage in
                    var prompt = try packet.modelPrompt(compaction: stage.compaction)
                    if case .repair(let issues, let previousDraft) = stage {
                        if #available(macOS 26.4, *) {
                            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
                            prompt = try await SessionNoteStageInstructions.repairPrompt(
                                packet: packet, issues: issues, previousDraft: previousDraft,
                                tokenCount: { try await model.tokenCount(for: $0) }
                            )
                        } else {
                            prompt = try await SessionNoteStageInstructions.repairPrompt(
                                packet: packet, issues: issues, previousDraft: previousDraft
                            )
                        }
                    }
                    let session = LanguageModelSession(
                        model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                        instructions: SessionNoteStageInstructions.instructions(for: stage)
                    )
                    let response = try await session.respond(
                        to: prompt,
                        options: GenerationOptions(maximumResponseTokens: 900)
                    )
                    let clean = SessionNoteOutputSanitizer.sanitize(response.content, scrubber: packet.scrubber)
                    passes.append(EvaluationModelPass(
                        stage: stage == .standardDraft ? "initial" : stage == .compactDraft ? "compact" : "repair",
                        output: response.content,
                        issueCodes: SessionNoteOutputValidator.validate(clean, evidence: packet, requireMaterialCoverage: true).issueCodes
                    ))
                    try SessionNoteOutputBoundary.validate(response.content)
                    return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                var record = NarrativeEvaluator.evaluate(item, result: result)
                record.modelPasses = passes
                records.append(record)
            } catch {
                var record = NarrativeEvaluator.failure(item, error: error)
                record.modelPasses = passes
                records.append(record)
            }
        }

        let formatter = ISO8601DateFormatter()
        let report = EvaluationReport(
            provider: "Apple FoundationModels SystemLanguageModel permissiveContentTransformations (Session Notes production mode)",
            modelAvailability: String(describing: availability),
            generatedAt: formatter.string(from: Date()),
            records: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        if let outputIndex = CommandLine.arguments.firstIndex(of: "--output"),
           CommandLine.arguments.indices.contains(outputIndex + 1) {
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[outputIndex + 1]), options: .atomic)
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
