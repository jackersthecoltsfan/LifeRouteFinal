import Foundation

@main
struct VisualSupportPromptContractTests {
    private static var assertions = 0
    private static var failures = 0

    static func main() {
        let examples: [(label: String, description: String, reference: Bool, subject: String)] = [
            ("TV", "", false, "television"),
            ("Trash", "", false, "Trash"),
            ("Backpack", "", false, "Backpack"),
            ("Computer", "", false, "Computer"),
            ("Puzzle", "", true, "Puzzle"),
            ("Backpack", "Blue fabric with a red front pocket.", true, "Backpack"),
        ]

        for example in examples {
            let request = VisualSupportImagePrompt(
                label: example.label,
                visualDescription: example.description,
                hasReference: example.reference
            )
            expect(request.subject == example.subject, "\(example.label): intended subject survives")
            expect(request.conceptDescriptions.first == "Show only \(example.subject).", "\(example.label): subject only, no label-printing directive")
            expect(request.assembledPrompt.contains(example.subject), "\(example.label): assembled subject survives")
            expect(request.visualDescription == example.description, "\(example.label): user appearance survives")
            expect((request.referenceGuidance != nil) == example.reference, "\(example.label): reference mode is explicit")
            expect(request.conceptDescriptions.allSatisfy { !$0.isEmpty && $0.count <= 700 }, "\(example.label): bounded nonempty concepts")
            expect(request.conceptDescriptions.count <= 7, "\(example.label): bounded concept count")
            verifyTextFreeContract(request, context: example.label)

            // Exact ordered Apple inputs, using only synthetic fixture data.
            let evidence: [String: Any] = [
                "label": example.label, "visualDescription": example.description,
                "hasReference": example.reference, "conceptDescriptions": request.conceptDescriptions,
                "assembledPrompt": request.assembledPrompt,
            ]
            let data = try! JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys])
            print("PROMPT_EVIDENCE " + String(decoding: data, as: UTF8.self))
        }

        for label in [" tv ", "Tv", "TV\n"] {
            expect(VisualSupportImagePrompt(label: label, visualDescription: "", hasReference: false).subject == "television", "bounded TV normalization")
        }
        for label in ["TV stand", "Trash can", "sweater", "bedside lamp", "outdoor backpack", "water play", "outside", "break", "help", "more", "bathroom", "eat", "sleep"] {
            let request = VisualSupportImagePrompt(label: label, visualDescription: "", hasReference: false)
            expect(request.subject == label, "literal concept, no substring substitution: \(label)")
            expect(!request.assembledPrompt.contains("child"), "no invented child scene: \(label)")
        }

        let described = VisualSupportImagePrompt(label: "  Computer\n", visualDescription: "  Green case for outdoor use.\n", hasReference: true)
        expect(described.subject == "Computer", "trim label without altering display storage")
        expect(described.visualDescription == "Green case for outdoor use.", "description keyword cannot replace subject or discard appearance")
        expect(described.conceptDescriptions.contains("Green case for outdoor use."), "description reaches the Apple concept list")
        expect(described.referenceGuidance == "Use the reference image only for the requested subject's identifying features.", "reference is limited to intended subject")
        verifyTextFreeContract(described, context: "described reference")

        let blank = VisualSupportImagePrompt(label: "TV", visualDescription: " \n\t ", hasReference: false)
        expect(blank.visualDescription.isEmpty && blank.conceptDescriptions.count == 5, "empty description adds no fallback or helper copy")
        let bounded = VisualSupportImagePrompt(label: String(repeating: "x", count: 140), visualDescription: String(repeating: "y", count: 800), hasReference: true)
        expect(bounded.subject.count == 120, "existing subject bound preserved")
        expect(bounded.visualDescription.count == 700, "existing description bound preserved")
        expect(bounded.conceptDescriptions.count == 7, "long inputs cannot add concept entries")
        verifyTextFreeContract(bounded, context: "bounded reference")

        // The builder has no mutable cross-request state. Regenerate/edit uses the same contract.
        let original = VisualSupportImagePrompt(label: "TV", visualDescription: "", hasReference: true)
        let regenerated = VisualSupportImagePrompt(label: "TV", visualDescription: "", hasReference: true)
        let edited = VisualSupportImagePrompt(label: "Backpack", visualDescription: "Red fabric.", hasReference: false)
        expect(original == regenerated, "regeneration keeps identical request intent")
        expect(edited.subject == "Backpack" && edited.referenceGuidance == nil, "edited request has no stale subject/reference")
        expect(!edited.assembledPrompt.contains("television"), "previous request cannot leak into edited request")

        print("Visual support prompt contracts: \(assertions) assertions, \(failures) failures.")
        if failures > 0 { exit(1) }
    }

    private static func verifyTextFreeContract(_ request: VisualSupportImagePrompt, context: String) {
        let prompt = request.assembledPrompt.lowercased()
        expect(prompt.contains("single subject, centered, large in frame, no extra objects"), "\(context): object composition contract")
        expect(prompt.contains("clean minimal illustration, high contrast, easy to recognize"), "\(context): recognition style contract")
        expect(prompt.contains("plain white background"), "\(context): minimal background contract")
        expect(prompt.contains("no words, letters, numbers, captions, labels, text-bearing logos, watermarks, or ui elements"), "\(context): explicit default no-text constraint")
        expect(request.conceptDescriptions.last == "No words, letters, numbers, captions, labels, text-bearing logos, watermarks, or UI elements.", "\(context): no-text policy follows user input")
        for forbidden in ["aba", "child-readable", "child-friendly", "visual support", "visual-support", "icon for", "exact user label", "functional concept:", "liferoute", "general", "choice boards", "first/then", "optional visual description", "exact icon label", "describe only what helps", "master"] {
            expect(!prompt.contains(forbidden), "\(context): no injected product/helper text: \(forbidden)")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { failures += 1; print("FAIL: \(message)") }
    }
}
