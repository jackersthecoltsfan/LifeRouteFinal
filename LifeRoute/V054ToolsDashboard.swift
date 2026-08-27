import SwiftUI

struct V054ToolsDashboard: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var router: AppRouter
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var clientState: ClientProfileCore
    @StateObject private var visualState = ClientVisualSupportCore()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 17) {
                hero

                LazyVGrid(columns: columns, spacing: 10) {
                    NavigationLink {
                        VisualTimerView(timer: toolsState.timer)
                    } label: {
                        toolCard("Visual Timer", "Reliable session timing", "timer", palette.accent)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ClientFirstThenVisualView(visualState: visualState, clientState: clientState)
                    } label: {
                        toolCard("First / Then", "Build a clear visual sequence", "arrow.right.circle.fill", .green)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ClientVisualSupportCenter(visualState: visualState, clientState: clientState)
                    } label: {
                        toolCard("Visual Supports", "Icons, boards, and schedules", "photo.on.rectangle.angled", .purple)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        QuickSessionNotesView(toolsState: toolsState, clientState: clientState)
                    } label: {
                        toolCard("Quick Notes", "Capture scratch notes fast", "note.text", palette.accentSecondary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AISessionPlanBuilderView(clientState: clientState)
                    } label: {
                        toolCard("AI Session Plan", "Build a real session flow", "brain.head.profile.fill", .orange)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AISessionNoteGeneratorView(clientState: clientState)
                    } label: {
                        toolCard("AI Session Note", "Draft from supplied facts", "sparkles.rectangle.stack.fill", .cyan)
                    }
                    .buttonStyle(.plain)
                }

                clientContextCard

                Text("AI features use Apple’s on-device Foundation Model when Apple Intelligence is available. Clinical drafts still require review before use.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { visualState.retainClients(clientState.clients) }
        .onReceive(clientState.$clients) { clients in
            visualState.retainClients(clients)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(palette.panelGradient)

            LinearGradient(
                colors: [palette.accent.opacity(0.20), .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 130, weight: .black))
                .foregroundStyle(palette.accent.opacity(0.055))
                .offset(x: 190, y: 48)

            VStack(alignment: .leading, spacing: 9) {
                Text("SESSION TOOLS")
                    .font(.caption.weight(.black))
                    .tracking(2)
                    .foregroundStyle(palette.accent)
                Text("Your session command center.")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Visual supports, quick capture, smarter planning, and documentation assistance in one place.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(21)
        }
        .frame(minHeight: 205)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func toolCard(_ title: String, _ subtitle: String, _ systemImage: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            Spacer(minLength: 0)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.07), radius: 14, y: 7)
    }

    private var clientContextCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.14))
                Image(systemName: "person.2.fill")
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Client context")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(clientState.clients.isEmpty ? "General tools ready · no client required" : "\(clientState.clients.count) client profiles + General mode")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Button("Manage") { router.select(.setup) }
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
        }
        .lifeRouteCard()
    }
}
