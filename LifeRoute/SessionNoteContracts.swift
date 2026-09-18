import Foundation

// Shared evidence and style policy is composed into every production stage.
enum SessionNoteClinicalInstructions {
    static let sharedConstraints = """
    Use person-first, objective third-person wording and role-based identity only: the client, RBT, LBS, BCBA, BHT, and caregiver relationship roles. Keep caregiver reports attributed to the exact supplied relationship role and keep each report adjacent to the reported fact; never turn a report into direct observation or replace a supplied mother, father, grandmother, parent, or caregiver role with another role.
    Preserve every clinically relevant supplied fact exactly once unless the evidence clearly describes distinct repeated occurrences. This includes location, attendees, pairing, targets, transitions, prompting, reinforcement, behaviors of concern, intervention, observable outcome, caregiver collaboration, and LBS/BCBA instruction when present. Include a behavior of concern only when evidence says it occurred. Say “behaviors of concern.”
    Integrate every clear current-session measurement exactly once beside its matching target or behavior. Preserve target association, measurement type, numeric value, unit, prompt level, and attribution. Exclude administrative screenshot content. Saved terminology is context only, never session evidence.
    Never invent function, intent, emotion, cause, progress, training, supervision, treatment changes, recommendations, effectiveness, or causal relationships. Preserve explicitly supplied conclusions with their attribution and qualifications. Conservative synthesis may group preferred play explicitly used to build rapport as pairing, consolidate repeated teaching or modelling of communication requests as FCT, and describe explicitly supported movement between activities as transition support. Such synthesis must retain the actual activities, communication modality, prompting, and actors; it never establishes an outcome or treatment effect.
    Improve grammar, possessives, role clarity, sentence structure, transitions, and organization while preserving supplied meaning. Use chronology only when supported by explicit sequence words, times, or stated before/after relationships. A fact ledger's display order is bookkeeping, not timeline evidence. When order is unknown, group related facts coherently without adding first/then/after/later relationships or while/as/when/where/throughout relationships. Expand unambiguous abbreviations, such as functional communication training (FCT). Retain qualifications and attribution; clinical terminology is not a reason to remove a supplied fact.
    Write natural, useful prose with detail proportional to the evidence. Sparse evidence may be one short cohesive paragraph, with no minimum word, sentence, or paragraph count. Develop richer evidence into substantive paragraphs: make setting, participants, and the beginning clear; connect supplied interventions, activities, transitions, and community work in order; describe supplied behaviors, responses, reinforcement, and the session ending in context. Use these groups only where the facts exist and chronology allows; never require a fixed paragraph count. Expand shorthand into complete professional sentences and meaningfully connect related events instead of compressing a rich session into a few short sentences or converting each bullet mechanically. Do not repeat facts or add generic sentences to fill space.
    Preserve a supplied qualitative response at its original specificity; it does not establish broader engagement, participation throughout the session, independent performance, improvement, or successful transitions. Do not invent prompting, reinforcement, redirection, caregiver involvement beyond presence, treatment-plan compliance, future plans, missing-data claims, or statements that no measurements or outcomes were recorded. Include these only when explicitly supplied, with their original qualifications and attribution. End when the supplied facts have been expressed; no mandatory summary or future-treatment-plan close.
    Use complete professional sentences, periods instead of semicolon chains, and varied sentence openings. Separate distinct session topics into readable paragraphs at supported changes in activity or focus; preserve related reports and their attribution together. Do not force a paragraph count or headings. Retain supplied session conclusions and closing activities, including observations raised to the BCBA. Return the complete session narrative only, without a standard closing sentence or writer credential. Finish every sentence within the response budget; do not sacrifice the ending to lengthen the prose. Return editable narrative paragraphs only, without headings, lists, markdown, fact IDs, template language, disclaimers, or commentary.
    """
}

enum SessionNoteBoundaryError: LocalizedError, Equatable {
    case typedFactsOverLimit(Int)
    case measurementSectionOverLimit(Int)
    case quantitativeSectionOverLimit(Int)
    case attachmentLimit
    case outputCharacterLimit
    case unfinishedOutput
    case writerRoleRequired

    var statusTitle: String {
        switch self {
        case .outputCharacterLimit, .unfinishedOutput: return "Incomplete output rejected"
        case .writerRoleRequired: return "Writer role required"
        default: return "Evidence exceeds the note limit"
        }
    }

    var diagnosticCode: String {
        switch self {
        case .typedFactsOverLimit: return "typedFactsOverLimit"
        case .measurementSectionOverLimit: return "measurementSectionOverLimit"
        case .quantitativeSectionOverLimit: return "quantitativeSectionOverLimit"
        case .attachmentLimit: return "attachmentLimit"
        case .outputCharacterLimit: return "outputCharacterLimit"
        case .unfinishedOutput: return "unfinishedOutput"
        case .writerRoleRequired: return "writerRoleRequired"
        }
    }

    var errorDescription: String? {
        let detail: String
        switch self {
        case .typedFactsOverLimit(let count):
            detail = "Session facts contain \(count) characters; this note request supports up to 5200. Shorten the request yourself before generating."
        case .measurementSectionOverLimit(let limit):
            detail = "The complete measurements cannot fit this generation step's \(limit)-character evidence section. No shortened measurement records were used. Reduce the evidence in this request before trying again."
        case .quantitativeSectionOverLimit(let limit):
            detail = "The complete supporting quantitative evidence cannot fit this generation step's \(limit)-character section. No shortened evidence was used."
        case .attachmentLimit:
            detail = "A note request supports up to six screenshots. Choose no more than six before trying again."
        case .outputCharacterLimit:
            detail = "The model response reached the note's output size limit. LifeRoute cannot verify that it finished, so this attempt was rejected."
        case .unfinishedOutput:
            detail = "The model response ended without final sentence punctuation and may contain an unfinished clause. This attempt was rejected; adding punctuation would not establish completeness."
        case .writerRoleRequired:
            detail = "Your saved profile credential must explicitly identify RBT, BHT, BT, or ABA Therapist before a note can be generated. Check Profile & Work in Setup. A credential ID alone does not establish the writer role."
        }
        return detail + " Your complete facts and previous draft were preserved."
    }
}

enum SessionNoteWriterRole: String, CaseIterable {
    case rbt = "RBT"
    case bht = "BHT"
    case bt = "BT"
    case abaTherapist = "ABA Therapist"

    // Existing Setup > Profile & Work storage. The optional credential ID is not
    // itself a role; only an explicit, unambiguous label can establish one.
    static let profileCredentialKey = "liferoute.rbtProfile.credential"

    static func resolve(profileCredential: String) throws -> Self {
        let label = profileCredential.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ").lowercased()
        switch label {
        case "rbt", "registered behavior technician": return .rbt
        case "bht", "behavioral health technician": return .bht
        case "bt", "behavior technician": return .bt
        case "aba therapist", "applied behavior analysis therapist": return .abaTherapist
        default: throw SessionNoteBoundaryError.writerRoleRequired
        }
    }
}

enum SessionNoteStandardClosing {
    private static let action = "will continue to maintain pairing and rapport with the client, implement skill acquisition and behavior reduction protocols as written, and consult the supervising clinician regarding any questions, concerns, or barriers to progress."

    static func sentence(for role: SessionNoteWriterRole) -> String {
        "\(role.rawValue) \(action)"
    }

    static func isPresent(in body: String) -> Bool {
        // Keep this blocker through the existing clinician-to-role normalization.
        // Matching the full sentence would lose it when that formatter edits its tail.
        body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .localizedCaseInsensitiveContains("will continue to maintain pairing and rapport with the client")
    }
}

