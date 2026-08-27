import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

enum LifeRouteThemeCategory: String, CaseIterable, Identifiable {
    case core = "Core"
    case metallic = "Metallic"
    case scenery = "Scenery"
    case dynamic = "Dynamic"
    case fluid = "Fluid"
    var id: String { rawValue }
}

struct LifeRouteThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let panelElevated: Color
    let accent: Color
    let accentSecondary: Color
    let textPrimary: Color
    let textSecondary: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var panelGradient: LinearGradient {
        LinearGradient(colors: [panelElevated.opacity(0.88), panel.opacity(0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSecondary, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func makeThemePalette(_ bgA: UInt, _ bgB: UInt, _ panel: UInt, _ elevated: UInt, _ accent: UInt, _ accent2: UInt) -> LifeRouteThemePalette {
    .init(
        backgroundTop: Color(hex: bgA),
        backgroundBottom: Color(hex: bgB),
        panel: Color(hex: panel),
        panelElevated: Color(hex: elevated),
        accent: Color(hex: accent),
        accentSecondary: Color(hex: accent2),
        textPrimary: .white,
        textSecondary: .white.opacity(0.70)
    )
}

enum LifeRouteTheme: String, CaseIterable, Identifiable {
    case royal, obsidian, carbon, midnight, navyNoir
    case titanium, slate, moltenGold, phantomSilver
    case ocean, aurora, forest, plum, ember
    case solarFlare, electricStorm, ultraviolet, arcticPulse
    case sapphireTide

    var id: String { rawValue }

    var name: String {
        switch self {
        case .royal: return "Royal"
        case .obsidian: return "Obsidian"
        case .carbon: return "Carbon"
        case .midnight: return "Midnight"
        case .navyNoir: return "Navy Noir"
        case .titanium: return "Titanium"
        case .slate: return "Slate"
        case .moltenGold: return "Molten Gold"
        case .phantomSilver: return "Phantom Silver"
        case .ocean: return "Ocean"
        case .aurora: return "Aurora"
        case .forest: return "Forest"
        case .plum: return "Plum"
        case .ember: return "Ember"
        case .solarFlare: return "Solar Flare"
        case .electricStorm: return "Electric Storm"
        case .ultraviolet: return "Ultraviolet"
        case .arcticPulse: return "Arctic Pulse"
        case .sapphireTide: return "Sapphire Tide"
        }
    }

    var category: LifeRouteThemeCategory {
        switch self {
        case .royal, .obsidian, .carbon, .midnight, .navyNoir: return .core
        case .titanium, .slate, .moltenGold, .phantomSilver: return .metallic
        case .ocean, .aurora, .forest, .plum, .ember: return .scenery
        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse: return .dynamic
        case .sapphireTide: return .fluid
        }
    }

    var symbol: String {
        switch category {
        case .core: return "sparkles"
        case .metallic: return "hexagon.fill"
        case .scenery: return "mountain.2.fill"
        case .dynamic: return "bolt.fill"
        case .fluid: return "drop.fill"
        }
    }

    var palette: LifeRouteThemePalette {
        switch self {
        case .royal: return makeThemePalette(0x071329, 0x05284f, 0x0d2038, 0x143f68, 0xedb847, 0xfbdc80)
        case .obsidian: return makeThemePalette(0x07080a, 0x17120b, 0x111116, 0x242019, 0xd69d38, 0xffdfa0)
        case .carbon: return makeThemePalette(0x0e1114, 0x1c2228, 0x1a2026, 0x343d46, 0xb8c6d4, 0xe9f0f7)
        case .midnight: return makeThemePalette(0x080924, 0x24113f, 0x171333, 0x32265c, 0x7b68ff, 0xb8a5ff)
        case .navyNoir: return makeThemePalette(0x04101d, 0x08293d, 0x091d2c, 0x103b54, 0xd4a547, 0x63b0ff)
        case .titanium: return makeThemePalette(0x171c21, 0x2d3842, 0x292f36, 0x4a555f, 0xb4d1ef, 0xebf3fb)
        case .slate: return makeThemePalette(0x10171f, 0x263440, 0x1b2530, 0x384859, 0x96b2cc, 0xd2e0ee)
        case .moltenGold: return makeThemePalette(0x1f1002, 0x4c2503, 0x2e1906, 0x573008, 0xffbd19, 0xffe86b)
        case .phantomSilver: return makeThemePalette(0x101419, 0x242e38, 0x1a2028, 0x3c4a57, 0xc1d5e7, 0xf2f9ff)
        case .ocean: return makeThemePalette(0x031a29, 0x00465c, 0x052d3d, 0x085162, 0x35d8ef, 0x72f5df)
        case .aurora: return makeThemePalette(0x051a21, 0x162d49, 0x0a252d, 0x164c4b, 0x54f2d1, 0x7e8cff)
        case .forest: return makeThemePalette(0x061a12, 0x123821, 0x0b2519, 0x16442d, 0x79d889, 0xbfe66b)
        case .plum: return makeThemePalette(0x18081f, 0x41114d, 0x27102f, 0x511c5f, 0xe060eb, 0xff9bc7)
        case .ember: return makeThemePalette(0x211006, 0x4c1908, 0x301209, 0x5b210f, 0xff7a40, 0xffc54d)
        case .solarFlare: return makeThemePalette(0x29060a, 0x5c1405, 0x35100c, 0x6b1f0b, 0xff4f2b, 0xffc23d)
        case .electricStorm: return makeThemePalette(0x05071f, 0x220a48, 0x111235, 0x2a195b, 0x00dcff, 0x7f46ff)
        case .ultraviolet: return makeThemePalette(0x15052b, 0x430d52, 0x241037, 0x531c65, 0xb73dff, 0xff66ba)
        case .arcticPulse: return makeThemePalette(0x06172a, 0x123050, 0x0c253c, 0x1f455f, 0x5ce7e5, 0x91adff)
        case .sapphireTide: return makeThemePalette(0x00142a, 0x00506b, 0x00283f, 0x055163, 0x0782ff, 0x59f0d2)
        }
    }
}

final class LifeRouteThemeStore: ObservableObject {
    private static let storageKey = "liferoute.selectedTheme"

    @Published var selectedTheme: LifeRouteTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
            LifeRouteAppearance.configure(theme: selectedTheme)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let theme = saved.flatMap(LifeRouteTheme.init(rawValue:)) ?? .royal
        selectedTheme = theme
        LifeRouteAppearance.configure(theme: theme)
    }

    var palette: LifeRouteThemePalette { selectedTheme.palette }
}

private struct LifeRouteThemePaletteKey: EnvironmentKey {
    static let defaultValue = LifeRouteTheme.royal.palette
}

extension EnvironmentValues {
    var lifeRoutePalette: LifeRouteThemePalette {
        get { self[LifeRouteThemePaletteKey.self] }
        set { self[LifeRouteThemePaletteKey.self] = newValue }
    }
}

enum LifeRouteDesign {
    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 22
        static let hero: CGFloat = 30
    }
}

struct LifeRouteCardModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(LifeRouteDesign.Spacing.comfortable)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous).fill(palette.panelGradient))
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [palette.accentSecondary.opacity(0.24), Color.white.opacity(0.08), palette.accent.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.24), radius: 20, y: 10)
    }
}

