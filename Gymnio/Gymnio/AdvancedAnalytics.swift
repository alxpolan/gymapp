import Foundation

// MARK: - Advanced metric models

struct PersonalRecord: Identifiable {
    var id: String { exercise }
    let exercise: String
    let maxWeight: Double
    let maxReps: Int
    let bestOneRepMax: Double
    let bestSetVolume: Double
    let bestOneRepMaxDate: Date?
}

enum TrendCategory {
    case improving, steady, declining, new

    var systemImage: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .steady:    return "arrow.right"
        case .declining: return "arrow.down.right"
        case .new:       return "sparkles"
        }
    }

    var labelKey: String {
        switch self {
        case .improving: return "trend.improving"
        case .steady:    return "trend.steady"
        case .declining: return "trend.declining"
        case .new:       return "trend.new"
        }
    }
}

struct ProgressTrend: Identifiable {
    var id: String { exercise }
    let exercise: String
    let weeklyChangeKg: Double
    let category: TrendCategory
    let latestOneRepMax: Double
}

struct MuscleVolume: Identifiable {
    var id: String { group.rawValue }
    let group: MuscleGroup
    let volume: Double
    let share: Double
    let setCount: Int
}

struct VolumePoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
    let label: String
    let weekStart: Date
}

struct StreakInfo {
    let currentWeekStreak: Int
    let longestWeekStreak: Int
    let activeDays: Int
    let sessionsThisWeek: Int
    let weeklyAverage: Double
    let consistency: Double
}

enum AdvancedAnalytics {

