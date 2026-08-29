#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.6.3 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_first_existing(text: str, olds: list[str], new: str, label: str) -> str:
    matches = [old for old in olds if text.count(old) == 1]
    if len(matches) != 1:
        raise SystemExit(f"v0.6.3 patch failed: {label} expected once, found {len(matches)}")
    return text.replace(matches[0], new, 1)


def sub_once(text: str, pattern: str, replacement: str, label: str, flags: int = re.S) -> str:
    text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"v0.6.3 patch failed: {label}")
    return text


def patch_theme_model() -> None:
    path = "LifeRoute/LifeRouteApp.swift"
    text = read(path)
    if "case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible" in text:
        return

    old_palette_helper = '''private func makeThemePalette(_ bgA: UInt, _ bgB: UInt, _ panel: UInt, _ elevated: UInt, _ accent: UInt, _ accent2: UInt) -> LifeRouteThemePalette {
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
}'''
    new_palette_helper = '''private func makeThemePalette(
    _ bgA: UInt,
    _ bgB: UInt,
    _ panel: UInt,
    _ elevated: UInt,
    _ accent: UInt,
    _ accent2: UInt,
    textPrimary: Color = .white,
    textSecondary: Color = .white.opacity(0.70)
) -> LifeRouteThemePalette {
    .init(
        backgroundTop: Color(hex: bgA),
        backgroundBottom: Color(hex: bgB),
        panel: Color(hex: panel),
        panelElevated: Color(hex: elevated),
        accent: Color(hex: accent),
        accentSecondary: Color(hex: accent2),
        textPrimary: textPrimary,
        textSecondary: textSecondary
    )
}'''
    text = replace_once(text, old_palette_helper, new_palette_helper, "theme palette helper")

    text = replace_once(
        text,
        "    case mountain, space, desert, sunshine\n",
        "    case mountain, space, desert, sunshine\n    case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible\n",
        "v0.6.3 core theme enum cases",
    )

    text = replace_once(
        text,
        '''        case .sunshine: return "Sunshine"
        }''',
        '''        case .sunshine: return "Sunshine"
        case .sunflare: return "Sunflare"
        case .noir: return "Noir"
        case .golden: return "Golden"
        case .cobaltShine: return "Cobalt Shine"
        case .light: return "Light"
        case .dark: return "Dark"
        case .kaleidoscope: return "Kaleidoscope"
        case .classic: return "Classic"
        case .accessible: return "Accessible"
        }''',
        "v0.6.3 core theme names",
    )

    text = replace_once(
        text,
        "        case .royal, .obsidian, .carbon, .midnight, .navyNoir: return .core",
        "        case .royal, .obsidian, .carbon, .midnight, .navyNoir, .sunflare, .noir, .golden, .cobaltShine, .light, .dark, .kaleidoscope, .classic, .accessible: return .core",
        "v0.6.3 core theme categories",
    )

    text = replace_once(
        text,
        '''        case .sunshine: return ("sun.max.fill", "sun.horizon.fill")
        }''',
        '''        case .sunshine: return ("sun.max.fill", "sun.horizon.fill")
        case .sunflare: return ("sun.max.fill", "flame.fill")
        case .noir: return ("circle.hexagongrid.fill", "diamond.fill")
        case .golden: return ("seal.fill", "sun.max.fill")
        case .cobaltShine: return ("diamond.fill", "drop.fill")
        case .light: return ("cloud.sun.fill", "sparkles")
        case .dark: return ("moon.fill", "circle.grid.cross.fill")
        case .kaleidoscope: return ("camera.filters", "sparkles")
        case .classic: return ("circle.lefthalf.filled", "square.fill")
        case .accessible: return ("accessibility", "circle.fill")
        }''',
        "v0.6.3 core artwork symbols",
    )

    text = replace_once(
        text,
        '''        case .sunshine: return makeThemePalette(0x10243b, 0x3b6a79, 0x173149, 0x426678, 0xffc44f, 0xffef9a)
        }''',
        '''        case .sunshine: return makeThemePalette(0x10243b, 0x3b6a79, 0x173149, 0x426678, 0xffc44f, 0xffef9a)
        case .sunflare: return makeThemePalette(0x251008, 0x733017, 0x431a0d, 0x88401e, 0xc8602f, 0xf1a45d)
        case .noir: return makeThemePalette(0x040506, 0x181b1f, 0x0b0d0f, 0x2d3238, 0x929aa2, 0edf1f4)
        case .golden: return makeThemePalette(0x1c1103, 0x4b3009, 0x2d1c05, 0x694613, 0xb87a25, 0xf4d36d)
        case .cobaltShine: return makeThemePalette(0x020d2b, 0x073d89, 0x061d4e, 0x0d5db7, 0x2d8cff, 0x83c8ff)
        case .light: return makeThemePalette(
            0xf7eaf2, 0xeaf4ff, 0xf5f0ff, 0xeef9f2, 0xb9a7e8, 0xf3c7d9,
            textPrimary: Color(hex: 0x18222c),
            textSecondary: Color(hex: 0x344451).opacity(0.82)
        )
        case .dark: return makeThemePalette(0x040609, 0x11161d, 0x0a0e13, 0x1b232c, 0x526778, 0x718596)
        case .kaleidoscope: return makeThemePalette(0x25104f, 0x082f6f, 0x321267, 0x0d5d88, 0xffd43b, 0xff4fab)
        case .classic: return makeThemePalette(0x000000, 0x1a1a1a, 0x101010, 0x343434, 0xbfbfbf, 0xffffff)
        case .accessible: return makeThemePalette(0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff, textPrimary: .white, textSecondary: .white)
        }''',
        "v0.6.3 core palettes",
    )

    # The outer app chrome is the true app-wide background. Use the same cinematic
    # renderer there so Scenery imagery survives navigation pushes and every tab.
    pattern = r'''private struct LifeRouteChromeModifier: ViewModifier \{.*?\n\}\n\nprivate struct LifeRouteThemeBackdrop'''
    replacement = '''private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\\.lifeRoutePalette) private var palette
    @Environment(\\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        ZStack {
            LifeRouteCinematicBackdrop(theme: theme, palette: palette)
                .ignoresSafeArea()
            content
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: theme)
        .environment(\\.defaultMinListRowHeight, 52)
        .tint(palette.accent)
        .preferredColorScheme(theme == .light ? .light : .dark)
    }
}

private struct LifeRouteThemeBackdrop'''
    text = sub_once(text, pattern, replacement, "global cinematic chrome")

    # Respect the Light palette's dark typography while preserving all existing dark themes.
    text = replace_once(
        text,
        "        let secondary = UIColor.white.withAlphaComponent(0.58)\n",
        "        let primary = UIColor(palette.textPrimary)\n        let secondary = UIColor(palette.textSecondary)\n",
        "appearance palette text colors",
    )
    text = text.replace(".foregroundColor: UIColor.white,", ".foregroundColor: primary,")
    text = text.replace(".foregroundColor: UIColor.white.withAlphaComponent(0.68),", ".foregroundColor: secondary,")

    write(path, text)


