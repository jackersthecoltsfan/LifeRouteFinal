import Foundation

@main
private struct SessionNoteRefinementTests {
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ label: String) {
        count += 1
        guard value() else { fatalError("Refinement assertion \(count): \(label)") }
    }
    static func packet(_ facts: String) -> SessionNoteEvidencePacket {
        .make(typedFacts: facts, ocrEvidence: "", savedTerminologyContext: "", profileCode: nil)
    }
    static let facts = """
    The session took place at home with the client, mother, sibling, RBT, and BCBA present.
    The mother reported that the client slept poorly.
    At the beginning, the RBT used bubbles and blocks for pairing.
    The BCBA modelled functional communication training using the client's AAC device to request a break.
    The RBT provided gestural prompts for break requests.
    After pairing, the RBT supported the transition to table activities with a visual schedule.
    The client engaged in hand biting twice. The RBT blocked hand biting and offered a chew tube.
    The RBT raised the observation of repeated swallowing to the BCBA.
    The session ended with free play and pairing. The RBT concluded that the client continued to need gestural prompts for break requests.
    """
    static let note = """
    The client, mother, sibling, RBT, and BCBA were present for the home session. According to the mother, the client had poor sleep. Opening pairing activities included bubbles and blocks with the RBT.

    Functional communication training was modelled by the BCBA using the client's AAC device for break requests. The RBT used gestural prompts for these requests. The RBT used a visual schedule to support the transition to table activities after pairing.

    Two episodes of hand biting occurred. The RBT blocked hand biting and offered a chew tube. Repeated swallowing was discussed with the BCBA by the RBT.

    Free play and pairing closed the session. The RBT concluded that gestural prompts remained necessary for break requests.
    """
    static func main() async throws {
        let p = packet(facts)
        let coverage = SessionNoteMaterialCoverage.assess(note, evidence: p)
        check(coverage.missingFactIDs.isEmpty, "professional paraphrase retains all material facts: \(coverage.missingFactIDs)")
        for omitted in [
            "mother, ", "sibling, ", "According to the mother, the client had poor sleep. ",
            "Functional communication training was modelled by the BCBA using the client's AAC device for break requests. ",
            "The RBT used gestural prompts for these requests. ",
            "Repeated swallowing was discussed with the BCBA by the RBT. ",
            "Free play and pairing closed the session. ",
            "The RBT concluded that gestural prompts remained necessary for break requests."
        ] {
            let incomplete = note.replacingOccurrences(of: omitted.trimmingCharacters(in: .whitespaces), with: "")
            // A role mentioned elsewhere still preserves presence except an omitted sibling.
            if omitted == "mother, " { continue }
            check(!SessionNoteMaterialCoverage.assess(incomplete, evidence: p).missingFactIDs.isEmpty, "detect omitted material clause: \(omitted)")
        }
        let wrongReport = note.replacingOccurrences(of: "According to the mother, the client had poor sleep.", with: "The mother reported that bubbles were available. The client had poor sleep.")
        check(!SessionNoteMaterialCoverage.assess(wrongReport, evidence: p).missingFactIDs.isEmpty, "report attribution stays with the reported state")
        let semicolons = "The RBT modelled a break request; the client used AAC; the RBT provided a gestural prompt."
        let result = try await SessionNoteGenerationPipeline.generateNote(packet: packet(semicolons), writerRole: .rbt, request: { _ in semicolons })
        check(!result.draft.contains(";"), "independent semicolon clauses become complete sentences")
        check(result.draft.contains(". The client"), "new sentence is capitalised")
        check(result.draft.contains("AAC"), "punctuation repair retains modality")
        let list = "The mother reported limited sleep; no breakfast; and fatigue."
        let listRepair = SessionNoteOutputSanitizer.sanitize(list, scrubber: packet(list).scrubber)
        check(!listRepair.contains(". No breakfast"), "dependent report fragments never become unattributed standalone sentences")
        let paragraphs = ["The session occurred at home.", "The RBT used bubbles for pairing.", "The client requested a break using ASL.", "The RBT supported a transition with a visual schedule.", "The client sorted blocks.", "Free play closed the session."]
        check(SessionNoteOutputSanitizer.reflow(paragraphs) == paragraphs, "six supplied topic groups are not forced into four")
        let reflowed = SessionNoteOutputSanitizer.reflow([note.replacingOccurrences(of: "\n\n", with: " ")])
        check(reflowed.count >= 3, "multi-topic note separates at session structure")
        check(reflowed.joined(separator: " ") == note.replacingOccurrences(of: "\n\n", with: " "), "paragraph repair retains exact sentence order and content")
        let synthesisFacts = "The RBT joined the client's preferred play with bubbles to build rapport. The RBT repeatedly modelled requesting a break using AAC."
        let synthesis = "The RBT used bubble play for pairing. Functional communication training included repeated RBT modelling of break requests using AAC."
        check(SessionNoteOutputValidator.validate(synthesis, evidence: packet(synthesisFacts)).hardBlockerCodes.isEmpty, "supported pairing and FCT synthesis is allowed")
        let invented = "The RBT used bubble play for pairing. Functional communication training included repeated RBT modelling of break requests using AAC. The client made progress and transitioned successfully."
        check(!SessionNoteOutputValidator.validate(invented, evidence: packet(synthesisFacts)).isSafe, "synthesis does not license outcomes or progress")
        let modalities = packet("The client requested a break using ASL. The RBT provided a verbal prompt.")
        check(!SessionNoteMaterialCoverage.assess("The client requested a break using AAC. The RBT provided a verbal prompt.", evidence: modalities).missingFactIDs.isEmpty, "ASL cannot be replaced by AAC")
        check(!SessionNoteMaterialCoverage.assess("The client independently requested a break using ASL.", evidence: modalities).missingFactIDs.isEmpty, "prompting cannot be replaced with independence")
        let negated = packet("The mother reported that the client did not sleep.")
        check(!SessionNoteMaterialCoverage.assess("The mother reported that the client slept.", evidence: negated).missingFactIDs.isEmpty, "negation retained")
        check(SessionNoteMaterialCoverage.assess("The mother stated that the client did not sleep.", evidence: negated).missingFactIDs.isEmpty, "attributed negation paraphrase accepted")
        var requests = 0
        let repaired = try await SessionNoteGenerationPipeline.generateNote(packet: p, writerRole: .rbt, request: { _ in
            requests += 1
            return requests == 1 ? note.replacingOccurrences(of: "Repeated swallowing was discussed with the BCBA by the RBT.", with: "") : note
        })
        check(requests == 2 && repaired.outcome == .repaired, "omission triggers exactly one bounded repair")
        check(repaired.draft.contains("swallowing"), "repair restores supervisor observation")
        check(repaired.completeness == .reviewRequired, "mechanical coverage never certifies clinical completeness")
        let pairs = [
            ("AAC requests were 80% correct. ASL requests were 40% correct.", "AAC requests were 40% correct. ASL requests were 80% correct."),
            ("The mother reported poor sleep and the grandmother reported a full breakfast.", "The grandmother reported poor sleep and the mother reported a full breakfast."),
            ("The BCBA modelled AAC requests. The RBT provided gestural prompts for ASL requests.", "The RBT modelled AAC requests. The BCBA provided gestural prompts for ASL requests.")
        ]
        for (source, swapped) in pairs {
            check(SessionNoteMaterialCoverage.assess(source, evidence: packet(source)).missingFactIDs.isEmpty, "local facts cover themselves")
            check(!SessionNoteMaterialCoverage.assess(swapped, evidence: packet(source)).missingFactIDs.isEmpty, "local roles, reports and measurements cannot be swapped")
        }
        for (source, reassigned) in [
            ("The RBT modelled AAC requests. The mother was present.", "The RBT was present. The mother modelled AAC requests."),
            ("The RBT modelled AAC requests. The mother was present.", "The RBT was present. AAC requests were modelled by the mother."),
            ("The RBT modelled AAC requests. The client was present.", "The RBT was present. AAC requests were modelled by the client."),
            ("Before table work, the client used AAC. After table work, the client played with blocks.", "After table work, the client used AAC. Before table work, the client played with blocks.")
        ] {
            check(!SessionNoteMaterialCoverage.assess(reassigned, evidence: packet(source)).missingFactIDs.isEmpty, "local actor and before/after relations are preserved")
            var attempts = 0
            let safe = try await SessionNoteGenerationPipeline.generateNote(packet: packet(source), writerRole: .rbt, request: { _ in attempts += 1; return reassigned })
            check(attempts == 2 && safe.outcome == .fallback && SessionNoteMaterialCoverage.assess(safe.draft, evidence: packet(source)).missingFactIDs.isEmpty, "product cannot accept role or chronology reversal as generated")
        }
        check(!SessionNoteMaterialCoverage.supportsPairing("The BCBA discussed rapport building."), "discussion alone cannot establish pairing activity")
        check(!SessionNoteMaterialCoverage.supportsPairing("The RBT planned preferred play to build rapport."), "planned pairing cannot become an observed event")
        let negativeTeaching = "The BCBA discussed communication teaching but did not model AAC requests."
        check(!SessionNoteOutputValidator.validate(negativeTeaching + " The RBT implemented FCT.", evidence: packet(negativeTeaching)).isSafe, "negated modelling cannot authorize FCT")
        for source in ["The RBT planned to model AAC requests.", "The client played with blocks. An AAC device was nearby."] {
            check(!SessionNoteMaterialCoverage.supportsCommunicationTeaching(source), "plans and device presence do not establish teaching")
        }
        let compound = "The RBT modelled an AAC request and the client selected help."
        check(SessionNoteMaterialCoverage.assess("The RBT modelled an AAC request. The client selected help.", evidence: packet(compound)).missingFactIDs.isEmpty, "independent clauses may become separate complete sentences")
        let qualified = "The RBT modelled an AAC request. The client needed a verbal prompt."
        check(SessionNoteMaterialCoverage.assess("The RBT modelled an AAC request, and the client needed a verbal prompt.", evidence: packet(qualified)).missingFactIDs.isEmpty, "a local qualifier does not contaminate another clause")
        let conclusion = "The RBT concluded that transition support remained necessary."
        check(SessionNoteMaterialCoverage.assess("In the RBT's assessment, the client continued to require transition support.", evidence: packet(conclusion)).missingFactIDs.isEmpty, "supplied assessment paraphrase is retained")
        let repeated = "The client requested help through AAC. The RBT presented a puzzle. The client requested help through AAC."
        check(SessionNoteOutputSanitizer.sanitize(repeated, scrubber: packet(repeated).scrubber) == repeated, "distinct repeated episodes separated by an event are retained")
        let late = "The RBT discussed repeated swallowing with the BCBA."
        let large = (1...38).map { "At activity \($0), the client used AAC to request a break with a gestural prompt from the RBT." }.joined(separator: " ") + " " + late
        check(large.count < 5200 && large.count > 3000, "large fixture exercises substantial allowed input")
        check(!SessionNoteMaterialCoverage.assess(large.replacingOccurrences(of: late, with: ""), evidence: packet(large)).missingFactIDs.isEmpty, "late material fact cannot disappear in a large input")
        var failedRepairCalls = 0
        let incomplete = note.replacingOccurrences(of: "Repeated swallowing was discussed with the BCBA by the RBT.", with: "")
        do {
            let fallback = try await SessionNoteGenerationPipeline.generateNote(packet: p, writerRole: .rbt, request: { _ in failedRepairCalls += 1; return incomplete })
            check(fallback.outcome == .fallback && fallback.draft.contains("swallowing"), "persistent omission yields complete fallback, never successful partial prose")
        } catch SessionNotePipelineError.rejected {
            check(true, "unsafe fallback is explicitly rejected")
        }
        check(failedRepairCalls == 2, "failed completeness repair is bounded to two model requests")
        print("Session Note refinement fixtures passed (\(count) assertions).")
    }
}
