import SwiftUI
import PostHog

// MARK: - Small stat cell (trophy shelf, strength score)

private struct MiniStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(Color.gymText)
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

// MARK: - Trophy shelf (Pro): PRs this month, total PRs, best week ever

struct TrophyShelfCard: View {
    let records: [PersonalRecord]
    let entries: [WorkoutEntry]
    @EnvironmentObject var store: AppStore

    private var monthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return records.filter {
            guard let date = $0.bestOneRepMaxDate else { return false }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }.count
    }

    private var bestWeek: VolumePoint? {
        AdvancedAnalytics.weeklyVolume(entries: entries, weeks: 26).max { $0.value < $1.value }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("insights.trophy.title"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.gymText)
                HStack(spacing: 0) {
                    MiniStat(value: "\(records.count)", label: store.t("insights.trophy.total"))
                    MiniStat(value: "\(monthCount)", label: store.t("insights.trophy.month"))
                    if let best = bestWeek, best.value > 0 {
                        MiniStat(
                            value: "\(formatWeightValue(store.displayWeight(best.value).rounded()))",
                            label: store.t("insights.trophy.bestWeek"))
                    }
                }
            }
        }
    }
}

// MARK: - Strength score (Pro): best estimated 1RM per muscle + total

struct StrengthScoreCard: View {
    let groups: [ExerciseGroup]
    @EnvironmentObject var store: AppStore

    private static let order: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms, .core]

    private var rows: [(MuscleGroup, Double)] {
        Self.order.compactMap { muscle in
            let best = groups
                .filter { MuscleGroup.classify($0.exercise) == muscle }
                .flatMap { $0.entries }
                .map { AdvancedAnalytics.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
                .max() ?? 0
            return best > 0 ? (muscle, best) : nil
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.t("insights.strength.title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.gymText)
                    Spacer()
                    Text("\(formatWeightValue(store.displayWeight(rows.map { $0.1 }.reduce(0, +)).rounded())) \(store.unitLabel)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(Color.gymAccent)
                }
                ForEach(rows, id: \.0) { muscle, best in
                    HStack {
                        Text(store.t(muscle.titleKey))
                            .font(.system(size: 15))
                            .foregroundColor(Color.gymText)
                        Spacer()
                        Text("\(formatWeightValue(store.displayWeight(best))) \(store.unitLabel)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.gymText)
                    }
                }
            }
        }
    }
}

// MARK: - Plateau warnings (Pro, computed locally): flat despite regular training

struct PlateauCard: View {
    let trends: [ProgressTrend]
    @EnvironmentObject var store: AppStore

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.gymWarning)
                    Text(store.t("insights.plateau.title"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.gymText)
                }
                ForEach(trends.prefix(3)) { trend in
                    Text(store.t("coach.plateau.message", trend.exercise))
                        .font(.system(size: 14))
                        .secondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Training heatmap (free): last 26 weeks, color by volume

struct YearHeatmapCard: View {
    let entries: [WorkoutEntry]
    @EnvironmentObject var store: AppStore

    private static let weeks = 26

    private var dayVolumes: [Date: Double] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        guard let start = calendar.date(byAdding: .weekOfYear, value: -(Self.weeks - 1), to: thisWeekStart) else { return [:] }
        var volumes: [Date: Double] = [:]
        for entry in entries where entry.date >= start {
            let day = calendar.startOfDay(for: entry.date)
            volumes[day, default: 0] += entry.weight * Double(entry.reps)
        }
        return volumes
    }

    private var columns: [[Date]] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<Self.weeks).compactMap { week in
            calendar.date(byAdding: .weekOfYear, value: -(Self.weeks - 1 - week), to: thisWeekStart)
                .map { weekStart in (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }
        }
    }

    var body: some View {
        let volumes = dayVolumes
        let maxVolume = volumes.values.max() ?? 1
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("insights.heatmap.title"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.gymText)
                HStack(spacing: 3) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, days in
                        VStack(spacing: 3) {
                            ForEach(days, id: \.self) { day in
                                let ratio = (volumes[day] ?? 0) / maxVolume
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(ratio <= 0 ? Color.gymSurfaceRaised
                                        : Color.gymAccent.opacity(0.25 + 0.75 * min(ratio * 1.5, 1)))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Monthly recap share card (Pro design), rendered to an image

struct MonthRecapShareCard: View {
    let monthText: String
    let sessionsText: String
    let volumeText: String
    let topLiftText: String
    let sessionsLabel: String
    let volumeLabel: String
    let topLiftLabel: String

    var body: some View {
        ZStack {
            Color(hex: "0E0E10")

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                    Text(monthText.uppercased())
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(1.4)
                }
                .foregroundColor(Color(hex: "FF5B2E"))

                Spacer()

                recapRow(value: sessionsText, label: sessionsLabel)
                recapRow(value: volumeText, label: volumeLabel)
                recapRow(value: topLiftText, label: topLiftLabel)

                Spacer()

                Rectangle().fill(Color(hex: "2E2E33")).frame(height: 1)

                HStack {
                    Text("GYMNIO")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(Color(hex: "F2F0EB"))
                    Spacer()
                }
                .padding(.top, 14)
            }
            .padding(28)
        }
        .frame(width: 360, height: 450)
    }

    private func recapRow(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .heavy).monospacedDigit())
                .foregroundColor(Color(hex: "F2F0EB"))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Color(hex: "9A978F"))
        }
        .padding(.vertical, 6)
    }

    @MainActor
    static func render(_ card: MonthRecapShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}

