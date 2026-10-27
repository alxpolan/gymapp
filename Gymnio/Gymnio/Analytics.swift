import Foundation

enum Analytics {

    // MARK: - Stats

    static func workoutStats(entries: [WorkoutEntry]) -> WorkoutStats {
        let totalVolume = entries.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        let unique = Set(entries.map { $0.exercise })
        let freq = Dictionary(grouping: entries, by: { $0.exercise })
            .max(by: { $0.value.count < $1.value.count })?.key
        return WorkoutStats(
            totalWorkouts: entries.count,
            uniqueExercises: unique.count,
            totalVolumeKg: totalVolume,
            mostFrequentExercise: freq
        )
    }

    // MARK: - Progression alerts

    static func progressionAlerts(groups: [ExerciseGroup]) -> [ProgressionAlert] {
        groups.compactMap { group in
            let sorted = group.entries.sorted(by: WorkoutEntry.chronological)
            guard sorted.count >= 5 else { return nil }
            let last5 = sorted.suffix(5)
            let weight = last5.first!.weight
            guard last5.allSatisfy({ $0.weight == weight }) else { return nil }
            return ProgressionAlert(exercise: group.exercise, currentWeight: weight)
        }
    }

    // MARK: - Top exercises by volume

    static func topExercisesByVolume(groups: [ExerciseGroup], limit: Int = 5) -> [ExerciseGroup] {
        groups.sorted { $0.totalVolume > $1.totalVolume }.prefix(limit).map { $0 }
    }

    // MARK: - Chart data

    static func weightChartData(entries: [WorkoutEntry], limit: Int = 10) -> [ChartDataPoint] {
        let recent = entries.suffix(limit)
        return recent.enumerated().map { idx, e in
            ChartDataPoint(index: idx, value: e.weight, label: shortDate(e.date))
        }
    }

    static func repsChartData(entries: [WorkoutEntry], limit: Int = 10) -> [ChartDataPoint] {
        let recent = entries.suffix(limit)
        return recent.enumerated().map { idx, e in
            ChartDataPoint(index: idx, value: Double(e.reps), label: shortDate(e.date))
        }
    }

    static func volumeChartData(entries: [WorkoutEntry], limit: Int = 10) -> [ChartDataPoint] {
        let recent = entries.suffix(limit)
        return recent.enumerated().map { idx, e in
            ChartDataPoint(index: idx, value: e.weight * Double(e.reps), label: shortDate(e.date))
        }
    }

    // MARK: - Helpers

    private static func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM"
        return fmt.string(from: date)
    }
}
