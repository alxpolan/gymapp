import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.colorScheme) var scheme

    @State private var groups: [ExerciseGroup] = []
    @State private var streak = StreakInfo(currentWeekStreak: 0, longestWeekStreak: 0, activeDays: 0,
                                           sessionsThisWeek: 0, weeklyAverage: 0, consistency: 0)
    @State private var weekly: [VolumePoint] = []
    @State private var muscles: [MuscleVolume] = []
    @State private var records: [PersonalRecord] = []
    @State private var trends: [ProgressTrend] = []
    @State private var recap: CoachInsight?
    @State private var coachFeed: [CoachInsight] = []
    @State private var selected1RM: String = ""
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ScreenTitle(text: store.t("insights.title"))
                        Spacer()
                        if premium.isPro { ProBadge() }
                    }
                    .padding(.bottom, 4)

                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        weeklyVolumeCard

                        if let recap { CoachRecapCard(insight: recap) }

                        if !premium.isPro { UpgradeCTACard() }

                        InsightSectionHeader(title: store.t("insights.coach"), isPro: true)
                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.coach") {
                            CoachFeedCard(insights: premium.isPro ? coachFeed : Coach.insights(store: store))
                        }

                        InsightSectionHeader(title: store.t("insights.est1rm"), isPro: true)
                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.est1rm") {
                            OneRMCard(groups: groups, selected: $selected1RM)
                        }

                        InsightSectionHeader(title: store.t("insights.records"), isPro: true)
                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.records") {
                            RecordsCard(records: records)
                        }

                        InsightSectionHeader(title: store.t("insights.muscle"), isPro: true)
                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.muscle") {
                            MuscleSplitCard(muscles: muscles)
                        }

                        InsightSectionHeader(title: store.t("insights.trends"), isPro: true)
                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.trends") {
                            TrendsCard(trends: trends)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: reload)
        .onChange(of: store.entries.count) { _, _ in reload() }
        .onChange(of: premium.isPro) { _, _ in reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(scheme == .dark ? Color(hex: "555555") : Color(hex: "cccccc"))
            Text(store.t("insights.empty"))
                .font(.system(size: 16))
                .secondaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    // MARK: - Free overview

    private var overviewCard: some View {
        GlassCard {
            HStack(spacing: 0) {
                OverviewStat(value: "\(streak.currentWeekStreak)",
                             label: store.t("insights.overview.streak"),
                             color: Color(hex: "FF9500"), icon: "flame.fill")
                OverviewStat(value: "\(streak.activeDays)",
                             label: store.t("insights.overview.days"),
                             color: Color.tint(scheme), icon: "calendar")
                OverviewStat(value: "\(Int(streak.consistency * 100))%",
                             label: store.t("insights.overview.consistency"),
                             color: Color(hex: "34C759"), icon: "target")
            }
        }
    }

    private var weeklyVolumeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("insights.weeklyVolume"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                if weekly.contains(where: { $0.value > 0 }) {
                    Chart(weekly) { pt in
                        BarMark(x: .value("w", pt.label),
                                y: .value("v", store.displayWeight(pt.value)))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                            startPoint: .top, endPoint: .bottom))
                            .cornerRadius(4)
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .frame(height: 150)
                } else {
                    Text(store.t("insights.weeklyVolume.empty"))
                        .font(.system(size: 13)).secondaryText()
                }
            }
        }
    }

    // MARK: - Data

    private func reload() {
        store.reload()
        groups = store.groupedExercises().filter { !$0.entries.isEmpty }
        streak = AdvancedAnalytics.streakInfo(entries: store.entries)
        weekly = AdvancedAnalytics.weeklyVolume(entries: store.entries)
        muscles = AdvancedAnalytics.muscleDistribution(groups: groups)
        records = AdvancedAnalytics.recordsBoard(groups: groups)
        trends = AdvancedAnalytics.progressTrends(groups: groups)
        recap = Coach.weeklyRecap(store: store)
        coachFeed = Coach.insights(store: store)
        if selected1RM.isEmpty || !groups.contains(where: { $0.exercise == selected1RM }) {
            selected1RM = groups.max(by: { $0.entries.count < $1.entries.count })?.exercise ?? ""
        }
    }
}

// MARK: - Overview stat

private struct OverviewStat: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .secondaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coach recap card

struct CoachRecapCard: View {
    let insight: CoachInsight
    @Environment(\.colorScheme) var scheme
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: insight.systemImage)
                        .font(.system(size: 20))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text(insight.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                }
                Text(insight.message)
                    .font(.system(size: 14))
                    .secondaryText()
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Coach feed card

