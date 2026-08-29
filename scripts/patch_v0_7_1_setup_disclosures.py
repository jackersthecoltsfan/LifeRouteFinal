#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETUP = ROOT / "LifeRoute/V054SetupView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 Setup disclosure patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region_after(text: str, owner: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        owner_start = text.index(owner)
        start = text.index(start_token, owner_start)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.1 Setup disclosure patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def main() -> None:
    text = SETUP.read_text(encoding="utf-8")
    marker = "v0.7.1 Setup disclosure groups"
    if marker in text:
        return

    required = [
        "v0.7.0 Build E Setup Control Center",
        "struct V054SetupView: View",
        "private var weeklyTodosCard: some View",
        "private var addTodoCard: some View",
        "routingState.addTodo(",
        "routingState.addSavedPlace(",
        "routingState.removeSavedPlace(id: place.id)",
        "V054ClientProfilesView(clientState: clientState)",
        "V054ThemeCenterView()",
        "@State private var message: String?",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 Setup disclosure patch failed: Build E Setup baseline missing {missing}")

    body = r'''    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                hero

                LifeRouteSetupDisclosureGroup(
                    title: "Appearance",
                    subtitle: themeStore.selectedTheme.name,
                    systemImage: "sparkles",
                    isExpanded: $appearanceExpanded
                ) {
                    themeCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Profile & Work",
                    subtitle: rbtName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "RBT identity and organization" : rbtName,
                    systemImage: "person.crop.circle.badge.checkmark",
                    isExpanded: $profileExpanded
                ) {
                    rbtProfileCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Navigation & Places",
                    subtitle: "\(preferredNavigationApp.title) · \(routingState.savedPlaces.count) saved places",
                    systemImage: "location.north.line.fill",
                    isExpanded: $navigationExpanded
                ) {
                    navigationAppCard
                    homeCard
                    savedPlacesCard
                    addPlaceCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Weekly To-Dos",
                    subtitle: "Recurring planning and destinations",
                    systemImage: "checklist",
                    isExpanded: $todosExpanded
                ) {
                    weeklyTodosCard
                    addTodoCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Clinical",
                    subtitle: clientState.clients.isEmpty ? "Client profiles" : "\(clientState.clients.count) saved client profiles",
                    systemImage: "person.2.fill",
                    isExpanded: $clinicalExpanded
                ) {
                    clientCard
                }

                LifeRouteSetupDisclosureGroup(
                    title: "Privacy",
                    subtitle: "Local-first storage details",
                    systemImage: "lock.shield.fill",
                    isExpanded: $privacyExpanded
                ) {
                    privacyCard
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if homeDraft.isEmpty { homeDraft = routingState.homeAddress }
        }
    }

'''
    text = replace_region_after(
        text,
        "struct V054SetupView: View {",
        "    var body: some View {",
        "    private var hero: some View {",
        body,
        "V054SetupView body",
    )

    disclosure = r'''// v0.7.1 Setup disclosure groups: keep every existing control, reduce simultaneous visual load.
private struct LifeRouteSetupDisclosureGroup<Content: View>: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
                LifeRouteHaptics.selection()
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.accent.opacity(isExpanded ? 0.18 : 0.10))
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isExpanded ? palette.accentSecondary : palette.accent)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(isExpanded ? "expanded" : "collapsed")")

            if isExpanded {
                VStack(spacing: 10) {
                    content
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(palette.panel.opacity(0.54), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(isExpanded ? 0.20 : 0.10), lineWidth: 1)
        }
    }
}

'''
    # Raw Python strings preserve Swift key-path backslashes exactly; normalize one doubled slash below
    # so the generated Swift is @Environment(\.lifeRoutePalette), not a literal doubled key path.
    disclosure = disclosure.replace("@Environment(\\\\.lifeRoutePalette)", "@Environment(\\.lifeRoutePalette)")
    text = replace_once(
        text,
        "struct V054SetupView: View {",
        disclosure + "struct V054SetupView: View {",
        "Setup disclosure component",
    )

    text = replace_once(
        text,
        "    @State private var message: String?\n",
        '''    @State private var message: String?

    // v0.7.1 Setup disclosure groups: Appearance is immediately useful; heavier sections start collapsed.
    @State private var appearanceExpanded = true
    @State private var profileExpanded = false
    @State private var navigationExpanded = false
    @State private var todosExpanded = false
    @State private var clinicalExpanded = false
    @State private var privacyExpanded = false
''',
        "Setup disclosure state",
    )

    SETUP.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.1 Setup disclosure patch applied: Appearance starts open while Profile & Work, "
        "Navigation & Places, Weekly To-Dos, Clinical, and Privacy start collapsed; all existing cards and actions remain."
    )


if __name__ == "__main__":
    main()