    // MARK: - Estimated 1RM (Epley)

    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        if reps == 1 { return weight }
        let r = Double(min(reps, 20))
        return weight * (1 + r / 30.0)
    }

    static func bestOneRepMax(entries: [WorkoutEntry]) -> Double {
        entries.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }

    static func oneRepMaxSeries(entries: [WorkoutEntry], limit: Int = 12) -> [ChartDataPoint] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        let sortedDays = byDay.keys.sorted()
        let points = sortedDays.map { day -> (Date, Double) in
            let best = byDay[day]!.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return (day, best)
        }
        return points.suffix(limit).enumerated().map { idx, pair in
            ChartDataPoint(index: idx, value: pair.1, label: shortDate(pair.0))
        }
    }

    // MARK: - Personal records

    static func personalRecord(for group: ExerciseGroup) -> PersonalRecord? {
        guard !group.entries.isEmpty else { return nil }
        let maxWeight = group.entries.map { $0.weight }.max() ?? 0
        let maxReps = group.entries.map { $0.reps }.max() ?? 0
        let bestSetVolume = group.entries.map { $0.weight * Double($0.reps) }.max() ?? 0
        let best1RMEntry = group.entries.max {
            estimatedOneRepMax(weight: $0.weight, reps: $0.reps)
                < estimatedOneRepMax(weight: $1.weight, reps: $1.reps)
        }
        let best1RM = best1RMEntry.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) } ?? 0
        return PersonalRecord(
            exercise: group.exercise,
            maxWeight: maxWeight,
            maxReps: maxReps,
            bestOneRepMax: best1RM,
            bestSetVolume: bestSetVolume,
            bestOneRepMaxDate: best1RMEntry?.date
        )
    }

    static func recordsBoard(groups: [ExerciseGroup]) -> [PersonalRecord] {
        groups.compactMap(personalRecord(for:))
            .sorted { $0.bestOneRepMax > $1.bestOneRepMax }
    }

    // MARK: - Progressive-overload trend

    static func progressTrend(for group: ExerciseGroup) -> ProgressTrend {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: group.entries) { cal.startOfDay(for: $0.date) }
        let days = byDay.keys.sorted()
        let latest = days.last.flatMap { d in
            byDay[d]!.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max()
        } ?? 0

        guard days.count >= 3, let first = days.first else {
            return ProgressTrend(exercise: group.exercise, weeklyChangeKg: 0, category: .new, latestOneRepMax: latest)
        }

        let samples: [(x: Double, y: Double)] = days.map { day in
            let x = Double(cal.dateComponents([.day], from: first, to: day).day ?? 0)
            let y = byDay[day]!.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return (x, y)
        }
        let n = Double(samples.count)
        let sumX = samples.reduce(0) { $0 + $1.x }
        let sumY = samples.reduce(0) { $0 + $1.y }
        let sumXY = samples.reduce(0) { $0 + $1.x * $1.y }
        let sumX2 = samples.reduce(0) { $0 + $1.x * $1.x }
        let denom = n * sumX2 - sumX * sumX
        let slopePerDay = denom == 0 ? 0 : (n * sumXY - sumX * sumY) / denom
        let weekly = slopePerDay * 7

        let category: TrendCategory
        if weekly > 0.25 { category = .improving }
        else if weekly < -0.25 { category = .declining }
        else { category = .steady }

        return ProgressTrend(exercise: group.exercise, weeklyChangeKg: weekly, category: category, latestOneRepMax: latest)
    }

    static func progressTrends(groups: [ExerciseGroup]) -> [ProgressTrend] {
        groups.filter { !$0.entries.isEmpty }
            .map(progressTrend(for:))
            .sorted { $0.latestOneRepMax > $1.latestOneRepMax }
    }

    // MARK: - Muscle-group distribution

    static func muscleDistribution(groups: [ExerciseGroup]) -> [MuscleVolume] {
        var volumeByGroup: [MuscleGroup: Double] = [:]
        var setsByGroup: [MuscleGroup: Int] = [:]
        for group in groups {
            let mg = MuscleGroup.classify(group.exercise)
            volumeByGroup[mg, default: 0] += group.totalVolume
            setsByGroup[mg, default: 0] += group.entries.count
        }
        let total = volumeByGroup.values.reduce(0, +)
        guard total > 0 else { return [] }
        return volumeByGroup.map { mg, vol in
            MuscleVolume(group: mg, volume: vol, share: vol / total, setCount: setsByGroup[mg] ?? 0)
        }
        .sorted { $0.volume > $1.volume }
    }

    // MARK: - Weekly volume

    static func weeklyVolume(entries: [WorkoutEntry], weeks: Int = 8) -> [VolumePoint] {
        guard !entries.isEmpty else { return [] }
        var cal = Calendar.current
        cal.firstWeekday = 2
        let now = Date()
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var points: [VolumePoint] = []
        for i in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -i, to: thisWeekStart),
                  let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { continue }
            let vol = entries
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            points.append(VolumePoint(index: weeks - 1 - i, value: vol, label: shortDate(weekStart), weekStart: weekStart))
        }
        return points
    }

    // MARK: - Streaks & consistency

    static func streakInfo(entries: [WorkoutEntry]) -> StreakInfo {
        guard !entries.isEmpty else {
            return StreakInfo(currentWeekStreak: 0, longestWeekStreak: 0, activeDays: 0,
                              sessionsThisWeek: 0, weeklyAverage: 0, consistency: 0)
        }
        var cal = Calendar.current
        cal.firstWeekday = 2

        let activeDays = Set(entries.map { cal.startOfDay(for: $0.date) }).count

        let weekStarts = Set(entries.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        let now = Date()
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        var current = 0
        var cursor = thisWeekStart
        while weekStarts.contains(cursor) {
            current += 1
            cursor = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }

        let sortedWeeks = weekStarts.sorted()
        var longest = 0, run = 0
        var prev: Date?
        for w in sortedWeeks {
            if let p = prev, let next = cal.date(byAdding: .weekOfYear, value: 1, to: p), next == w {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = w
        }

        let sessionsThisWeek = Set(entries
            .filter { cal.dateInterval(of: .weekOfYear, for: $0.date)?.start == thisWeekStart }
            .map { cal.startOfDay(for: $0.date) }).count

        let spanWeeks = max(sortedWeeks.count, 1)
        let totalSessions = Set(entries.map { cal.startOfDay(for: $0.date) }).count
        let weeklyAverage = Double(totalSessions) / Double(spanWeeks)

        var activeInWindow = 0
        for i in 0..<8 {
            if let w = cal.date(byAdding: .weekOfYear, value: -i, to: thisWeekStart), weekStarts.contains(w) {
                activeInWindow += 1
            }
        }
        let consistency = Double(activeInWindow) / 8.0

        return StreakInfo(currentWeekStreak: current, longestWeekStreak: longest, activeDays: activeDays,
                          sessionsThisWeek: sessionsThisWeek, weeklyAverage: weeklyAverage, consistency: consistency)
    }

    // MARK: - Helpers

    private static func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM"
        return fmt.string(from: date)
    }
}