def patch_theme_center() -> None:
    path = "LifeRoute/V054ThemeCenterView.swift"
    text = read(path)
    desired = "[.royal, .cobaltShine, .golden, .sunflare, .noir, .kaleidoscope, .light, .dark, .classic, .accessible]"
    if desired in text:
        return

    text = replace_first_existing(
        text,
        [
            "[.royal, .obsidian, .carbon, .midnight, .navyNoir, .titanium, .slate, .moltenGold, .phantomSilver]",
            "return LifeRouteTheme.phaseOneCoreGlassCatalog",
        ],
        desired,
        "ordered v0.6.3 Core theme catalog",
    )
    text = replace_first_existing(
        text,
        [
            "Core combines the original LifeRoute and metallic color systems. Dynamic themes use animated shimmering light waves across every screen. Scenery contains six persistent cinematic environments: Mountain, Ocean, Space, Desert, Forest, and Sunshine.",
            "12 still app-wide glass environments with no continuous ambient motion.",
        ],
        "Core contains ten polished metallic color systems, ordered from LifeRoute’s signature Royal through expressive colorways and then minimal utility themes. Dynamic keeps animated shimmering light waves. Scenery keeps six cinematic environments whose imagery persists across every app page.",
        "v0.6.3 Theme Center description",
    )
    write(path, text)


