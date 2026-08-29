from pathlib import Path


VIEW_PATH = Path("LifeRoute/AIClinicalToolsViews.swift")
CORE_PATH = Path("LifeRoute/LifeRouteIntelligenceCore.swift")
MARKER = "v0.8.0 follow-up session-note refinement"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"v0.8.0 session-note follow-up failed: expected one {label}, found {count}"
        )
    return text.replace(old, new, 1)


view = VIEW_PATH.read_text(encoding="utf-8")
core = CORE_PATH.read_text(encoding="utf-8")

if MARKER in view and MARKER in core:
    print("LifeRoute v0.8.0 session-note follow-up is already materialized.")
    raise SystemExit(0)
if MARKER in view or MARKER in core:
    raise SystemExit("v0.8.0 session-note follow-up is only partially materialized")


attachment_model = r'''// v0.8.0 follow-up session-note refinement:
// Multiple screenshots keep stable UI identity while their bytes remain in-memory only.
private struct SessionNoteScreenshotAttachment: Identifiable {
    let id: UUID
    let pickerItem: PhotosPickerItem
    let data: Data
}

'''
view = replace_once(
    view,
    "@MainActor\nprotocol SessionNoteGenerating: AnyObject {",
    attachment_model + "@MainActor\nprotocol SessionNoteGenerating: AnyObject {",
    "attachment model insertion",
)

signature_count = view.count("        screenshotData: Data?,")
if signature_count != 3:
    raise SystemExit(
        "v0.8.0 session-note follow-up failed: "
        f"expected three multiline runtime screenshot signatures, found {signature_count}"
    )
view = view.replace("        screenshotData: Data?,", "        screenshotDataItems: [Data],")
view = replace_once(
    view,
    "func start(narrative: String, screenshotData: Data?, client: LifeRouteClientProfile?)",
    "func start(narrative: String, screenshotDataItems: [Data], client: LifeRouteClientProfile?)",
    "runtime start screenshot signature",
)

call_count = view.count("screenshotData: screenshotData")
if call_count != 3:
    raise SystemExit(
        "v0.8.0 session-note follow-up failed: "
        f"expected three runtime screenshot calls, found {call_count}"
    )
view = view.replace(
    "screenshotData: screenshotData",
    "screenshotDataItems: screenshotDataItems",
)

state_anchor = '''    @State private var narrative = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var localNotice: String?'''
state_replacement = '''    @State private var narrative = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var screenshotAttachments: [SessionNoteScreenshotAttachment] = []
    @State private var isLoadingScreenshots = false
    @State private var localNotice: String?'''
view = replace_once(view, state_anchor, state_replacement, "multi-screenshot state")

task_anchor = '''        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                screenshotData = nil
                return
            }
            let data = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled, selectedPhotoItem == self.selectedPhotoItem else { return }
            screenshotData = data
        }'''
task_replacement = '''        .task(id: selectedPhotoItems) {
            await loadSelectedScreenshots()
        }'''
view = replace_once(view, task_anchor, task_replacement, "multi-screenshot loader task")

subtitle_anchor = (
    'subtitle: "Draft from supplied session facts, optional local screenshot text, '
    'and reviewed client context.",'
)
subtitle_replacement = (
    'subtitle: "Draft from supplied session facts, one or more local data screenshots, '
    'and reviewed client context.",'
)
view = replace_once(view, subtitle_anchor, subtitle_replacement, "note header copy")

picker_anchor = r'''            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 11) {
                    Image(systemName: screenshotData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshotData == nil ? "Attach data screenshot" : "Data screenshot ready")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Optional · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
'''
picker_replacement = r'''            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                HStack(spacing: 11) {
                    Image(systemName: screenshotAttachments.isEmpty ? "photo.badge.plus" : "photo.stack.fill")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshotAttachments.isEmpty ? "Attach data screenshots" : "Add or change screenshots")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Up to 6 · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    if isLoadingScreenshots {
                        ProgressView()
                            .tint(palette.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if !screenshotAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attached data screenshots")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(screenshotAttachments.count) of 6")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(palette.accentSecondary)
                    }

                    ForEach(Array(screenshotAttachments.enumerated()), id: \.element.id) { index, attachment in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.image.fill")
                                .foregroundStyle(palette.accent)
                            Text("Data screenshot \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.textPrimary)
                            Spacer()
                            Button(role: .destructive) {
                                removeScreenshot(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Remove data screenshot \(index + 1)")
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 44)
                        .background(palette.panelElevated.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Attached data screenshots")
            }
'''
view = replace_once(view, picker_anchor, picker_replacement, "multi-screenshot picker")

