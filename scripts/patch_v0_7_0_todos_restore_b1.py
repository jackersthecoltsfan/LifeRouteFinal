#!/usr/bin/env python3
from pathlib import Path

# Reuse the already-reviewed domain, persistence, and Setup restoration work, but
# apply Home integration with B.1-aware structural anchors instead of an older
# exact Build B text block.
import patch_v0_7_0_todos_restore as todo_restore

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def require_once(text: str, token: str, label: str) -> None:
    count = text.count(token)
    if count != 1:
        raise SystemExit(f"v0.7.0 B.1 To-Dos patch failed: {label} expected once, found {count}")


def patch_today_b1() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 restored To-Do gap fillers" in text:
        return

    start_token = "    private var gapSuggestions: some View {"
    end_token = "    @ViewBuilder\n    private func liveSummary"
    require_once(text, start_token, "gapSuggestions section")
    require_once(text, end_token, "liveSummary boundary")

    start = text.index(start_token)
    end = text.index(end_token, start)
    block = text[start:end]

    suggestion_line_start = block.find("            let suggestions = routingState.savedPlaces.filter")
    if suggestion_line_start < 0:
        raise SystemExit("v0.7.0 B.1 To-Dos patch failed: saved-place suggestion declaration missing")
    suggestion_line_end = block.find("\n", suggestion_line_start)
    if suggestion_line_end < 0:
        raise SystemExit("v0.7.0 B.1 To-Dos patch failed: malformed saved-place suggestion declaration")
    suggestion_line = block[suggestion_line_start:suggestion_line_end + 1]

    block = block.replace(
        suggestion_line,
        "            // v0.7.0 restored To-Do gap fillers: flexible weekly tasks surface before saved-place ideas.\n"
        "            let openTodos = routingState.todos.filter { !$0.completed }\n"
        + suggestion_line,
        1,
    )

    old_condition = "            if suggestions.isEmpty {"
    new_condition = "            if openTodos.isEmpty && suggestions.isEmpty {"
    require_once(block, old_condition, "empty gap-filler condition")
    block = block.replace(old_condition, new_condition, 1)

    old_empty_copy = 'Text("Mark saved places as gap suggestions in Setup and they’ll surface here.")'
    if old_empty_copy in block:
        block = block.replace(
            old_empty_copy,
            'Text("Add a weekly to-do or mark saved places as gap suggestions in Setup and they’ll surface here.")',
            1,
        )

    # B.1 contains another same-indent `else` in this property. Anchor the insertion
    # to the specific empty-state condition we just replaced instead of counting all elses.
    condition_pos = block.index(new_condition)
    else_token = "            } else {\n"
    else_pos = block.find(else_token, condition_pos)
    if else_pos < 0:
        raise SystemExit("v0.7.0 B.1 To-Dos patch failed: populated branch for gap condition missing")
    insert_pos = else_pos + len(else_token)

    todo_cards = r'''                ForEach(openTodos.prefix(3)) { todo in
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.15))
                            Image(systemName: todo.category.systemImage)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("\(todo.durationMinutes) min · due \(todo.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            if !todo.address.isEmpty {
                                Text(todo.address)
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            routingState.setTodoCompleted(id: todo.id, completed: true)
                            LifeRouteHaptics.success()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(todo.title)")
                    }
                    .lifeRouteCard()
                }

'''
    block = block[:insert_pos] + todo_cards + block[insert_pos:]

    require_once(block, "ForEach(suggestions.prefix(4))", "saved-place suggestion limit")
    block = block.replace(
        "ForEach(suggestions.prefix(4))",
        "ForEach(suggestions.prefix(openTodos.isEmpty ? 4 : 2))",
        1,
    )

    TODAY.write_text(text[:start] + block + text[end:], encoding="utf-8")


def main() -> None:
    todo_restore.patch_routing()
    todo_restore.patch_store()
    todo_restore.patch_setup()
    patch_today_b1()
    print(
        "LifeRoute v0.7.0 B.1 native To-Dos restored: flexible weekly tasks persist locally, live beside Saved Places in Setup, preserve the legacy task metadata, completion/undo, and surface in Home gap fillers."
    )


if __name__ == "__main__":
    main()
