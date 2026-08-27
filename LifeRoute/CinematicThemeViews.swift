import SwiftUI

extension LifeRouteTheme {
    var cinematicImageURL: URL? {
        let value: String?
        switch self {
        case .royal:
            value = "https://images.unsplash.com/photo-1490237251747-4557595144b4?auto=format&fit=crop&w=1800&q=88"
        case .midnight:
            value = "https://images.unsplash.com/photo-1490237251747-4557595144b4?auto=format&fit=crop&w=1800&q=82"
        case .ocean:
            value = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1800&q=88"
        case .aurora:
            value = "https://images.unsplash.com/photo-1529963183134-61a90db47eaf?auto=format&fit=crop&w=1800&q=88"
        case .forest:
            value = "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1800&q=88"
        case .plum:
            value = "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1800&q=86"
        case .ember, .solarFlare:
            value = "https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=1800&q=86"
        case .arcticPulse:
            value = "https://images.unsplash.com/photo-1529963183134-61a90db47eaf?auto=format&fit=crop&w=1800&q=84"
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
        case .core: return "Premium Dark"
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
                                .saturation(1.05)
                                .contrast(1.08)
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
        case .dynamic:
            ZStack {
                RadialGradient(
                    colors: [palette.accent.opacity(0.48), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.85
                )
                palette.backgroundGradient.opacity(0.72)
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? palette.accent : palette.accentSecondary)
                        .opacity(0.12)
                        .frame(width: size.width * 0.9, height: CGFloat(12 + index * 5))
                        .blur(radius: CGFloat(8 + index))
                        .rotationEffect(.degrees(-36))
                        .offset(x: CGFloat(index - 2) * 44, y: CGFloat(index - 2) * 105)
                }
            }
        case .fluid:
            ZStack {
                palette.backgroundGradient
                Ellipse()
                    .fill(palette.accent.opacity(0.24))
                    .frame(width: size.width * 1.1, height: size.height * 0.5)
                    .blur(radius: 32)
                    .rotationEffect(.degrees(-18))
                    .offset(x: size.width * 0.26, y: -size.height * 0.18)
                Ellipse()
                    .stroke(palette.accentSecondary.opacity(0.18), lineWidth: 24)
                    .frame(width: size.width * 1.15, height: size.height * 0.55)
                    .blur(radius: 12)
                    .rotationEffect(.degrees(18))
                    .offset(x: -size.width * 0.30, y: size.height * 0.25)
            }
        case .core, .scenery:
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

struct LifeRouteCinematicThemeThumbnail: View {
    let theme: LifeRouteTheme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LifeRouteCinematicBackdrop(theme: theme, palette: theme.palette, compact: true)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.76)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                Text(theme.cinematicTreatmentLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(11)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