def patch_cinematic_backdrop() -> None:
    path = "LifeRoute/CinematicThemeViews.swift"
    text = read(path)
    if "v0.6.3 polished Core treatment" in text or "v0.6.3 Core color-scheme-only cleanup" in text:
        return

    text = replace_once(text, 'case .core: return "Premium Dark"', 'case .core: return "Polished Metallic"', "Core treatment label")

    old_core_scenery = '''        case .core, .scenery:
            ZStack {
                palette.backgroundGradient
                RadialGradient(
                    colors: [palette.accent.opacity(0.22), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: max(size.width, size.height) * 0.8
                )
                LifeRouteThemeArtwork(theme: theme, palette: palette, compact: compact)
            }'''
    new_core_scenery = '''        case .core:
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
            }'''
    text = replace_once(text, old_core_scenery, new_core_scenery, "polished Core fallback")
    write(path, text)


def patch_shell_transparency() -> None:
    path = "LifeRoute/V054ContentView.swift"
    text = read(path)
    if ".background(Color.clear) // v0.6.3 keep cinematic scenery visible" in text:
        return
    current_content = read("LifeRoute/ContentView.swift")
    if "TabView(selection: $router.selectedSection)" in current_content and ".toolbar(.hidden, for: .tabBar)" in current_content:
        return

    text = replace_once(
        text,
        "            .tint(themeStore.palette.accent)\n",
        "            .tint(themeStore.palette.accent)\n            .background(Color.clear) // v0.6.3 keep cinematic scenery visible\n",
        "TabView transparency",
    )

    text = replace_once(
        text,
        "        let secondary = UIColor.white.withAlphaComponent(0.58)\n",
        "        let primary = UIColor(palette.textPrimary)\n        let secondary = UIColor(palette.textSecondary)\n",
        "visible chrome palette text colors",
    )
    text = text.replace(".foregroundColor: UIColor.white,", ".foregroundColor: primary,")
    write(path, text)


