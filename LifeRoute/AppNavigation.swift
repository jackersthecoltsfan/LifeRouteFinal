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
        case .schedule: return "Schedule"
        case .tools: return "Tools"
        case .resources: return "Resources"
        case .setup: return "Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver"
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
        case .todayDetails: return "Today navigation"
        case .scheduleDetails: return "Schedule navigation"
        case .toolsDetails: return "Session Tools navigation"
        case .resourcesDetails: return "Resources navigation"
        case .setupDetails: return "Setup navigation"
        }
    }

    var subtitle: String {
        switch self {
        case .todayDetails:
            return "This destination is owned by Today’s native NavigationStack."
        case .scheduleDetails:
            return "Day, Week, and Month functionality will be migrated into this native stack."
        case .toolsDetails:
            return "ABA and session tools will return here in audited feature batches."
        case .resourcesDetails:
            return "External resources will be restored without taking over app navigation."
        case .setupDetails:
            return "Setup state will be migrated without reintroducing a login gate."
        }
    }

    var systemImage: String {
        switch self {
        case .todayDetails: return "checkmark.circle"
        case .scheduleDetails: return "calendar.badge.checkmark"
        case .toolsDetails: return "wrench.and.screwdriver"
        case .resourcesDetails: return "books.vertical"
        case .setupDetails: return "gearshape"
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

    func select(_ section: AppSection) {
        selectedSection = section
    }

    func open(_ route: AppRoute, in section: AppSection) {
        selectedSection = section
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
}
