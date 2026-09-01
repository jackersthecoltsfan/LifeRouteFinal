import SwiftUI

// Checkpoint 02: one explicit owner for all top-level and stack navigation.
// No feature or cosmetic module should create a competing navigation state.
enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case schedule
    case tools
    case resources
    case setup

    var id: Self { self }

    var title: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Calendar"
        case .tools: return "Tools"
        case .resources: return "Resources"
        case .setup: return "Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver.fill"
        case .resources: return "books.vertical"
        case .setup: return "gearshape"
        }
    }
}

enum AppRoute: Hashable {
    case todayDetails
    case scheduleDetails
    case toolsDetails
    case resourcesDetails
    case setupDetails

    var title: String {
        switch self {
        case .todayDetails: return "Today"
        case .scheduleDetails: return "Calendar"
        case .toolsDetails: return "Session Tools"
        case .resourcesDetails: return "Resources"
        case .setupDetails: return "Setup"
        }
    }

    var subtitle: String {
        switch self {
        case .todayDetails:
            return "Keep your routes, saved places, and daily flow close at hand."
        case .scheduleDetails:
            return "Move between your day, week, and month while keeping calendar context together."
        case .toolsDetails:
            return "Open focused tools for timing, notes, visual supports, and session planning."
        case .resourcesDetails:
            return "Jump quickly to the parts of LifeRoute you use throughout the workday."
        case .setupDetails:
            return "Manage your appearance, clients, home location, and saved places."
        }
    }

    var systemImage: String {
        switch self {
        case .todayDetails: return "sun.max.fill"
        case .scheduleDetails: return "calendar.badge.checkmark"
        case .toolsDetails: return "wrench.and.screwdriver.fill"
        case .resourcesDetails: return "books.vertical.fill"
        case .setupDetails: return "gearshape.fill"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedSection: AppSection = .today
    @Published var todayPath = NavigationPath()
    @Published var schedulePath = NavigationPath()
    @Published var toolsPath = NavigationPath()
    @Published var resourcesPath = NavigationPath()
    @Published var setupPath = NavigationPath()
    @Published private var isBottomToolbarSuppressed = false

    func select(_ section: AppSection) {
        guard selectedSection != section else { return }
        selectedSection = section
    }

    func open(_ route: AppRoute, in section: AppSection) {
        if selectedSection != section {
            selectedSection = section
        }
        switch section {
        case .today:
            todayPath.append(route)
        case .schedule:
            schedulePath.append(route)
        case .tools:
            toolsPath.append(route)
        case .resources:
            resourcesPath.append(route)
        case .setup:
            setupPath.append(route)
        }
    }

    func resetPath(for section: AppSection) {
        switch section {
        case .today:
            todayPath = NavigationPath()
        case .schedule:
            schedulePath = NavigationPath()
        case .tools:
            toolsPath = NavigationPath()
        case .resources:
            resourcesPath = NavigationPath()
        case .setup:
            setupPath = NavigationPath()
        }
    }

    func setBottomToolbarSuppressed(_ suppressed: Bool) {
        guard isBottomToolbarSuppressed != suppressed else { return }
        isBottomToolbarSuppressed = suppressed
    }

    var shouldShowBottomToolbar: Bool {
        guard !isBottomToolbarSuppressed else { return false }
        switch selectedSection {
        case .today:
            return todayPath.isEmpty
        case .schedule:
            return schedulePath.isEmpty
        case .tools:
            return toolsPath.isEmpty
        case .resources:
            return resourcesPath.isEmpty
        case .setup:
            return setupPath.isEmpty
        }
    }
}

private struct LifeRouteDeepDestinationModifier: ViewModifier {
    @EnvironmentObject private var router: AppRouter

    func body(content: Content) -> some View {
        navigationContent(content)
            .onAppear {
                router.setBottomToolbarSuppressed(true)
            }
            .onDisappear {
                router.setBottomToolbarSuppressed(false)
            }
    }

    @ViewBuilder
    private func navigationContent(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .containerBackground(Color.clear, for: .navigation)
        } else {
            content
        }
    }
}

extension View {
    func lifeRouteDeepDestination() -> some View {
        modifier(LifeRouteDeepDestinationModifier())
    }
}

// Checkpoint 06: scene transitions share one bounded persistence-flush task.
// A second inactive/background transition joins the work already in flight
// instead of creating another lifecycle-owned task.
@MainActor
final class AppLifecycleCore: ObservableObject {
    private var persistenceFlushTask: Task<Void, Never>?

    func flushPersistenceForSceneTransition() {
        guard persistenceFlushTask == nil else { return }
        persistenceFlushTask = Task { @MainActor [weak self] in
            await LifeRoutePersistenceStore.shared.flushPendingWrites()
            self?.persistenceFlushTask = nil
        }
    }

    deinit {
        persistenceFlushTask?.cancel()
    }
}

// iOS 16 compatibility shim for the simple empty-state surface used by the
// functional-core rebuild. SwiftUI's system ContentUnavailableView starts at
// iOS 17, while LifeRoute still supports iOS 16 during this rebuild.
struct ContentUnavailableView: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let systemImage: String
    let description: Text

    init(_ title: String, systemImage: String, description: Text) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ScenicRoyalCard(role: .readability) {
            VStack(spacing: 14) {
                ScenicRoyalIconBadge(systemImage: systemImage)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    description
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }
}