view = replace_once(
    view,
    '''    private var hasEvidence: Bool {
        !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || screenshotData != nil
    }''',
    '''    private var hasEvidence: Bool {
        !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !screenshotAttachments.isEmpty
    }''',
    "multi-screenshot evidence guard",
)

view = replace_once(
    view,
    'return "Apple Intelligence did not finish this step within 75 seconds. Your facts, screenshot, and prior draft were preserved."',
    'return "Apple Intelligence did not finish this step within 75 seconds. Your facts, screenshots, and prior draft were preserved."',
    "timeout preservation copy",
)
view = replace_once(
    view,
    'return "The request stopped safely. Your facts, screenshot, and prior draft were preserved."',
    'return "The request stopped safely. Your facts, screenshots, and prior draft were preserved."',
    "cancel preservation copy",
)

helper_anchor = '''    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)'''
helper_replacement = r'''    private func loadSelectedScreenshots() async {
        let selectedItems = Array(selectedPhotoItems.prefix(6))
        guard !selectedItems.isEmpty else {
            screenshotAttachments.removeAll()
            isLoadingScreenshots = false
            return
        }

        isLoadingScreenshots = true
        defer { isLoadingScreenshots = false }

        var loaded: [SessionNoteScreenshotAttachment] = []
        var failedCount = 0
        for item in selectedItems {
            guard !Task.isCancelled else { return }
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
                failedCount += 1
                continue
            }
            let stableID = screenshotAttachments.first(where: { $0.pickerItem == item })?.id ?? UUID()
            loaded.append(SessionNoteScreenshotAttachment(id: stableID, pickerItem: item, data: data))
        }

        guard !Task.isCancelled, selectedPhotoItems == selectedItems else { return }
        screenshotAttachments = loaded
        if failedCount > 0 {
            localNotice = "\(failedCount) screenshot\(failedCount == 1 ? "" : "s") could not be loaded. The remaining attachments are ready."
        } else {
            localNotice = "\(loaded.count) data screenshot\(loaded.count == 1 ? "" : "s") ready for local text recognition."
        }
    }

    private func removeScreenshot(_ attachment: SessionNoteScreenshotAttachment) {
        selectedPhotoItems.removeAll { $0 == attachment.pickerItem }
        screenshotAttachments.removeAll { $0.id == attachment.id }
        localNotice = "Data screenshot removed."
    }

    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)'''
view = replace_once(view, helper_anchor, helper_replacement, "screenshot helpers")

start_anchor = '''        runtime.start(
            narrative: narrative,
            screenshotDataItems: screenshotDataItems,
            client: selectedClient
        )'''
start_replacement = r'''        runtime.start(
            narrative: narrative,
            screenshotDataItems: screenshotAttachments.map(\.data),
            client: selectedClient
        )'''
view = replace_once(view, start_anchor, start_replacement, "generation attachment snapshot")


core_signature_anchor = '''    static func generateABASessionNote(
        narrative: String,
        screenshotData: Data?,
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void = { _ in }
    ) async throws -> String {
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        var recognized = ""
        if let screenshotData {
            recognized = await recognizeText(in: screenshotData)
        }

        guard !cleanNarrative.isEmpty || !recognized.isEmpty else {
            throw LifeRouteIntelligenceError.emptyInput
        }
'''
core_signature_replacement = '''    // v0.8.0 follow-up session-note refinement:
    // Typed narrative remains primary; up to six screenshot OCR streams are supplemental.
    static func generateABASessionNote(
        narrative: String,
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void = { _ in }
    ) async throws -> String {
        let cleanNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizedScreenshots = await recognizeSessionNoteScreenshots(screenshotDataItems)

        guard !cleanNarrative.isEmpty || recognizedScreenshots.contains(where: { !$0.isEmpty }) else {
            throw LifeRouteIntelligenceError.emptyInput
        }
'''
core = replace_once(
    core,
    core_signature_anchor,
    core_signature_replacement,
    "multi-screenshot core signature",
)

core = replace_once(
    core,
    '''        let boundedNarrative = String(cleanNarrative.prefix(5_200))
        let boundedOCR = String(recognized.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_700))
        let clientCode = client?.code ?? "General / no client"
        let clientContext = String(compactSessionNoteClientContext(client).prefix(550))''',
    '''        let clinicianNeutralNarrative = cleanNarrative.replacingOccurrences(
            of: "Brandon Good",
            with: "RBT",
            options: [.caseInsensitive]
        )
        let boundedNarrative = String(clinicianNeutralNarrative.prefix(5_200))
        let boundedOCR = formattedSessionNoteScreenshotEvidence(recognizedScreenshots)
        let clientCode = client?.code ?? "General / no client"
        let clientContext = String(
            compactSessionNoteClientContext(client)
                .replacingOccurrences(of: "Brandon Good", with: "RBT", options: [.caseInsensitive])
                .prefix(500)
        )''',
    "bounded typed evidence context",
)

