import Foundation

@main
private struct SessionNoteBetaSafeDraftingTests {
    private static var assertions = 0

    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard value() else { fatalError("Beta-safe drafting assertion \(assertions): \(message)") }
    }

    private static func makeDraft(_ facts: String) throws -> String {
        try SessionNoteBetaSafeDeterministicDrafting.draft(from: facts)
    }

    static func main() throws {
        expect(SessionNoteBetaSafeDeterministicDrafting.mode == .betaSafeDeterministic,
               "the explicit production drafting owner is beta-safe deterministic")

        let sparse = try makeDraft("RBT met at home\nsession ended free play")
        expect(sparse == "The RBT met at home.\n\nThe session concluded with free play.",
               "sparse shorthand becomes concise professional prose with an explicit closing")

        let ordinary = try makeDraft("setting at home\nparticipants RBT, client, mom\nRBT used bubbles for pairing\nclient sorted cards")
        expect(ordinary.contains("The session took place at home."), "setting is preserved")
        expect(ordinary.contains("RBT, client, the client's mother"), "participants are professionally named without adding a role")
        expect(ordinary.contains("The RBT used bubbles for pairing."), "RBT action receives grammatical realization")
        expect(ordinary.contains("The client sorted cards."), "client action receives grammatical realization")
        let jointActivity = try makeDraft("RBT and client played blocks")
        expect(jointActivity == "The RBT and the client played blocks.",
               "joint RBT/client activity receives professional subject wording")

        let caregiver = try makeDraft("mom reported poor sleep")
        expect(caregiver == "The client's mother reported poor sleep.", "caregiver report keeps attribution")

        let chronology = try makeDraft("At the beginning, RBT used bubbles for pairing\nAfter pairing, client transitioned to table activities")
        expect(chronology.contains("At the beginning, the RBT used bubbles for pairing."), "explicit opening chronology is retained")
        expect(chronology.contains("After pairing, the client transitioned to table activities."), "explicit after relationship is retained")
        expect(!chronology.lowercased().contains("later"), "no chronology is added")

        let aac = try makeDraft("RBT modeled help on AAC")
        expect(aac == "The RBT modeled the word \"help\" using the client's AAC device.", "AAC shorthand is professionally expanded")
        let alreadyQuotedAAC = try makeDraft("RBT modeled \"help\" on AAC")
        expect(alreadyQuotedAAC == "The RBT modeled the word \"help\" using the client's AAC device.", "already-quoted AAC shorthand keeps one quote pair")
        expect(!alreadyQuotedAAC.contains("\"\"help\"\""), "already-quoted AAC shorthand is never double-wrapped")
        let singleQuotedAAC = try makeDraft("RBT modeled 'help' on AAC")
        expect(singleQuotedAAC == "The RBT modeled the word 'help' using the client's AAC device.", "single-quoted supplied wording keeps its quote intent")
        let ordinaryHelp = try makeDraft("RBT used help on AAC")
        expect(ordinaryHelp == "The RBT used help on AAC.", "unrelated unquoted wording is not given invented quotes")
        expect(!aac.contains("\"AAC\""), "only the supplied AAC term is quoted")

        let numeric = try makeDraft("client requested break 4/5 trials with verbal prompt")
        expect(numeric.contains("4/5"), "explicit measurement is retained")
        expect(numeric.contains("verbal prompt"), "explicit prompt level is retained")
        expect(!numeric.contains("80%"), "no measurement is invented")

        let serious = try makeDraft("mom reported client was assaulted by peer and had bruise on left arm\nclient went to urgent care")
        expect(serious.contains("The client's mother reported"), "serious report keeps caregiver attribution")
        expect(serious.contains("the client was assaulted"), "serious report receives grammatical client wording")
        expect(serious.contains("a bruise on left arm"), "serious injury wording is grammatical without changing the supplied detail")
        expect(serious.contains("assaulted by peer"), "serious event detail is preserved")
        expect(serious.contains("bruise on left arm"), "injury detail is preserved")
        expect(serious.contains("urgent care"), "urgent-care detail is preserved")
        expect(!serious.lowercased().contains("severity"), "no medical severity is inferred")

        let ambiguous = try makeDraft("transition outside")
        expect(ambiguous == "The session included a transition outside.", "ambiguous transition receives no invented actor")
        expect(!ambiguous.contains("The RBT transitioned"), "ambiguous transition never assigns an actor")

        let rich = try makeDraft("setting at school\nRBT and client played blocks\nclient requested help using AAC\nmom reported poor sleep\nclient engaged in hand biting twice\nsession ended reading")
        expect(rich.contains("The session took place at school."), "rich fixture retains setting")
        expect(rich.contains("The client's mother reported poor sleep."), "rich fixture retains report")
        expect(rich.contains("hand biting twice"), "rich fixture retains behavior and number")
        expect(rich.contains("The session concluded with reading."), "rich fixture retains closing activity")
        expect(rich.contains("\n\n"), "topic changes produce coherent paragraphs without a fixed count")

        let identicalFacts = "RBT modeled help on AAC\ntransition outside"
        let firstIdenticalDraft = try makeDraft(identicalFacts)
        let secondIdenticalDraft = try makeDraft(identicalFacts)
        expect(firstIdenticalDraft == secondIdenticalDraft, "identical facts yield identical drafts")

        let evidenceSamples: [(String, String)] = [
            ("sparse", "RBT met at home\nsession ended free play"),
            ("rich", "setting at school\nRBT and client played blocks\nclient requested help using AAC\nmom reported poor sleep\nclient engaged in hand biting twice\nsession ended reading"),
            ("caregiver", "mom reported poor sleep"),
            ("chronology", "At the beginning, RBT used bubbles for pairing\nAfter pairing, client transitioned to table activities"),
            ("aac", "RBT modeled help on AAC"),
            ("measurement", "client requested break 4/5 trials with verbal prompt"),
            ("serious", "mom reported client was assaulted by peer and had bruise on left arm\nclient went to urgent care"),
            ("ambiguity", "transition outside")
        ]
        for (label, facts) in evidenceSamples {
            let started = DispatchTime.now().uptimeNanoseconds
            let draft = try makeDraft(facts)
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - started
            let printableFacts = facts.replacingOccurrences(of: "\n", with: " | ")
            let printableDraft = draft.replacingOccurrences(of: "\n", with: " | ")
            print("BETA_SAFE_SAMPLE \(label) | RAW: \(printableFacts) | DRAFT: \(printableDraft) | LATENCY_NS: \(elapsedNanoseconds)")
        }

        print("Session Note beta-safe deterministic drafting fixtures passed (\(assertions) assertions).")
    }
}
