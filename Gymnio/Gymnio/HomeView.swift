import SwiftUI
import Charts
import StoreKit

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @Environment(\.requestReview) var requestReview
    @State private var stats = WorkoutStats(totalWorkouts: 0, uniqueExercises: 0, totalVolumeKg: 0)
    @State private var alerts: [ProgressionAlert] = []
    @State private var topGroups: [ExerciseGroup] = []
    @State private var chartIndex: Int = 0
    @State private var navPath = NavigationPath()
    @State private var coachInsight: CoachInsight?

    private var greeting: String {
        if store.forceMorningGreeting { return store.t("home.greeting.morning") }
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return store.t("home.greeting.morning")
        case 12..<18: return store.t("home.greeting.afternoon")
        default:     return store.t("home.greeting.evening")
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {

                        HStack {
                            Text(greeting)
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                            Spacer()
                            GlassCircleButton(icon: "gearshape.fill") {
                                navPath.append(NavDest.settings)
                            }
                        }
                        .padding(.bottom, 4)

                        if store.entries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: store.exercises.isEmpty ? "plus.circle" : "dumbbell")
                                    .font(.system(size: 64))
                                    .foregroundColor(scheme == .dark ? Color(hex: "555555") : Color(hex: "cccccc"))
                                    .padding(.top, 60)
                                Text(store.exercises.isEmpty
                                     ? store.t("exercises.empty")
                                     : store.t("home.noLogs"))
                                    .font(.system(size: 18, weight: .semibold))
                                    .secondaryText()
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {

                            if let coachInsight {
                                CoachRecapCard(insight: coachInsight)
                            }

                            if store.homeSettings.showProgressionAlert, let alert = alerts.first {
                                ProgressionAlertCard(alert: alert)
                            }

                            if store.homeSettings.showStats {
                                GlassCard {
                                    HStack(spacing: 0) {
                                        HomeStatCard(value: "\(stats.totalWorkouts)",
                                                     label: store.t("home.stats.workouts"),
                                                     color: Color.tint(scheme))
                                        HomeStatDivider()
                                        HomeStatCard(value: "\(Int(store.displayWeight(stats.totalVolumeKg) / 1000))k",
                                                     label: String(format: store.t("home.stats.kg"), store.unitLabel),
                                                     color: .statRed)
                                        HomeStatDivider()
                                        HomeStatCard(value: "\(stats.uniqueExercises)",
                                                     label: store.t("home.stats.exercises"),
                                                     color: .statTeal)
                                    }
                                }
                            }

                            if store.homeSettings.showCharts && !topGroups.isEmpty && store.entries.count >= 3 {
                                let chartGroups = Array(topGroups.prefix(3))
                                VStack(spacing: 6) {
                                    GeometryReader { geo in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 0) {
                                                ForEach(Array(chartGroups.enumerated()), id: \.element.id) { i, group in
                                                    HomeChartCard(group: group)
                                                        .frame(width: geo.size.width)
                                                        .id(i)
                                                }
                                            }
                                            .scrollTargetLayout()
                                        }
                                        .scrollTargetBehavior(.paging)
                                        .scrollPosition(id: Binding<Int?>(
                                            get: { chartIndex },
                                            set: { chartIndex = $0 ?? 0 }
                                        ))
                                    }
                                    .frame(height: 230)

                                    PaginationDots(total: chartGroups.count, current: chartIndex)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            if store.homeSettings.showTopExercises && !topGroups.isEmpty {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(store.t("home.top.title"))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                                            .padding(.bottom, 16)

                                        ForEach(Array(topGroups.prefix(3).enumerated()), id: \.element.id) { idx, group in
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color.tint(scheme).opacity(0.25))
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Text("\(idx + 1)")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(Color.tint(scheme))
                                                    )
                                                Text(group.exercise)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text(String(format: "%.0f \(store.unitLabel)", store.displayWeight(group.totalVolume)))
                                                    .font(.system(size: 13, weight: .medium))
                                                    .secondaryText()
                                            }
                                            .padding(.bottom, idx < min(topGroups.count, 3) - 1 ? 12 : 0)
                                        }
                                    }
                                }
                            }

                            GlassCard {
                                Button {
                                    navPath.append(NavDest.customizeHome)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundColor(Color.tint(scheme))
                                        Text(store.t("home.customize"))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .secondaryText()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavDest.self) { dest in
                switch dest {
                case .settings:      SettingsView()
                case .customizeHome: CustomizeHomeView()
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: store.entries.count) { _, count in
            let key = "review_requested_at_10"
            let days = Set(store.entries.map { Calendar.current.startOfDay(for: $0.date) }).count
            let premium = PremiumManager.shared
            let nearPaywall = !premium.isPro && count >= premium.freeEntryLimit - 1
            if !nearPaywall && store.paywallRequest == nil && AppStore.shouldRequestReview(entryCount: count, distinctDays: days, alreadyAsked: UserDefaults.standard.bool(forKey: key)) {
                UserDefaults.standard.set(true, forKey: key)
                requestReview()
            }
        }
    }

    private func reload() {
        store.reload()
        let groups = store.groupedExercises()
        stats = Analytics.workoutStats(entries: store.entries)
        alerts = Analytics.progressionAlerts(groups: groups)
        topGroups = Analytics.topExercisesByVolume(groups: groups)
        coachInsight = Coach.weeklyRecap(store: store)
    }
}

