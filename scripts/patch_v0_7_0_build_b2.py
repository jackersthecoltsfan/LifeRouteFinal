#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"
TOOLS = ROOT / "LifeRoute/SessionToolsViews.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build B.2 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_in_section(text: str, start_token: str, end_token: str, old: str, new: str, label: str) -> str:
    start = text.index(start_token)
    end = text.index(end_token, start)
    section = text[start:end]
    section = replace_once(section, old, new, label)
    return text[:start] + section + text[end:]


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 Build B.2 device QA" in text:
        return
    if "v0.7.0 Build B.1 Today/Home parity" not in text:
        raise SystemExit("v0.7.0 Build B.2 patch failed: B.1 Today/Home baseline missing")

    text = replace_once(
        text,
        "// v0.7.0 Build B.1 Today/Home parity: device-tuned against the approved target screenshot.\n",
        "// v0.7.0 Build B.1 Today/Home parity: device-tuned against the approved target screenshot.\n"
        "// v0.7.0 Build B.2 device QA: real-iPhone density pass against the approved reference.\n",
        "B.2 marker",
    )

    text = replace_once(text, "LazyVStack(spacing: LifeRouteDesign.Layout.cardGap)", "LazyVStack(spacing: 9)", "Home stack spacing")
    text = replace_once(text, ".padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)", ".padding(.horizontal, 12)", "Home horizontal inset")
    text = replace_once(text, ".padding(.top, 10)", ".padding(.top, 7)", "Home top inset")

    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        ".font(.system(size: dynamicTypeSize.isAccessibilitySize ? 27 : 30, weight: .black, design: .rounded))",
        ".font(.system(size: dynamicTypeSize.isAccessibilitySize ? 26 : 28, weight: .black, design: .rounded))",
        "hero brand size",
    )
    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        ".font(.caption.weight(.semibold))\n                    .foregroundStyle(.white.opacity(0.84))",
        ".font(.caption2.weight(.semibold))\n                    .foregroundStyle(.white.opacity(0.84))",
        "hero subtitle size",
    )
    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        ".frame(width: 42, height: 42)",
        ".frame(width: 38, height: 38)",
        "hero day control size",
    )
    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        "Spacer(minLength: 42)",
        "Spacer(minLength: 28)",
        "hero spacer",
    )
    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        "            .padding(16)\n        }\n        .frame(height: dynamicTypeSize.isAccessibilitySize ? 238 : 205)",
        "            .padding(14)\n        }\n        .frame(height: dynamicTypeSize.isAccessibilitySize ? 222 : 182)",
        "hero height and inset",
    )

    text = replace_in_section(
        text,
        "    private var quickActions: some View {",
        "    private var overviewCard: some View {",
        "VStack(alignment: .leading, spacing: 9)",
        "VStack(alignment: .leading, spacing: 7)",
        "quick action section spacing",
    )
    text = replace_in_section(
        text,
        "    private var quickActions: some View {",
        "    private var overviewCard: some View {",
        "LazyVGrid(columns: quickActionColumns, spacing: 10)",
        "LazyVGrid(columns: quickActionColumns, spacing: 8)",
        "quick action grid spacing",
    )

    text = replace_in_section(
        text,
        "    private var overviewCard: some View {",
        "    private func nextEventCard",
        "VStack(alignment: .leading, spacing: 11)",
        "VStack(alignment: .leading, spacing: 8)",
        "overview spacing",
    )
    text = replace_in_section(
        text,
        "    private func nextEventCard",
        "    private var gapSuggestions: some View {",
        ".padding(13)",
        ".padding(10)",
        "next event padding",
    )

    # The reference uses a plain blue text affordance rather than a pill-like button.
    see_all = '''                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })\n            }\n\n            // v0.7.0 restored To-Do gap fillers'''
    see_all_replacement = '''                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })\n                .buttonStyle(.plain)\n            }\n\n            // v0.7.0 restored To-Do gap fillers'''
    text = replace_once(text, see_all, see_all_replacement, "plain See all action")

    text = replace_in_section(
        text,
        "    private func gapSuggestionRow",
        "    private var liveDayCard: some View {",
        ".frame(width: 46, height: 46)",
        ".frame(width: 42, height: 42)",
        "gap icon size",
    )
    text = replace_in_section(
        text,
        "    private func gapSuggestionRow",
        "    private var liveDayCard: some View {",
        ".padding(10)\n        .background(",
        ".padding(8)\n        .background(",
        "gap row padding",
    )

    # To-Do rows were restored after B.1 and should use the same compact Home rhythm as saved places.
    todo_start = text.index("            // v0.7.0 restored To-Do gap fillers")
    todo_end = text.index("                ForEach(suggestions.prefix", todo_start)
    todo_block = text[todo_start:todo_end]
    todo_block = replace_once(todo_block, ".frame(width: 46, height: 46)", ".frame(width: 42, height: 42)", "To-Do icon size")
    todo_block = replace_once(
        todo_block,
        "                    .lifeRouteCard()",
        "                    .padding(8)\n"
        "                    .background(palette.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))\n"
        "                    .overlay {\n"
        "                        RoundedRectangle(cornerRadius: 16, style: .continuous)\n"
        "                            .stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)\n"
        "                    }",
        "compact To-Do card",
    )
    text = text[:todo_start] + todo_block + text[todo_end:]

    # Quick-action controls should read like the compact reference, not four large cards.
    qa_start = text.index("    private func quickActionLabel(")
    qa_end = text.index("    private func overviewMetric(", qa_start)
    qa = text[qa_start:qa_end]
    qa = replace_once(qa, ".frame(width: 46, height: 46)", ".frame(width: 42, height: 42)", "quick action icon size")
    qa = replace_once(qa, ".font(.caption2.weight(.semibold))", ".font(.system(size: 11, weight: .semibold))", "quick action label font")
    qa = replace_once(qa, ".frame(maxWidth: .infinity, minHeight: 78, alignment: .top)", ".frame(maxWidth: .infinity, minHeight: 68, alignment: .top)", "quick action height")
    text = text[:qa_start] + qa + text[qa_end:]

    metric_start = text.index("    private func overviewMetric(")
    metric_end = text.index("    private var totalDrivingDurationLabel", metric_start)
    metric = text[metric_start:metric_end]
    metric = replace_once(metric, ".frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)", ".frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)", "metric height")
    metric = replace_once(metric, ".padding(10)", ".padding(8)", "metric padding")
    text = text[:metric_start] + metric + text[metric_end:]

    TODAY.write_text(text, encoding="utf-8")


