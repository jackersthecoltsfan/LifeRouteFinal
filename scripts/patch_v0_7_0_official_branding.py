#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
TODAY = ROOT / "LifeRoute/V054TodayView.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"
WIDGET = ROOT / "LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 official branding patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_brand_component() -> None:
    text = APP.read_text(encoding="utf-8")
    if "v0.7.0 official LifeRoute brand mark" in text:
        return
    anchor = "struct LifeRouteSectionLabel: View {"
    if anchor not in text:
        raise SystemExit("v0.7.0 official branding patch failed: shared brand component anchor missing")

    component = r'''// v0.7.0 official LifeRoute brand mark — refined 1E/1F hybrid identity.
enum LifeRouteBrandMarkVariant {
    case master
    case standard
    case small
    case micro
}

struct LifeRouteBrandMark: View {
    let variant: LifeRouteBrandMarkVariant

    private let navyDeep = Color(red: 0.008, green: 0.027, blue: 0.075)
    private let navyMid = Color(red: 0.025, green: 0.105, blue: 0.22)
    private let navyLift = Color(red: 0.06, green: 0.22, blue: 0.37)
    private let gold = Color(red: 0.88, green: 0.65, blue: 0.23)
    private let goldBright = Color(red: 1.00, green: 0.86, blue: 0.45)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [navyDeep, navyMid, navyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if variant != .micro {
                    brandTopo(size: proxy.size)
                        .stroke(navyLift.opacity(variant == .master ? 0.34 : 0.20), lineWidth: max(0.7, side * 0.012))
                    brandMountains(size: proxy.size)
                        .fill(navyLift.opacity(variant == .small ? 0.34 : 0.48))
                }

                brandRoute(size: proxy.size)
                    .stroke(gold.opacity(0.24), style: StrokeStyle(lineWidth: max(3, side * 0.12), lineCap: .round, lineJoin: .round))
                    .blur(radius: variant == .micro ? 0.5 : side * 0.035)

                brandRoute(size: proxy.size)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: max(1.5, side * 0.047), lineCap: .round, lineJoin: .round)
                    )

                Text("LR")
                    .font(.system(size: side * (variant == .micro ? 0.48 : 0.52), weight: .black, design: .serif))
                    .tracking(-side * 0.045)
                    .foregroundStyle(
                        LinearGradient(colors: [goldBright, gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.56), radius: max(1, side * 0.025), y: side * 0.018)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.47)

                Image(systemName: "mappin")
                    .font(.system(size: side * (variant == .micro ? 0.18 : 0.20), weight: .black))
                    .foregroundStyle(goldBright)
                    .shadow(color: .black.opacity(0.46), radius: max(1, side * 0.018), y: 1)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.34)

                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold, goldBright], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(1, side * 0.025)
                    )
                    .padding(max(1.5, side * 0.045))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute logo")
    }

    private func brandMountains(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.73))
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.31, y: size.height * 0.66))
            path.addLine(to: CGPoint(x: size.width * 0.47, y: size.height * 0.49))
            path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width * 0.79, y: size.height * 0.52))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.69))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func brandTopo(size: CGSize) -> Path {
        Path { path in
            for index in 0..<4 {
                let y = size.height * (0.18 + CGFloat(index) * 0.12)
                path.move(to: CGPoint(x: -size.width * 0.08, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width * 1.08, y: y + size.height * 0.035),
                    control1: CGPoint(x: size.width * 0.26, y: y + size.height * 0.07),
                    control2: CGPoint(x: size.width * 0.72, y: y - size.height * 0.06)
                )
            }
        }
    }

    private func brandRoute(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.92))
            path.addCurve(
                to: CGPoint(x: size.width * 0.40, y: size.height * 0.69),
                control1: CGPoint(x: size.width * 0.29, y: size.height * 0.84),
                control2: CGPoint(x: size.width * 0.37, y: size.height * 0.77)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.60, y: size.height * 0.55),
                control1: CGPoint(x: size.width * 0.45, y: size.height * 0.60),
                control2: CGPoint(x: size.width * 0.58, y: size.height * 0.62)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.50, y: size.height * 0.40),
                control1: CGPoint(x: size.width * 0.64, y: size.height * 0.49),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.44)
            )
        }
    }
}

'''
    text = text.replace(anchor, component + anchor, 1)
    APP.write_text(text, encoding="utf-8")


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 official branding Today hero" in text:
        return
    old = '''                HStack(alignment: .center, spacing: 0) {
                    Text("Life")
                        .foregroundStyle(.white)
                    Text("Route")
                        .foregroundStyle(palette.accentSecondary)
                    Spacer(minLength: 12)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accentSecondary)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.30), in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 27 : 30, weight: .black, design: .rounded))
'''
    new = '''                // v0.7.0 official branding Today hero: official mark + stable LifeRoute wordmark.
                HStack(alignment: .center, spacing: 10) {
                    LifeRouteBrandMark(variant: .small)
                        .frame(width: 46, height: 46)
                        .accessibilityHidden(true)

                    Text("LifeRoute")
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 27 : 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer(minLength: 12)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accentSecondary)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.30), in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }
'''
    text = replace_once(text, old, new, "Today old split Life/Route wordmark")
    TODAY.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    if "v0.7.0 official branding Setup header" in text:
        return
    old = '            LifeRouteIconBadge(systemImage: "slider.horizontal.3", prominent: true)\n'
    new = '''            // v0.7.0 official branding Setup header.
            LifeRouteBrandMark(variant: .small)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
'''
    text = replace_once(text, old, new, "Setup generic header icon")
    SETUP.write_text(text, encoding="utf-8")


