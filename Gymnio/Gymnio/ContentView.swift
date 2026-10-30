import SwiftUI
import PostHog

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var selectedTab: Int = 0

    private var forceTabBar: Bool {
        CommandLine.arguments.contains("-ui_test_force_tab_bar")
    }

    @Environment(\.scenePhase) private var scenePhase

    /// iOS 18+ uses the new `Tab` API (with the search-role "add" tab); earlier systems use tab items.
    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selectedTab) {
                Tab(store.t("nav.home"), systemImage: "house", value: 0) {
                    HomeView()
                }
                Tab(store.t("nav.exercises"), systemImage: "dumbbell", value: 1) {
                    NavigationStack { ExercisesView() }
                }
                Tab(store.t("nav.insights"), systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                    NavigationStack { InsightsView() }
                }
                Tab(store.t("nav.history"), systemImage: SymbolCompat.history, value: 3) {
                    HistoryView()
                }
                Tab(store.t("nav.add"), systemImage: "plus", value: 4, role: .search) {
                    Color.clear
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label(store.t("nav.home"), systemImage: "house") }
                    .tag(0)
                NavigationStack { ExercisesView() }
                    .tabItem { Label(store.t("nav.exercises"), systemImage: "dumbbell") }
                    .tag(1)
                NavigationStack { InsightsView() }
                    .tabItem { Label(store.t("nav.insights"), systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(2)
                HistoryView()
                    .tabItem { Label(store.t("nav.history"), systemImage: SymbolCompat.history) }
                    .tag(3)
                Color.clear
                    .tabItem { Label(store.t("nav.add"), systemImage: "plus") }
                    .tag(4)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        let stack = ZStack {
            tabs
            .onChangeCompat(of: selectedTab) { new in
                if new == 4 {
                    store.showAddExercise = true
                    DispatchQueue.main.async { selectedTab = 1 }
                }
            }
            .sheet(item: $store.quickLogRequest) { request in
                QuickLogView(exercise: request.exercise)
                    .environmentObject(store)
                    .environmentObject(PremiumManager.shared)
            }

            if store.showAddExercise {
                Color.black
                    .opacity(scheme == .dark ? 0.55 : 0.35)
                    .ignoresSafeArea()
                    .onTapGesture { store.showAddExercise = false }
                    .transition(.opacity)

                AddExerciseView()
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.showAddExercise)
        .sheet(item: $store.paywallRequest) { request in
            PaywallView(source: request.source)
                .environmentObject(store)
                .environmentObject(PremiumManager.shared)
        }
        .fullScreenCover(isPresented: $store.showOnboarding) {
            OnboardingView(defaultUnit: store.weightUnit)
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
        }
        .onChangeCompat(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                PostHogSDK.shared.flush()
            }
            if phase == .active {
                RestTimerManager.shared.endExpired()
            }
        }
        .preferredColorScheme(store.colorScheme)

        if forceTabBar {
            stack.environment(\.horizontalSizeClass, .compact)
        } else {
            stack
        }
    }
}
