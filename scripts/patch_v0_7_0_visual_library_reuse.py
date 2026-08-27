#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 visual library patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 saved visual library reuse" in text:
        return

    required = [
        "struct ClientVisualSupportCenter: View",
        "visualState.choiceBoards(for: selectedClientCode).count",
        "visualState.schedules(for: selectedClientCode).count",
        'Text("Saved \\(libraryName) boards")',
        'Text("Saved \\(libraryName) schedules")',
        "private struct ClientVisualIconThumbnail: View",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 visual library patch failed: expected visual-support baseline missing {missing}")

    center_anchor = '''                HStack(spacing: 8) {
                    VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                    VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count, label: "Boards")
                    VisualLibraryMetric(value: visualState.schedules(for: selectedClientCode).count, label: "Schedules")
                }
                .lifeRouteCard()

                Text("\\(libraryDisplayName) visual supports are saved locally in protected LifeRoute app data on this iPhone.")'''
    center_replacement = '''                HStack(spacing: 8) {
                    VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                    VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count, label: "Boards")
                    VisualLibraryMetric(value: visualState.schedules(for: selectedClientCode).count, label: "Schedules")
                }
                .lifeRouteCard()

                // v0.7.0 saved visual library reuse: saved boards and schedules are discoverable
                // from the library itself instead of being stranded at the bottom of builder screens.
                savedVisualLibrary

                Text("\\(libraryDisplayName) visual supports are saved locally in protected LifeRoute app data on this iPhone.")'''
    text = replace_once(text, center_anchor, center_replacement, "saved library placement")

    visual_hero_anchor = '''    private var visualHero: some View {
'''
    saved_library = r'''    private var savedVisualLibrary: some View {
        let boards = visualState.choiceBoards(for: selectedClientCode)
        let schedules = visualState.schedules(for: selectedClientCode)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved visuals")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(boards.count + schedules.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.12), in: Capsule())
            }

            if boards.isEmpty && schedules.isEmpty {
                VisualBuilderEmptyState(
                    title: "No saved boards or schedules",
                    subtitle: "Save a Choice Board or Visual Schedule and it will be available here to reopen and use.",
                    systemImage: "square.stack.3d.up"
                )
            } else {
                if !boards.isEmpty {
                    Text("CHOICE BOARDS")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(palette.textSecondary)

                    ForEach(boards) { board in
                        NavigationLink {
                            ClientChoiceBoardPreviewView(
                                visualState: visualState,
                                board: board,
                                clientCode: selectedClientCode
                            )
                        } label: {
                            SavedVisualLibraryRow(
                                title: board.title,
                                detail: "\(board.iconIDs.count) choices · \(board.columns) columns",
                                systemImage: "square.grid.2x2.fill",
                                actionLabel: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !schedules.isEmpty {
                    Text("VISUAL SCHEDULES")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, boards.isEmpty ? 0 : 3)

                    ForEach(schedules) { schedule in
                        NavigationLink {
                            ClientVisualSchedulePreviewView(
                                visualState: visualState,
                                schedule: schedule,
                                clientCode: selectedClientCode
                            )
                        } label: {
                            SavedVisualLibraryRow(
                                title: schedule.title,
                                detail: "\(schedule.steps.count) steps",
                                systemImage: "list.number",
                                actionLabel: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .lifeRouteCard()
    }

'''
    text = replace_once(text, visual_hero_anchor, saved_library + visual_hero_anchor, "saved visual library content")

    board_delete = '''                                Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
                                    .font(.caption.weight(.semibold))'''
    board_actions = '''                                HStack(spacing: 10) {
                                    NavigationLink {
                                        ClientChoiceBoardPreviewView(
                                            visualState: visualState,
                                            board: board,
                                            clientCode: clientCode
                                        )
                                    } label: {
                                        Label("Preview board", systemImage: "rectangle.on.rectangle")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)

                                    Spacer()

                                    Button("Delete board", role: .destructive) { visualState.removeChoiceBoard(id: board.id) }
                                        .font(.caption.weight(.semibold))
                                }'''
    text = replace_once(text, board_delete, board_actions, "choice board preview action")

    schedule_delete = '''                                Button("Delete schedule", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
                                    .font(.caption.weight(.semibold))'''
    schedule_actions = '''                                HStack(spacing: 10) {
                                    NavigationLink {
                                        ClientVisualSchedulePreviewView(
                                            visualState: visualState,
                                            schedule: schedule,
                                            clientCode: clientCode
                                        )
                                    } label: {
                                        Label("Open schedule", systemImage: "rectangle.on.rectangle")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)

                                    Spacer()

                                    Button("Delete schedule", role: .destructive) { visualState.removeSchedule(id: schedule.id) }
                                        .font(.caption.weight(.semibold))
                                }'''
    text = replace_once(text, schedule_delete, schedule_actions, "schedule open action")

    preview_anchor = '''private struct VisualBuilderHero: View {
'''
    previews = r'''private struct SavedVisualLibraryRow: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let detail: String
    let systemImage: String
    let actionLabel: String

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Text(actionLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(11)
        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct ClientChoiceBoardPreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let board: ClientChoiceBoard
    let clientCode: String

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: board.columns == 3 ? 3 : 2
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 5) {
                    Text(board.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Choice Board · \(libraryName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(board.iconIDs, id: \.self) { iconID in
                        if let icon = visualState.icon(id: iconID, for: clientCode) {
                            VStack(spacing: 9) {
                                ClientVisualIconThumbnail(
                                    icon: icon,
                                    size: board.columns == 3 ? 88 : 132
                                )
                                Text(icon.label)
                                    .font(board.columns == 3 ? .subheadline.weight(.bold) : .headline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.78)
                            }
                            .frame(maxWidth: .infinity, minHeight: board.columns == 3 ? 140 : 188)
                            .padding(10)
                            .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.accent.opacity(0.24), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .navigationTitle("Board Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

struct ClientVisualSchedulePreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let schedule: ClientVisualSchedule
    let clientCode: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 5) {
                    Text(schedule.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Visual Schedule · \(libraryName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    ForEach(Array(schedule.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 13) {
                            Text("\(index + 1)")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.black.opacity(0.80))
                                .frame(width: 36, height: 36)
                                .background(palette.accent, in: Circle())

                            if let iconID = step.iconID,
                               let icon = visualState.icon(id: iconID, for: clientCode) {
                                ClientVisualIconThumbnail(icon: icon, size: 68)
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
                                .stroke(palette.accent.opacity(0.20), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .navigationTitle("Schedule Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }
}

'''
    text = replace_once(text, preview_anchor, previews + preview_anchor, "saved visual preview views")

    PATH.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 visual library reuse patch applied: saved choice boards and schedules now appear in the Visual Supports library, can be reopened from the library or builders, and have session-ready preview screens."
    )


if __name__ == "__main__":
    main()
