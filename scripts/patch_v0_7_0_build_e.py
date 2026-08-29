#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "LifeRoute/ResourcePortalViews.swift"
CLIENTS = ROOT / "LifeRoute/V054ClientViews.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.0 Build E patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def patch_resources() -> None:
    text = RESOURCES.read_text(encoding="utf-8")
    if "v0.7.0 Build E Resources" in text:
        return

    required = [
        "ResourcePortalHubView",
        "ResourcePortalCore()",
        "portalState.portals(in: category)",
        "portalState.addCustomPortal(",
        "portalState.removeCustomPortal(id: portal.id)",
        "openURL(url)",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build E patch failed: Resources baseline missing {missing}")

    body = r'''    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero

                ForEach(LifeRoutePortalCategory.allCases) { category in
                    portalSection(category)
                }

                customPortalCard

                Label(
                    "LifeRoute launches third-party portals only. Credentials, sign-in, and data entered there remain with the destination service.",
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
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

'''
    text = replace_region(text, "    var body: some View {", "    private var hero: some View {", body, "Resources body")

    hero = r'''    private var hero: some View {
        // v0.7.0 Build E Resources: compact premium launchpad; ResourcePortalCore remains the owner.
        HStack(spacing: 12) {
            LifeRouteIconBadge(systemImage: "rectangle.connected.to.line.below", prominent: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Resources")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Clinical, work, training, and company portals.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(portalState.builtInPortals.count)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                Text(portalState.customPortals.isEmpty ? "BUILT-IN" : "+ \(portalState.customPortals.count) CUSTOM")
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(13)
        .background(palette.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

'''
    text = replace_region(text, "    private var hero: some View {", "    private func portalSection(_ category: LifeRoutePortalCategory) -> some View {", hero, "Resources hero")

    section = r'''    private func portalSection(_ category: LifeRoutePortalCategory) -> some View {
        let portals = portalState.portals(in: category)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)
                Text(category.rawValue.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text("\(portals.count)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(palette.accentSecondary)
            }
            .frame(minHeight: 30)

            VStack(spacing: 6) {
                ForEach(portals) { portal in
                    portalRow(portal)
                }
            }
        }
    }

'''
    text = replace_region(text, "    private func portalSection(_ category: LifeRoutePortalCategory) -> some View {", "    private func portalRow(_ portal: LifeRoutePortalLink) -> some View {", section, "Resources portal section")

    row = r'''    private func portalRow(_ portal: LifeRoutePortalLink) -> some View {
        HStack(spacing: 8) {
            Button {
                guard let url = portal.url else { return }
                LifeRouteHaptics.primaryAction()
                openURL(url)
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(palette.accent.opacity(0.12))
                        Image(systemName: portal.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(portal.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                            if portal.isCustom {
                                Text("CUSTOM")
                                    .font(.system(size: 8, weight: .black))
                                    .tracking(0.5)
                                    .foregroundStyle(palette.accentSecondary)
                            }
                        }
                        Text(portal.subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 52)

            if portal.isCustom {
                Button(role: .destructive) {
                    LifeRouteHaptics.selection()
                    portalState.removeCustomPortal(id: portal.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(portal.title)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

'''
    text = replace_region(text, "    private func portalRow(_ portal: LifeRoutePortalLink) -> some View {", "    private var customPortalCard: some View {", row, "Resources portal row")
    text = text.replace('Label("Add company portal", systemImage: "plus.app.fill")\n                .font(.title3.weight(.bold))', 'Label("Add Company Portal", systemImage: "plus.app.fill")\n                .font(.headline.weight(.bold))', 1)
    RESOURCES.write_text(text, encoding="utf-8")


def patch_clients() -> None:
    text = CLIENTS.read_text(encoding="utf-8")
    if "v0.7.0 Build E Client Hub" in text:
        return

    required = [
        "V054ClientProfilesView",
        "V054ClientEditorView",
        "clientState.removeClient(id: profile.id)",
        "clientState.saveProfile(",
        "V054AddressField",
        "ClientProfileCore.normalizedPair",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build E patch failed: Clients baseline missing {missing}")

    hub = r'''struct V054ClientProfilesView: View {
    // v0.7.0 Build E Client Hub: code-first, compact, privacy-first presentation.
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 11) {
                HStack(spacing: 12) {
                    LifeRouteIconBadge(systemImage: "person.2.fill", prominent: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clients")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text("ABA-style client codes and practical session context.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 9) {
                    Label("\(clientState.clients.count) SAVED", systemImage: "person.crop.circle.fill")
                    Label("LOCAL-FIRST", systemImage: "lock.fill")
                }
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.accentSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: nil)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(width: 34, height: 34)
                            .background(palette.accentGradient, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Client")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("First two + last two initials only")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 56)
                    .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                LifeRouteSectionLabel(title: "Client Context")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                if clientState.clients.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                        Text("No client profiles yet")
                            .font(.headline)
                            .foregroundStyle(palette.textPrimary)
                        Text("General session and visual tools still work without a client profile.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(palette.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                } else {
                    ForEach(clientState.clients) { profile in
                        clientCard(profile)
                    }
                }

                Text("Store only the minimum client context needed for LifeRoute workflows. Avoid full names or unnecessary identifying information.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clientCard(_ profile: LifeRouteClientProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Text(profile.code)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accentSecondary)
                    .frame(width: 64, height: 46)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.code)
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Label(profile.address.isEmpty ? "No service address" : profile.address, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    V054ClientEditorView(clientState: clientState, profile: profile)
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
                .accessibilityLabel("Edit \(profile.code)")
            }

            HStack(spacing: 6) {
                metric(profile.currentTargets.count, "Targets")
                metric(profile.preferredActivities.count, "Preferred")
                metric(profile.behaviorsOfConcern.count, "Behaviors")
            }

            HStack {
                Text("CLIENT CONTEXT")
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Button(role: .destructive) {
                    clientState.removeClient(id: profile.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption.weight(.bold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.caption.weight(.black))
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

'''
    text = replace_region(text, "struct V054ClientProfilesView: View {", "struct V054ClientEditorView: View {", hub, "Client Hub")

    editor_body = r'''    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                codeCard
                locationCard
                listCard
                contextCard
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 92)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(profileID == nil ? "New Client" : codePreview)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                Button {
                    save()
                } label: {
                    Label(isSaving ? "Saving…" : "Save Client", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
                .disabled(isSaving)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(palette.panel.opacity(0.94))
        }
    }

'''
    editor_start = text.index("struct V054ClientEditorView: View {")
    body_start = text.index("    var body: some View {", editor_start)
    code_start = text.index("    private var codeCard: some View {", body_start)
    text = text[:body_start] + editor_body + text[code_start:]

    code_card = r'''    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ABA CLIENT CODE")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(palette.accentSecondary)
                    Text("Use first two + last two initials only.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Text(codePreview)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accentSecondary)
                    .frame(minWidth: 58, minHeight: 40)
            }

            HStack(spacing: 10) {
                labeledField("FIRST 2") {
                    TextField("Ab", text: $first2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                labeledField("LAST 2") {
                    TextField("Cd", text: $last2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.16), lineWidth: 1)
        }
    }

'''
    text = replace_region(text, "    private var codeCard: some View {", "    private var locationCard: some View {", code_card, "Client code card")
    CLIENTS.write_text(text, encoding="utf-8")


def patch_setup() -> None:
    text = SETUP.read_text(encoding="utf-8")
    if "v0.7.0 Build E Setup Control Center" in text:
        return

    required = [
        "private var weeklyTodosCard: some View",
        "private var addTodoCard: some View",
        "routingState.addTodo(",
        "routingState.addSavedPlace(",
        "routingState.removeSavedPlace(id: place.id)",
        "V054ClientProfilesView(clientState: clientState)",
        "V054ThemeCenterView()",
        "preferredNavigationAppRaw",
        "routingState.setHomeAddress(homeDraft)",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build E patch failed: Setup materialized baseline missing {missing}")

    body = r'''    var body: some View {
        // v0.7.0 Build E Setup Control Center: grouped presentation over existing native owners.
        ScrollView {
            LazyVStack(spacing: 12) {
                hero

                LifeRouteSectionLabel(title: "Profile / Work Identity")
                    .frame(maxWidth: .infinity, alignment: .leading)
                rbtProfileCard

                LifeRouteSectionLabel(title: "Navigation & Places")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                navigationAppCard
                homeCard
                savedPlacesCard
                addPlaceCard

                LifeRouteSectionLabel(title: "Weekly To-Dos")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                weeklyTodosCard
                addTodoCard

                LifeRouteSectionLabel(title: "Clinical")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                clientCard

                LifeRouteSectionLabel(title: "Appearance")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                themeCard

                LifeRouteSectionLabel(title: "Privacy")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                privacyCard
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
    text = replace_region(text, "    var body: some View {", "    private var hero: some View {", body, "Setup body")

    hero = r'''    private var hero: some View {
        HStack(spacing: 12) {
            LifeRouteIconBadge(systemImage: "slider.horizontal.3", prominent: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Setup")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Your LifeRoute control center.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(routingState.savedPlaces.count)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                Text("PLACES")
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(13)
        .background(palette.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
    }

'''
    text = replace_region(text, "    private var hero: some View {", "    private var rbtProfileCard: some View {", hero, "Setup hero")

    theme_card = r'''    private var themeCard: some View {
        NavigationLink {
            V054ThemeCenterView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeStore.selectedTheme.palette.backgroundGradient)
                    Circle()
                        .fill(themeStore.selectedTheme.palette.accent)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(themeStore.selectedTheme.palette.accentSecondary, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Center")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(themeStore.selectedTheme.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accentSecondary)
                    Text("Color and material system")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(12)
            .background(palette.panel.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

'''
    text = replace_region(text, "    private var themeCard: some View {", "    private var clientCard: some View {", theme_card, "Setup theme card")

    text = text.replace(
        'Text("Keep your own work identity separate from client profiles. These fields stay on this iPhone and can be used by future LifeRoute personalization features.")',
        'Text("Your work identity stays separate from client profiles and is stored locally.")',
        1,
    )
    text = text.replace(
        'Text("Choose which app LifeRoute should use when you open a route. Route estimates still use Apple MapKit inside LifeRoute.")',
        'Text("Choose the app used when you open a route. Estimates remain MapKit-powered inside LifeRoute.")',
        1,
    )
    text = text.replace(
        'Text("Home is the routing fallback when live current location is unavailable, and it powers Return Home planning.")',
        'Text("Routing fallback when live location is unavailable; also powers Return Home.")',
        1,
    )
    SETUP.write_text(text, encoding="utf-8")


def patch_themes() -> None:
    text = THEMES.read_text(encoding="utf-8")
    if "v0.7.0 Build E Theme Center" in text:
        return

    required = [
        "LifeRouteThemeStore",
        "themeStore.selectedTheme = theme",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build E patch failed: Theme Center baseline missing {missing}")

    if "LifeRouteTheme.allCases" not in text and "LifeRouteTheme.phaseOneCoreGlassCatalog" not in text:
        raise SystemExit(
            "v0.7.0 Build E patch failed: Theme Center baseline missing ['LifeRouteTheme.allCases', 'LifeRouteTheme.phaseOneCoreGlassCatalog']"
        )

    final = r'''import SwiftUI

struct V054ThemeCenterView: View {
    // v0.7.0 Build E Theme Center: compact browser over the existing LifeRouteThemeStore.
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .all

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }

        func matches(_ theme: LifeRouteTheme) -> Bool {
            switch self {
            case .all:
                return true
            case .core:
                return theme.category == .core || theme.category == .metallic
            case .dynamic:
                return theme.category == .dynamic || theme.category == .fluid
            case .scenery:
                return theme.category == .scenery
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                selectedThemeHeader
                categoryStrip

                LifeRouteSectionLabel(title: "Theme Browser")
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredThemes) { theme in
                        themeCard(theme)
                    }
                }

                Label(
                    "Core themes remain color/material systems. Selecting a theme updates the existing app-wide theme owner and persists normally.",
                    systemImage: "checkmark.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredThemes: [LifeRouteTheme] {
        LifeRouteTheme.allCases.filter(selectedCategory.matches)
    }

    private var selectedThemeHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(themeStore.selectedTheme.palette.backgroundGradient)

                Circle()
                    .fill(themeStore.selectedTheme.palette.accent)
                    .frame(width: 38, height: 38)

                Circle()
                    .stroke(themeStore.selectedTheme.palette.accentSecondary, lineWidth: 3)
                    .frame(width: 54, height: 54)
            }
            .frame(width: 82, height: 82)
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(themeStore.selectedTheme.palette.accent.opacity(0.42), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE THEME")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accentSecondary)
                Text(themeStore.selectedTheme.name)
                    .font(.title3.weight(.black))
                    .foregroundStyle(palette.textPrimary)
                Text(themeStore.selectedTheme.category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)
        }
        .padding(12)
        .background(palette.panel.opacity(0.60), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.16), lineWidth: 1)
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ThemeFilter.allCases) { filter in
                    Button {
                        selectedCategory = filter
                        LifeRouteHaptics.selection()
                    } label: {
                        LifeRoutePill(title: filter.rawValue, isSelected: selectedCategory == filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedCategory == filter ? "Selected" : "Not selected")
                }
            }
        }
    }

    private func themeCard(_ theme: LifeRouteTheme) -> some View {
        let selected = themeStore.selectedTheme == theme

        return Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(theme.palette.backgroundGradient)
                        .frame(height: 78)

                    HStack(spacing: 7) {
                        Circle()
                            .fill(theme.palette.accent)
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(theme.palette.accentSecondary)
                            .frame(width: 18, height: 18)
                    }
                    .padding(9)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(theme.palette.accentSecondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                Text(theme.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Text(theme.category.rawValue.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
            }
            .padding(9)
            .background(selected ? palette.panelElevated.opacity(0.62) : palette.panel.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.62) : Color.white.opacity(0.06), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
'''
    THEMES.write_text(final, encoding="utf-8")


def main() -> None:
    patch_resources()
    patch_clients()
    patch_setup()
    patch_themes()
    print(
        "LifeRoute v0.7.0 Build E applied: Resources, Clients, Setup/Saved Places/Weekly To-Dos, and Theme Center now use the compact premium supporting-surface hierarchy while existing native domain and persistence owners remain intact."
    )


if __name__ == "__main__":
    main()