FULLSCREEN_PREVIEWS = r'''struct ClientChoiceBoardPreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let board: ClientChoiceBoard
    let clientCode: String

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: board.columns == 3 ? 3 : 2)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(board.title)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            Text("Choice Board · \(libraryName)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close board preview")
                    }

                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(board.iconIDs, id: \.self) { iconID in
                            if let icon = visualState.icon(id: iconID, for: clientCode) {
                                VStack(spacing: 9) {
                                    ClientVisualIconThumbnail(icon: icon, size: board.columns == 3 ? 94 : 142)
                                    Text(icon.label)
                                        .font(board.columns == 3 ? .subheadline.weight(.bold) : .headline.weight(.bold))
                                        .foregroundStyle(palette.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.76)
                                }
                                .frame(maxWidth: .infinity, minHeight: board.columns == 3 ? 148 : 200)
                                .padding(10)
                                .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(palette.accent.opacity(0.26), lineWidth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

struct ClientVisualSchedulePreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var visualState: ClientVisualSupportCore
    let schedule: ClientVisualSchedule
    let clientCode: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(schedule.title)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            Text("Visual Schedule · \(libraryName)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close schedule preview")
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(schedule.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 13) {
                                Text("\(index + 1)")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .frame(width: 38, height: 38)
                                    .background(palette.accent, in: Circle())

                                if let iconID = step.iconID,
                                   let icon = visualState.icon(id: iconID, for: clientCode) {
                                    ClientVisualIconThumbnail(icon: icon, size: 76)
                                }

                                Text(step.label)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.accent.opacity(0.22), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

'''


