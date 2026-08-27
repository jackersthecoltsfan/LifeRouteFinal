#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build A patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_design_system() -> None:
    path = "LifeRoute/LifeRouteApp.swift"
    text = read(path)
    if "v0.7.0 Build A design system" in text:
        return

    text = replace_once(
        text,
        "enum LifeRouteDesign {\n",
        "enum LifeRouteDesign {\n    // v0.7.0 Build A design system: compact premium geometry shared by every later screen family.\n",
        "design-system marker",
    )

    old_radius = '''    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 22
        static let hero: CGFloat = 30
    }
}'''
    new_radius = '''    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 18
        static let hero: CGFloat = 26
        static let iconContainer: CGFloat = 12
    }

    enum Layout {
        static let pageHorizontal: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let minimumTouchTarget: CGFloat = 44
        static let primaryControlHeight: CGFloat = 50
        static let secondaryControlHeight: CGFloat = 46
    }

    enum Stroke {
        static let subtle: CGFloat = 1
    }

    enum Elevation {
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
    }
}'''
    text = replace_once(text, old_radius, new_radius, "v0.7 design tokens")

    text = replace_once(
        text,
        ".background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous).fill(palette.panelGradient))",
        '''.background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.panelElevated.opacity(0.90), palette.panel.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )''',
        "card material",
    )
    text = replace_once(
        text,
        "colors: [palette.accentSecondary.opacity(0.24), Color.white.opacity(0.08), palette.accent.opacity(0.12)]",
        "colors: [palette.accentSecondary.opacity(0.18), Color.white.opacity(0.07), palette.accent.opacity(0.10)]",
        "card stroke palette",
    )
    text = replace_once(
        text,
        "lineWidth: 1\n                    )\n            }\n            .shadow(color: Color.black.opacity(0.24), radius: 20, y: 10)",
        "lineWidth: LifeRouteDesign.Stroke.subtle\n                    )\n            }\n            .shadow(color: Color.black.opacity(0.20), radius: LifeRouteDesign.Elevation.cardRadius, y: LifeRouteDesign.Elevation.cardY)",
        "card stroke and elevation",
    )

    text = replace_once(
        text,
        ".frame(maxWidth: .infinity, minHeight: 50)",
        ".frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.primaryControlHeight)",
        "primary control height",
    )
    text = replace_once(
        text,
        ".shadow(color: palette.accent.opacity(configuration.isPressed ? 0.14 : 0.24), radius: configuration.isPressed ? 10 : 16, y: configuration.isPressed ? 3 : 6)",
        ".shadow(color: palette.accent.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 7 : 11, y: configuration.isPressed ? 2 : 4)",
        "primary button elevation",
    )
    text = replace_once(
        text,
        ".frame(maxWidth: .infinity, minHeight: 46)",
        ".frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.secondaryControlHeight)",
        "secondary control height",
    )
    text = replace_once(
        text,
        ".shadow(color: palette.accent.opacity(configuration.isPressed ? 0.04 : 0.09), radius: 8, y: 3)",
        ".shadow(color: palette.accent.opacity(configuration.isPressed ? 0.03 : 0.07), radius: 7, y: 3)",
        "secondary button elevation",
    )

    insertion_marker = "struct LifeRouteThemeArtwork: View {\n"
    components = '''// MARK: - v0.7.0 Build A reusable visual primitives

struct LifeRoutePageBackground: View {
    @Environment(\\.lifeRoutePalette) private var palette
    @Environment(\\.lifeRouteTheme) private var theme

    var body: some View {
        LifeRouteCinematicBackdrop(theme: theme, palette: palette)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct LifeRouteSectionLabel: View {
    @Environment(\\.lifeRoutePalette) private var palette
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct LifeRouteIconBadge: View {
    @Environment(\\.lifeRoutePalette) private var palette
    let systemImage: String
    var prominent = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(prominent ? palette.accent : palette.textPrimary)
            .frame(width: LifeRouteDesign.Layout.minimumTouchTarget, height: LifeRouteDesign.Layout.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .fill(prominent ? palette.accent.opacity(0.14) : palette.panelElevated.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .stroke(prominent ? palette.accent.opacity(0.28) : Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
            }
    }
}

struct LifeRoutePill: View {
    @Environment(\\.lifeRoutePalette) private var palette
    let title: String
    var systemImage: String? = nil
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isSelected ? Color.black.opacity(0.82) : palette.textSecondary)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background {
            if isSelected {
                Capsule().fill(palette.accentGradient)
            } else {
                Capsule().fill(palette.panelElevated.opacity(0.72))
            }
        }
        .overlay {
            Capsule()
                .stroke(isSelected ? palette.accentSecondary.opacity(0.32) : Color.white.opacity(0.08), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }
}

struct LifeRouteScreenHeader: View {
    @Environment(\\.lifeRoutePalette) private var palette
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                LifeRouteIconBadge(systemImage: systemImage, prominent: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LifeRouteModalChromeModifier: ViewModifier {
    @Environment(\\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.backgroundGradient.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .tint(palette.accent)
    }
}

extension View {
    func lifeRouteModalChrome() -> some View {
        modifier(LifeRouteModalChromeModifier())
    }
}

'''
    text = replace_once(text, insertion_marker, components + insertion_marker, "shared v0.7 components")
    write(path, text)


