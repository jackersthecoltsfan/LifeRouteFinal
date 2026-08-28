from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    target = ROOT / path
    text = target.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise SystemExit(
            f"v0.7.1 theme fixture matrix patch expected one anchor in {path}, "
            f"found {text.count(old)}"
        )
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "LifeRoute/LifeRouteApp.swift",
    '''#if DEBUG
private enum LifeRouteVisualFixture: String {
    case canyonDay = "canyon-day"
    case royalCurrent = "royal-current"

    static var current: LifeRouteVisualFixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteVisualFixture") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return LifeRouteVisualFixture(rawValue: arguments[valueIndex])
    }

    static var themeOverride: LifeRouteTheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteThemeOverride") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return LifeRouteTheme(rawValue: arguments[valueIndex])
    }

    var theme: LifeRouteTheme {
        switch self {
        case .canyonDay: return .sceneryCanyonDay
        case .royalCurrent: return .royalCurrent
        }
    }
}

private struct LifeRouteVisualFixtureView: View {
    let fixture: LifeRouteVisualFixture

    var body: some View {
        LifeRouteLiveThemeEnvironment(
            theme: fixture.theme,
            palette: fixture.theme.palette,
            reduceMotion: false,
            isActive: true
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}
#endif''',
    '''#if DEBUG
private struct LifeRouteVisualFixtureSelection {
    let theme: LifeRouteTheme
    let reduceMotion: Bool
}

private enum LifeRouteVisualFixture: String {
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
              theme.isV071RetainedDynamic || theme.isV071RetainedScenery else {
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
              theme.isV071RetainedDynamic || theme.isV071RetainedScenery else {
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
#endif''',
)

replace_once(
    "LifeRoute/LifeRouteApp.swift",
    '''    func body(content: Content) -> some View {
        // v0.7.0 Theme Phase 3 persistent environment host: one mount above the five-tab shell.''',
    '''    func body(content: Content) -> some View {
#if DEBUG
        let fixtureReduceMotion = LifeRouteVisualFixture.reduceMotionOverride
#else
        let fixtureReduceMotion = false
#endif
        // v0.7.0 Theme Phase 3 persistent environment host: one mount above the five-tab shell.''',
)

replace_once(
    "LifeRoute/LifeRouteApp.swift",
    '''                    reduceMotion: reduceMotion,
                    isActive: scenePhase == .active''',
    '''                    reduceMotion: reduceMotion || fixtureReduceMotion,
                    isActive: scenePhase == .active''',
)

replace_once(
    "LifeRoute/LifeRouteApp.swift",
    '''        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: theme)''',
    '''        .animation((reduceMotion || fixtureReduceMotion) ? nil : .easeInOut(duration: 0.24), value: theme)''',
)

replace_once(
    "LifeRoute/V054ContentView.swift",
    '''    static var sectionOverride: AppSection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteSectionOverride") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return AppSection(rawValue: arguments[valueIndex])
    }
}''',
    '''    static var sectionOverride: AppSection? {
        section(for: "-LifeRouteSectionOverride")
    }

    static var cycleSectionOverride: AppSection? {
        section(for: "-LifeRouteCycleSection")
    }

    static let cycleDelayNanoseconds: UInt64 = 9_000_000_000

    private static func section(for argument: String) -> AppSection? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: argument) else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return AppSection(rawValue: arguments[valueIndex])
    }
}''',
)

replace_once(
    "LifeRoute/V054ContentView.swift",
    '''        .onChange(of: router.selectedSection) { _ in''',
    '''        .task {
#if DEBUG
            guard let section = LifeRouteDebugLaunch.cycleSectionOverride else { return }
            try? await Task.sleep(nanoseconds: LifeRouteDebugLaunch.cycleDelayNanoseconds)
            guard !Task.isCancelled else { return }
            router.select(section)
#endif
        }
        .onChange(of: router.selectedSection) { _ in''',
)

print(
    "LifeRoute v0.7.1 theme fixture matrix patch applied: all twenty retained raw theme "
    "identifiers can launch in the standalone renderer or full app shell; Reduce Motion can be "
    "forced deterministically; and DEBUG validation can move from Today to another tab in-process."
)
