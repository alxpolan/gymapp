import Foundation

/// Sample numbers shown (blurred) behind the Pro lock while a free user has no data of their own yet.
enum ProDemoData {

    static func groups() -> [ExerciseGroup] {
        let calendar = Calendar.current
        let weights: [Double] = [60, 62.5, 62.5, 65, 67.5, 67.5, 70, 72.5]
        let reps = [8, 8, 9, 8, 8, 9, 8, 8]
        let entries = weights.indices.map { i -> WorkoutEntry in
            let date = calendar.date(byAdding: .day, value: -7 * (weights.count - 1 - i), to: Date()) ?? Date()
            return WorkoutEntry.create(exercise: "Bench Press", weight: weights[i], reps: reps[i], date: date)
        }
        return [ExerciseGroup(exercise: "Bench Press", entries: entries)]
    }

    static let records: [PersonalRecord] = [
        PersonalRecord(exercise: "Squat", maxWeight: 120, maxReps: 10, bestOneRepMax: 142, bestSetVolume: 1080, bestOneRepMaxDate: Date()),
        PersonalRecord(exercise: "Bench Press", maxWeight: 82.5, maxReps: 12, bestOneRepMax: 98, bestSetVolume: 800, bestOneRepMaxDate: Date()),
        PersonalRecord(exercise: "Deadlift", maxWeight: 150, maxReps: 6, bestOneRepMax: 176, bestSetVolume: 900, bestOneRepMaxDate: Date())
    ]

    static let muscles: [MuscleVolume] = [
        MuscleVolume(group: .legs, volume: 9200, share: 0.34, setCount: 24),
        MuscleVolume(group: .chest, volume: 6800, share: 0.25, setCount: 18),
        MuscleVolume(group: .back, volume: 6100, share: 0.22, setCount: 20),
        MuscleVolume(group: .shoulders, volume: 3100, share: 0.11, setCount: 12),
        MuscleVolume(group: .arms, volume: 2000, share: 0.08, setCount: 10)
    ]

    static let trends: [ProgressTrend] = [
        ProgressTrend(exercise: "Squat", weeklyChangeKg: 1.8, category: .improving, latestOneRepMax: 142),
        ProgressTrend(exercise: "Bench Press", weeklyChangeKg: 0.9, category: .improving, latestOneRepMax: 98),
        ProgressTrend(exercise: "Overhead Press", weeklyChangeKg: 0, category: .steady, latestOneRepMax: 64)
    ]
}
