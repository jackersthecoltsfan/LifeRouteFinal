#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build B.1 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


HERO_SCENE = r'''private struct LifeRouteTodayHeroScene: View {
    private let brandGold = Color(red: 0.96, green: 0.72, blue: 0.20)
    private let brandGoldBright = Color(red: 1.00, green: 0.86, blue: 0.43)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.015, green: 0.055, blue: 0.12),
                        Color(red: 0.02, green: 0.16, blue: 0.29),
                        Color(red: 0.015, green: 0.07, blue: 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.08, green: 0.46, blue: 0.72).opacity(0.55),
                        Color(red: 0.02, green: 0.18, blue: 0.34).opacity(0.24),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.46, y: 0.43),
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.72
                )

                Ellipse()
                    .fill(Color(red: 0.18, green: 0.58, blue: 0.82).opacity(0.13))
                    .frame(width: size.width * 0.92, height: size.height * 0.30)
                    .blur(radius: 18)
                    .offset(x: -size.width * 0.08, y: size.height * 0.04)

                mountainBack(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.30, blue: 0.50).opacity(0.74),
                                Color(red: 0.025, green: 0.11, blue: 0.23).opacity(0.95),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                mountainMid(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.22, blue: 0.38),
                                Color(red: 0.015, green: 0.065, blue: 0.13),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                mountainFront(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.025, green: 0.09, blue: 0.16),
                                Color.black.opacity(0.94),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                routePath(size)
                    .stroke(
                        brandGold.opacity(0.22),
                        style: StrokeStyle(lineWidth: 17, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 10)

                routePath(size)
                    .stroke(
                        brandGold.opacity(0.42),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 4)

                routePath(size)
                    .stroke(
                        LinearGradient(
                            colors: [brandGoldBright, brandGold, brandGoldBright],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round)
                    )

                routePath(size)
                    .stroke(
                        Color.white.opacity(0.50),
                        style: StrokeStyle(lineWidth: 0.65, lineCap: .round, lineJoin: .round)
                    )
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func mountainBack(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.56))
            path.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.42))
            path.addLine(to: CGPoint(x: size.width * 0.20, y: size.height * 0.25))
            path.addLine(to: CGPoint(x: size.width * 0.31, y: size.height * 0.47))
            path.addLine(to: CGPoint(x: size.width * 0.44, y: size.height * 0.31))
            path.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.45))
            path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.24))
            path.addLine(to: CGPoint(x: size.width * 0.84, y: size.height * 0.44))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.31))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func mountainMid(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width * 0.15, y: size.height * 0.44))
            path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.43, y: size.height * 0.39))
            path.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.60))
            path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.38))
            path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.55))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.44))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func mountainFront(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.75))
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.61))
            path.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.74))
            path.addLine(to: CGPoint(x: size.width * 0.53, y: size.height * 0.58))
            path.addLine(to: CGPoint(x: size.width * 0.70, y: size.height * 0.73))
            path.addLine(to: CGPoint(x: size.width * 0.87, y: size.height * 0.62))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.69))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func routePath(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.49, y: size.height * 1.06))
            path.addCurve(
                to: CGPoint(x: size.width * 0.53, y: size.height * 0.74),
                control1: CGPoint(x: size.width * 0.33, y: size.height * 0.91),
                control2: CGPoint(x: size.width * 0.70, y: size.height * 0.84)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.46, y: size.height * 0.60),
                control1: CGPoint(x: size.width * 0.59, y: size.height * 0.69),
                control2: CGPoint(x: size.width * 0.39, y: size.height * 0.68)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.61, y: size.height * 0.49),
                control1: CGPoint(x: size.width * 0.50, y: size.height * 0.55),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.53)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.75, y: size.height * 0.44),
                control1: CGPoint(x: size.width * 0.66, y: size.height * 0.47),
                control2: CGPoint(x: size.width * 0.70, y: size.height * 0.46)
            )
        }
    }
}
'''


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 Build B.1 Today/Home parity" in text:
        return
    if "v0.7.0 Build B Today/Home" not in text:
        raise SystemExit("v0.7.0 Build B.1 patch failed: Build B Today/Home baseline is not materialized")

    text = replace_once(
        text,
        "// v0.7.0 Build B Today/Home: the reference implementation for the v0.7 screen language.\n",
        "// v0.7.0 Build B Today/Home: the reference implementation for the v0.7 screen language.\n// v0.7.0 Build B.1 Today/Home parity: device-tuned against the approved target screenshot.\n",
        "B.1 marker",
    )

    text = replace_once(
        text,
        "    @State private var selectedDay = Calendar.current.startOfDay(for: Date())\n",
        "    @State private var selectedDay = Calendar.current.startOfDay(for: Date())\n    @State private var showingDayPicker = false\n",
        "day picker state",
    )

    text = replace_once(
        text,
        "                hero\n                daySelector\n                quickActions\n",
        "                hero\n                if !Calendar.current.isDateInToday(selectedDay) {\n                    selectedDayContext\n                }\n                quickActions\n",
        "remove persistent day card",
    )

    text = replace_once(
        text,
        "        .onChange(of: selectedDay) { _ in\n            liveDayEnabled = false\n        }\n",
        "        .onChange(of: selectedDay) { _ in\n            liveDayEnabled = false\n        }\n        .sheet(isPresented: $showingDayPicker) {\n            dayPickerSheet\n        }\n",
        "day picker sheet presentation",
    )

    old_sun = '''                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accentSecondary)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.30), in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                        .accessibilityHidden(true)'''
    new_sun = '''                    Button {
                        showingDayPicker = true
                        LifeRouteHaptics.selection()
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(brandGold)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.30), in: Circle())
                            .overlay {
                                Circle().stroke(brandGold.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose day")'''
    text = replace_once(text, old_sun, new_sun, "hero day-picker button")

    text = replace_once(
        text,
        "                    Text(\"Route\")\n                        .foregroundStyle(palette.accentSecondary)\n",
        "                    Text(\"Route\")\n                        .foregroundStyle(brandGold)\n",
        "brand title gold",
    )

    text = replace_once(
        text,
        "                        accent: palette.accentSecondary\n                    )\n",
        "                        accent: brandGold\n                    )\n",
        "Plan Route gold",
    )
    text = replace_once(
        text,
        "                        accent: palette.accent,\n                        isActive: routingState.liveLocationEnabled\n",
        "                        accent: routeBlue,\n                        isActive: routingState.liveLocationEnabled\n",
        "Current Location blue",
    )
    text = replace_once(
        text,
        "                    quickActionLabel(\"Open Schedule\", \"calendar\", accent: palette.accentSecondary)\n",
        "                    quickActionLabel(\"Open Schedule\", \"calendar\", accent: schedulePurple)\n",
        "Schedule purple",
    )
    text = replace_once(
        text,
        "                    quickActionLabel(\"Add Stop\", \"plus\", accent: palette.accentSecondary)\n",
        "                    quickActionLabel(\"Add Stop\", \"plus\", accent: brandGold)\n",
        "Add Stop gold",
    )

    text = replace_once(
        text,
        "                    .foregroundStyle(palette.accentSecondary)\n                    .lineLimit(2)\n",
        "                    .foregroundStyle(brandGold)\n                    .lineLimit(2)\n",
        "event title gold",
    )
    text = replace_once(
        text,
        "                    .foregroundStyle(palette.accent)\n                    .lineLimit(1)\n                    .minimumScaleFactor(0.72)\n",
        "                    .foregroundStyle(routeBlue)\n                    .lineLimit(1)\n                    .minimumScaleFactor(0.72)\n",
        "event countdown blue",
    )

    text = replace_once(
        text,
        '''                overviewMetric(
                    value: "\\(drivingEstimates.count)",
                    label: "Total Drives",
                    detail: Calendar.current.isDateInToday(selectedDay) ? "Today" : "Calculated",
                    systemImage: "car.fill"
                )
                overviewMetric(
                    value: totalDrivingDurationLabel,
                    label: "Est. Driving",
                    detail: "Total",
                    systemImage: "clock.fill"
                )''',
        '''                overviewMetric(
                    value: "\\(drivingEstimates.count)",
                    label: "Total Drives",
                    detail: Calendar.current.isDateInToday(selectedDay) ? "Today" : "Calculated",
                    systemImage: "car.fill",
                    accent: brandGold
                )
                overviewMetric(
                    value: totalDrivingDurationLabel,
                    label: "Est. Driving",
                    detail: "Total",
                    systemImage: "clock.fill",
                    accent: routeBlue
                )''',
        "overview metric accents",
    )

    text = replace_once(
        text,
        "        systemImage: String\n    ) -> some View {\n",
        "        systemImage: String,\n        accent: Color\n    ) -> some View {\n",
        "overview metric signature",
    )
    text = replace_once(
        text,
        "                    .foregroundStyle(palette.accent)\n                Text(label)\n",
        "                    .foregroundStyle(accent)\n                Text(label)\n",
        "overview metric icon accent",
    )
    text = replace_once(
        text,
        "                .foregroundStyle(palette.textPrimary)\n                .lineLimit(1)\n                .minimumScaleFactor(0.72)\n            Text(detail)\n",
        "                .foregroundStyle(accent)\n                .lineLimit(1)\n                .minimumScaleFactor(0.72)\n            Text(detail)\n",
        "overview metric value accent",
    )

    selector_marker = "    private var daySelector: some View {\n"
    selector_insert = r'''    private var brandGold: Color {
        Color(red: 0.96, green: 0.72, blue: 0.20)
    }

    private var routeBlue: Color {
        Color(red: 0.28, green: 0.72, blue: 0.96)
    }

    private var schedulePurple: Color {
        Color(red: 0.68, green: 0.40, blue: 0.96)
    }

    private var selectedDayContext: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(brandGold)
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 8)
            Button("Back to Today") {
                selectedDay = Calendar.current.startOfDay(for: Date())
                LifeRouteHaptics.selection()
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(brandGold)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(palette.panel.opacity(0.52), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                LifeRouteScreenHeader(
                    title: "Choose Day",
                    subtitle: "Home stays compact; date browsing remains available here.",
                    systemImage: "calendar"
                )
                daySelector
                Spacer(minLength: 0)
            }
            .padding(16)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDayPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(245)])
        .lifeRouteModalChrome()
    }

'''
    text = replace_once(text, selector_marker, selector_insert + selector_marker, "compact day picker helpers")

    hero_marker = "private struct LifeRouteTodayHeroScene: View {\n"
    if hero_marker not in text:
        raise SystemExit("v0.7.0 Build B.1 patch failed: hero scene marker missing")
    text = text.split(hero_marker, 1)[0] + HERO_SCENE

    PATH.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 Build B.1 patch applied: persistent date card removed from default Home, selected-day browsing moved behind the hero control, blue/gold target accents locked into Home, and the mountain-road hero gained higher-contrast cinematic depth."
    )


if __name__ == "__main__":
    main()
