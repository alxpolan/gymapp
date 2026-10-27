import Foundation

func formatWeightValue(_ value: Double) -> String {
    var s = String(format: "%.2f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

// MARK: - WorkoutEntry

struct WorkoutEntry: Codable, Identifiable, Equatable {
    var id: String
    var exercise: String
    var weight: Double
    var reps: Int
    var date: Date
    var createdAt: Date = Date()

    static func create(exercise: String, weight: Double, reps: Int, date: Date = Date()) -> WorkoutEntry {
        WorkoutEntry(id: UUID().uuidString, exercise: exercise, weight: weight, reps: reps, date: date, createdAt: Date())
    }

    enum CodingKeys: String, CodingKey { case id, exercise, weight, reps, date, createdAt }

    init(id: String, exercise: String, weight: Double, reps: Int, date: Date, createdAt: Date) {
        self.id = id
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
        self.date = date
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        exercise = try c.decode(String.self, forKey: .exercise)
        weight = try c.decode(Double.self, forKey: .weight)
        reps = try c.decode(Int.self, forKey: .reps)
        date = try c.decode(Date.self, forKey: .date)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
    }

    static func chronological(_ a: WorkoutEntry, _ b: WorkoutEntry) -> Bool {
        a.date != b.date ? a.date < b.date : a.createdAt < b.createdAt
    }

    static func reverseChronological(_ a: WorkoutEntry, _ b: WorkoutEntry) -> Bool {
        a.date != b.date ? a.date > b.date : a.createdAt > b.createdAt
    }
}

// MARK: - ExerciseGroup

struct ExerciseGroup: Identifiable {
    var id: String { exercise }
    var exercise: String
    var entries: [WorkoutEntry]

    var lastWeight: Double { entries.last?.weight ?? 0 }
    var lastReps: Int { entries.last?.reps ?? 0 }
    var lastDate: Date? { entries.last?.date }
    var totalVolume: Double { entries.reduce(0) { $0 + $1.weight * Double($1.reps) } }
}

// MARK: - HomeViewSettings

struct HomeViewSettings: Codable, Equatable {
    var showProgressionAlert: Bool = true
    var showStats: Bool = true
    var showCharts: Bool = true
    var showTopExercises: Bool = true
}

// MARK: - WorkoutStats

struct WorkoutStats {
    var totalWorkouts: Int
    var uniqueExercises: Int
    var totalVolumeKg: Double
    var mostFrequentExercise: String?
}

// MARK: - ProgressionAlert

struct ProgressionAlert: Identifiable {
    var id: String { exercise }
    var exercise: String
    var currentWeight: Double
}

// MARK: - ChartDataPoint

struct ChartDataPoint: Identifiable {
    var id = UUID()
    var index: Int
    var value: Double
    var label: String
}
