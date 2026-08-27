import SwiftUI
import UIKit

enum LifeRouteDesign {
    enum ColorToken {
        static let midnight = Color(red: 0.025, green: 0.055, blue: 0.12)
        static let deepNavy = Color(red: 0.035, green: 0.09, blue: 0.19)
        static let navy = Color(red: 0.055, green: 0.14, blue: 0.28)
        static let elevatedNavy = Color(red: 0.075, green: 0.18, blue: 0.34)
        static let gold = Color(red: 0.93, green: 0.72, blue: 0.28)
        static let softGold = Color(red: 0.98, green: 0.84, blue: 0.48)
        static let primaryText = Color.white.opacity(0.96)
        static let secondaryText = Color.white.opacity(0.68)
        static let hairline = Color.white.opacity(0.10)
        static let cardFill = Color.white.opacity(0.055)
    }

    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 18
        static let hero: CGFloat = 24
    }

    static let screenGradient = LinearGradient(
        colors: [ColorToken.midnight, ColorToken.deepNavy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambientGlow = RadialGradient(
        colors: [ColorToken.navy.opacity(0.48), ColorToken.midnight.opacity(0)],
        center: .topTrailing,
        startRadius: 10,
        endRadius: 420
    )

    static let accentGlow = RadialGradient(
        colors: [ColorToken.gold.opacity(0.10), ColorToken.midnight.opacity(0)],
        center: .bottomLeading,
        startRadius: 20,
        endRadius: 360
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.085), ColorToken.navy.opacity(0.22)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStroke = LinearGradient(
        colors: [ColorToken.softGold.opacity(0.24), ColorToken.hairline, ColorToken.gold.opacity(0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct LifeRouteCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(LifeRouteDesign.Spacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .fill(LifeRouteDesign.cardGradient)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .stroke(LifeRouteDesign.cardStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}

struct LifeRoutePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(LifeRouteDesign.ColorToken.midnight)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, LifeRouteDesign.Spacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LifeRouteDesign.ColorToken.softGold, LifeRouteDesign.ColorToken.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
            }
            .shadow(color: LifeRouteDesign.ColorToken.gold.opacity(0.16), radius: 14, y: 5)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct LifeRouteChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LifeRouteDesign.screenGradient
                .ignoresSafeArea()
            LifeRouteDesign.ambientGlow
                .ignoresSafeArea()
            LifeRouteDesign.accentGlow
                .ignoresSafeArea()
            content
                .scrollContentBackground(.hidden)
        }
        .environment(\.defaultMinListRowHeight, 50)
        .tint(LifeRouteDesign.ColorToken.gold)
        .preferredColorScheme(.dark)
    }
}

extension View {
    func lifeRouteCard() -> some View {
        modifier(LifeRouteCardModifier())
    }

    func lifeRouteChrome() -> some View {
        modifier(LifeRouteChromeModifier())
    }
}

private enum LifeRouteAppearance {
    private static let midnight = UIColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1)
    private static let deepNavy = UIColor(red: 0.035, green: 0.09, blue: 0.19, alpha: 1)
    private static let elevatedNavy = UIColor(red: 0.075, green: 0.18, blue: 0.34, alpha: 1)
    private static let gold = UIColor(red: 0.93, green: 0.72, blue: 0.28, alpha: 1)
    private static let softGold = UIColor(red: 0.98, green: 0.84, blue: 0.48, alpha: 1)
    private static let secondary = UIColor.white.withAlphaComponent(0.58)
    private static let hairline = UIColor.white.withAlphaComponent(0.08)

    static func configure() {
        configureNavigation()
        configureTabs()
        configureControls()
        configureScrollableSurfaces()
    }

    private static func configureNavigation() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithTransparentBackground()
        navigation.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navigation.backgroundColor = deepNavy.withAlphaComponent(0.78)
        navigation.shadowColor = gold.withAlphaComponent(0.10)
        navigation.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigation
        navigationBar.scrollEdgeAppearance = navigation
        navigationBar.compactAppearance = navigation
        navigationBar.tintColor = gold

        let barButton = UIBarButtonItem.appearance()
        barButton.tintColor = gold
        barButton.setTitleTextAttributes([.foregroundColor: gold], for: .normal)
    }

    private static func configureTabs() {
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = midnight.withAlphaComponent(0.86)
        tab.shadowColor = gold.withAlphaComponent(0.09)
        configure(tab.stackedLayoutAppearance)
        configure(tab.inlineLayoutAppearance)
        configure(tab.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
        tabBar.tintColor = gold
        tabBar.unselectedItemTintColor = secondary
    }

    private static func configureControls() {
        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = elevatedNavy.withAlphaComponent(0.62)
        segmented.selectedSegmentTintColor = gold
        segmented.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.78),
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        segmented.setTitleTextAttributes([
            .foregroundColor: midnight,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)

        UISwitch.appearance().onTintColor = gold
        UISwitch.appearance().thumbTintColor = UIColor.white
        UIStepper.appearance().tintColor = gold
        UIDatePicker.appearance().tintColor = gold
        UISlider.appearance().minimumTrackTintColor = gold
        UITextField.appearance().tintColor = softGold
        UITextView.appearance().tintColor = softGold
        UIRefreshControl.appearance().tintColor = gold
        UIActivityIndicatorView.appearance().color = gold
        UIProgressView.appearance().progressTintColor = gold
    }

    private static func configureScrollableSurfaces() {
        let table = UITableView.appearance()
        table.backgroundColor = .clear
        table.separatorColor = hairline
        table.sectionHeaderTopPadding = 12

        UITableViewCell.appearance().backgroundColor = deepNavy.withAlphaComponent(0.60)
        UITableViewHeaderFooterView.appearance().tintColor = .clear
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self]).textColor = secondary

        UICollectionView.appearance().backgroundColor = .clear
        UICollectionViewCell.appearance().backgroundColor = .clear

        UIScrollView.appearance().indicatorStyle = .white
    }

    private static func configure(_ item: UITabBarItemAppearance) {
        item.normal.iconColor = secondary
        item.normal.titleTextAttributes = [
            .foregroundColor: secondary,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        item.selected.iconColor = gold
        item.selected.titleTextAttributes = [
            .foregroundColor: gold,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
    }
}

@main
struct LifeRouteApp: App {
    init() {
        LifeRouteAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .lifeRouteChrome()
        }
    }
}
