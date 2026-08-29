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

struct SessionNoteEvidencePacket {
    let typedFacts: String
    let quantitativeOCR: String
    let savedTerminologyContext: String
    let scrubber: SessionNoteIdentifierScrubber
    let numericClaims: [SessionNoteNumericClaim]
    let promptLevels: Set<String>

    static func make(
        typedFacts: String,
        ocrEvidence: String,
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
        let normalizedOCR = SessionNoteEvidenceNormalizer.quantitativeOCR(
            scrubber.scrub(ocrEvidence)
        )
        let normalizedContext = SessionNoteEvidenceNormalizer.savedContext(
            scrubber.scrub(savedTerminologyContext)
        )
        let factualEvidence = [normalizedFacts, normalizedOCR].joined(separator: "\n")

        return SessionNoteEvidencePacket(
            typedFacts: normalizedFacts,
            quantitativeOCR: normalizedOCR,
            savedTerminologyContext: normalizedContext,
            scrubber: scrubber,
            numericClaims: SessionNoteEvidenceNormalizer.numericClaims(in: factualEvidence),
            promptLevels: SessionNoteEvidenceNormalizer.promptLevels(in: factualEvidence)
        )
    }

    func modelPrompt(compaction: SessionNoteRequestCompaction) -> String {
        let ocrLimit = compaction == .standard ? 1_600 : 650
        let context = compaction == .standard ? savedTerminologyContext : ""
        return """
        SESSION FACTS — primary evidence:
        \(typedFacts.isEmpty ? "none" : String(typedFacts.prefix(5_200)))

        CLEAR QUANTITATIVE OCR — supporting evidence only:
        \(quantitativeOCR.isEmpty ? "none" : String(quantitativeOCR.prefix(ocrLimit)))

        NEUTRAL TERMINOLOGY CONTEXT — never evidence that an event occurred:
        \(context.isEmpty ? "none" : String(context.prefix(280)))
        """
    }
}

enum SessionNotePipelineStage: Equatable {
    case standardDraft
    case compactDraft
    case repair([String])
}

enum SessionNotePipelineEvent: Equatable {
    case compacting
    case repairing
}

enum SessionNotePipelineError: LocalizedError, Equatable {
    case contextTooLarge
    case rejected

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
        progress: @escaping (SessionNotePipelineEvent) async -> Void = { _ in }
    ) async throws -> String {
        let firstRawDraft: String
        do {
            firstRawDraft = try await request(.standardDraft)
        } catch SessionNotePipelineError.contextTooLarge {
            await progress(.compacting)
            firstRawDraft = try await request(.compactDraft)
        }

        let firstDraft = SessionNoteOutputSanitizer.sanitize(
            firstRawDraft,
            scrubber: packet.scrubber
        )
        let firstValidation = SessionNoteOutputValidator.validate(firstDraft, evidence: packet)
        if firstValidation.isAcceptable {
            return firstValidation.draft
        }

        await progress(.repairing)
        let repairedRawDraft = try await request(.repair(firstValidation.issues))
        let repairedDraft = SessionNoteOutputSanitizer.sanitize(
            repairedRawDraft,
            scrubber: packet.scrubber
        )
        let repairedValidation = SessionNoteOutputValidator.validate(repairedDraft, evidence: packet)
        guard repairedValidation.isAcceptable else {
            throw SessionNotePipelineError.rejected
        }
        return repairedValidation.draft
    }
}

enum SessionNoteRequestRaceError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Apple Intelligence did not finish this generation step in time. Your session facts and any previous draft are still here."
    }
}

final class SessionNoteRequestRace: @unchecked Sendable {
    private let lock = NSLock()
    private let timeoutNanoseconds: UInt64
    private var continuation: CheckedContinuation<String, Error>?
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

    func run(operation: @escaping () async throws -> String) async throws -> String {
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

    private func resolve(_ result: Result<String, Error>) {
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
        let lines = normalizeLines(value, removeAmbiguousOCR: true)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.contains(where: \.isNumber) }
        return String(lines.joined(separator: "\n").prefix(1_600))
    }

    static func savedContext(_ value: String) -> String {
        String(normalizeLines(value, removeAmbiguousOCR: true).prefix(280))
    }

