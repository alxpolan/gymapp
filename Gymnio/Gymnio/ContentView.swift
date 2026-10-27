import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var selectedTab: Int = 0

    private var forceTabBar: Bool {
        CommandLine.arguments.contains("-ui_test_force_tab_bar")
    }

    @ViewBuilder
    var body: some View {
        let stack = ZStack {
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

                Tab(store.t("nav.history"), systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: 3) {
                    HistoryView()
                }

                Tab(store.t("nav.add"), systemImage: "plus", value: 4, role: .search) {
                    Color.clear
                }
            }
            .onChange(of: selectedTab) { _, new in
                if new == 4 {
                    store.showAddExercise = true
                    DispatchQueue.main.async { selectedTab = 1 }
                }
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
        .preferredColorScheme(store.colorScheme)

        if forceTabBar {
            stack.environment(\.horizontalSizeClass, .compact)
        } else {
            stack
        }
    }
}