def patch_timer_audio() -> None:
    path = "LifeRoute/SessionToolsDomain.swift"
    text = read(path)
    if "v0.6.3 cosine release" in text:
        return

    text = replace_once(text, "    private static let pulseDuration = 0.11", "    private static let pulseDuration = 0.14", "gentler pulse duration")

    old_pulse = '''            let attack = min(1, t / 0.006)
            let decay = exp(-24 * t)
            let fundamental = sin(2 * Double.pi * frequency * t)
            let bellSecond = 0.20 * sin(2 * Double.pi * frequency * 2.0 * t)
            let bellThird = 0.07 * sin(2 * Double.pi * frequency * 3.01 * t)
            let softDetune = 0.06 * sin(2 * Double.pi * frequency * 1.006 * t)
            samples[frame] = Float((fundamental + bellSecond + bellThird + softDetune) * attack * decay * 0.60)'''
    new_pulse = '''            let attack = min(1, t / 0.012)
            let decay = exp(-18 * t)
            let releaseStart = Self.pulseDuration * 0.62
            let releaseProgress = max(0, (t - releaseStart) / (Self.pulseDuration - releaseStart))
            // v0.6.3 cosine release reaches silence smoothly so the buffer cannot end on a click.
            let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
            let fundamental = sin(2 * Double.pi * frequency * t)
            let softSecond = 0.12 * sin(2 * Double.pi * frequency * 2.0 * t)
            let softDetune = 0.025 * sin(2 * Double.pi * frequency * 1.004 * t)
            samples[frame] = Float((fundamental + softSecond + softDetune) * attack * decay * release * 0.46)'''
    text = replace_once(text, old_pulse, new_pulse, "click-free gentle pulse synthesis")

    old_completion = '''                let attack = min(1, localTime / 0.008)
                let decay = exp(-19 * localTime)
                value += sin(2 * Double.pi * note.frequency * localTime) * attack * decay * 0.85'''
    new_completion = '''                let attack = min(1, localTime / 0.012)
                let decay = exp(-16 * localTime)
                let releaseStart = 0.12
                let releaseProgress = max(0, (localTime - releaseStart) / (0.19 - releaseStart))
                let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
                let fundamental = sin(2 * Double.pi * note.frequency * localTime)
                let softSecond = 0.10 * sin(2 * Double.pi * note.frequency * 2.0 * localTime)
                value += (fundamental + softSecond) * attack * decay * release * 0.68'''
    text = replace_once(text, old_completion, new_completion, "click-free completion-note release")
    write(path, text)


def patch_live_day_core() -> None:
    path = "LifeRoute/LiveDayActivityCore.swift"
    text = read(path)
    if "day: Date = Date()" in text:
        return

    text = replace_once(
        text,
        '''        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool
    ) async {''',
        '''        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool,
        day: Date = Date()
    ) async {''',
        "selected day Live Activity input",
    )
    text = replace_once(
        text,
        '            message = "Add a timed event today before starting Live Day on the Lock Screen."',
        '            message = "Add a timed event on the selected day before starting Live Day on the Lock Screen."',
        "selected day empty message",
    )
    text = replace_once(
        text,
        "            dayLabel: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())",
        "            dayLabel: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())",
        "selected day Live Activity label",
    )
    write(path, text)


def patch_day_route_planner() -> None:
    path = "LifeRoute/DayRoutePlanningView.swift"
    text = read(path)
    if "var day: Date = Date()" in text:
        return

    text = replace_once(
        text,
        "    @ObservedObject var routingState: RoutingLocationCore\n",
        "    @ObservedObject var routingState: RoutingLocationCore\n    var day: Date = Date()\n",
        "route planner selected day",
    )
    text = text.replace("todayEvents", "dayEvents")
    text = replace_once(text, "        calendarState.events(on: Date())", "        calendarState.events(on: day)", "route planner day event query")
    text = replace_once(
        text,
        'Text("No calendar events with locations are available today. Add or refresh an event location in Schedule first.")',
        'Text("No calendar events with locations are available on \\(day.formatted(date: .abbreviated, time: .omitted)). Add or refresh an event location in Schedule first.")',
        "route planner selected day empty copy",
    )
    write(path, text)


