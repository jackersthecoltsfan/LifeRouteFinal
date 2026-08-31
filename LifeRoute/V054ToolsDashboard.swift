import SwiftUI
import Foundation

struct V054ToolsDashboard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle

    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore

    @StateObject private var visualState = ClientVisualSupportCore()

    private var toolColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard)]
        }
        return [
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.standard),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                ScenicRoyalScreenHeader(
                    title: "Tools",
                    subtitle: "Practical support for clearer, calmer sessions."
                ) {
                    ScenicRoyalIconBadge(systemImage: "wrench.and.screwdriver")
                }

                readinessCard

                ScenicRoyalSectionHeader(
                    "Session toolkit",
                    subtitle: "Choose a focused tool and keep your current client context.",
                    systemImage: "square.grid.2x2"
                )

                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    LazyVGrid(columns: toolColumns, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        NavigationLink {
                            VisualTimerView(timer: toolsState.timer)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Visual Timer",
                                subtitle: "A calm countdown with visual, tone, and haptic choices.",
                                systemImage: "timer"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "First / Then",
                                subtitle: "Build a clear two-step visual sequence.",
                                systemImage: "arrow.right.square"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            VisualAIAssistedStudioView(visualState: visualState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Visual Supports",
                                subtitle: "Create and reuse icons, boards, and ABA visuals.",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "Quick Notes",
                                subtitle: "Capture useful session details with minimal friction.",
                                systemImage: "note.text"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            AISessionPlanBuilderView(clientState: clientState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "AI Session Plan",
                                subtitle: "Organize approved targets and reinforcers into a flow.",
                                systemImage: "brain.head.profile"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            AISessionNoteGeneratorView(clientState: clientState, toolsState: toolsState)
                                .lifeRouteDeepDestination()
                        } label: {
                            ScenicRoyalToolTile(
                                title: "AI Session Note",
                                subtitle: "Create an evidence-bound draft for review and editing.",
                                systemImage: "doc.text.magnifyingglass"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                clientContextCard

                Label(
                    "AI drafts use Apple’s on-device model when available. Review every clinical output before use.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(scenicStyle.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.hairline)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            router.setBottomToolbarSuppressed(false)
            visualState.retainClients(clientState.clients)
        }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var readinessCard: some View {
        ScenicRoyalInsetRow(role: .readability) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        readinessStatus
                        manageClientsButton
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        readinessStatus
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.hairline)
                        manageClientsButton
                    }
                }
            }
        }
    }

    private var readinessStatus: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Image(systemName: clientState.clients.isEmpty ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(scenicStyle.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(clientState.clients.isEmpty ? "General mode ready" : "Client context ready")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scenicStyle.primaryText)
                Text(clientState.clients.isEmpty ? "No client profile required for core tools." : "\(clientState.clients.count) saved client profile\(clientState.clients.count == 1 ? "" : "s") available.")
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var manageClientsButton: some View {
        Button("Manage clients") {
            LifeRouteHaptics.selection()
            router.select(.setup)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(scenicStyle.accent)
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
            alignment: .leading
        )
        .accessibilityHint("Opens Setup to manage client profiles")
    }

    private var clientContextCard: some View {
        ScenicRoyalCard(role: .card) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: "person.2")
                    .foregroundStyle(scenicStyle.accent)
                    .frame(width: 34, height: 34)
                    .scenicRoyalSurface(role: .ambient, cornerRadius: 17)
                    .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Client context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scenicStyle.primaryText)
                Text(clientState.clients.isEmpty ? "General tools only" : "General + saved ABA client codes")
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