def patch_theme_center() -> None:
    text = THEMES.read_text(encoding="utf-8")
    if "v0.7.0 official branding Theme Center" in text:
        return
    old = '''                Text("ACTIVE THEME")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accentSecondary)
'''
    new = '''                // v0.7.0 official branding Theme Center: retain theme preview, add the fixed navy/gold identity.
                HStack(spacing: 6) {
                    LifeRouteBrandMark(variant: .micro)
                        .frame(width: 19, height: 19)
                        .accessibilityHidden(true)
                    Text("ACTIVE THEME")
                }
                .font(.caption2.weight(.black))
                .tracking(0.8)
                .foregroundStyle(palette.accentSecondary)
'''
    text = replace_once(text, old, new, "Theme Center active-theme label")
    THEMES.write_text(text, encoding="utf-8")


def patch_live_activity() -> None:
    text = WIDGET.read_text(encoding="utf-8")
    if "v0.7.0 official LifeRoute widget micro mark" in text:
        return

    component = r'''// v0.7.0 official LifeRoute widget micro mark: simplified LR/pin identity for tiny system surfaces.
private struct LifeRouteWidgetBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.01, green: 0.04, blue: 0.10))
            Text("LR")
                .font(.system(size: 8.2, weight: .black, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.34))
            Circle()
                .fill(Color(red: 1.0, green: 0.88, blue: 0.46))
                .frame(width: 2.8, height: 2.8)
                .offset(y: -4.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute")
    }
}

'''
    text = text.replace("@main\nstruct LifeRouteLiveActivityWidgetBundle", component + "@main\nstruct LifeRouteLiveActivityWidgetBundle", 1)

    text = replace_once(
        text,
        '''                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .foregroundStyle(.yellow)
                        Text("LifeRoute")''',
        '''                        LifeRouteWidgetBrandMark()
                            .frame(width: 20, height: 20)
                        Text("LifeRoute")''',
        "Dynamic Island expanded brand icon",
    )
    text = replace_once(
        text,
        '''                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(.yellow)''',
        '''                LifeRouteWidgetBrandMark()
                    .frame(width: 20, height: 20)''',
        "Dynamic Island compact brand icon",
    )
    text = replace_once(
        text,
        '''                Image(systemName: "location.fill")
                    .foregroundStyle(.yellow)''',
        '''                LifeRouteWidgetBrandMark()
                    .frame(width: 18, height: 18)''',
        "Dynamic Island minimal brand icon",
    )
    text = replace_once(
        text,
        '''                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.yellow)
                    Text("LIFEROUTE · LIVE DAY")''',
        '''                    LifeRouteWidgetBrandMark()
                        .frame(width: 20, height: 20)
                    Text("LIFEROUTE · LIVE DAY")''',
        "Lock Screen brand icon",
    )

    WIDGET.write_text(text, encoding="utf-8")


def main() -> None:
    patch_brand_component()
    patch_today()
    patch_setup()
    patch_theme_center()
    patch_live_activity()
    print(
        "LifeRoute v0.7.0 official branding applied: the refined navy/gold LR + pin + route + mountain/topographic identity now owns the app's reusable brand mark, Today hero, Setup header, Theme Center branding context, and Live Activity/Dynamic Island micro mark without altering navigation or protected functionality."
    )


if __name__ == "__main__":
    main()