enum SessionNoteInputBounds {
    static func validateTypedFacts(characterCount: Int) throws {
        if characterCount > 5_200 { throw SessionNoteBoundaryError.typedFactsOverLimit(characterCount) }
    }
}

// MARK: - Beta-safe deterministic drafting

/// The single production drafting policy for the beta. This is intentionally not
/// exposed as a user setting: normal Session Note drafting must remain local and
/// deterministic until a separately-qualified production path replaces it.
enum SessionNoteDraftingMode: Equatable {
    case betaSafeDeterministic
}

enum SessionNoteBetaSafeDraftingError: LocalizedError, Equatable {
    case emptyDraft
    case numericGroundingFailed
    case chronologyGroundingFailed

    var errorDescription: String? {
        switch self {
        case .emptyDraft:
            return "LifeRoute could not form a draft from those session facts. Your facts and previous draft were preserved."
        case .numericGroundingFailed, .chronologyGroundingFailed:
            return "LifeRoute kept the session facts unchanged because a beta drafting safety check could not be completed."
        }
    }
}

/// A deliberately small, fact-preserving realization pass. It does not infer
/// missing actors, outcomes, interventions, or order. Its only job is to turn
/// supplied units into readable, editable professional sentences and paragraphs.
enum SessionNoteBetaSafeDeterministicDrafting {
    static let mode: SessionNoteDraftingMode = .betaSafeDeterministic

    static func draft(from narrative: String) throws -> String {
        let source = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw SessionNoteBetaSafeDraftingError.emptyDraft }

        var paragraphs: [[String]] = [[]]
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                if !(paragraphs.last?.isEmpty ?? true) { paragraphs.append([]) }
                continue
            }

            for unit in sentenceUnits(from: line) {
                let sentence = realize(unit)
                guard !sentence.isEmpty else { continue }
                if shouldBeginNewParagraph(before: sentence, existing: paragraphs[paragraphs.count - 1]) {
                    paragraphs.append([])
                }
                paragraphs[paragraphs.count - 1].append(sentence)
            }
        }

        let result = paragraphs
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw SessionNoteBetaSafeDraftingError.emptyDraft }
        try validateGrounding(draft: result, source: source)
        return result
    }

    private static func sentenceUnits(from line: String) -> [String] {
        let trimmed = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-•* "))
        guard !trimmed.isEmpty else { return [] }

        var units: [String] = []
        var current = ""
        for character in trimmed {
            current.append(character)
            if ".!?".contains(character) {
                let candidate = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty { units.append(candidate) }
                current = ""
            }
        }
        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { units.append(remainder) }
        return units.isEmpty ? [trimmed] : units
    }

    private static func realize(_ rawUnit: String) -> String {
        let raw = rawUnit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-•* "))
        guard !raw.isEmpty else { return "" }
        let withoutTerminal = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        let lower = withoutTerminal.lowercased()

        if lower == "transition outside" {
            return "The session included a transition outside."
        }
        if lower.hasPrefix("session ended ") || lower.hasPrefix("session ended with ") {
            let activity = withoutTerminal
                .replacingOccurrences(of: "session ended with ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "session ended ", with: "", options: .caseInsensitive)
            return "The session concluded with \(activity)."
        }
        if lower.hasPrefix("closing activity ") {
            let activity = String(withoutTerminal.dropFirst("closing activity ".count))
            return "The session concluded with \(activity)."
        }
        if lower.hasPrefix("mom reported ") {
            let report = reportedClause(String(withoutTerminal.dropFirst("mom reported ".count)))
            return "The client's mother reported \(report)."
        }
        if lower.hasPrefix("caregiver reported ") {
            return "The caregiver reported \(String(withoutTerminal.dropFirst("caregiver reported ".count)))."
        }
        if lower.hasPrefix("rbt modeled ") && lower.hasSuffix(" on aac") {
            let beginning = String(withoutTerminal.dropFirst("RBT modeled ".count))
            let content = String(beginning.dropLast(" on AAC".count))
            if !content.contains(" ") {
                return "The RBT modeled the word \"\(content)\" using the client's AAC device."
            }
            return "The RBT modeled \(content) using the client's AAC device."
        }
        if lower.hasPrefix("setting ") {
            return "The session took place \(String(withoutTerminal.dropFirst("setting ".count)))."
        }
        if lower.hasPrefix("participants ") {
            let list = String(withoutTerminal.dropFirst("participants ".count))
            return "The following participants were present: \(professionalizeParticipantList(list))."
        }
        if lower == "free play" || lower == "pairing" || lower == "table activities" {
            return "The session included \(withoutTerminal)."
        }

        let expanded = expandLeadingRole(in: withoutTerminal)
        return finishSentence(expanded)
    }

    private static func expandLeadingRole(in source: String) -> String {
        var normalized = source
            .replacingOccurrences(of: ", RBT ", with: ", the RBT ", options: .caseInsensitive)
            .replacingOccurrences(of: ", client ", with: ", the client ", options: .caseInsensitive)
        if normalized.lowercased().hasPrefix("at beginning,") {
            normalized = "At the beginning," + normalized.dropFirst("At beginning,".count)
        }
        let lower = normalized.lowercased()
        if lower.hasPrefix("rbt and client") {
            return "The RBT and the client" + normalized.dropFirst("RBT and client".count)
        }
        if lower.hasPrefix("rbt ") {
            return "The RBT " + normalized.dropFirst(4)
        }
        if lower.hasPrefix("client ") {
            return "The client " + normalized.dropFirst(7)
        }
        if lower.hasPrefix("mom ") {
            return "The client's mother " + normalized.dropFirst(4)
        }
        if lower.hasPrefix("mother ") {
            return "The client's mother " + normalized.dropFirst(7)
        }
        if lower.hasPrefix("father ") {
            return "The client's father " + normalized.dropFirst(7)
        }
        if lower.hasPrefix("bcba ") {
            return "The BCBA " + normalized.dropFirst(5)
        }
        return normalized
    }

    private static func reportedClause(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("client ") else { return trimmed }
        return ("the client " + trimmed.dropFirst("client ".count))
            .replacingOccurrences(of: " had bruise ", with: " had a bruise ", options: .caseInsensitive)
    }

    private static func professionalizeParticipantList(_ list: String) -> String {
        list.components(separatedBy: ",").map { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.caseInsensitiveCompare("mom") == .orderedSame ? "the client's mother" : trimmed
        }.joined(separator: ", ")
    }

    private static func finishSentence(_ source: String) -> String {
        let compact = source
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = compact.first else { return "" }
        let capitalized = String(first).uppercased() + compact.dropFirst()
        return capitalized.hasSuffix(".") || capitalized.hasSuffix("!") || capitalized.hasSuffix("?")
            ? capitalized
            : capitalized + "."
    }

    private static func shouldBeginNewParagraph(before sentence: String, existing: [String]) -> Bool {
        guard !existing.isEmpty else { return false }
        let lower = sentence.lowercased()
        // These topic changes are explicitly represented by the sentence itself;
        // they do not impose a fixed paragraph count or infer an event order.
        return lower.hasPrefix("the client's mother reported")
            || lower.hasPrefix("the caregiver reported")
            || lower.hasPrefix("the session concluded")
    }

    private static func validateGrounding(draft: String, source: String) throws {
        let numericPattern = #"\b\d+(?:\.\d+)?(?:\s*/\s*\d+)?%?\b"#
        let expression = try! NSRegularExpression(pattern: numericPattern)
        let range = NSRange(draft.startIndex..., in: draft)
        for match in expression.matches(in: draft, range: range) {
            guard let swiftRange = Range(match.range, in: draft) else { continue }
            guard source.contains(String(draft[swiftRange])) else {
                throw SessionNoteBetaSafeDraftingError.numericGroundingFailed
            }
        }

        let sourceLower = source.lowercased()
        let draftLower = draft.lowercased()
        let chronologyRequirements: [(draft: String, source: [String])] = [
            ("later", ["later"]),
            ("after", ["after"]),
            ("before", ["before"]),
            ("while", ["while"]),
            ("concluded", ["ended", "concluded", "closing"])
        ]
        for requirement in chronologyRequirements where draftLower.contains(requirement.draft) {
            guard requirement.source.contains(where: sourceLower.contains) else {
                throw SessionNoteBetaSafeDraftingError.chronologyGroundingFailed
            }
        }
    }
}

