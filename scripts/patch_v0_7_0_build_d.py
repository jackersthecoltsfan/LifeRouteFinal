#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "LifeRoute/V054ToolsDashboard.swift"
CLINICAL = ROOT / "LifeRoute/AIClinicalToolsViews.swift"
SESSION = ROOT / "LifeRoute/SessionToolsViews.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build D patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.0 Build D patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


DASHBOARD_VIEW = r'''struct V054ToolsDashboard: View {
    // v0.7.0 Build D Tools/ABA: clinical-first hierarchy with all existing tools preserved.
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @StateObject private var visualState = ClientVisualSupportCore()

    private var sessionColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }
        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                toolsHeader
                readinessStrip

                LifeRouteSectionLabel(title: "Clinical")
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)
                } label: {
                    clinicalCard(
                        title: "Session Note",
                        subtitle: "Turn supplied session facts into a reviewable ABA draft.",
                        systemImage: "sparkles.rectangle.stack.fill",
                        eyebrow: "DOCUMENTATION"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                NavigationLink {
                    AISessionPlanBuilderView(clientState: clientState)
                } label: {
                    clinicalCard(
                        title: "Session Plan",
                        subtitle: "Organize approved targets, reinforcers, and session time into a usable flow.",
                        systemImage: "brain.head.profile",
                        eyebrow: "PREP"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                LifeRouteSectionLabel(title: "In Session")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                LazyVGrid(columns: sessionColumns, spacing: 10) {
                    NavigationLink {
                        VisualTimerView(timer: toolsState.timer)
                    } label: {
                        sessionToolCard("Visual Timer", "Reliable timing", "timer")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                    } label: {
                        sessionToolCard("Quick Notes", "Capture details fast", "note.text")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                    } label: {
                        sessionToolCard("First / Then", "Clear visual sequence", "arrow.right.circle.fill")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)
                    } label: {
                        sessionToolCard("Visual Supports", "Icons, boards, schedules", "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.plain)
                }

                clientContextCard

                Label(
                    "AI drafts use Apple’s on-device model when available. Review clinical output before use.",
                    systemImage: "lock.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { visualState.retainClients(clientState.clients) }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var toolsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tools")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("ABA workflow, ready when you are.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            LifeRouteIconBadge(systemImage: "wrench.and.screwdriver.fill", prominent: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readinessStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: clientState.clients.isEmpty ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(clientState.clients.isEmpty ? "General mode ready" : "Client context ready")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty ? "No client profile required for core tools." : "\(clientState.clients.count) saved client profile\(clientState.clients.count == 1 ? "" : "s") available.")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 4)

            Button("Manage") {
                LifeRouteHaptics.selection()
                router.select(.setup)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accent)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func clinicalCard(title: String, subtitle: String, systemImage: String, eyebrow: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption2.weight(.black))
                    .tracking(0.9)
                    .foregroundStyle(palette.accentSecondary)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel.opacity(0.64), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func sessionToolCard(_ title: String, _ subtitle: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            LifeRouteIconBadge(systemImage: systemImage, prominent: true)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(12)
        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var clientContextCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Client context")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty ? "General tools only" : "General + saved ABA client codes")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 48)
        .background(palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

'''


NOTE_HERO = r'''    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Note",
                subtitle: "Draft from supplied session facts, optional local screenshot text, and reviewed client context.",
                systemImage: "sparkles.rectangle.stack.fill"
            )

            HStack(spacing: 8) {
                Label("ON-DEVICE", systemImage: "apple.intelligence")
                Text("·")
                Text("SUPPLIED FACTS ONLY")
            }
            .font(.caption2.weight(.black))
            .tracking(0.7)
            .foregroundStyle(palette.accentSecondary)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
    }

'''


PLAN_HERO = r'''    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Plan",
                subtitle: "Shape approved targets, known reinforcers, client context, and session time into a practical flow.",
                systemImage: "brain.head.profile"
            )

            Label("SUPERVISOR-APPROVED INPUTS ONLY", systemImage: "checkmark.shield.fill")
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.accentSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
    }

'''


VISUAL_HERO = r'''    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Visual Supports",
                subtitle: "Create and reuse client-scoped or General icons, schedules, and visual supports.",
                systemImage: "photo.on.rectangle.angled"
            )

            Label("AI + MANUAL WORKSPACE", systemImage: "wand.and.stars")
                .font(.caption2.weight(.black))
                .tracking(0.7)
                .foregroundStyle(palette.accentSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

'''