struct MonthRecapShareButton: View {
    let entries: [WorkoutEntry]
    @EnvironmentObject var store: AppStore
    @State private var image: UIImage?

    private var monthEntries: [WorkoutEntry] {
        let calendar = Calendar.current
        let now = Date()
        return entries.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    private func volume(of sets: [WorkoutEntry]) -> Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private func topLift(in sets: [WorkoutEntry]) -> String {
        var bestName = ""
        var bestVolume = 0.0
        for (name, group) in Dictionary(grouping: sets, by: { $0.exercise }) {
            let vol = volume(of: group)
            if vol > bestVolume {
                bestVolume = vol
                bestName = name
            }
        }
        return bestName
    }

    private var shareLabel: some View {
        Label(store.t("insights.recap.share"), systemImage: "square.and.arrow.up")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Color.gymAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview(store.t("insights.recap.share"), image: Image(uiImage: image))) {
                    shareLabel
                }
                .simultaneousGesture(TapGesture().onEnded {
                    PostHogSDK.shared.capture("month_recap_share_tapped")
                })
            } else {
                // Placeholder: an empty Group may never run .task, so the button
                // would never render. This swaps for the ShareLink once ready.
                shareLabel.opacity(0.4)
            }
        }
        .task(id: monthEntries.count) {
            let calendar = Calendar.current
            let monthEntries = monthEntries
            guard !monthEntries.isEmpty else { return }
            let monthText: String = {
                let f = DateFormatter()
                f.locale = store.locale
                f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
                return f.string(from: Date())
            }()
            let sessions = Set(monthEntries.compactMap { $0.workoutId }).count
            let volume = volume(of: monthEntries)
            let topLift = topLift(in: monthEntries)
            let card = MonthRecapShareCard(
                monthText: monthText,
                sessionsText: "\(sessions)",
                volumeText: "\(formatWeightValue(store.displayWeight(volume).rounded())) \(store.unitLabel)",
                topLiftText: topLift,
                sessionsLabel: store.t("insights.recap.sessions"),
                volumeLabel: store.t("summary.volume"),
                topLiftLabel: store.t("insights.recap.topLift"))
            image = MonthRecapShareCard.render(card)
        }
    }
}
