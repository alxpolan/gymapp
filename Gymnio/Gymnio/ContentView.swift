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
    @EnvironmentObject var premium: PremiumManager

    /// iOS 18+ uses the new `Tab` API (with the search-role "add" tab); earlier systems use tab items.
    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selectedTab) {
                Tab(store.t("nav.train"), systemImage: "dumbbell.fill", value: 0) { TrainView() }
                Tab(store.t("nav.history"), systemImage: "calendar", value: 1) { HistoryView() }
                Tab(store.t("nav.exercises"), systemImage: "list.bullet", value: 2) { NavigationStack { ExercisesView() } }
                Tab(store.t("nav.progress"), systemImage: "trophy.fill", value: 3) { NavigationStack { InsightsView() } }
            }
        } else {
            TabView(selection: $selectedTab) {
                TrainView()
                    .tabItem { Label(store.t("nav.train"), systemImage: "dumbbell.fill") }
                    .tag(0)
                HistoryView()
                    .tabItem { Label(store.t("nav.history"), systemImage: "calendar") }
                    .tag(1)
                NavigationStack { ExercisesView() }
                    .tabItem { Label(store.t("nav.exercises"), systemImage: "list.bullet") }
                    .tag(2)
                NavigationStack { InsightsView() }
                    .tabItem { Label(store.t("nav.progress"), systemImage: "trophy.fill") }
                    .tag(3)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        let stack = ZStack {
            tabs
                .fullScreenCover(isPresented: $store.showActiveWorkout) {
                    ActiveWorkoutView()
                        .environmentObject(store)
                        .environmentObject(PremiumManager.shared)
                        .preferredColorScheme(store.colorScheme)
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
        .sheet(item: Binding(get: { store.showActiveWorkout ? nil : store.paywallRequest },
                             set: { store.paywallRequest = $0 })) { request in
            PaywallView(source: request.source)
                .environmentObject(store)
                .environmentObject(PremiumManager.shared)
        }
        .fullScreenCover(isPresented: $store.showOnboarding) {
            OnboardingView(defaultUnit: store.weightUnit)
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
        }
        .onChangeCompat(of: premium.isPro) { _ in store.trackSessionStart() }
        .onChangeCompat(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                PostHogSDK.shared.flush()
            }
            if phase == .active {
                store.trackSessionStart()
                RestTimerManager.shared.endExpired()
            }
        }
        .tint(Color.gymAccent)
        .preferredColorScheme(store.colorScheme)

        if forceTabBar {
            stack.environment(\.horizontalSizeClass, .compact)
        } else {
            stack
        }
    }
}