struct CoachFeedCard: View {
    let insights: [CoachInsight]
    @Environment(\.colorScheme) var scheme
    var body: some View {
        VStack(spacing: 10) {
            if insights.isEmpty {
                GlassCard {
                    Text(" ")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
            } else {
                ForEach(insights) { insight in
                    GlassCard {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(insight.tint.opacity(0.18)).frame(width: 38, height: 38)
                                Image(systemName: insight.systemImage)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(insight.tint)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                                Text(insight.message)
                                    .font(.system(size: 13))
                                    .secondaryText()
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Estimated 1RM card

struct OneRMCard: View {
    let groups: [ExerciseGroup]
    @Binding var selected: String
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var selectedIndex: Int? = nil

    private var group: ExerciseGroup? { groups.first { $0.exercise == selected } }
    private var data: [ChartDataPoint] {
        guard let group else { return [] }
        return AdvancedAnalytics.oneRepMaxSeries(entries: group.entries)
    }
    private var best: Double {
        guard let group else { return 0 }
        return AdvancedAnalytics.bestOneRepMax(entries: group.entries)
    }
    private var selectedPoint: ChartDataPoint? {
        guard let sel = selectedIndex else { return nil }
        return data.min(by: { abs($0.index - sel) < abs($1.index - sel) })
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("insights.est1rm.best"))
                            .font(.system(size: 12)).secondaryText()
                        Text("\(formatWeightValue(store.displayWeight(best))) \(store.unitLabel)")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                    }
                    Spacer()
                    Menu {
                        ForEach(groups) { g in
                            Button(g.exercise) { selected = g.exercise; selectedIndex = nil }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selected).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                        }
                        .foregroundColor(Color.tint(scheme))
                    }
                }

                if data.count >= 2 {
                    Chart(data) { pt in
                        LineMark(x: .value("i", pt.index), y: .value("v", store.displayWeight(pt.value)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme))
                            .lineStyle(StrokeStyle(lineWidth: 4))
                        AreaMark(x: .value("i", pt.index), y: .value("v", store.displayWeight(pt.value)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme).opacity(0.12))
                        if let sel = selectedPoint {
                            PointMark(x: .value("i", sel.index), y: .value("v", store.displayWeight(sel.value)))
                                .foregroundStyle(Color.tint(scheme))
                                .symbolSize(60)
                                .annotation(position: .top, spacing: 6,
                                            overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                    Text("\(formatWeightValue(store.displayWeight(sel.value))) \(store.unitLabel)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 7).padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                                }
                        }
                    }
                    .chartXSelection(value: $selectedIndex)
                    .chartXAxis(.hidden)
                    .frame(height: 140)
                } else {
                    Text(store.t("insights.est1rm.more"))
                        .font(.system(size: 13)).secondaryText()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
    }
}

// MARK: - Records board

struct RecordsCard: View {
    let records: [PersonalRecord]
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                ForEach(Array(records.prefix(8).enumerated()), id: \.element.id) { idx, r in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.exercise)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                            Text(String(format: store.t("insights.records.line"),
                                        formatWeightValue(store.displayWeight(r.maxWeight)), store.unitLabel, r.maxReps))
                                .font(.system(size: 12)).secondaryText()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatWeightValue(store.displayWeight(r.bestOneRepMax))) \(store.unitLabel)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.tint(scheme))
                            Text(store.t("insights.records.e1rm"))
                                .font(.system(size: 10)).secondaryText()
                        }
                    }
                    .padding(.vertical, 10)
                    if idx < min(records.count, 8) - 1 { Divider() }
                }
            }
        }
    }
}

// MARK: - Muscle split

struct MuscleSplitCard: View {
    let muscles: [MuscleVolume]
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(muscles) { m in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Image(systemName: m.group.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(m.group.color)
                                .frame(width: 20)
                            Text(store.t(m.group.titleKey))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                            Spacer()
                            Text("\(Int(m.share * 100))%")
                                .font(.system(size: 13, weight: .bold))
                                .secondaryText()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(m.group.color.opacity(0.15)).frame(height: 8)
                                Capsule().fill(m.group.color)
                                    .frame(width: max(6, geo.size.width * m.share), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Progress trends

struct TrendsCard: View {
    let trends: [ProgressTrend]
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    private func color(_ c: TrendCategory) -> Color {
        switch c {
        case .improving: return Color(hex: "34C759")
        case .declining: return Color(hex: "FF3B30")
        case .steady:    return Color(hex: "FF9500")
        case .new:       return Color(hex: "A06BFF")
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                ForEach(Array(trends.prefix(8).enumerated()), id: \.element.id) { idx, t in
                    HStack(spacing: 12) {
                        Image(systemName: t.category.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(color(t.category))
                            .frame(width: 22)
                        Text(t.exercise)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                        Spacer()
                        Text(trendLabel(t))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color(t.category))
                    }
                    .padding(.vertical, 10)
                    if idx < min(trends.count, 8) - 1 { Divider() }
                }
            }
        }
    }

    private func trendLabel(_ t: ProgressTrend) -> String {
        if t.category == .new { return store.t(t.category.labelKey) }
        let perWeek = store.displayWeight(t.weeklyChangeKg)
        let sign = perWeek >= 0 ? "+" : ""
        return "\(sign)\(formatWeightValue(perWeek)) \(store.unitLabel)/\(store.t("insights.trends.week"))"
    }
}
