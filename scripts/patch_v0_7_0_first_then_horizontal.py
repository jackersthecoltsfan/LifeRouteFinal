#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 First/Then horizontal patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 horizontal First Then preview" in text:
        return

    old_preview = '''                    VStack(spacing: 10) {
                        VisualSupportPreviewCard(
                            label: "FIRST",
                            icon: selectedIcon(idString: firstIconID),
                            fallbackText: firstText.isEmpty ? "First activity" : firstText
                        )
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                        VisualSupportPreviewCard(
                            label: "THEN",
                            icon: selectedIcon(idString: thenIconID),
                            fallbackText: thenText.isEmpty ? "Then activity" : thenText
                        )
                    }'''
    new_preview = '''                    // v0.7.0 horizontal First Then preview: FIRST reads left-to-right into THEN.
                    HStack(alignment: .center, spacing: 8) {
                        VisualSupportPreviewCard(
                            label: "FIRST",
                            icon: selectedIcon(idString: firstIconID),
                            fallbackText: firstText.isEmpty ? "First activity" : firstText,
                            compact: true
                        )
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel("Then")

                        VisualSupportPreviewCard(
                            label: "THEN",
                            icon: selectedIcon(idString: thenIconID),
                            fallbackText: thenText.isEmpty ? "Then activity" : thenText,
                            compact: true
                        )
                        .frame(maxWidth: .infinity)
                    }'''
    text = replace_once(text, old_preview, new_preview, "First/Then live preview layout")

    start = text.index("private struct VisualSupportPreviewCard: View {")
    end = text.index("struct SessionPlanOrganizerView: View", start)
    block = text[start:end]
    if "var compact = false" not in block:
        block = replace_once(
            block,
            '''    let fallbackText: String

    var body: some View {''',
            '''    let fallbackText: String
    var compact = false

    var body: some View {''',
            "compact preview parameter",
        )
        block = replace_once(
            block,
            "                ClientVisualIconThumbnail(icon: icon, size: 150)",
            "                ClientVisualIconThumbnail(icon: icon, size: compact ? 96 : 150)",
            "compact icon size",
        )
        block = block.replace(
            ".font(.title2.weight(.black))",
            ".font(compact ? .headline.weight(.black) : .title2.weight(.black))",
        )
        block = replace_once(
            block,
            ".frame(maxWidth: .infinity, minHeight: 190)\n        .padding(16)",
            ".frame(maxWidth: .infinity, minHeight: compact ? 158 : 190)\n        .padding(compact ? 10 : 16)",
            "compact card dimensions",
        )
        text = text[:start] + block + text[end:]

    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 First/Then preview patch applied: FIRST is left, THEN is right, with a left-to-right arrow between compact visual cards.")


if __name__ == "__main__":
    main()