def patch_today_selected_day() -> None:
    path = "LifeRoute/V054TodayView.swift"
    text = read(path)
    if "private var daySelector: some View" in text:
        return

    text = replace_once(
        text,
        "    @State private var returnHomeOnLiveDay = true\n",
        "    @State private var returnHomeOnLiveDay = true\n    @State private var selectedDay = Calendar.current.startOfDay(for: Date())\n",
        "main selected day state",
    )
    text = replace_once(
        text,
        "                hero\n                quickActions",
        "                hero\n                daySelector\n                quickActions",
        "main day selector placement",
    )
    text = replace_once(
        text,
        '        .navigationTitle("Today")\n',
        '        .navigationTitle(Calendar.current.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))\n        .onChange(of: selectedDay) { _ in\n            liveDayEnabled = false\n        }\n',
        "selected day navigation title",
    )

    text = text.replace("todayEvents", "selectedDayEvents")
    text = replace_once(
        text,
        "        calendarState.events(on: Date()).sorted { $0.start < $1.start }",
        "        calendarState.events(on: selectedDay).sorted { $0.start < $1.start }",
        "selected day event query",
    )
    text = replace_once(
        text,
        "        selectedDayEvents.first { $0.end > Date() }",
        "        Calendar.current.isDateInToday(selectedDay) ? selectedDayEvents.first { $0.end > Date() } : selectedDayEvents.first",
        "selected day next event",
    )

    selector = '''
    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DAY")
            HStack(spacing: 10) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                VStack(spacing: 3) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(palette.accent)

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            if !Calendar.current.isDateInToday(selectedDay) {
                Button {
                    selectedDay = Calendar.current.startOfDay(for: Date())
                    LifeRouteHaptics.selection()
                } label: {
                    Label("Jump to Today", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

'''
    text = replace_once(text, "    private var hero: some View {\n", selector + "    private var hero: some View {\n", "day selector view")

    # Every route-plan entry launched from the main screen inherits the selected day.
    planner_call = "DayRoutePlanningView(calendarState: calendarState, routingState: routingState)"
    count = text.count(planner_call)
    if count < 1:
        raise SystemExit("v0.6.3 patch failed: selected day planner calls missing")
    text = text.replace(planner_call, "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)")

    text = replace_once(text, 'sectionLabel("TODAY’S OVERVIEW")', 'sectionLabel(Calendar.current.isDateInToday(selectedDay) ? "TODAY’S OVERVIEW" : "DAY OVERVIEW")', "selected day overview label")
    text = replace_once(
        text,
        'Text("Generate a time-aware day and keep the next event / leave countdown visible on the iPhone Lock Screen and Dynamic Island.")',
        'Text("Generate and launch the selected day, with the next event / leave countdown visible on the iPhone Lock Screen and Dynamic Island.")',
        "selected day Live Day copy",
    )
    text = replace_once(
        text,
        'Label("Generate day + start Live Activity", systemImage: "sparkles")',
        'Label("Generate + launch selected day", systemImage: "sparkles")',
        "selected day launch button",
    )

    old_start_tail = '''                            routeEstimates: routingState.routeEstimates,
                            returnHomePlanned: returnHomeOnLiveDay
                        )'''
    new_start_tail = '''                            routeEstimates: routingState.routeEstimates,
                            returnHomePlanned: returnHomeOnLiveDay,
                            day: selectedDay
                        )'''
    # Only the start call gets the day parameter; update keeps its existing contract.
    start_index = text.find("await liveActivity.start(")
    if start_index == -1:
        raise SystemExit("v0.6.3 patch failed: Live Activity start call missing")
    tail_index = text.find(old_start_tail, start_index)
    if tail_index == -1:
        raise SystemExit("v0.6.3 patch failed: Live Activity start tail missing")
    text = text[:tail_index] + new_start_tail + text[tail_index + len(old_start_tail):]

    helper = '''
    private func shiftSelectedDay(by days: Int) {
        guard let shifted = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) else { return }
        selectedDay = Calendar.current.startOfDay(for: shifted)
        LifeRouteHaptics.selection()
    }

'''
    text = replace_once(text, "    private func timeRemaining(to target: Date, now: Date) -> String {\n", helper + "    private func timeRemaining(to target: Date, now: Date) -> String {\n", "selected day shift helper")
    write(path, text)


def main() -> None:
    patch_theme_model()
    patch_theme_center()
    patch_cinematic_backdrop()
    patch_shell_transparency()
    patch_timer_audio()
    patch_live_day_core()
    patch_day_route_planner()
    patch_today_selected_day()
    print("LifeRoute v0.6.3 native patch applied: persistent scenery, ten polished Core themes, selected-day generation/routing, and click-free gentler timer audio.")


if __name__ == "__main__":
    main()