// MARK: - NavDest
enum NavDest: Hashable {
    case settings, customizeHome
}

// MARK: - Progression Alert Card

struct ProgressionAlertCard: View {
    let alert: ProgressionAlert
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    private var bodyText: AttributedString {
        let isLbs = store.weightUnit == "lbs"
        let current = store.displayWeight(alert.currentWeight)
        let suggested = current + (isLbs ? 5.0 : 2.5)
        var raw = String(format: store.t(isLbs ? "home.progression.body.lbs" : "home.progression.body"),
                         alert.exercise, formatWeightValue(current), formatWeightValue(suggested))
        if CommandLine.arguments.contains("-ui_testing") {
            raw = raw.replacingOccurrences(of: " 💪", with: "")
        }
        return (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text(store.t("home.progression.ready"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                }
                Text(bodyText)
                    .font(.system(size: 14))
                    .secondaryText()
                    .lineSpacing(3)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "ff9500").opacity(scheme == .dark ? 0.22 : 0.14),
                         Color(hex: "ff6b00").opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }
}

// MARK: - Home Stat Card

struct HomeStatCard: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12))
                .secondaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeStatDivider: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        Rectangle()
            .fill(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 6)
    }
}

// MARK: - Home Chart Card

struct HomeChartCard: View {
    let group: ExerciseGroup
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    var data: [ChartDataPoint] { Analytics.weightChartData(entries: group.entries) }
    @State private var selectedIndex: Int? = nil

    private var selectedPoint: ChartDataPoint? {
        guard let sel = selectedIndex else { return nil }
        return data.min(by: { abs($0.index - sel) < abs($1.index - sel) })
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(group.exercise)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))

                if data.count >= 2 {
                    Chart(data) { pt in
                        LineMark(x: .value("i", pt.index), y: .value("kg", pt.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme))
                            .lineStyle(StrokeStyle(lineWidth: 5))
                        AreaMark(x: .value("i", pt.index), y: .value("kg", pt.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme).opacity(0.1))
                        if let sel = selectedPoint {
                            RuleMark(x: .value("i", sel.index))
                                .foregroundStyle(Color.tint(scheme).opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                            PointMark(x: .value("i", sel.index), y: .value("kg", sel.value))
                                .foregroundStyle(Color.tint(scheme))
                                .symbolSize(50)
                                .annotation(position: .top, spacing: 6,
                                            overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                    Text("\(formatWeightValue(store.displayWeight(sel.value))) \(store.unitLabel)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                                }
                        }
                    }
                    .chartXSelection(value: $selectedIndex)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartBackground { _ in Color.clear }
                    .frame(height: 120)
                }

                Text(selectedPoint.map { pt in
                    "\(formatWeightValue(store.displayWeight(pt.value))) \(store.unitLabel) • \(pt.label)"
                } ?? "\(store.t("detail.chart.weight")) (\(store.unitLabel))")
                    .font(.system(size: 14))
                    .secondaryText()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
            }
        }
    }
}
