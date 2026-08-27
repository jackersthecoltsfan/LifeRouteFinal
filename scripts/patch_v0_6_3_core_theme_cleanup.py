#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/CinematicThemeViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.6.3 Core color-scheme-only cleanup" in text:
        return

    old = '''        case .core:
            // v0.6.3 polished Core treatment. Accessible intentionally removes decoration.
            ZStack {
                if theme == .accessible {
                    Color.black
                } else if theme == .kaleidoscope {
                    LinearGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .saturation(1.20)
                    .contrast(1.08)

                    LinearGradient(
                        colors: [Color.white.opacity(0.30), .clear, Color.white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(-18))
                } else {
                    palette.backgroundGradient
                    ForEach(0..<7, id: \\.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(index.isMultiple(of: 2) ? 0.15 : 0.05),
                                        palette.accentSecondary.opacity(index.isMultiple(of: 2) ? 0.10 : 0.18),
                                        .clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: size.width * 1.24, height: CGFloat(10 + index * 7))
                            .blur(radius: CGFloat(7 + index))
                            .rotationEffect(.degrees(-27))
                            .offset(x: CGFloat(index - 3) * 28, y: CGFloat(index - 3) * 88)
                    }
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), .clear, palette.accent.opacity(0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if theme != .accessible {
                    LifeRouteThemeArtwork(theme: theme, palette: palette, compact: compact)
                }
            }'''

    new = '''        case .core:
            // v0.6.3 Core color-scheme-only cleanup: no symbols, imprints, artwork, or decorative bands.
            Group {
                if theme == .accessible {
                    Color.black
                } else if theme == .kaleidoscope {
                    LinearGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .saturation(1.18)
                } else {
                    palette.backgroundGradient
                }
            }'''

    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.6.3 Core cleanup failed: expected decorated Core block once, found {count}")

    PATH.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("LifeRoute v0.6.3 Core theme cleanup applied: Core themes are color schemes only, with no artwork/imprints.")


if __name__ == "__main__":
    main()
