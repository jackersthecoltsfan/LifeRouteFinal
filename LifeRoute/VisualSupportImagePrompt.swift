import Foundation

/// Model-facing artwork intent. Display labels and library metadata stay with the UI.
/// This normal generation path is text-free; it does not classify text-bearing requests.
struct VisualSupportImagePrompt: Equatable {
    let subject: String
    let visualDescription: String
    let referenceGuidance: String?
    let style = "Clean minimal illustration, high contrast, easy to recognize."
    let composition = "Single subject, centered, large in frame, no extra objects."
    let background = "Plain white background."
    let constraints = "No words, letters, numbers, captions, labels, text-bearing logos, watermarks, or UI elements."

    init(label: String, visualDescription: String, hasReference: Bool) {
        let cleanLabel = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        // Expand only this unambiguous abbreviation; preserve other concepts literally.
        subject = cleanLabel.caseInsensitiveCompare("TV") == .orderedSame ? "television" : cleanLabel
        self.visualDescription = String(visualDescription.trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        referenceGuidance = hasReference
            ? "Use the reference image only for the requested subject's identifying features."
            : nil
    }

    /// Short descriptions go directly to Apple's text concepts, without a product title
    /// or long-form extraction scaffold. User appearance data precedes fixed constraints.
    var conceptDescriptions: [String] {
        var descriptions = ["Show only \(subject)."]
        if !visualDescription.isEmpty {
            descriptions.append(visualDescription)
        }
        if let referenceGuidance {
            descriptions.append(referenceGuidance)
        }
        descriptions.append(contentsOf: [style, composition, background, constraints])
        return descriptions
    }

    /// A deterministic rendering of the exact ordered concepts for tests and review.
    var assembledPrompt: String {
        conceptDescriptions.joined(separator: " ")
    }
}