def patch_visuals() -> None:
    text = TOOLS.read_text(encoding="utf-8")
    if "v0.7.0 B.2 save and fullscreen preview" in text:
        return
    required = [
        "v0.7.0 saved visual library reuse",
        "v0.7.0 horizontal First Then preview",
        "struct ClientChoiceBoardBuilderView: View",
        "struct ClientVisualScheduleBuilderView: View",
        "struct ClientChoiceBoardPreviewView: View",
        "struct ClientVisualSchedulePreviewView: View",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build B.2 patch failed: visual baseline missing {missing}")

    text = text.replace(
        "// MARK: - General + client-specific visual supports\n",
        "// MARK: - General + client-specific visual supports\n// v0.7.0 B.2 save and fullscreen preview: real-device visual-support QA.\n",
        1,
    )

    # Replace the prior navigation-sized preview implementations with true session-sized full-screen views.
    preview_start = text.index("struct ClientChoiceBoardPreviewView: View {")
    preview_end = text.index("private struct VisualBuilderHero: View {", preview_start)
    text = text[:preview_start] + FULLSCREEN_PREVIEWS + text[preview_end:]

    # Choice Board: persistent Save & Preview action, explicit success feedback, and immediate full-screen use.
    board_start = text.index("struct ClientChoiceBoardBuilderView: View {")
    board_end = text.index("struct ClientFirstThenVisualView: View {", board_start)
    board = text[board_start:board_end]
    board = replace_once(
        board,
        "    @State private var message: String?\n",
        "    @State private var message: String?\n    @State private var previewBoard: ClientChoiceBoard?\n",
        "choice board preview state",
    )
    board = replace_once(
        board,
        '''                    Button("Save board to \\(libraryName)") { saveBoard() }\n                        .buttonStyle(LifeRoutePrimaryButtonStyle())''',
        '''                    Text("When the board is ready, use Save & Preview below. It stays visible while you scroll.")\n                        .font(.caption)\n                        .foregroundStyle(palette.textSecondary)''',
        "choice board embedded save control",
    )
    board = replace_once(
        board,
        '''        .navigationTitle("Choice Boards")\n        .navigationBarTitleDisplayMode(.inline)''',
        '''        .navigationTitle("Choice Boards")\n        .navigationBarTitleDisplayMode(.inline)\n        .safeAreaInset(edge: .bottom) {\n            Button {\n                saveBoard()\n            } label: {\n                Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")\n            }\n            .buttonStyle(LifeRoutePrimaryButtonStyle())\n            .padding(.horizontal, 18)\n            .padding(.vertical, 8)\n            .background(.ultraThinMaterial)\n        }\n        .fullScreenCover(item: $previewBoard) { board in\n            ClientChoiceBoardPreviewView(visualState: visualState, board: board, clientCode: clientCode)\n        }''',
        "choice board sticky save and preview",
    )
    board = replace_once(
        board,
        '''            _ = try visualState.saveChoiceBoard(clientCode: clientCode, title: boardTitle, iconIDs: ordered, columns: columns)\n            selectedIconIDs.removeAll()\n            message = "Choice board saved to \\(libraryName)."''',
        '''            let saved = try visualState.saveChoiceBoard(clientCode: clientCode, title: boardTitle, iconIDs: ordered, columns: columns)\n            selectedIconIDs.removeAll()\n            message = "Choice board saved to \\(libraryName)."\n            previewBoard = saved''',
        "choice board save result",
    )
    text = text[:board_start] + board + text[board_end:]

    # Visual Schedule gets the same unmissable save flow and full-screen session preview.
    schedule_start = text.index("struct ClientVisualScheduleBuilderView: View {")
    schedule_end = text.index("private struct VisualBuilderHero: View {", schedule_start)
    schedule = text[schedule_start:schedule_end]
    schedule = replace_once(
        schedule,
        "    @State private var message: String?\n",
        "    @State private var message: String?\n    @State private var previewSchedule: ClientVisualSchedule?\n",
        "schedule preview state",
    )
    schedule = replace_once(
        schedule,
        '''                    Button("Save schedule to \\(libraryName)") { saveSchedule() }\n                        .buttonStyle(LifeRoutePrimaryButtonStyle())''',
        '''                    Text("When the sequence is ready, use Save & Preview below. It stays visible while you scroll.")\n                        .font(.caption)\n                        .foregroundStyle(palette.textSecondary)''',
        "schedule embedded save control",
    )
    schedule = replace_once(
        schedule,
        '''        .navigationTitle("Visual Schedules")\n        .navigationBarTitleDisplayMode(.inline)''',
        '''        .navigationTitle("Visual Schedules")\n        .navigationBarTitleDisplayMode(.inline)\n        .safeAreaInset(edge: .bottom) {\n            Button {\n                saveSchedule()\n            } label: {\n                Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")\n            }\n            .buttonStyle(LifeRoutePrimaryButtonStyle())\n            .padding(.horizontal, 18)\n            .padding(.vertical, 8)\n            .background(.ultraThinMaterial)\n        }\n        .fullScreenCover(item: $previewSchedule) { schedule in\n            ClientVisualSchedulePreviewView(visualState: visualState, schedule: schedule, clientCode: clientCode)\n        }''',
        "schedule sticky save and preview",
    )
    schedule = replace_once(
        schedule,
        '''            _ = try visualState.saveSchedule(clientCode: clientCode, title: title, steps: steps)\n            steps.removeAll()\n            message = "Visual schedule saved to \\(libraryName)."''',
        '''            let saved = try visualState.saveSchedule(clientCode: clientCode, title: title, steps: steps)\n            steps.removeAll()\n            message = "Visual schedule saved to \\(libraryName)."\n            previewSchedule = saved''',
        "schedule save result",
    )
    text = text[:schedule_start] + schedule + text[schedule_end:]

    TOOLS.write_text(text, encoding="utf-8")


def main() -> None:
    patch_today()
    patch_visuals()
    print(
        "LifeRoute v0.7.0 Build B.2 patch applied: Home tightened to real-device reference density, Choice Boards and Visual Schedules gained persistent Save & Preview actions, and saved visual previews now use true full-screen session presentation."
    )


if __name__ == "__main__":
    main()