enum SessionNoteOutputCompleteness: Equatable {
    // The adapter supplies no completion-limit/finish-reason signal. Safety/format checks
    // cannot establish semantic coverage, even when the response ends with a period.
    case reviewRequired

    var message: String {
        "This draft may be incomplete. Compare every supplied fact and measurement with the draft before use; the model may omit details or stop at its response limit."
    }
}

enum SessionNoteOutputBoundary {
    static func validate(_ raw: String) throws {
        if raw.count >= 8_000 { throw SessionNoteBoundaryError.outputCharacterLimit }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty responses retain the existing single repair/fallback path.
        if let last = trimmed.last, !".!?".contains(last) {
            throw SessionNoteBoundaryError.unfinishedOutput
        }
    }
}

struct SessionNoteRecognizedScreenshot: Equatable {
    let text: String
    let exceededTextLimit: Bool

    static func bounded(_ raw: String) -> SessionNoteRecognizedScreenshot {
        // Never extract measurements from an arbitrarily shortened OCR prefix.
        let exceeded = raw.count > 12_000
        return SessionNoteRecognizedScreenshot(text: exceeded ? "" : raw, exceededTextLimit: exceeded)
    }
}

struct SessionNoteExtractionSummary: Equatable {
    let attachmentCount: Int
    let measurementCount: Int
    let attachmentsWithoutReadableMeasurements: Int
    let attachmentsExceedingTextLimit: Int

    static func make(
        screenshots: [SessionNoteRecognizedScreenshot],
        measurements: [SessionNoteMeasurementEvidence]
    ) -> SessionNoteExtractionSummary {
        SessionNoteExtractionSummary(
            attachmentCount: screenshots.count,
            measurementCount: measurements.count,
            // Count per image before cross-image deduplication: a duplicate readable image
            // must not be described as unreadable just because its values were already seen.
            attachmentsWithoutReadableMeasurements: screenshots.filter {
                SessionNoteOCRMeasurementExtractor.extract(from: [$0.text]).isEmpty
            }.count,
            attachmentsExceedingTextLimit: screenshots.filter(\.exceededTextLimit).count
        )
    }

    var message: String {
        guard attachmentCount > 0 else { return "No screenshots were included in this attempt." }
        let status = measurementCount == 0 ? "No readable measurements extracted." :
            (attachmentsWithoutReadableMeasurements > 0 ? "Mixed extraction." : "Measurements extracted; image review required.")
        let limit = attachmentsExceedingTextLimit == 0 ? "" :
            " \(attachmentsExceedingTextLimit) attachment(s) exceeded the text-reading limit and contributed no measurements."
        return "\(status) \(measurementCount) distinct measurement(s) read from \(attachmentCount) attachment(s); \(attachmentsWithoutReadableMeasurements) attachment(s) yielded no readable measurements.\(limit) Check every image for missed values. This does not mean an image contained no measurements."
    }
}

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
    let originalTypedCharacterCount: Int
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
            originalTypedCharacterCount: typedFacts.count,
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

    func validateBounds(compaction: SessionNoteRequestCompaction) throws {
        try SessionNoteInputBounds.validateTypedFacts(characterCount: max(originalTypedCharacterCount, typedFacts.count))
        let limit = compaction == .standard ? 1_600 : 900
        if structuredMeasurements.map(\.promptLine).joined(separator: "\n").count > limit {
            throw SessionNoteBoundaryError.measurementSectionOverLimit(limit)
        }
        if quantitativeOCR.count > limit {
            throw SessionNoteBoundaryError.quantitativeSectionOverLimit(limit)
        }
    }

    func modelPrompt(compaction: SessionNoteRequestCompaction) throws -> String {
        try validateBounds(compaction: compaction)
        let context = compaction == .standard ? savedTerminologyContext : ""
        let measurementLines = structuredMeasurements
            .map(\.promptLine)
            .joined(separator: "\n")
        var sections = [
            """
            REQUIRED FACT LEDGER — reconstruct every F-ID as supplied factual evidence. IDs and display order are not chronology and must not appear in the note:
            \(SessionNoteEvidenceNormalizer.factLedger(from: typedFacts))
            """
        ]
        if !measurementLines.isEmpty {
            sections.append("""
            CLEAR CURRENT-SESSION MEASUREMENTS — integrate every entry and keep each target, type, value, unit, and prompt level associated exactly:
            \(measurementLines)
            """)
        }
        if !quantitativeOCR.isEmpty {
            sections.append("""
            OTHER CLEAR QUANTITATIVE OCR — supporting evidence only; never use administrative screenshot content:
            \(quantitativeOCR)
            """)
        }
        if !context.isEmpty {
            sections.append("""
            NEUTRAL TERMINOLOGY CONTEXT — never evidence that an event occurred:
            \(String(context.prefix(280)))
            """)
        }
        sections.append("""
        PROFESSIONAL RECONSTRUCTION REQUIREMENTS:
        - Silently account for every F-ID before drafting. Express every material fact once, while retaining distinct repeated occurrences when the evidence distinguishes them. Do not output IDs or an accounting list.
        - Preserve each reporting relationship exactly and keep the report attribution in the same sentence as the reported fact. Do not generalize a supplied mother, father, grandmother, parent, or caregiver into a different role.
        - Do not copy conversational transitions or preserve the source clause structure. Rebuild each event with its supplied actor in objective ABA documentation language. Express generic work only as instructional activities or a work period; do not invent its content.
        - Reorder only from explicit sequence words, times, or stated before/after relationships inside the facts. Fact-ID order alone proves nothing. If exact order is unknown, use non-temporal grouping and do not add first, then, after, following, later, beginning, ending, while, as, when, where, or throughout claims.
        - Connect supported opening, setting, reports, activities, interventions, observable responses, transitions, and closing events into a natural session flow. Do not create a missing event merely to bridge two supplied facts.
        - Use the shared evidence-proportional style guidance; a concise single paragraph is acceptable. Integrate each measurement in the sentence about its matching target or behavior; never append a detached data list.
        - Empty evidence categories are omitted from this request. Do not mention absent, unavailable, unrecorded, or nonexistent measurements, data, interventions, outcomes, or behaviors unless an F-ID explicitly states that absence.
        - End after the supplied facts. Do not append generic participation, session-continuation, unsupported summary, treatment-plan, or future-plan sentences. Retain supplied conclusions and closing activities with their original qualifications and attribution.
        """)
        return sections.joined(separator: "\n\n")
    }
}

enum SessionNotePipelineStage: Equatable {
    case standardDraft
    case compactDraft
    case repair([String], previousDraft: String = "")

    var compaction: SessionNoteRequestCompaction {
        self == .standardDraft ? .standard : .compactRetry
    }
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
        case .generated: return "Draft requires review"
        case .repaired: return "Repaired draft requires review"
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
    let extractionSummary: SessionNoteExtractionSummary?
    let completeness: SessionNoteOutputCompleteness

