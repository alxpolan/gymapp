import Foundation

func formatWeightValue(_ value: Double) -> String {
    var s = String(format: "%.2f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

// MARK: - Set type

enum SetKind: String, Codable, CaseIterable {
    case warmup, drop, failure

    var titleKey: String { "setkind.\(rawValue)" }
    var letter: String {
        switch self { case .warmup: return "W"; case .drop: return "D"; case .failure: return "F" }
    }
}

// MARK: - WorkoutEntry

struct WorkoutEntry: Codable, Identifiable, Equatable {
    var id: String
    var exercise: String
    var weight: Double
    var reps: Int
    var date: Date
    var createdAt: Date = Date()
    /// The training this set belongs to. Older entries have none and are grouped by day (see `Workout.group`).
    var workoutId: String?
    /// nil = normal working set.
    var kind: SetKind?
    /// Rate of perceived exertion (6–10), optional.
    var rpe: Double?

    var isWarmup: Bool { kind == .warmup }

    static func create(exercise: String, weight: Double, reps: Int, date: Date = Date(), workoutId: String? = nil,
                       kind: SetKind? = nil, rpe: Double? = nil) -> WorkoutEntry {
        WorkoutEntry(id: UUID().uuidString, exercise: exercise, weight: weight, reps: reps, date: date, createdAt: Date(),
                     workoutId: workoutId, kind: kind, rpe: rpe)
    }

    enum CodingKeys: String, CodingKey { case id, exercise, weight, reps, date, createdAt, workoutId, kind, rpe }

    init(id: String, exercise: String, weight: Double, reps: Int, date: Date, createdAt: Date, workoutId: String? = nil,
         kind: SetKind? = nil, rpe: Double? = nil) {
        self.kind = kind
        self.rpe = rpe
        self.id = id
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
        self.date = date
        self.createdAt = createdAt
        self.workoutId = workoutId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        exercise = try c.decode(String.self, forKey: .exercise)
        weight = try c.decode(Double.self, forKey: .weight)
        reps = try c.decode(Int.self, forKey: .reps)
        date = try c.decode(Date.self, forKey: .date)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        workoutId = try c.decodeIfPresent(String.self, forKey: .workoutId)
        kind = try c.decodeIfPresent(SetKind.self, forKey: .kind)
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
    }

    static func chronological(_ a: WorkoutEntry, _ b: WorkoutEntry) -> Bool {
        a.date != b.date ? a.date < b.date : a.createdAt < b.createdAt
    }

    static func reverseChronological(_ a: WorkoutEntry, _ b: WorkoutEntry) -> Bool {
        a.date != b.date ? a.date > b.date : a.createdAt > b.createdAt
    }
}

// MARK: - Workout (one training session)

struct Workout: Identifiable {
    let id: String
    /// Chronological.
    let entries: [WorkoutEntry]

    var start: Date { entries.map { $0.date }.min() ?? Date() }
    var end: Date { entries.map { $0.date }.max() ?? start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// Working sets only: warm-ups do not count towards sets, volume or records.
    var workingEntries: [WorkoutEntry] { entries.filter { !$0.isWarmup } }
    var setCount: Int { workingEntries.count }
    var volumeKg: Double { workingEntries.reduce(0) { $0 + $1.weight * Double($1.reps) } }
    /// Exercise names in the order they were first trained.
    var exercises: [String] {
        var seen = Set<String>()
        return entries.compactMap { seen.insert($0.exercise).inserted ? $0.exercise : nil }
    }

    func sets(for exercise: String) -> [WorkoutEntry] { entries.filter { $0.exercise == exercise } }

    /// Groups entries into workouts: by `workoutId`, and older entries without one by calendar day. Newest first.
    static func group(_ entries: [WorkoutEntry], calendar: Calendar = .current) -> [Workout] {
        var buckets: [String: [WorkoutEntry]] = [:]
        for entry in entries {
            let day = Int(calendar.startOfDay(for: entry.date).timeIntervalSince1970)
            buckets[entry.workoutId ?? "day-\(day)", default: []].append(entry)
        }
        return buckets
            .map { Workout(id: $0.key, entries: $0.value.sorted(by: { WorkoutEntry.chronological($0, $1) })) }
            .sorted(by: { $0.start > $1.start })
    }
}

/// The training that is currently being logged (survives an app restart).
struct ActiveWorkout: Codable, Equatable {
    var id: String
    var startedAt: Date
    /// Exercise names in the order they were added.
    var exercises: [String]
    var note: String?
    /// Target number of sets per exercise when started from a routine.
    var plannedSets: [String: Int] = [:]
    /// Exercises that form a superset with the exercise right after them.
    var linkedToNext: [String] = []

    init(id: String, startedAt: Date, exercises: [String]) {
        self.id = id
        self.startedAt = startedAt
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        exercises = try c.decode([String].self, forKey: .exercises)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        plannedSets = try c.decodeIfPresent([String: Int].self, forKey: .plannedSets) ?? [:]
        linkedToNext = try c.decodeIfPresent([String].self, forKey: .linkedToNext) ?? []
    }

    enum CodingKeys: String, CodingKey { case id, startedAt, exercises, note, plannedSets, linkedToNext }
}

// MARK: - Exercise details set by the user

/// How an exercise is logged. Duration exercises store seconds in `reps`.
enum ExerciseType: String, Codable, CaseIterable {
    case weightReps, bodyweightReps, duration

    var titleKey: String { "extype.\(rawValue)" }
    var usesWeight: Bool { self == .weightReps }
}

struct ExerciseMeta: Codable, Equatable {
    /// `ExerciseType.rawValue`; nil = guessed from the name.
    var type: String?
    /// Rest timer for this exercise in seconds; nil = global setting.
    var restSeconds: Int?
    /// `MuscleGroup.rawValue`; nil = guessed from the name.
    var muscle: String?
    /// File name inside the photos folder.
    var photo: String?
}

// MARK: - Routine (reusable workout template)

struct RoutineExercise: Codable, Equatable, Identifiable {
    var name: String
    var sets: Int
    var id: String { name }
}

struct Routine: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var exercises: [RoutineExercise]
    var createdAt: Date = Date()
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

// MARK: - ChartDataPoint

struct ChartDataPoint: Identifiable {
    var id = UUID()
    var index: Int
    var value: Double
    var label: String
}
