import SwiftUI
import UIKit

#if DEBUG
struct LifeRouteVisualFixtureSelection {
    let theme: LifeRouteTheme
    let reduceMotion: Bool
}

enum LifeRouteVisualFixture: String {
    // Historical aliases remain stable for the Build #98 regression fixtures.
    case canyonDay = "canyon-day"
    case royalCurrent = "royal-current"

    static var current: LifeRouteVisualFixtureSelection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteVisualFixture") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }

        let rawValue = arguments[valueIndex]
        let aliasedTheme = LifeRouteVisualFixture(rawValue: rawValue)?.theme
        guard let theme = aliasedTheme ?? LifeRouteTheme(rawValue: rawValue),
              theme.isPhaseOneCoreGlass || theme.isV071RetainedDynamic || theme.isV071RetainedScenery else {
            return nil
        }

        return LifeRouteVisualFixtureSelection(
            theme: theme,
            reduceMotion: reduceMotionOverride
        )
    }

    static var themeOverride: LifeRouteTheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteThemeOverride") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex),
              let theme = LifeRouteTheme(rawValue: arguments[valueIndex]),
              theme.isPhaseOneCoreGlass || theme.isV071RetainedDynamic || theme.isV071RetainedScenery else {
            return nil
        }
        return theme
    }

    static var reduceMotionOverride: Bool {
        ProcessInfo.processInfo.arguments.contains("-LifeRouteFixtureReduceMotion")
    }

    var theme: LifeRouteTheme {
        switch self {
        case .canyonDay: return .sceneryCanyonDay
        case .royalCurrent: return .royalCurrent
        }
    }
}

private struct LifeRouteVisualFixtureView: View {
    let fixture: LifeRouteVisualFixtureSelection

    var body: some View {
        LifeRouteLiveThemeEnvironment(
            theme: fixture.theme,
            palette: fixture.theme.palette,
            reduceMotion: fixture.reduceMotion,
            isActive: true
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}
#endif

private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
#if DEBUG
        let fixtureReduceMotion = LifeRouteVisualFixture.reduceMotionOverride
#else
        let fixtureReduceMotion = false
#endif
        ScenicRoyalEnvironmentHost(
            theme: theme,
            palette: palette,
            reduceMotionOverride: fixtureReduceMotion
        ) {
            content
        }
    }
}

extension View {
    func lifeRouteCard() -> some View { modifier(LifeRouteCardModifier()) }
    func lifeRouteReadableTextSurface(cornerRadius: CGFloat = 14) -> some View {
        modifier(LifeRouteReadableTextSurfaceModifier(cornerRadius: cornerRadius))
    }
    func lifeRouteChrome() -> some View { modifier(LifeRouteChromeModifier()) }
}

enum LifeRouteAppearance {
    static func configure(theme: LifeRouteTheme) {
        let palette = theme.palette
        let background = UIColor(palette.backgroundTop)
        let panel = UIColor(palette.panel)
        let elevated = UIColor(palette.panelElevated)
        let accent = UIColor(palette.accent)
        let primary = UIColor(palette.textPrimary)
        let secondary = UIColor(palette.textSecondary)

        // UIKit owns the iOS 26 Liquid Glass navigation-bar material. Build 117
        // combined a global appearance proxy with repeated live-bar mutation,
        // which can leave UIKit's private navigation layout state inconsistent.
        if LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(
            ProcessInfo.processInfo.operatingSystemVersion
        ) {
            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            nav.backgroundColor = background.withAlphaComponent(0.54)
            nav.shadowColor = accent.withAlphaComponent(0.10)
            nav.titleTextAttributes = [.foregroundColor: primary, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
            nav.largeTitleTextAttributes = [.foregroundColor: primary, .font: UIFont.systemFont(ofSize: 34, weight: .bold)]

            let navButton = UIBarButtonItemAppearance(style: .plain)
            navButton.normal.titleTextAttributes = [
                .foregroundColor: accent,
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            navButton.highlighted.titleTextAttributes = [
                .foregroundColor: accent.withAlphaComponent(0.68),
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            nav.buttonAppearance = navButton
            nav.backButtonAppearance = navButton

            let doneButton = UIBarButtonItemAppearance(style: .done)
            doneButton.normal.titleTextAttributes = [
                .foregroundColor: accent,
                .font: UIFont.systemFont(ofSize: 16, weight: .bold)
            ]
            nav.doneButtonAppearance = doneButton

            UINavigationBar.appearance().standardAppearance = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactAppearance = nav
            UINavigationBar.appearance().tintColor = accent
            UIBarButtonItem.appearance().tintColor = accent
        }

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = background.withAlphaComponent(0.66)
        tab.shadowColor = accent.withAlphaComponent(0.09)
        configure(tab.stackedLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.inlineLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.compactInlineLayoutAppearance, accent: accent, secondary: secondary)
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
        tabBar.tintColor = accent
        tabBar.unselectedItemTintColor = secondary
        tabBar.itemPositioning = .fill
        tabBar.selectionIndicatorImage = makeTabSelectionIndicator(accent: accent)

        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = panel.withAlphaComponent(0.72)
        segmented.selectedSegmentTintColor = accent
        segmented.setTitleTextAttributes([
            .foregroundColor: secondary,
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
        table.separatorStyle = .none
        table.sectionHeaderTopPadding = 12

        let cell = UITableViewCell.appearance()
        cell.backgroundColor = panel.withAlphaComponent(0.28)
        cell.tintColor = accent

        let sectionLabel = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        sectionLabel.textColor = accent.withAlphaComponent(0.84)
        sectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)

        let tableButton = UIButton.appearance(whenContainedInInstancesOf: [UITableViewCell.self])
        tableButton.tintColor = accent

        UICollectionView.appearance().backgroundColor = .clear
    }

    private static func makeTabSelectionIndicator(accent: UIColor) -> UIImage {
        let size = CGSize(width: 64, height: 46)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(x: 3, y: 3, width: 58, height: 40)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)
            accent.withAlphaComponent(0.13).setFill()
            path.fill()
            accent.withAlphaComponent(0.20).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: 22, left: 31, bottom: 22, right: 31),
            resizingMode: .stretch
        )
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
#if DEBUG
            if let fixture = LifeRouteVisualFixture.current {
                LifeRouteVisualFixtureView(fixture: fixture)
            } else if ProcessInfo.processInfo.arguments.contains("-LifeRouteSessionNoteReadabilityFixture") {
                SessionNoteReadabilityFixtureView()
                    .lifeRouteChrome()
                    .environmentObject(themeStore)
                    .environment(\.lifeRoutePalette, themeStore.palette)
                    .environment(\.lifeRouteTheme, themeStore.selectedTheme)
            } else {
                appContent
            }
#else
            appContent
#endif
        }
    }

    private var appContent: some View {
        ContentView()
            .lifeRouteChrome()
            .environmentObject(themeStore)
            .environment(\.lifeRoutePalette, themeStore.palette)
            .environment(\.lifeRouteTheme, themeStore.selectedTheme)
    }
}