struct LifeRoutePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.78))
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.accentGradient))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(Color.white.opacity(0.23), lineWidth: 0.8) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.14 : 0.24), radius: configuration.isPressed ? 10 : 16, y: configuration.isPressed ? 3 : 6)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct LifeRouteSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.panelElevated.opacity(configuration.isPressed ? 0.94 : 0.68)))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(palette.accent.opacity(configuration.isPressed ? 0.46 : 0.28), lineWidth: 1) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.04 : 0.09), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        ZStack {
            palette.backgroundGradient.ignoresSafeArea()
            RadialGradient(colors: [palette.accent.opacity(0.22), .clear], center: .topTrailing, startRadius: 8, endRadius: 430).ignoresSafeArea()
            RadialGradient(colors: [palette.accentSecondary.opacity(0.10), .clear], center: .bottomLeading, startRadius: 20, endRadius: 380).ignoresSafeArea()
            content.scrollContentBackground(.hidden)
        }
        .environment(\.defaultMinListRowHeight, 52)
        .tint(palette.accent)
        .preferredColorScheme(.dark)
    }
}

extension View {
    func lifeRouteCard() -> some View { modifier(LifeRouteCardModifier()) }
    func lifeRouteChrome() -> some View { modifier(LifeRouteChromeModifier()) }
}

enum LifeRouteAppearance {
    static func configure(theme: LifeRouteTheme) {
        let palette = theme.palette
        let background = UIColor(palette.backgroundTop)
        let panel = UIColor(palette.panel)
        let elevated = UIColor(palette.panelElevated)
        let accent = UIColor(palette.accent)
        let secondary = UIColor.white.withAlphaComponent(0.58)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = background.withAlphaComponent(0.78)
        nav.shadowColor = accent.withAlphaComponent(0.10)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 34, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accent
        UIBarButtonItem.appearance().tintColor = accent

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = background.withAlphaComponent(0.88)
        tab.shadowColor = accent.withAlphaComponent(0.09)
        configure(tab.stackedLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.inlineLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.compactInlineLayoutAppearance, accent: accent, secondary: secondary)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = secondary

        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = panel.withAlphaComponent(0.72)
        segmented.selectedSegmentTintColor = accent
        segmented.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.68),
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .normal)
        segmented.setTitleTextAttributes([
            .foregroundColor: UIColor.black.withAlphaComponent(0.78),
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ], for: .selected)

        UISwitch.appearance().onTintColor = accent
        UIStepper.appearance().tintColor = accent
        UIDatePicker.appearance().tintColor = accent
        UITextField.appearance().tintColor = accent
        UITextField.appearance().backgroundColor = elevated.withAlphaComponent(0.24)
        UITextView.appearance().tintColor = accent
        UITextView.appearance().backgroundColor = panel.withAlphaComponent(0.28)
        UIActivityIndicatorView.appearance().color = accent
        UIProgressView.appearance().progressTintColor = accent

        let table = UITableView.appearance()
        table.backgroundColor = .clear
        table.separatorColor = UIColor.white.withAlphaComponent(0.07)
        table.sectionHeaderTopPadding = 18

        let cell = UITableViewCell.appearance()
        cell.backgroundColor = panel.withAlphaComponent(0.54)
        cell.tintColor = accent

        UICollectionView.appearance().backgroundColor = .clear
    }

    private static func configure(_ item: UITabBarItemAppearance, accent: UIColor, secondary: UIColor) {
        item.normal.iconColor = secondary
        item.normal.titleTextAttributes = [.foregroundColor: secondary, .font: UIFont.systemFont(ofSize: 10, weight: .medium)]
        item.selected.iconColor = accent
        item.selected.titleTextAttributes = [.foregroundColor: accent, .font: UIFont.systemFont(ofSize: 10, weight: .bold)]
    }
}

@main
struct LifeRouteApp: App {
    @StateObject private var themeStore = LifeRouteThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .lifeRouteChrome()
                .environmentObject(themeStore)
                .environment(\.lifeRoutePalette, themeStore.palette)
        }
    }
}