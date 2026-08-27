import SwiftUI

typealias ContentView = V054ContentView

struct V054ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @StateObject private var lifecycleState = AppLifecycleCore()
    @StateObject private var router = AppRouter()
    @StateObject private var calendarState = CalendarCoreState()
    @StateObject private var providerState = CalendarProviderCore()
    @StateObject private var routingState = RoutingLocationCore()
    @StateObject private var clientState = ClientProfileCore()
    @StateObject private var toolsState = SessionToolsCore()

    var body: some View {
        ZStack {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: themeStore.palette
            )
            .ignoresSafeArea()

            TabView(selection: $router.selectedSection) {
                NavigationStack(path: $router.todayPath) {
                    V054TodayView(
                        router: router,
                        calendarState: calendarState,
                        routingState: routingState
                    )
                }
                .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
                .tag(AppSection.today)

                NavigationStack(path: $router.schedulePath) {
                    V054ScheduleView(
                        calendarState: calendarState,
                        providerState: providerState
                    )
                }
                .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
                .tag(AppSection.schedule)

                NavigationStack(path: $router.toolsPath) {
                    V054ToolsDashboard(
                        router: router,
                        toolsState: toolsState,
                        clientState: clientState
                    )
                }
                .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
                .tag(AppSection.tools)

                NavigationStack(path: $router.resourcesPath) {
                    ResourcePortalHubView()
                }
                .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
                .tag(AppSection.resources)

                NavigationStack(path: $router.setupPath) {
                    V054SetupView(
                        routingState: routingState,
                        clientState: clientState
                    )
                }
                .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
                .tag(AppSection.setup)
            }
        }
        .onOpenURL { url in
            if url.scheme?.lowercased() == "liferoute" {
                router.select(.today)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                routingState.resumeForegroundLocationIfNeeded()
                return
            }

            lifecycleState.flushPersistenceForSceneTransition()
            if phase == .background {
                routingState.cancelPendingOperations()
            }
        }
    }
}