def patch_dashboard() -> None:
    text = DASHBOARD.read_text(encoding="utf-8")
    if "v0.7.0 Build D Tools/ABA" in text:
        return
    required = [
        "struct V054ToolsDashboard: View",
        "struct VisualAIAssistedStudioView: View",
        "AISessionNoteGeneratorView",
        "AISessionPlanBuilderView",
        "VisualTimerView",
        "QuickSessionNotesView",
        "ClientFirstThenVisualView",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build D patch failed: dashboard baseline missing {missing}")

    text = replace_region(
        text,
        "struct V054ToolsDashboard: View {",
        "struct VisualAIAssistedStudioView: View {",
        DASHBOARD_VIEW,
        "Tools dashboard",
    )

    visual_start = text.index("struct VisualAIAssistedStudioView: View {")
    visual_end = text.find("\nstruct ", visual_start + len("struct VisualAIAssistedStudioView: View {"))
    if visual_end == -1:
        visual_end = len(text)
    visual = text[visual_start:visual_end]
    if "private var hero: some View" in visual:
        hero_start = visual.index("    private var hero: some View {")
        hero_end = visual.index("    private var libraryCard: some View {", hero_start)
        visual = visual[:hero_start] + VISUAL_HERO + visual[hero_end:]
        visual = visual.replace("LazyVStack(spacing: 16)", "LazyVStack(spacing: 12)", 1)
        visual = visual.replace("            .padding(18)\n            .padding(.bottom, 28)", "            .padding(.horizontal, 16)\n            .padding(.top, 10)\n            .padding(.bottom, 28)", 1)
        text = text[:visual_start] + visual + text[visual_end:]

    DASHBOARD.write_text(text, encoding="utf-8")


def patch_clinical() -> None:
    text = CLINICAL.read_text(encoding="utf-8")
    if "v0.7.0 Build D clinical presentation" in text:
        return
    required = [
        "struct AISessionNoteGeneratorView: View",
        "LifeRouteIntelligenceCore.generateABASessionNote(",
        "struct AISessionPlanBuilderView: View",
        "Review every sentence before using a generated draft",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build D patch failed: clinical baseline missing {missing}")

    text = text.replace(
        "struct AISessionNoteGeneratorView: View {",
        "// v0.7.0 Build D clinical presentation: visual hierarchy only; generation contracts are unchanged.\nstruct AISessionNoteGeneratorView: View {",
        1,
    )

    note_start = text.index("struct AISessionNoteGeneratorView: View {")
    plan_start = text.index("struct AISessionPlanBuilderView: View {")
    note = text[note_start:plan_start]
    hero_start = note.index("    private var hero: some View {")
    hero_end = note.index("    private var inputCard: some View {", hero_start)
    note = note[:hero_start] + NOTE_HERO + note[hero_end:]
    note = note.replace("LazyVStack(spacing: 16)", "LazyVStack(spacing: 12)", 1)
    note = note.replace("            .padding(18)\n            .padding(.bottom, 24)", "            .padding(.horizontal, 16)\n            .padding(.top, 10)\n            .padding(.bottom, 24)", 1)
    note = note.replace('.navigationTitle("AI Session Note")', '.navigationTitle("Session Note")', 1)
    note = note.replace(".frame(minHeight: 180)", ".frame(minHeight: 160)", 1)
    note = note.replace(".frame(minHeight: 260)", ".frame(minHeight: 230)", 1)

    text = text[:note_start] + note + text[plan_start:]

    plan_start = text.index("struct AISessionPlanBuilderView: View {")
    next_struct = text.find("\nstruct ", plan_start + len("struct AISessionPlanBuilderView: View {"))
    if next_struct == -1:
        next_struct = len(text)
    plan = text[plan_start:next_struct]
    hero_start = plan.index("    private var hero: some View {")
    hero_end = plan.index("    private var contextCard: some View {", hero_start)
    plan = plan[:hero_start] + PLAN_HERO + plan[hero_end:]
    plan = plan.replace("LazyVStack(spacing: 16)", "LazyVStack(spacing: 12)", 1)
    plan = plan.replace("            .padding(18)\n            .padding(.bottom, 24)", "            .padding(.horizontal, 16)\n            .padding(.top, 10)\n            .padding(.bottom, 24)", 1)
    plan = plan.replace('.navigationTitle("AI Session Plan")', '.navigationTitle("Session Plan")', 1)
    plan = plan.replace(".frame(minHeight: 300)", ".frame(minHeight: 250)", 1)
    text = text[:plan_start] + plan + text[next_struct:]

    CLINICAL.write_text(text, encoding="utf-8")


def patch_timer() -> None:
    text = SESSION.read_text(encoding="utf-8")
    if "v0.7.0 Build D timer presentation" in text:
        return
    required = [
        "struct VisualTimerView: View",
        "TimelineView(.periodic(from: .now, by: 1))",
        "timer.start(minutes:",
        "timer.pause()",
        "timer.resume()",
        "timer.addMinute()",
        "timer.reset()",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build D patch failed: timer baseline missing {missing}")

    start = text.index("struct VisualTimerView: View {")
    end = text.index("struct QuickSessionNotesView: View {", start)
    timer = text[start:end]
    timer = timer.replace(
        "struct VisualTimerView: View {",
        "struct VisualTimerView: View {\n    // v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.",
        1,
    )
    timer = replace_once(
        timer,
        "            LazyVStack(spacing: 18) {\n                TimelineView(.periodic(from: .now, by: 1)) { context in",
        '''            LazyVStack(spacing: 12) {
                LifeRouteScreenHeader(
                    title: "Visual Timer",
                    subtitle: "Fast, dependable session timing with the validated crescendo and completion audio.",
                    systemImage: "timer"
                )

                TimelineView(.periodic(from: .now, by: 1)) { context in''',
        "timer header",
    )
    timer = timer.replace(".font(.system(size: 58, weight: .black, design: .rounded))", ".font(.system(size: 52, weight: .black, design: .rounded))", 1)
    timer = timer.replace(".frame(width: 245, height: 245)", ".frame(width: 220, height: 220)", 1)
    timer = timer.replace("                    .padding(20)\n                    .lifeRouteCard()", "                    .padding(16)\n                    .lifeRouteCard()", 1)
    timer = timer.replace("            .padding(18)\n            .padding(.bottom, 24)", "            .padding(.horizontal, 16)\n            .padding(.top, 10)\n            .padding(.bottom, 24)", 1)
    text = text[:start] + timer + text[end:]
    SESSION.write_text(text, encoding="utf-8")


def main() -> None:
    patch_dashboard()
    patch_clinical()
    patch_timer()
    print(
        "LifeRoute v0.7.0 Build D patch applied: Tools is clinical-first and compact, Session Note/Plan and Visual Supports use the shared v0.7 hierarchy, and Visual Timer is visually tightened while all validated clinical, timer, client, visual-library, and native-navigation behavior remains owned by the existing domains."
    )


if __name__ == "__main__":
    main()