core = replace_once(
    core,
    '''        - Write natural, objective, person-first clinical prose appropriate for insurance documentation. Use approximately 2–4 concise cohesive paragraphs; do not pad a sparse session.
        - Preserve chronological order. Start with location/people present when supplied, then describe what the RBT did, the client's observable response, prompting, reinforcement, skill acquisition, transitions, and behaviors where they actually occurred.''',
    '''        - Write natural, objective, person-first clinical prose appropriate for high-quality ABA and insurance documentation. Use approximately 2–4 concise cohesive paragraphs; do not pad a sparse session.
        - Refer to the clinician only as "the RBT" or "RBT." Never use a personal clinician or profile name in the note body.
        - Convert rough shorthand into connected chronological prose without adding facts. Start with location/people present when supplied, then describe what the RBT implemented, the client's observable response, the exact prompting provided, reinforcement delivered, skill acquisition, transitions, and behaviors where they actually occurred.
        - Build a cohesive clinical narrative rather than a list: link each supplied intervention to the corresponding client response, prompting, reinforcement, and observable outcome, and use concise transitions between session events.''',
    "clinical narrative contract",
)

core = replace_once(
    core,
    '''        - Integrate clear percentages, frequencies, and other values naturally beside the matching target/behavior; never create a separate data dump.
        - If OCR conflicts with an explicit narrative fact, preserve the narrative fact and omit uncertain OCR rather than overwriting the user's account.
        - Describe successful or lower-performing skills objectively when clear data supports it. When clear data shows a target still requires intervention, it is acceptable to state that the target continues to require intervention, but do not invent an explanation or unsupported progress claim.
        - Never convert behavior frequency/count data into a percentage.''',
    '''        - Keep every measurement in its supplied type and unit; never flatten unlike data into generic percentages or convert counts, frequency, duration, latency, rate, trials, independent responses, or prompted responses into another type.
        - Percentage data may describe skill accuracy, opportunities, or success only when the target label supports that meaning. Frequency/count data describes the supplied number of instances or events. Duration describes how long an event or response lasted. Latency describes the supplied time before a response or initiation. Rate preserves the supplied events-per-unit. Trial data preserves the supplied correct/total or trial-based form. Independent and prompted responding remain distinct, including exact prompt levels when present.
        - OCR evidence is grouped by screenshot and tagged by likely measurement type. Treat an [AMBIGUOUS OCR] tag as uncertain; omit it unless the surrounding label and value make the meaning clear.
        - Integrate clear values naturally beside the matching target or behavior; never create a separate data dump.
        - If OCR conflicts with an explicit narrative fact, preserve the narrative fact and omit uncertain OCR rather than overwriting the user's account.
        - Describe successful or lower-performing skills objectively when clear data supports it. When clear data shows a target still requires intervention, it is acceptable to state that the target continues to require intervention, but do not invent an explanation or unsupported progress claim.''',
    "mixed measurement data contract",
)

core = replace_once(
    core,
    '''        let firstDraft = try await generate(instructions: instructions, prompt: prompt)
        guard sessionNoteNeedsMasterABARepair(firstDraft) else {
            return firstDraft
        }''',
    '''        let firstDraft = sanitizedSessionNoteDraft(
            try await generate(instructions: instructions, prompt: prompt)
        )
        guard sessionNoteNeedsMasterABARepair(firstDraft) else {
            return firstDraft
        }''',
    "first-draft clinician sanitizer",
)
core = replace_once(
    core,
    '''        let repairedDraft = try await generate(
            instructions: instructions + """''',
    '''        let repairedDraft = sanitizedSessionNoteDraft(try await generate(
            instructions: instructions + """''',
    "repair-draft sanitizer opening",
)
core = replace_once(
    core,
    '''            prompt: prompt
        )

        guard !sessionNoteNeedsMasterABARepair(repairedDraft) else {''',
    '''            prompt: prompt
        ))

        guard !sessionNoteNeedsMasterABARepair(repairedDraft) else {''',
    "repair-draft sanitizer closing",
)

helpers_anchor = '''    static func generateABASessionNote(
        narrative: String,
        screenshotDataItems: [Data],'''