    init(
        draft: String,
        outcome: SessionNoteFinalOutcome,
        issueCodes: [String],
        diagnostics: SessionNoteDiagnosticReceipt = SessionNoteDiagnosticReceipt(events: []),
        extractionSummary: SessionNoteExtractionSummary? = nil,
        completeness: SessionNoteOutputCompleteness = .reviewRequired
    ) {
        self.draft = draft
        self.outcome = outcome
        self.issueCodes = issueCodes
        self.diagnostics = diagnostics
        self.extractionSummary = extractionSummary
        self.completeness = completeness
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
    // Product entry point. The existing pipeline accepts the evidence-bound narrative,
    // including raw-output boundaries, deterministic repair, one model repair,
    // and safe fallback/rejection. Nothing appends unsupported boilerplate.
    static func generateNote(
        packet: SessionNoteEvidencePacket,
        writerRole _: SessionNoteWriterRole,
        request: @escaping (SessionNotePipelineStage) async throws -> String,
        progress: @escaping (SessionNotePipelineEvent) async -> Void = { _ in },
        diagnostic: @escaping (SessionNotePipelineDiagnosticEvent) -> Void = { _ in }
    ) async throws -> SessionNoteGenerationResult {
        let narrative = try await generate(
            packet: packet, request: request, progress: progress, diagnostic: diagnostic,
            enforceMaterialCoverage: true
        )
        try Task.checkCancellation()
        try SessionNoteOutputBoundary.validate(narrative.draft)
        return narrative
    }

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
        diagnostic: @escaping (SessionNotePipelineDiagnosticEvent) -> Void = { _ in },
        enforceMaterialCoverage: Bool = false
    ) async throws -> SessionNoteGenerationResult {
        var diagnosticEvents: [SessionNotePipelineDiagnosticEvent] = []
        func record(_ event: SessionNotePipelineDiagnosticEvent) {
            diagnosticEvents.append(event)
            diagnostic(event)
        }

        // Enforce bounds even for injected model adapters; no stage receives a prefix.
        func boundedRequest(_ stage: SessionNotePipelineStage) async throws -> String {
            try Task.checkCancellation()
            try packet.validateBounds(compaction: stage.compaction)
            let raw = try await request(stage)
            try Task.checkCancellation()
            try SessionNoteOutputBoundary.validate(raw)
            return raw
        }

        let firstRawDraft: String
        do {
            firstRawDraft = try await boundedRequest(.standardDraft)
        } catch SessionNotePipelineError.contextTooLarge {
            await progress(.compacting)
            firstRawDraft = try await boundedRequest(.compactDraft)
        }

        let firstSanitization = SessionNoteOutputSanitizer.sanitizeWithReport(
            firstRawDraft,
            scrubber: packet.scrubber
        )
        let firstValidation = SessionNoteOutputValidator.validate(firstSanitization.draft, evidence: packet, requireMaterialCoverage: enforceMaterialCoverage)
        record(.initialIssueCodes(firstValidation.issueCodes))
        let firstRepair = SessionNoteDeterministicRepairer.repair(
            firstValidation.draft,
            validation: firstValidation,
            evidence: packet
        )
        record(.deterministicRepairCodes(
            Array(Set(firstSanitization.appliedIssueCodes + firstRepair.appliedIssueCodes)).sorted()
        ))
        let normalizedValidation = SessionNoteOutputValidator.validate(firstRepair.draft, evidence: packet, requireMaterialCoverage: enforceMaterialCoverage)
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
        let repairedRawDraft = try await boundedRequest(.repair(
            normalizedValidation.boundedModelRepairInstructions,
            previousDraft: normalizedValidation.draft
        ))
        let repairedSanitization = SessionNoteOutputSanitizer.sanitizeWithReport(
            repairedRawDraft,
            scrubber: packet.scrubber
        )
        let repairedInitialValidation = SessionNoteOutputValidator.validate(repairedSanitization.draft, evidence: packet, requireMaterialCoverage: enforceMaterialCoverage)
        let repairedDeterministic = SessionNoteDeterministicRepairer.repair(
            repairedInitialValidation.draft,
            validation: repairedInitialValidation,
            evidence: packet
        )
        record(.deterministicRepairCodes(
            Array(Set(repairedSanitization.appliedIssueCodes + repairedDeterministic.appliedIssueCodes)).sorted()
        ))
        let repairedValidation = SessionNoteOutputValidator.validate(repairedDeterministic.draft, evidence: packet, requireMaterialCoverage: enforceMaterialCoverage)
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

        if let fallback = SessionNoteConservativeFallback.make(from: packet, requireMaterialCoverage: enforceMaterialCoverage) {
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
    static func factLedger(from value: String) -> String {
        let units = distinctFactUnits(from: value)
        guard !units.isEmpty else { return "[no factual entries supplied]" }
        return units.enumerated().map { index, unit in
            String(format: "F%02d | %@", index + 1, unit)
        }.joined(separator: "\n")
    }

    static func deduplicatedFacts(from value: String) -> String {
        distinctFactUnits(from: value).joined(separator: "\n")
    }

    static func distinctFactUnits(from value: String) -> [String] {
        let units = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isNewline)
            .flatMap { SessionNoteMaterialCoverage.clauses(String($0)) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var previous: String?
        return units.filter { unit in
            let key = unit.lowercased()
            defer { previous = key }
            return key != previous
        }
    }

    static func typedFacts(_ value: String) -> String {
        let normalized = normalizeLines(value, removeAmbiguousOCR: false)
        return ABATerminologyNormalizer.normalize(normalized)
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
        return lines.joined(separator: "\n")
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
            let pattern = level == "independent" ? "independent(?:ly)?" : NSRegularExpression.escapedPattern(for: level)
            return lower.range(
                of: "(?<![A-Za-z])\(pattern)(?![A-Za-z])",
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

// A bounded omission screen over the same fact units sent to the model. It is
// deliberately not a semantic proof: aliases allow ordinary paraphrase, local
// anchors protect attribution/modality, and uncertain coverage uses the existing
// single repair path. Every presented draft still requires human fact review.
struct SessionNoteMaterialCoverage {
    let factCount: Int
    let missingFactIDs: [String]

    static func assess(_ draft: String, evidence: SessionNoteEvidencePacket) -> Self {
        let facts = SessionNoteEvidenceNormalizer.distinctFactUnits(from: evidence.typedFacts)
        let sentences = draft.components(separatedBy: "\n\n").flatMap { clauses($0) + [""] }
        var candidates = sentences
        for (first, second) in zip(sentences, sentences.dropFirst()) {
            // Only explicit continuation can inherit a subject/report. Do not
            // allow an unrelated sentence to supply the missing attribution.
            if second.range(of: #"(?i)^(?:these|this|such|the same|the RBT used .*these|the client also)\b"#, options: .regularExpression) != nil {
                candidates.append(first + " " + second)
            }
        }
        let staffRoles: Set<String> = ["rbt", "bcba", "lbs", "bht"]
        var precedingStaff: Set<String> = []
        let targetTokens = candidates.map { candidate -> Set<String> in
            if candidate.isEmpty { precedingStaff = []; return [] }
            var result = tokens(candidate)
            let explicitActor = candidate.range(of: #"(?i)^(?:the\s+)?(?:client|mother|father|grandmother|grandfather|caregiver|parent|sibling|brother|sister)\b"#, options: .regularExpression) != nil
            let anotherActor = !result.intersection(["mother", "father", "grandmother", "grandfather", "caregiver", "parent", "sibling", "brother", "sister"]).isEmpty
                || matches(#"\bby (?:the )?client\b"#, in: candidate)
            let explicitStaff = result.intersection(staffRoles)
            if explicitStaff.isEmpty, precedingStaff.count == 1, !result.contains("report"), !explicitActor, !anotherActor {
                result.formUnion(precedingStaff)
            }
            if explicitActor || anotherActor { precedingStaff = [] }
            if !explicitStaff.isEmpty { precedingStaff = explicitStaff }
            return result
        }
        let missing = facts.enumerated().compactMap { index, fact -> String? in
            let required = tokens(fact)
            guard !required.isEmpty else { return nil }
            let anchors = required.intersection(protectedTokens).union(required.filter { Double($0) != nil })
            // An opening attendee list may naturally become a context sentence
            // followed by a family-presence sentence. This exception supplies no
            // actor/action evidence and never applies to intervention or reports.
            if matches(#"\bpresent\b"#, in: fact),
               !matches(#"\b(?:reported|modelled|modeled|provided|used|left|arrived|before|after)\b"#, in: fact) {
                let opening = tokens(draft.components(separatedBy: "\n\n").first ?? "")
                if anchors.isSubset(of: opening), required.subtracting(protectedTokens).isSubset(of: opening) {
                    return nil
                }
            }
            let covered = targetTokens.contains { candidate in
                guard anchors.isSubset(of: candidate) else { return false }
                // A negation or a need/assessment claim cannot substitute for an
                // observed occurrence, even if all the activity words remain.
                for qualifier in ["not", "need", "conclude"] {
                    if required.contains(qualifier) != candidate.contains(qualifier) { return false }
                }
                let common = required.intersection(candidate)
                let content = required.subtracting(protectedTokens)
                let contentMatches = content.intersection(candidate)
                return Double(common.count) / Double(required.count) >= 0.65
                    && (content.isEmpty || Double(contentMatches.count) / Double(content.count) >= 0.6)
            }
            return covered ? nil : String(format: "F%02d", index + 1)
        }
        return Self(factCount: facts.count, missingFactIDs: missing)
    }

    static func clauses(_ value: String) -> [String] {
        let normalized = SessionNoteOutputSanitizer.normalizeSemicolons(value)
        let independentSubject = #"(?:,\s*)?\band\s+(?=(?:the\s+)?(?:client|RBT|BCBA|LBS|BHT|mother|father|grandmother|grandfather|caregiver|parent|sibling)\b\s+(?:reported|stated|shared|modelled|modeled|used|provided|needed|required|requested|selected|delivered|offered|engaged|transitioned|returned|completed|practiced|blocked|supported|responded|concluded|discussed|raised)\b)"#
        return SessionNoteOutputSanitizer.splitSentences(normalized).flatMap { sentence -> [String] in
            let split = sentence.replacingOccurrences(of: independentSubject, with: "\n", options: [.regularExpression, .caseInsensitive])
            return split.components(separatedBy: "\n").flatMap { clause -> [String] in
                // Split shorthand measurement/activity lists only when no report
                // or conclusion attribution would be detached from a fragment.
                if !matches(#"\b(?:reported|stated|shared|according to|concluded)\b"#, in: clause) {
                    return clause.components(separatedBy: ";")
                }
                return [clause]
            }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
    }

    static func supportsPairing(_ value: String) -> Bool {
        clauses(value).contains { clause in
            !matches(#"\b(?:not|no|never|will|planned|proposed|discussed)\b"#, in: clause)
                && matches(#"\b(?:build|building|built) rapport\b|\brapport[- ]building\b|\bpairing\b"#, in: clause)
                && matches(#"\b(?:play|preferred|activities|activity|pairing)\b"#, in: clause)
        }
    }

    static func supportsCommunicationTeaching(_ value: String) -> Bool {
        if matches(#"\b(?:FCT|functional communication training)\b"#, in: value) { return true }
        return clauses(value).contains {
            !matches(#"\b(?:not|no|never|didn't|will|planned|proposed|discussed|recommend(?:ed)?)\b"#, in: $0)
                && matches(#"\b(?:model(?:led|ed|ling|ing)?|demonstrat(?:ed|ing)|taught|teach(?:ing)?)\b"#, in: $0)
                && matches(#"\b(?:request(?:s|ed|ing)?|communicat(?:ion|ing))\b"#, in: $0)
                && matches(#"\b(?:AAC|ASL|speech|sign(?:s|ing)?|picture|communication)\b"#, in: $0)
        }
    }

    private static let protectedTokens: Set<String> = [
        "mother", "father", "grandmother", "grandfather", "sibling", "brother", "sister", "caregiver", "parent",
        "rbt", "bcba", "lbs", "bht", "aac", "asl", "pecs", "verbal", "gestural", "physical", "independent",
        "report", "model", "discuss", "conclude", "not", "need", "end", "before", "after",
    ]

    private static func matches(_ pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func relationshipTokens(_ value: String) -> Set<String> {
        let stripped = value.replacingOccurrences(
            of: #"(?i)\b(?:while|during|throughout|when|where|upon|at the same time(?: that)?)\b"#,
            with: "", options: .regularExpression
        )
        var result = tokens(stripped)
        if matches(#"\bclient\b"#, in: value) { result.insert("client") }
        return result
    }

    private static func tokens(_ value: String) -> Set<String> {
        var normalized = value.lowercased().replacingOccurrences(of: "’", with: "'")
        let aliases: [(String, String)] = [
            (#"\b(?:registered behavior technician)\b"#, "rbt"),
            (#"\b(?:board[- ]certified behavior analyst)\b"#, "bcba"),
            (#"\b(?:augmentative (?:and|&) alternative communication)\b"#, "aac"),
            (#"\bamerican sign language\b"#, "asl"),
            (#"\bfunctional communication(?: training)?\b"#, "fct"),
            (#"\b(?:build|building|built) rapport\b|\brapport[- ]building\b"#, "pairing"),
            (#"\baccording to\b|\b(?:reported|stated|shared that)\b"#, "report"),
            (#"\b(?:modelled|modeled|modelling|modeling|demonstrated|demonstrating)\b"#, "model"),
            (#"\b(?:raised (?:the )?observation of|raised|discussed|discussion|brought up|consulted)\b"#, "discuss"),
            (#"\b(?:concluded|conclusion|concluding|assessment)\b"#, "conclude"),
            (#"\b(?:continued to need|continued to require|remained necessary|still required|needed|requires?|required)\b"#, "need"),
            (#"\b(?:at the beginning|opening|began|started)\b"#, "begin"),
            (#"\b(?:ended|closed|closing)\b"#, "end"),
            (#"\b(?:following|afterward)\b"#, "after"),
            (#"\bprior to\b"#, "before"),
            (#"\b(?:slept|sleeping)\b"#, "sleep"),
            (#"\bpoorly\b"#, "poor"),
            (#"\b(?:no|without|never)\b|\bdidn't\b"#, "not"),
            (#"\btwice\b|\btwo (?:episodes|occurrences|times)\b"#, "2"),
            (#"\bfree[- ]play\b"#, "free play"),
            (#"\b(?:utilized|used|provided)\b"#, "use"),
            (#"\b(?:took place|occurred|was held)\b"#, "session"),
            (#"\b(?:mom|mum)\b"#, "mother"),
            (#"\bdad\b"#, "father"),
            (#"\bgrandma\b"#, "grandmother"),
        ]
        for (pattern, replacement) in aliases {
            normalized = normalized.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        let stop: Set<String> = ["a", "an", "the", "s", "of", "to", "with", "in", "at", "on", "for", "and", "or", "by", "from", "that", "which", "as", "was", "were", "is", "are", "be", "been", "had", "has", "have", "did", "client", "session", "activity", "activities", "include", "included", "including", "used", "use", "through", "using", "it", "its", "these", "this", "their", "his", "her", "they", "them", "there", "continued", "continue", "engaged", "present", "remained", "repeatedly", "repeated", "observation", "period", "then", "moved"]
        return Set(normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { word in
            let w = String(word)
            if stop.contains(w) { return "" }
            if ["requests", "requested", "requesting"].contains(w) { return "request" }
            if ["prompts", "prompted", "prompting"].contains(w) { return "prompt" }
            if ["supported", "supporting"].contains(w) { return "support" }
            if w.count > 4 && w.hasSuffix("ing") && w != "pairing" && w != "swallowing" { return String(w.dropLast(3)) }
            if w.count > 4 && w.hasSuffix("ed") { return String(w.dropLast(2)) }
            if w.count > 3 && w.hasSuffix("s") && !["pecs", "lbs", "asl"].contains(w) { return String(w.dropLast()) }
            return w
        }.filter { !$0.isEmpty && !stop.contains($0) })
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

        let beforeLedgerIdentifiers = cleaned
        cleaned = cleaned
            .replacingOccurrences(
                of: #"(?i)\(\s*F\d{2,3}\s*\)"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?im)^\s*F\d{2,3}\s*\|\s*"#,
                with: "",
                options: .regularExpression
            )
        if cleaned != beforeLedgerIdentifiers { repairs.append("SN-FORMAT-010") }

        let beforeSentenceBoundaries = cleaned
        cleaned = normalizeSemicolons(cleaned)
        if cleaned != beforeSentenceBoundaries { repairs.append("SN-FORMAT-011") }

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

        let beforeDuplicateRemoval = paragraphs
        paragraphs = removingExactRepeatedSentences(from: paragraphs)
        if paragraphs != beforeDuplicateRemoval { repairs.append("SN-QUALITY-007") }

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

    private static func removingExactRepeatedSentences(from paragraphs: [String]) -> [String] {
        return paragraphs.compactMap { paragraph in
            var previous: String?
            let retained = splitSentences(paragraph).filter { sentence in
                let key = normalizeSentenceSpacing(sentence).lowercased()
                defer { previous = key }
                return key != previous
            }
            return retained.isEmpty ? nil : retained.joined(separator: " ")
        }
    }

    static func ensureTerminalPunctuation(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return trimmed + "."
    }

    // Retain model-selected paragraphs. Only split an oversized paragraph at a
    // topic boundary already expressed in its sentences; never reorder content.
    static func reflow(_ paragraphs: [String]) -> [String] {
        paragraphs.flatMap { paragraph -> [String] in
            guard paragraph.count > 520 else { return [paragraph] }
            let sentences = splitSentences(paragraph)
            var groups: [String] = []
            var current: [String] = []
            var previousTopic: Int?
            for sentence in sentences {
                let topic = narrativeTopic(sentence)
                if !current.isEmpty, let topic, topic != previousTopic {
                    groups.append(current.joined(separator: " "))
                    current.removeAll()
                }
                current.append(sentence)
                if let topic { previousTopic = topic }
            }
            if !current.isEmpty { groups.append(current.joined(separator: " ")) }
            return groups
        }
    }

    private static func narrativeTopic(_ sentence: String) -> Int? {
        let patterns = [
            #"(?i)\b(?:session (?:ended|closed)|closed the session|toward the end|near the end|free[- ]play|conclud(?:ed|ing|sion))\b"#,
            #"(?i)\b(?:discuss(?:ed|ion)|raised|consult(?:ed|ation))\b"#,
            #"(?i)\b(?:biting|elopement|aggression|behaviors? of concern|blocked|redirect(?:ed|ion|ing)|pushed|threw)\b"#,
            #"(?i)\b(?:transition(?:s|ed|ing)?|NET|natural environment teaching)\b"#,
            #"(?i)\b(?:FCT|functional communication|AAC|ASL|prompt(?:s|ing)?|instructional|targeted|programming)\b"#,
            #"(?i)\b(?:pairing|rapport|present|reported|according to|home session)\b"#,
            #"(?i)^(?:later|next|following this)\b"#,
        ]
        return patterns.firstIndex { sentence.range(of: $0, options: .regularExpression) != nil }
    }

    static func normalizeSemicolons(_ value: String) -> String {
        // Do not detach dependent phrases or a caregiver's reported clause from
        // its attribution. A remaining chain goes to the bounded prose repair.
        value.components(separatedBy: "\n\n").map { paragraph in
            splitSentences(paragraph).map { sentence in
                guard sentence.contains(";"),
                      sentence.range(of: #"(?i)\b(?:reported|stated|shared|according to|per)\b"#, options: .regularExpression) == nil else { return sentence }
                let clauses = sentence.components(separatedBy: ";")
                let independent = #"(?i)^\s*(?:the\s+)?(?:client|RBT|BCBA|LBS|BHT|mother|father|grandmother|caregiver|parent)\b\s+(?:\w+\s+)?(?:used|provided|modelled|modeled|requested|selected|delivered|offered|engaged|transitioned|returned|completed|practiced|blocked|supported|responded)\b"#
                guard clauses.dropFirst().allSatisfy({ $0.range(of: independent, options: .regularExpression) != nil }) else { return sentence }
                return clauses.enumerated().map { index, clause in
                    let trimmed = clause.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard index > 0, let first = trimmed.first else { return trimmed }
                    return first.uppercased() + trimmed.dropFirst()
                }.joined(separator: ". ")
            }.joined(separator: " ")
        }.joined(separator: "\n\n")
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

        if validation.issueCodes.contains("SN-CHRONOLOGY-002") {
            let independentLocationClause = #"(?i)\s+where\s+(?=(?:the\s+)?(?:client(?:'s\s+(?:mother|father|grandmother))?|RBT|BCBA|LBS|BHT|mother|father|grandmother|caregiver|parent)\s+(?:was|were|is|used|provided|requested|returned|completed|transitioned|remained)\b)"#
            let paragraphs = repaired.components(separatedBy: "\n\n").map { paragraph in
                SessionNoteOutputSanitizer.splitSentences(paragraph).map { sentence in
                    guard SessionNoteOutputValidator.containsUnsupportedSimultaneity(in: sentence, evidence: evidence, locationOnly: true) else { return sentence }
                    let pieces = sentence.replacingOccurrences(of: independentLocationClause, with: "\n", options: .regularExpression).components(separatedBy: "\n")
                    guard pieces.count > 1 else { return sentence }
                    return pieces.enumerated().map { index, piece in
                        let capitalized = index == 0 ? piece : piece.prefix(1).uppercased() + piece.dropFirst()
                        return capitalized.last.map { ".!?".contains($0) } == true ? capitalized : capitalized + "."
                    }.joined(separator: " ")
                }.joined(separator: " ")
            }
            let separated = paragraphs.joined(separator: "\n\n")
            if separated != repaired { repairs.append("SN-CHRONOLOGY-002") }
            repaired = separated
        }

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

        // Remove only this demonstrated standalone padding sentence. Mixed clinical
        // claims require the existing bounded model repair, never whole-sentence deletion.
        if validation.issueCodes.contains("SN-QUALITY-006") {
            repaired = repaired.components(separatedBy: "\n\n").map { paragraph in
                SessionNoteOutputSanitizer.splitSentences(paragraph)
                    .filter { $0.lowercased() != "the rbt continued the session." }
                    .joined(separator: " ")
            }.filter { !$0.isEmpty }.joined(separator: "\n\n")
            repairs.append("SN-QUALITY-006")
        }

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


}

enum SessionNoteConservativeFallback {
    static func make(from evidence: SessionNoteEvidencePacket, requireMaterialCoverage: Bool = false) -> String? {
        guard evidence.structuredMeasurements.isEmpty else { return nil }
        let facts = SessionNoteEvidenceNormalizer.deduplicatedFacts(from: evidence.typedFacts)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        return final.isSafe && (!requireMaterialCoverage || SessionNoteMaterialCoverage.assess(final.draft, evidence: evidence).missingFactIDs.isEmpty) ? final.draft : nil
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
        requireStructuredMeasurementCoverage: Bool = true,
        requireMaterialCoverage: Bool = false
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
        // Legacy product boilerplate is never factual session evidence, even if
        // pasted into facts. It must not enter an evidence-bound narrative.
        if SessionNoteStandardClosing.isPresent(in: cleaned) {
            issues.append(issue(
                "SN-CLINICAL-014", .hardBlocker, .clinicalClaimVerification, .boundedModel,
                "Remove the legacy standard closing. End the narrative after the supplied session facts without adding future-plan or treatment-protocol claims."
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

        let paragraphs = cleaned.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if paragraphs.contains(where: { $0.count > 900 && SessionNoteOutputSanitizer.splitSentences($0).count >= 4 }) {
            issues.append(issue(
                "SN-FORMAT-007", .repairable, .quality, .boundedModel,
                "Separate the oversized paragraph at supported changes of activity or topic, without reordering facts or inventing a sequence. Keep report attribution attached."
            ))
        }
        if cleaned.contains(";") {
            issues.append(issue(
                "SN-FORMAT-011", .repairable, .quality, .boundedModel,
                "Replace semicolon chains with complete sentences or grammatical coordinated clauses. Retain the subject, report attribution, qualifications, and every fact; do not create sentence fragments."
            ))
        }
        if let last = cleaned.last, !".!?".contains(last) {
            issues.append(issue(
                "SN-FORMAT-008", .repairable, .formatNormalization, .deterministic,
                "Add final punctuation."
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
        if lower.contains("the rbt continued the session."),
           evidence.typedFacts.range(of: #"(?i)\b(?:the )?RBT continued (?:the )?session\b"#, options: .regularExpression) == nil {
            issues.append(issue(
                "SN-QUALITY-006", .repairable, .quality, .deterministic,
                "Remove the standalone generic session-continuation padding sentence."
            ))
        }
        if hasRepetitiveOpenings(cleaned) {
            issues.append(issue(
                "SN-QUALITY-003", .repairable, .quality, .boundedModel,
                "Replace mechanical Then/After-this or role-then sentence chains with natural transitions while preserving every supplied fact and supported chronological relationship."
            ))
        }
        if containsUnsupportedSpecificChronology(in: cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-CHRONOLOGY-001", .hardBlocker, .clinicalClaimVerification, .boundedModel,
                "Remove first, then, after, following, later, beginning, or ending relationships that the supplied facts do not establish. Group unordered facts without asserting a timeline."
            ))
        }
        if containsUnsupportedSimultaneity(in: cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-CHRONOLOGY-002", .hardBlocker, .clinicalClaimVerification, .boundedModel,
                "Remove while, as, when, where, or throughout relationships that the supplied facts do not establish. Connect facts without asserting simultaneity, location, or duration."
            ))
        }
        if isMissingRequiredReportAttribution(in: cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-ROLE-001", .hardBlocker, .clinicalClaimVerification, .boundedModel,
                "Restore each caregiver report in the same sentence as its exact supplied mother, father, grandmother, parent, or caregiver relationship and reported fact."
            ))
        }
        if containsUnsupportedMissingDataClaim(in: cleaned, evidence: evidence) {
            issues.append(issue(
                "SN-EVIDENCE-007", .hardBlocker, .evidenceVerification, .boundedModel,
                "Remove claims that measurements, data, outcomes, or target values were absent or unrecorded unless the supplied facts explicitly state that absence."
            ))
        }
        issues.append(contentsOf: unsupportedClosedWorldClaims(in: cleaned, evidence: evidence))
        if requireMaterialCoverage {
            let coverage = SessionNoteMaterialCoverage.assess(cleaned, evidence: evidence)
            if !coverage.missingFactIDs.isEmpty {
                issues.append(issue(
                    "SN-COVERAGE-001", .repairable, .quality, .boundedModel,
                    "Check potentially omitted or misattributed facts " + coverage.missingFactIDs.joined(separator: ", ") + ". Restore their material meaning, actors, communication methods, prompting, reports, and supplied conclusions from the original ledger. Paraphrase naturally; do not add facts."
                ))
            }
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
        let supplied = [
            evidence.typedFacts,
            evidence.quantitativeOCR,
            evidence.structuredMeasurements.map(\.promptLine).joined(separator: "\n"),
        ]
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
        var result = patterns.compactMap { code, pattern, instruction in
            let outputContains = value.range(of: pattern, options: .regularExpression) != nil
            let evidenceContains = supplied.range(of: pattern, options: .regularExpression) != nil
            return outputContains && !evidenceContains
                ? issue(code, .hardBlocker, .clinicalClaimVerification, .boundedModel, instruction)
                : nil
        }
        // Narrow additions to the existing evidence-presence checks. These are not
        // a semantic completeness certificate; qualified facts still require review.
        let additions: [(String, String, String)] = [
            ("SN-CLINICAL-009", #"(?i)\b(?:was|remained|stayed)\s+(?:actively\s+|well\s+)?engaged\b|\b(?:sustained|demonstrated)\s+engagement\b"#, "engagement or participation"),
            ("SN-CLINICAL-009", #"(?i)\bparticipat(?:ed|es|ing|ion)\b"#, "engagement or participation"),
            ("SN-CLINICAL-010", #"(?i)\b(?:will|plans? to|intends? to)\b[^.!?\n]*(?:treatment plan|future sessions?|next session)|\b(?:continu(?:e|ed|ing)|implement(?:ed|ing)|follow(?:ed|ing)|adher(?:ed|ence)|complian(?:t|ce))\b[^.!?\n]*\btreatment plan\b"#, "treatment-plan compliance or future plans"),
            ("SN-CLINICAL-011", #"(?i)\b(?:reinforcement|reinforced|reinforcing|earned)\b"#, "reinforcement or praise"),
            ("SN-CLINICAL-011", #"(?i)\b(?:praise|praised|praising)\b"#, "reinforcement or praise"),
            ("SN-CLINICAL-012", #"(?i)\b(?:because|due to|resulted in|led to|in order to)\b"#, "purpose or causal relationships"),
            ("SN-CLINICAL-013", #"(?i)\b(?:engaged|engagement|participat(?:ed|es|ing|ion))\b[^.!?\n]*\bthroughout (?:the )?session\b"#, "sustained engagement, sustained participation, or successful transitions"),
            ("SN-CLINICAL-013", #"(?i)\b(?:successful transitions?|transitioned successfully)\b"#, "sustained engagement, sustained participation, or successful transitions"),
        ]
        for (code, pattern, claim) in additions {
            if value.range(of: pattern, options: .regularExpression) != nil,
               supplied.range(of: pattern, options: .regularExpression) == nil {
                result.append(issue(code, .hardBlocker, .clinicalClaimVerification, .boundedModel,
                    "Remove unsupported \(claim); preserve all supplied facts, qualifications, and attribution. A positive response alone does not support this claim."))
            }
        }
        return result
    }

    private static func hasRepetitiveOpenings(_ value: String) -> Bool {
        let sentences = SessionNoteOutputSanitizer.splitSentences(value)
        let mechanicalCount = sentences.filter { sentence in
            sentence.range(
                of: #"(?i)^(?:then(?:,)?|after this(?:,)?|the (?:RBT|client) then)\b"#,
                options: .regularExpression
            ) != nil
        }.count
        return mechanicalCount >= 2
    }

    private static func containsUnsupportedSpecificChronology(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Bool {
        let chronologyPattern = #"(?i)\b(?:first|then|after(?:ward| this)?|before|following (?:this|the|that)|later (?:in|during) the session|at the beginning|toward the end|near the end)\b"#
        let independentFactLines = evidence.typedFacts
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return independentFactLines.count >= 2 &&
            value.range(of: chronologyPattern, options: .regularExpression) != nil &&
            evidence.typedFacts.range(of: chronologyPattern, options: .regularExpression) == nil
    }

    static func containsUnsupportedSimultaneity(
        in value: String,
        evidence: SessionNoteEvidencePacket,
        locationOnly: Bool = false
    ) -> Bool {
        // Validate the relationship in its own sentence. A matching word in an
        // unrelated fact cannot license a new link; equivalent temporal wording
        // does not itself make a supplied relationship unsupported.
        let concurrent = #"(?i)\b(?:while|at the same time(?: that)?|as (?:the )?(?:client|RBT|LBS|BCBA|BHT|caregiver|mother|father|grandmother|parent))\b"#
        let relationships = [
            (#"(?i)\bwhile\b|\bas (?:the )?(?:client|RBT|LBS|BCBA|BHT|caregiver|mother|father|grandmother|parent)\b"#, concurrent),
            (#"(?i)\bthroughout\b"#, #"(?i)\bthroughout\b"#),
            (#"(?i)\bwhen\b"#, #"(?i)\b(?:when|upon)\b"#),
            (#"(?i)\bwhere\b"#, #"(?i)\bwhere\b"#),
        ]
        let sourceSentences = SessionNoteOutputSanitizer.splitSentences(evidence.typedFacts)
        return SessionNoteOutputSanitizer.splitSentences(value).contains { sentence in
            relationships.contains { outputPattern, sourcePattern in
                if locationOnly && sourcePattern != #"(?i)\bwhere\b"# { return false }
                guard sentence.range(of: outputPattern, options: .regularExpression) != nil else { return false }
                let claim = SessionNoteMaterialCoverage.relationshipTokens(sentence)
                return !sourceSentences.contains { source in
                    guard source.range(of: sourcePattern, options: .regularExpression) != nil else { return false }
                    // A mixed sequence needs its actual clauses preserved; a bag
                    // of activity tokens cannot turn then/after into while.
                    if source.range(of: #"(?i)\b(?:then|before|after|following|followed)\b"#, options: .regularExpression) != nil,
                       source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        != sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                        return false
                    }
                    let support = SessionNoteMaterialCoverage.relationshipTokens(source)
                    let anchors = claim.intersection(["client", "rbt", "bcba", "lbs", "bht", "mother", "father", "grandmother", "caregiver", "parent", "not", "report"])
                    return !claim.isEmpty && anchors.isSubset(of: support)
                        && Double(claim.intersection(support).count) / Double(claim.count) >= 0.8
                }
            }
        }
    }

    private static func isMissingRequiredReportAttribution(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Bool {
        let source = evidence.typedFacts as NSString
        let reporterPattern = #"(?i)\b(?:the\s+)?(?:client(?:'s|’s)\s+)?(mother|father|grandmother|caregiver|parent)\s+(?:reported|stated|shared)\b"#
        guard let regex = try? NSRegularExpression(pattern: reporterPattern) else { return false }
        let sourceMatches = regex.matches(
            in: evidence.typedFacts,
            range: NSRange(location: 0, length: source.length)
        )
        let requiredRoles = Set(sourceMatches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            return source.substring(with: match.range(at: 1)).lowercased()
        })
        guard !requiredRoles.isEmpty else { return false }

        let sentences = SessionNoteOutputSanitizer.splitSentences(value)
        let attributionPattern = #"(?i)\b(?:reported|stated|shared|according to|per)\b"#
        return requiredRoles.contains { role in
            let rolePattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: role) + #"\b"#
            return !sentences.contains { sentence in
                sentence.range(of: rolePattern, options: .regularExpression) != nil &&
                    sentence.range(of: attributionPattern, options: .regularExpression) != nil
            }
        }
    }

    private static func containsUnsupportedMissingDataClaim(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> Bool {
        let outputPattern = #"(?i)\b(?:no|without)\s+(?:clear\s+|current[- ]session\s+)?(?:measurements?|measurement data|data points?|target data|behavior data|measurable outcomes?)\b|\b(?:measurements?|data points?|target data|behavior data|measurable outcomes?)\s+(?:were|was)\s+(?:not\s+)?(?:recorded|provided|available|observed|noted)\b|\babsence of measurable outcomes?\b"#
        let evidencePattern = #"(?i)\b(?:no|without)\s+(?:measurements?|measurement data|data points?|target data|behavior data|measurable outcomes?)\b|\b(?:measurements?|data points?|target data|behavior data|measurable outcomes?)\s+(?:were|was)\s+not\s+(?:recorded|provided|available|observed|noted)\b"#
        return value.range(of: outputPattern, options: .regularExpression) != nil &&
            evidence.typedFacts.range(of: evidencePattern, options: .regularExpression) == nil
    }

    private static func unsupportedClosedWorldClaims(
        in value: String,
        evidence: SessionNoteEvidencePacket
    ) -> [SessionNoteValidationIssue] {
        let supplied = [
            evidence.typedFacts,
            evidence.quantitativeOCR,
            evidence.structuredMeasurements.map(\.promptLine).joined(separator: "\n"),
        ].joined(separator: "\n")
        let guardedFamilies: [(String, String, String)] = [
            (
                "SN-CLINICAL-015",
                #"(?i)\b(?:pairing|rapport building|built rapport)\b"#,
                "Remove pairing or rapport claims not present in the supplied current-session facts."
            ),
            (
                "SN-CLINICAL-016",
                #"(?i)\b(?:functional communication training|functional communication|FCT)\b"#,
                "Remove functional communication training claims not present in the supplied current-session facts."
            ),
            (
                "SN-CLINICAL-017",
                #"(?i)\b(?:prompt(?:ed|ing|s)?|verbal cue|gestural cue|physical guidance)\b"#,
                "Remove prompting or cueing not present in the supplied current-session facts. Do not relabel a different intervention as prompting."
            ),
            (
                "SN-CLINICAL-018",
                #"(?i)\b(?:redirect(?:ed|ing|s)?|guided? back)\b"#,
                "Remove redirection not present in the supplied current-session facts. Do not relabel a different intervention as redirection."
            ),
            (
                "SN-CLINICAL-019",
                #"(?i)\b(?:reported|stated|shared that|according to)\b"#,
                "Remove caregiver-report attribution unless the supplied facts identify information as reported. Never convert direct observation into a report or a report into direct observation."
            ),
            (
                "SN-CLINICAL-020",
                #"(?i)\b(?:responded well|responded positively|successful(?:ly)?|positive response)\b"#,
                "Remove unsupported positive-response or success claims. An omitted intervention or outcome cannot be completed with a generic favorable response."
            ),
        ]
        return guardedFamilies.compactMap { code, pattern, instruction in
            if code == "SN-CLINICAL-015", SessionNoteMaterialCoverage.supportsPairing(supplied) { return nil }
            if code == "SN-CLINICAL-016", SessionNoteMaterialCoverage.supportsCommunicationTeaching(supplied) { return nil }
            let outputContains = value.range(of: pattern, options: .regularExpression) != nil
            let evidenceContains = supplied.range(of: pattern, options: .regularExpression) != nil
            return outputContains && !evidenceContains
                ? issue(code, .hardBlocker, .clinicalClaimVerification, .boundedModel, instruction)
                : nil
        }
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
        // Detailed clinical facts naturally share vocabulary. Require retained
        // rough structure in the candidate as well as high source overlap.
        guard hasRoughSourceStructure(candidateWithoutClose)
                || hasRoughDictationFragments(candidateWithoutClose)
                || hasRepetitiveOpenings(candidateWithoutClose) else { return false }
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
