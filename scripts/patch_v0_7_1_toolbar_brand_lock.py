#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "LifeRoute/V054ContentView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 toolbar brand-lock patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = SHELL.read_text(encoding="utf-8")
    marker = "v0.7.1 final toolbar brand lock"
    if marker in text:
        return

    required = [
        "v0.7.1 custom LifeRoute bottom toolbar",
        "v0.7.1 single-toolbar physical fix",
        "private struct LifeRouteBottomToolbar: View {",
        "private struct LifeRouteTabGlyph: View {",
        "let stroke = StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 toolbar brand-lock patch failed: baseline missing {missing}")

    start = text.index("private struct LifeRouteBottomToolbar: View {")
    end = text.index("private struct LifeRouteTabGlyph: View {", start)

    toolbar = r'''// v0.7.1 final toolbar brand lock: LifeRoute navy/gold chrome stays recognizable across every theme.
private struct LifeRouteBottomToolbar: View {
    @Binding var selection: AppSection
    let palette: LifeRouteThemePalette

    private let brandNavy = Color(red: 0.025, green: 0.070, blue: 0.145)
    private let brandNavyDeep = Color(red: 0.008, green: 0.026, blue: 0.065)
    private let brandGold = Color(red: 0.93, green: 0.70, blue: 0.31)
    private let brandGoldBright = Color(red: 1.00, green: 0.83, blue: 0.49)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppSection.allCases) { section in
                let selected = selection == section

                Button {
                    selection = section
                } label: {
                    VStack(spacing: 4) {
                        LifeRouteTabGlyph(
                            section: section,
                            color: selected ? brandGoldBright : brandGold.opacity(0.78)
                        )
                        .frame(width: 30, height: 28)

                        Text(section.lifeRouteToolbarTitle)
                            .font(.system(size: 10.0, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(selected ? brandGoldBright : Color.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 2)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(brandNavy.opacity(0.96))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [brandGold.opacity(0.11), Color.white.opacity(0.018)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [brandGoldBright.opacity(0.95), brandGold.opacity(0.64)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.25
                                        )
                                }
                                .shadow(color: brandGold.opacity(0.23), radius: 8, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.lifeRouteToolbarTitle)
                // v0.7.1 toolbar accessibility hardening: explicit value avoids conditional OptionSet inference.
                .accessibilityValue(selected ? "Selected" : "")
            }
        }
        .padding(5)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(brandNavyDeep.opacity(0.92))
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(brandNavy.opacity(0.30))
                // Theme color is reflection only; it never owns the navigation chrome.
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(palette.accent.opacity(0.035))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [brandGoldBright.opacity(0.72), Color.white.opacity(0.10), brandGold.opacity(0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.05
                )
        }
        .shadow(color: brandNavyDeep.opacity(0.68), radius: 16, y: 5)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }
}

'''

    text = text[:start] + toolbar + text[end:]
    text = replace_once(
        text,
        "let stroke = StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)",
        "let stroke = StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)",
        "refined custom glyph line weight",
    )

    SHELL.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.1 final toolbar brand lock applied: the single custom bar now uses stable deep navy/glass "
        "chrome, warm-gold line art and perimeter, a stronger navy selected capsule with gold edge/glow, lighter "
        "labels, refined glyph weight, and only a minimal theme-color reflection."
    )


if __name__ == "__main__":
    main()
