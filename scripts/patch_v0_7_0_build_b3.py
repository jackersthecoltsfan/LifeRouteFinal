#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"
TOOLS = ROOT / "LifeRoute/SessionToolsViews.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build B.3 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_in_section(text: str, start_token: str, end_token: str, old: str, new: str, label: str) -> str:
    start = text.index(start_token)
    end = text.index(end_token, start)
    section = text[start:end]
    section = replace_once(section, old, new, label)
    return text[:start] + section + text[end:]


HERO_SCENE = r'''private struct LifeRouteTodayHeroScene: View {
    private let gold = Color(red: 0.96, green: 0.72, blue: 0.20)
    private let goldBright = Color(red: 1.00, green: 0.88, blue: 0.49)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.008, green: 0.035, blue: 0.085),
                        Color(red: 0.018, green: 0.12, blue: 0.23),
                        Color(red: 0.012, green: 0.045, blue: 0.095),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.16, green: 0.52, blue: 0.78).opacity(0.52),
                        Color(red: 0.05, green: 0.24, blue: 0.42).opacity(0.18),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.50, y: 0.40),
                    startRadius: 2,
                    endRadius: max(size.width, size.height) * 0.68
                )

                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: size.width * 0.58)
                    .blur(radius: 32)
                    .offset(x: -size.width * 0.16, y: -size.height * 0.22)

                distantRange(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.40, blue: 0.61).opacity(0.82),
                                Color(red: 0.035, green: 0.13, blue: 0.24).opacity(0.98),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: 0.35)

                snowHighlights(size)
                    .fill(Color(red: 0.56, green: 0.72, blue: 0.84).opacity(0.30))
                    .blur(radius: 0.25)

                middleRange(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.055, green: 0.22, blue: 0.36),
                                Color(red: 0.012, green: 0.055, blue: 0.11),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                valleyMist(size)
                    .fill(Color(red: 0.11, green: 0.36, blue: 0.54).opacity(0.20))
                    .blur(radius: 13)

                foregroundRange(size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.018, green: 0.07, blue: 0.12),
                                Color.black.opacity(0.98),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                roadPath(size)
                    .stroke(gold.opacity(0.18), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
                    .blur(radius: 13)

                roadPath(size)
                    .stroke(gold.opacity(0.34), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .blur(radius: 5)

                roadPath(size)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold, goldBright], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                    )

                roadPath(size)
                    .stroke(Color.white.opacity(0.48), style: StrokeStyle(lineWidth: 0.70, lineCap: .round, lineJoin: .round))
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func distantRange(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size.height * 0.60))
            p.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.48))
            p.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.34))
            p.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.47))
            p.addLine(to: CGPoint(x: size.width * 0.39, y: size.height * 0.27))
            p.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.44))
            p.addLine(to: CGPoint(x: size.width * 0.60, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.70, y: size.height * 0.43))
            p.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.29))
            p.addLine(to: CGPoint(x: size.width, y: size.height * 0.48))
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
    }

    private func snowHighlights(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.34))
            p.addLine(to: CGPoint(x: size.width * 0.39, y: size.height * 0.27))
            p.addLine(to: CGPoint(x: size.width * 0.44, y: size.height * 0.36))
            p.addLine(to: CGPoint(x: size.width * 0.40, y: size.height * 0.33))
            p.closeSubpath()

            p.move(to: CGPoint(x: size.width * 0.54, y: size.height * 0.31))
            p.addLine(to: CGPoint(x: size.width * 0.60, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.34))
            p.addLine(to: CGPoint(x: size.width * 0.61, y: size.height * 0.30))
            p.closeSubpath()
        }
    }

    private func middleRange(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size.height * 0.69))
            p.addLine(to: CGPoint(x: size.width * 0.13, y: size.height * 0.52))
            p.addLine(to: CGPoint(x: size.width * 0.26, y: size.height * 0.61))
            p.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.43))
            p.addLine(to: CGPoint(x: size.width * 0.57, y: size.height * 0.62))
            p.addLine(to: CGPoint(x: size.width * 0.73, y: size.height * 0.44))
            p.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.59))
            p.addLine(to: CGPoint(x: size.width, y: size.height * 0.50))
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
    }

    private func foregroundRange(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size.height * 0.80))
            p.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.77))
            p.addLine(to: CGPoint(x: size.width * 0.53, y: size.height * 0.60))
            p.addLine(to: CGPoint(x: size.width * 0.71, y: size.height * 0.76))
            p.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.64))
            p.addLine(to: CGPoint(x: size.width, y: size.height * 0.72))
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
    }

    private func valleyMist(_ size: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: size.width * 0.18, y: size.height * 0.46, width: size.width * 0.72, height: size.height * 0.25))
    }

    private func roadPath(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: size.width * 0.48, y: size.height * 1.08))
            p.addCurve(
                to: CGPoint(x: size.width * 0.53, y: size.height * 0.78),
                control1: CGPoint(x: size.width * 0.29, y: size.height * 0.94),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.88)
            )
            p.addCurve(
                to: CGPoint(x: size.width * 0.46, y: size.height * 0.64),
                control1: CGPoint(x: size.width * 0.60, y: size.height * 0.73),
                control2: CGPoint(x: size.width * 0.38, y: size.height * 0.71)
            )
            p.addCurve(
                to: CGPoint(x: size.width * 0.61, y: size.height * 0.53),
                control1: CGPoint(x: size.width * 0.50, y: size.height * 0.59),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.56)
            )
            p.addCurve(
                to: CGPoint(x: size.width * 0.75, y: size.height * 0.48),
                control1: CGPoint(x: size.width * 0.66, y: size.height * 0.51),
                control2: CGPoint(x: size.width * 0.71, y: size.height * 0.50)
            )
        }
    }
}
'''