    static func numericClaims(in value: String) -> [SessionNoteNumericClaim] {
        let pattern = #"(?<![A-Za-z0-9])\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = value as NSString
        return regex.matches(in: value, range: NSRange(location: 0, length: source.length)).map { match in
            let raw = source.substring(with: match.range)
            let contextStart = max(0, match.range.location - 48)
            let contextEnd = min(source.length, NSMaxRange(match.range) + 48)
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
    let issues: [String]

    var isAcceptable: Bool { issues.isEmpty }
}

enum SessionNoteOutputSanitizer {
    private static let continuationSentence = "The RBT will continue implementing the established treatment plan during future sessions."

    static func sanitize(_ value: String, scrubber: SessionNoteIdentifierScrubber) -> String {
        var cleaned = scrubber.scrub(value)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
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
        let roleNormalizations: [(String, String)] = [
            (#"(?i)\bthe\s+registered behavior technician\b|\bregistered behavior technician\b"#, "the RBT"),
            (#"(?i)\bthe\s+board certified behavior analyst\b|\bboard certified behavior analyst\b"#, "the BCBA"),
            (#"(?i)\bthe\s+licensed behavior specialist\b|\blicensed behavior specialist\b"#, "the LBS"),
        ]
        for (pattern, replacement) in roleNormalizations {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        var paragraphs: [String] = []
        var current: [String] = []
        for raw in cleaned.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flush(&current, into: &paragraphs)
                continue
            }
            line = line.replacingOccurrences(
                of: #"^\s*(?:#{1,6}\s*)?(?:[-*•–—]\s+|\d+[.)]\s+)"#,
                with: "",
                options: .regularExpression
            )
            guard let content = contentRemovingHeading(from: line), !content.isEmpty else { continue }
            current.append(content)
        }
        flush(&current, into: &paragraphs)

        paragraphs = paragraphs
            .map { ABATerminologyNormalizer.normalize(normalizeSentenceSpacing($0)) }
            .filter { !$0.isEmpty }
        paragraphs = reflow(paragraphs)

        if !paragraphs.isEmpty,
           !paragraphs.joined(separator: " ").localizedCaseInsensitiveContains(
                "continue implementing the established treatment plan during future sessions"
           ) {
            paragraphs[paragraphs.count - 1] = ensureTerminalPunctuation(paragraphs.last ?? "")
                + " " + continuationSentence
        }
        return paragraphs
            .map(ensureTerminalPunctuation)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func ensureTerminalPunctuation(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return trimmed + "."
    }

    private static func reflow(_ paragraphs: [String]) -> [String] {
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
        evidence: SessionNoteEvidencePacket
    ) -> SessionNoteOutputValidation {
        var issues: [String] = []
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()

        if cleaned.isEmpty { issues.append("The response was empty.") }
        if let identifier = evidence.scrubber.survivingIdentifier(in: cleaned) {
            issues.append("A forbidden personal or profile identifier remained: \(identifier).")
        }
        if containsLikelyPersonalName(in: cleaned) {
            issues.append("A likely personal name remained instead of a role identifier.")
        }
        if containsIdentifierShape(in: cleaned) {
            issues.append("A client-code or identifiable-initials pattern remained in the narrative.")
        }
        if lower.contains("**") || lower.contains("```") || lower.range(of: #"(?m)^\s*#{1,6}\s+"#, options: .regularExpression) != nil {
            issues.append("Markdown remained in the narrative.")
        }
        if lower.range(
            of: #"(?im)^\s*(session\s*\d+|session note|treatment plan continuation|assessment|plan|conclusion)\s*:"#,
            options: .regularExpression
        ) != nil {
            issues.append("A heading remained in the narrative.")
        }
        if cleaned.range(
            of: #"(?m)^\s*[A-Z][A-Za-z /&-]{2,40}:\s*"#,
            options: .regularExpression
        ) != nil {
            issues.append("Heading-like scaffolding remained in the narrative.")
        }
        if lower.range(of: #"(?m)^\s*(?:[-*•–—]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil {
            issues.append("List or numbered scaffolding remained.")
        }
        if lower.contains("maladaptive behavior") || lower.contains("maladaptive behaviour") {
            issues.append("Use behaviors of concern terminology.")
        }
        if lower.range(of: #"(?<![A-Za-z])(i|we|my|our)(?![A-Za-z])"#, options: .regularExpression) != nil {
            issues.append("The note was not consistently third person.")
        }
        if lower.range(of: #"\b(clinician|therapist|provider)\b"#, options: .regularExpression) != nil {
            issues.append("Use the supplied ABA role rather than a generic or personal clinician label.")
        }
        if !lower.contains("continue implementing the established treatment plan during future sessions") {
            issues.append("The required treatment-plan continuation close was missing.")
        }

        let paragraphs = cleaned.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if paragraphs.count > 4 {
            issues.append("The response used more than four narrative paragraphs.")
        }
        if paragraphs.count == 1,
           SessionNoteOutputSanitizer.splitSentences(cleaned).count >= 4,
           cleaned.count > 520 {
            issues.append("A long single paragraph needs readable narrative grouping.")
        }
        if let last = cleaned.last, !".!?".contains(last) {
            issues.append("The final sentence was incomplete.")
        }
        let sentences = SessionNoteOutputSanitizer.splitSentences(cleaned)
        if sentences.count < 2 || !lower.contains("client") {
            issues.append("The narrative needs supplied client participation or response before the continuation close.")
        }

        let outputClaims = SessionNoteEvidenceNormalizer.numericClaims(in: cleaned)
        for claim in outputClaims {
            let candidates = evidence.numericClaims.filter { $0.value == claim.value }
            if candidates.isEmpty {
                issues.append("Numeric value \(claim.value) was not present in supplied facts or clear OCR.")
            } else if claim.kind != .unknown,
                      !candidates.contains(where: { $0.kind == claim.kind || $0.kind == .unknown }) {
                issues.append("Numeric value \(claim.value) changed measurement type to \(claim.kind.rawValue).")
            }
        }

        let outputPromptLevels = SessionNoteEvidenceNormalizer.promptLevels(in: cleaned)
        for level in outputPromptLevels.subtracting(evidence.promptLevels) {
            issues.append("Prompt level \(level) was not supplied in the evidence.")
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
            issues.append("The response asserted a behavior was absent without typed support.")
        }

        issues.append(contentsOf: unsupportedClinicalClaims(in: cleaned, evidence: evidence))

        if hasObviousTemplateLanguage(lower) {
            issues.append("Obvious template or model scaffolding remained.")
        }
        if hasRepetitiveOpenings(cleaned) {
            issues.append("The response used overly repetitive sentence openings.")
        }

        return SessionNoteOutputValidation(draft: cleaned, issues: Array(Set(issues)).sorted())
    }

    private static func containsLikelyPersonalName(in value: String) -> Bool {
        let pattern = #"\b[A-Z][a-z]{1,}\s+[A-Z][a-z]{1,}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let nsValue = value as NSString
        let allowed: Set<String> = [
            "The RBT", "The LBS", "The BCBA", "The BHT", "The Client",
            "Visual Schedule", "Choice Board", "First Then", "Apple Intelligence",
            "Treatment Plan",
        ]
        return regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length)).contains { match in
            !allowed.contains(nsValue.substring(with: match.range))
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
    ) -> [String] {
        let supplied = [evidence.typedFacts, evidence.quantitativeOCR]
            .joined(separator: "\n")
        let patterns: [(String, String)] = [
            (#"(?i)\b(function (?:was|is)|maintained by|attention[- ]seeking|escape[- ]maintained)\b"#, "An inferred behavioral function was not supplied."),
            (#"(?i)\b(wanted|felt|was upset|was happy|was frustrated|was unmotivated)\b"#, "An inferred internal state was not supplied."),
            (#"(?i)\b(made progress|demonstrated progress|improved|demonstrated improvement|regressed)\b"#, "A progress conclusion was not supplied."),
            (#"(?i)\b(caregiver training|trained the caregiver|educated the caregiver)\b"#, "Caregiver training was not supplied."),
            (#"(?i)\b(?:modified|changed|updated)\s+(?:the\s+)?(?:treatment plan|protocol|program|prompting)|\bnew\s+(?:targets?|programs?)\b"#, "A treatment or programming change was not supplied."),
            (#"(?i)\brecommend(?:ed|ation|ations)?\b"#, "A recommendation was not supplied."),
            (#"(?i)\b(reinforcement was effective|responded well to (?:the )?reinforcement)\b"#, "Reinforcement effectiveness was not supplied."),
            (#"(?i)\b(?:the\s+)?(?:BCBA|LBS)\s+(?:observed|modeled|provided feedback|modified|updated)\b"#, "Supervisor involvement was not supplied."),
        ]
        return patterns.compactMap { pattern, issue in
            let outputContains = value.range(of: pattern, options: .regularExpression) != nil
            let evidenceContains = supplied.range(of: pattern, options: .regularExpression) != nil
            return outputContains && !evidenceContains ? issue : nil
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
}
