import Foundation

enum Analytics {

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