def patch_shell() -> None:
    path = "LifeRoute/V054ContentView.swift"
    text = read(path)
    if "v0.7.0 Build A shell" in text:
        return

    old_background = '''            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.palette
            )
            .ignoresSafeArea()'''
    text = replace_once(text, old_background, "            LifeRoutePageBackground()", "shared page background")

    text = replace_once(
        text,
        ".background(Color.clear) // v0.6.3 keep cinematic scenery visible",
        ".background(Color.clear) // v0.7.0 Build A shell: preserve theme backdrop beneath native tab content",
        "Build A shell marker",
    )

    old_appearance = '''        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navigationAppearance.backgroundColor = background.withAlphaComponent(0.78)
        navigationAppearance.shadowColor = accent.withAlphaComponent(0.10)
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabAppearance.backgroundColor = background.withAlphaComponent(0.88)
        tabAppearance.shadowColor = accent.withAlphaComponent(0.09)'''
    new_appearance = '''        let chromeBlurStyle: UIBlurEffect.Style = theme == .light ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = UIBlurEffect(style: chromeBlurStyle)
        navigationAppearance.backgroundColor = background.withAlphaComponent(theme == .light ? 0.84 : 0.76)
        navigationAppearance.shadowColor = accent.withAlphaComponent(0.12)
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: UIFont.systemFont(ofSize: 17, weight: .semibold))
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont.systemFont(ofSize: 32, weight: .bold))
        ]

        let normalTabFont = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .medium))
        let selectedTabFont = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .semibold))
        let tabItems = UITabBarItemAppearance()
        tabItems.normal.iconColor = secondary
        tabItems.normal.titleTextAttributes = [
            .foregroundColor: secondary,
            .font: normalTabFont
        ]
        tabItems.selected.iconColor = accent
        tabItems.selected.titleTextAttributes = [
            .foregroundColor: accent,
            .font: selectedTabFont
        ]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: chromeBlurStyle)
        tabAppearance.backgroundColor = background.withAlphaComponent(theme == .light ? 0.90 : 0.91)
        tabAppearance.shadowColor = accent.withAlphaComponent(0.14)
        tabAppearance.stackedLayoutAppearance = tabItems
        tabAppearance.inlineLayoutAppearance = tabItems
        tabAppearance.compactInlineLayoutAppearance = tabItems'''
    text = replace_once(text, old_appearance, new_appearance, "premium native bar appearance")

    old_navigation_bar = '''            bar.compactAppearance = navigationAppearance
            bar.tintColor = accent'''
    new_navigation_bar = '''            bar.compactAppearance = navigationAppearance
            bar.tintColor = accent
            bar.prefersLargeTitles = false
            bar.isTranslucent = true'''
    text = replace_once(text, old_navigation_bar, new_navigation_bar, "compact navigation chrome")

    old_tab_bar = '''            bar.scrollEdgeAppearance = tabAppearance
            bar.tintColor = accent
            bar.unselectedItemTintColor = secondary'''
    new_tab_bar = '''            bar.scrollEdgeAppearance = tabAppearance
            bar.tintColor = accent
            bar.unselectedItemTintColor = secondary
            bar.itemPositioning = .fill
            bar.isTranslucent = true
            bar.layer.masksToBounds = false
            bar.layer.shadowColor = UIColor.black.cgColor
            bar.layer.shadowOpacity = 0.14
            bar.layer.shadowRadius = 10
            bar.layer.shadowOffset = CGSize(width: 0, height: -2)'''
    text = replace_once(text, old_tab_bar, new_tab_bar, "bottom navigation chrome")
    write(path, text)


def main() -> None:
    patch_design_system()
    patch_shell()
    print("LifeRoute v0.7.0 Build A patch applied: shared premium design system and native shell chrome restyled without changing five-tab routing or feature behavior.")


if __name__ == "__main__":
    main()