FIRST_THEN_FULLSCREEN = r'''struct ClientFirstThenSessionPreviewView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let libraryName: String
    let firstIcon: ClientVisualIcon?
    let firstText: String
    let thenIcon: ClientVisualIcon?
    let thenText: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("First / Then")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text(libraryName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close First Then preview")
                }

                Spacer(minLength: 2)

                HStack(alignment: .center, spacing: 10) {
                    sessionCard(label: "FIRST", icon: firstIcon, text: firstText)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Then")
                    sessionCard(label: "THEN", icon: thenIcon, text: thenText)
                }

                Spacer(minLength: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sessionCard(label: String, icon: ClientVisualIcon?, text: String) -> some View {
        VStack(spacing: 14) {
            Text(label)
                .font(.headline.weight(.black))
                .tracking(1.7)
                .foregroundStyle(palette.accentSecondary)

            if let icon {
                ClientVisualIconThumbnail(icon: icon, size: 132)
            } else {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(palette.accent.opacity(0.72))
                    .frame(height: 132)
            }

            Text(text)
                .font(.title3.weight(.black))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.accent.opacity(0.26), lineWidth: 1)
        }
    }
}

'''


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 Build B.3 device QA" in text:
        return
    required = [
        "v0.7.0 Build B.2 device QA",
        "v0.7.0 restored To-Do gap fillers",
        "private struct LifeRouteTodayHeroScene: View",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build B.3 patch failed: Home baseline missing {missing}")

    text = replace_once(
        text,
        "// v0.7.0 Build B.2 device QA: real-iPhone density pass against the approved reference.\n",
        "// v0.7.0 Build B.2 device QA: real-iPhone density pass against the approved reference.\n"
        "// v0.7.0 Build B.3 device QA: cinematic hero and one-screen information hierarchy tuned from real-device screenshots.\n",
        "B.3 Home marker",
    )

    text = replace_once(text, "LazyVStack(spacing: 9)", "LazyVStack(spacing: 8)", "Home stack rhythm")

    hero_start = text.index("private struct LifeRouteTodayHeroScene: View {")
    text = text[:hero_start] + HERO_SCENE

    # The target keeps one best gap suggestion on the landing screen; the library remains available through See all.
    text = replace_once(text, "ForEach(openTodos.prefix(3))", "ForEach(openTodos.prefix(1))", "Home To-Do preview count")
    text = replace_once(
        text,
        "ForEach(suggestions.prefix(openTodos.isEmpty ? 4 : 2))",
        "ForEach(suggestions.prefix(openTodos.isEmpty ? 1 : 0))",
        "Home saved-place preview count",
    )

    # Slightly reduce large metric typography without collapsing accessibility layouts.
    metric_start = text.index("    private func overviewMetric(")
    metric_end = text.index("    private var totalDrivingDurationLabel", metric_start)
    metric = text[metric_start:metric_end]
    metric = metric.replace(".font(.title2.weight(.bold))", ".font(.title3.weight(.bold))", 1)
    metric = metric.replace("minHeight: 60", "minHeight: 54", 1)
    text = text[:metric_start] + metric + text[metric_end:]

    # B.2 already made this card smaller; B.3 removes the remaining oversized no-event treatment.
    overview_start = text.index("    private var overviewCard: some View {")
    overview_end = text.index("    private func nextEventCard", overview_start)
    overview = text[overview_start:overview_end]
    overview = overview.replace(".padding(12)", ".padding(8)", 1)
    overview = overview.replace(
        "        .lifeRouteCard()",
        "        .padding(10)\n"
        "        .background(palette.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))\n"
        "        .overlay {\n"
        "            RoundedRectangle(cornerRadius: 18, style: .continuous)\n"
        "                .stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)\n"
        "        }",
        1,
    )
    text = text[:overview_start] + overview + text[overview_end:]

    # Keep hero close to the target's cinematic visual weight after the B.2 compression pass.
    text = replace_in_section(
        text,
        "    private var hero: some View {",
        "    private var brandGold: Color {",
        ".frame(height: dynamicTypeSize.isAccessibilitySize ? 222 : 182)",
        ".frame(height: dynamicTypeSize.isAccessibilitySize ? 230 : 194)",
        "hero visual weight",
    )

    qa_start = text.index("    private func quickActionLabel(")
    qa_end = text.index("    private func overviewMetric(", qa_start)
    qa = text[qa_start:qa_end]
    qa = qa.replace(".font(.system(size: 11, weight: .semibold))", ".font(.system(size: 10, weight: .semibold))", 1)
    qa = qa.replace("minHeight: 68", "minHeight: 64", 1)
    text = text[:qa_start] + qa + text[qa_end:]

    TODAY.write_text(text, encoding="utf-8")


def patch_visuals() -> None:
    text = TOOLS.read_text(encoding="utf-8")
    if "v0.7.0 B.3 visual presentation workflow" in text:
        return
    required = [
        "v0.7.0 B.2 save and fullscreen preview",
        "v0.7.0 horizontal First Then preview",
        "struct ClientVisualSupportCenter: View",
        "struct ClientChoiceBoardBuilderView: View",
        "struct ClientFirstThenVisualView: View",
        "struct ClientVisualScheduleBuilderView: View",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build B.3 patch failed: visual baseline missing {missing}")

    text = replace_once(
        text,
        "// v0.7.0 B.2 save and fullscreen preview: real-device visual-support QA.\n",
        "// v0.7.0 B.2 save and fullscreen preview: real-device visual-support QA.\n"
        "// v0.7.0 B.3 visual presentation workflow: editors hide the app tab bar, expose Library + Save actions, and First/Then presents full screen.\n",
        "B.3 visual marker",
    )

    # Let callers open the visual library already focused on the active General/client scope.
    center_start = text.index("struct ClientVisualSupportCenter: View {")
    center_end = text.index("struct ClientVisualIconMakerView: View {", center_start)
    center = text[center_start:center_end]
    center = replace_once(
        center,
        "    @State private var selectedClientCode = ClientVisualSupportCore.generalClientCode\n",
        "    @State private var selectedClientCode: String\n\n"
        "    init(visualState: ClientVisualSupportCore, clientState: ClientProfileCore, initialClientCode: String = ClientVisualSupportCore.generalClientCode) {\n"
        "        self.visualState = visualState\n"
        "        self.clientState = clientState\n"
        "        _selectedClientCode = State(initialValue: initialClientCode.isEmpty ? ClientVisualSupportCore.generalClientCode : initialClientCode)\n"
        "    }\n",
        "Visual Supports initial library",
    )
    text = text[:center_start] + center + text[center_end:]

    # Choice Board: hide main tabs so the persistent bottom controls can actually be seen on iPhone.
    board_start = text.index("struct ClientChoiceBoardBuilderView: View {")
    board_end = text.index("struct ClientFirstThenVisualView: View {", board_start)
    board = text[board_start:board_end]
    board = replace_once(
        board,
        "    @Environment(\\.lifeRoutePalette) private var palette\n",
        "    @Environment(\\.lifeRoutePalette) private var palette\n    @Environment(\\.dismiss) private var dismiss\n",
        "Choice Board dismiss owner",
    )
    old_board_inset = '''        .safeAreaInset(edge: .bottom) {
            Button {
                saveBoard()
            } label: {
                Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }'''
    new_board_inset = '''        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveBoard()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .tabBar)'''
    board = replace_once(board, old_board_inset, new_board_inset, "Choice Board visible action bar")
    text = text[:board_start] + board + text[board_end:]

    # First / Then: reusable save, direct library access, and true full-screen session presentation.
    first_start = text.index("struct ClientFirstThenVisualView: View {")
    first_end = text.index("struct ClientVisualScheduleBuilderView: View {", first_start)
    first = text[first_start:first_end]
    first = replace_once(
        first,
        "    @State private var thenIconID = \"\"\n",
        "    @State private var thenIconID = \"\"\n"
        "    @State private var sequenceTitle = \"First / Then\"\n"
        "    @State private var message: String?\n"
        "    @State private var showingFullScreenPreview = false\n",
        "First Then save state",
    )

    build_anchor = '''                    Text("Only icons saved to \\(libraryName) are available here.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)'''
    build_replacement = '''                    TextField("Saved visual title", text: $sequenceTitle)
                        .padding(10)
                        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text("Only icons saved to \\(libraryName) are available here. Saving First / Then stores it as a reusable two-step Visual Schedule in that same library.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }'''
    first = replace_once(first, build_anchor, build_replacement, "First Then save explanation")

    preview_title = '''                    Text("Live preview")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)'''
    preview_title_replacement = '''                    HStack {
                        Text("Live preview")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Button {
                            showingFullScreenPreview = true
                            LifeRouteHaptics.selection()
                        } label: {
                            Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.accent)
                    }'''
    first = replace_once(first, preview_title, preview_title_replacement, "First Then full-screen affordance")

    nav_anchor = '''        .navigationTitle("First / Then")
        .navigationBarTitleDisplayMode(.inline)'''
    nav_replacement = '''        .navigationTitle("First / Then")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                NavigationLink {
                    ClientVisualSupportCenter(
                        visualState: visualState,
                        clientState: clientState,
                        initialClientCode: selectedClientCode
                    )
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveFirstThen()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showingFullScreenPreview) {
            ClientFirstThenSessionPreviewView(
                libraryName: libraryName,
                firstIcon: selectedIcon(idString: firstIconID),
                firstText: resolvedFirstText,
                thenIcon: selectedIcon(idString: thenIconID),
                thenText: resolvedThenText
            )
        }'''
    first = replace_once(first, nav_anchor, nav_replacement, "First Then persistent actions")

    helper_anchor = '''    private func validateSelectedLibrary() {
'''
    helper_methods = r'''    private var resolvedFirstText: String {
        let clean = firstText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        return selectedIcon(idString: firstIconID)?.label ?? "First activity"
    }

    private var resolvedThenText: String {
        let clean = thenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        return selectedIcon(idString: thenIconID)?.label ?? "Then activity"
    }

    private func saveFirstThen() {
        let firstIcon = selectedIcon(idString: firstIconID)
        let thenIcon = selectedIcon(idString: thenIconID)
        let firstHasContent = !firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || firstIcon != nil
        let thenHasContent = !thenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thenIcon != nil
        guard firstHasContent, thenHasContent else {
            message = "Choose or enter both FIRST and THEN before saving."
            return
        }

        do {
            let cleanTitle = sequenceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try visualState.saveSchedule(
                clientCode: selectedClientCode,
                title: cleanTitle.isEmpty ? "First / Then" : cleanTitle,
                steps: [
                    ClientVisualScheduleStep(label: resolvedFirstText, iconID: firstIcon?.id),
                    ClientVisualScheduleStep(label: resolvedThenText, iconID: thenIcon?.id),
                ]
            )
            message = "Saved to \(libraryName) Visual Library."
            showingFullScreenPreview = true
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

'''
    first = replace_once(first, helper_anchor, helper_methods + helper_anchor, "First Then save helper")
    text = text[:first_start] + first + text[first_end:]

    # Schedule gets the same visible library/save bar and hides the main app tabs while editing.
    schedule_start = text.index("struct ClientVisualScheduleBuilderView: View {")
    schedule_end = text.index("private struct VisualBuilderHero: View {", schedule_start)
    schedule = text[schedule_start:schedule_end]
    schedule = replace_once(
        schedule,
        "    @Environment(\\.lifeRoutePalette) private var palette\n",
        "    @Environment(\\.lifeRoutePalette) private var palette\n    @Environment(\\.dismiss) private var dismiss\n",
        "Schedule dismiss owner",
    )
    old_schedule_inset = '''        .safeAreaInset(edge: .bottom) {
            Button {
                saveSchedule()
            } label: {
                Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }'''
    new_schedule_inset = '''        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Label("View Library", systemImage: "books.vertical.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    saveSchedule()
                } label: {
                    Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .tabBar)'''
    schedule = replace_once(schedule, old_schedule_inset, new_schedule_inset, "Schedule visible action bar")
    text = text[:schedule_start] + schedule + text[schedule_end:]

    # Insert the dedicated First / Then full-screen session surface beside the other saved-visual previews.
    insert_at = text.index("private struct VisualBuilderHero: View {")
    text = text[:insert_at] + FIRST_THEN_FULLSCREEN + text[insert_at:]

    TOOLS.write_text(text, encoding="utf-8")


def main() -> None:
    patch_today()
    patch_visuals()
    print(
        "LifeRoute v0.7.0 Build B.3 patch applied: Home receives a more cinematic target-parity hierarchy, visual builders expose unobscured Library + Save controls, and First/Then saves into the protected visual library with true full-screen presentation."
    )


if __name__ == "__main__":
    main()
