import SwiftUI

extension LifeRouteTheme {
    var cinematicImageURL: URL? {
        let value: String?
        switch self {
        case .mountain:
            value = "https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1800&q=90"
        case .ocean:
            value = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1800&q=90"
        case .space:
            value = "https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3?auto=format&fit=crop&w=1800&q=90"
        case .desert:
            value = "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1800&q=90"
        case .forest:
            value = "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1800&q=90"
        case .sunshine:
            value = "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1800&q=90"
        default:
            value = nil
        }
        return value.flatMap(URL.init(string:))
    }

    var cinematicTreatmentLabel: String {
        if cinematicImageURL != nil { return "Cinematic Scenery" }
        switch category {
        case .metallic: return "Premium Material"
        case .dynamic: return "Dynamic Energy"
        case .fluid: return "Fluid Depth"
        case .core: return "Polished Metallic"
        case .scenery: return "Cinematic Scenery"
        }
    }
}

struct LifeRouteCinematicBackdrop: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                palette.backgroundGradient

                if let url = theme.cinematicImageURL {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.35))) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .saturation(1.12)
                                .contrast(1.18)
                        case .empty:
                            cinematicLoading
                        case .failure:
                            proceduralFallback(size: proxy.size)
                        @unknown default:
                            proceduralFallback(size: proxy.size)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                    LinearGradient(
                        colors: [
                            palette.backgroundTop.opacity(compact ? 0.08 : 0.20),
                            palette.backgroundBottom.opacity(compact ? 0.28 : 0.64),
                            Color.black.opacity(compact ? 0.22 : 0.52)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    proceduralFallback(size: proxy.size)
                }

                edgeLight(size: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var cinematicLoading: some View {
        ZStack {
            palette.backgroundGradient
            ProgressView()
                .tint(palette.accent)
                .opacity(compact ? 0 : 0.6)
        }
    }

    @ViewBuilder
    private func proceduralFallback(size: CGSize) -> some View {
        switch theme.category {
        case .metallic:
            ZStack {
                LinearGradient(
                    colors: [palette.panelElevated, palette.backgroundBottom, palette.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.055 : 0.022))
                        .frame(width: size.width * 1.2, height: CGFloat(16 + index * 7))
                        .blur(radius: CGFloat(8 + index * 2))
                        .rotationEffect(.degrees(-28))
                        .offset(x: CGFloat(index - 3) * 36, y: CGFloat(index - 2) * 90)
                }
            }
        case .dynamic, .fluid:
            LifeRouteDynamicWaveBackdrop(palette: palette, compact: compact)
        case .core:
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
            }
        case .scenery:
            ZStack {
                palette.backgroundGradient
                RadialGradient(
                    colors: [palette.accent.opacity(0.22), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: max(size.width, size.height) * 0.8
                )
                LifeRouteThemeArtwork(theme: theme, palette: palette, compact: compact)
            }
        }
    }

    private func edgeLight(size: CGSize) -> some View {
        LinearGradient(
            colors: [palette.accentSecondary.opacity(0.12), .clear, palette.accent.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: size.width, height: size.height)
    }
}

struct LifeRouteDynamicWaveBackdrop: View {
    let palette: LifeRouteThemePalette
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: compact ? 0.16 : 0.06)) { context in
            GeometryReader { proxy in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    palette.backgroundGradient
                    RadialGradient(
                        colors: [palette.accent.opacity(0.44), .clear],
                        center: .topTrailing,
                        startRadius: 4,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.90
                    )
                    ForEach(0..<7, id: \.self) { index in
                        let phase = t * (0.42 + Double(index) * 0.035) + Double(index) * 0.78
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.accent.opacity(index.isMultiple(of: 2) ? 0.30 : 0.12),
                                        palette.accentSecondary.opacity(index.isMultiple(of: 2) ? 0.13 : 0.32),
                                        Color.white.opacity(0.07),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * 1.25, height: CGFloat(14 + index * 6))
                            .blur(radius: CGFloat(10 + index * 1))
                            .rotationEffect(.degrees(-31 + sin(phase * 0.55) * 7))
                            .offset(
                                x: CGFloat(sin(phase) * 70) + CGFloat(index - 3) * 18,
                                y: CGFloat(cos(phase * 0.82) * 82) + CGFloat(index - 3) * 94
                            )
                    }
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear, palette.accentSecondary.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipped()
            }
        }
    }
}