helpers = r'''    private static func recognizeSessionNoteScreenshots(_ imageDataItems: [Data]) async -> [String] {
        let limitedItems = Array(imageDataItems.prefix(6))
        return await withTaskGroup(of: (Int, String).self, returning: [String].self) { group in
            for (index, data) in limitedItems.enumerated() {
                group.addTask {
                    (index, await recognizeText(in: data))
                }
            }

            var indexedResults: [(Int, String)] = []
            for await result in group {
                indexedResults.append(result)
            }
            return indexedResults
                .sorted { $0.0 < $1.0 }
                .map { $0.1.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    private static func formattedSessionNoteScreenshotEvidence(_ recognizedScreenshots: [String]) -> String {
        let blocks = recognizedScreenshots.prefix(6).enumerated().map { screenshotIndex, recognized in
            let compactLines = recognized
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var taggedLines: [String] = []
            var lineIndex = 0
            while lineIndex < compactLines.count, taggedLines.count < 12 {
                var line = String(compactLines[lineIndex].prefix(180))
                let tags = sessionNoteEvidenceTags(for: line)
                if !line.contains(where: \.isNumber),
                   tags != ["AMBIGUOUS OCR"],
                   compactLines.indices.contains(lineIndex + 1),
                   compactLines[lineIndex + 1].contains(where: \.isNumber) {
                    line += " " + String(compactLines[lineIndex + 1].prefix(80))
                    lineIndex += 1
                }
                taggedLines.append("[\(tags.joined(separator: ", "))] \(line)")
                lineIndex += 1
            }

            let body = taggedLines.isEmpty ? "No clear OCR text." : taggedLines.joined(separator: "\n")
            return "SCREENSHOT \(screenshotIndex + 1):\n\(String(body.prefix(400)))"
        }
        return String(blocks.joined(separator: "\n\n").prefix(2_800))
    }

    private static func sessionNoteEvidenceTags(for line: String) -> [String] {
        let lower = line.lowercased()
        func matches(_ pattern: String) -> Bool {
            lower.range(of: pattern, options: .regularExpression) != nil
        }

        var tags: [String] = []
        if matches(#"\b(latency|time to respond|response time|time to begin|initiation delay)\b"#) {
            tags.append("LATENCY")
        }
        if matches(#"\b(rate|per minute|per hour|per session)\b|/(min|hr)\b"#) {
            tags.append("RATE")
        }
        if matches(#"\b(trials?|opportunities|correct out of)\b|\b\d+\s*/\s*\d+\b"#) {
            tags.append("TRIAL-BASED")
        }
        if lower.contains("%") || matches(#"\b(percent|percentage|accuracy)\b"#) {
            tags.append("PERCENTAGE")
        }
        if matches(#"\b(frequency|count|occurrences?|instances?|events?)\b"#) {
            tags.append("FREQUENCY/COUNT")
        }
        if matches(#"\bduration\b"#) || (
            tags.contains("LATENCY") == false &&
            tags.contains("RATE") == false &&
            matches(#"\b\d+(\.\d+)?\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)\b"#)
        ) {
            tags.append("DURATION")
        }
        if matches(#"\b(independent|independently|prompted|prompting|verbal prompt|gestural prompt|visual prompt|model prompt|partial physical|full physical)\b"#) {
            tags.append("INDEPENDENT/PROMPTED")
        }
        return tags.isEmpty ? ["AMBIGUOUS OCR"] : tags
    }

    private static func sanitizedSessionNoteDraft(_ draft: String) -> String {
        draft.replacingOccurrences(
            of: "Brandon Good",
            with: "the RBT",
            options: [.caseInsensitive]
        )
    }

'''
core = replace_once(
    core,
    helpers_anchor,
    helpers + helpers_anchor,
    "typed screenshot evidence helpers",
)

core = replace_once(
    core,
    '''        if lower.contains("maladaptive behavior") || lower.contains("maladaptive behaviours") {
            return true
        }
''',
    '''        if lower.contains("maladaptive behavior") || lower.contains("maladaptive behaviours") {
            return true
        }
        if lower.contains("brandon good") {
            return true
        }
''',
    "personal-name repair guard",
)


VIEW_PATH.write_text(view, encoding="utf-8")
CORE_PATH.write_text(core, encoding="utf-8")

print(
    "LifeRoute v0.8.0 session-note follow-up applied: RBT-only clinical narrative, stable "
    "multi-screenshot attachments, concurrent local OCR, typed mixed-measurement evidence, "
    "and preserved cancellable editing/copy/regeneration workflow."
)
