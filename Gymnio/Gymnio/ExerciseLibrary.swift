import Foundation

/// An exercise without a demo video: the name, where it trains and how it is logged.
struct LibraryExercise: Identifiable {
    let name: String
    let muscle: MuscleGroup
    let type: ExerciseType
    var id: String { name }
}

/// Common exercises so nobody has to type them. Videos exist only for `ExerciseCatalog.all`.
enum ExerciseLibrary {
    static let all: [LibraryExercise] = [
        LibraryExercise(name: "Incline Bench Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Decline Bench Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Dumbbell Bench Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Incline Barbell Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Machine Fly", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Pec Deck", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Cable Fly", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Low Cable Fly", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Landmine Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Chest Dip", muscle: .chest, type: .bodyweightReps),
        LibraryExercise(name: "Smith Machine Bench Press", muscle: .chest, type: .weightReps),
        LibraryExercise(name: "Decline Push-Ups", muscle: .chest, type: .bodyweightReps),
        LibraryExercise(name: "Incline Push-Ups", muscle: .chest, type: .bodyweightReps),
        LibraryExercise(name: "Diamond Push-Ups", muscle: .chest, type: .bodyweightReps),
        LibraryExercise(name: "Deadlift", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Barbell Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Pendlay Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Dumbbell Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Seated Cable Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "T-Bar Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Lat Pulldown", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Close-Grip Lat Pulldown", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Pull-Ups", muscle: .back, type: .bodyweightReps),
        LibraryExercise(name: "Chin-Ups", muscle: .back, type: .bodyweightReps),
        LibraryExercise(name: "Assisted Pull-Ups", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Straight-Arm Pulldown", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Face Pull", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Rack Pull", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Chest-Supported Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Hyperextension", muscle: .back, type: .bodyweightReps),
        LibraryExercise(name: "Shrugs", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Machine Row", muscle: .back, type: .weightReps),
        LibraryExercise(name: "Front Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Goblet Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Hack Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Smith Machine Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Box Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Pause Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Stiff-Leg Deadlift", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Single-Leg Romanian Deadlift", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Seated Leg Curl", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Standing Leg Curl", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Walking Lunges", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Reverse Lunges", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Glute Bridge", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Barbell Hip Thrust", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Cable Kickback", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Hip Abduction Machine", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Hip Adduction Machine", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Sissy Squat", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Nordic Curl", muscle: .legs, type: .bodyweightReps),
        LibraryExercise(name: "Donkey Calf Raise", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Calf Press", muscle: .legs, type: .weightReps),
        LibraryExercise(name: "Wall Sit", muscle: .legs, type: .duration),
        LibraryExercise(name: "Overhead Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Seated Dumbbell Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Arnold Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Machine Shoulder Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Lateral Raise", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Cable Lateral Raise", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Front Raise", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Rear Delt Fly", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Reverse Pec Deck", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Upright Row", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Push Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Landmine Shoulder Press", muscle: .shoulders, type: .weightReps),
        LibraryExercise(name: "Barbell Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Dumbbell Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Hammer Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Incline Dumbbell Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Preacher Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Cable Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Concentration Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Spider Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Tricep Pushdown", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Rope Pushdown", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Skull Crushers", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Overhead Tricep Extension", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Close-Grip Bench Press", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Tricep Kickback", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Bench Dips", muscle: .arms, type: .bodyweightReps),
        LibraryExercise(name: "Wrist Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Reverse Curl", muscle: .arms, type: .weightReps),
        LibraryExercise(name: "Plank", muscle: .core, type: .duration),
        LibraryExercise(name: "Side Plank", muscle: .core, type: .duration),
        LibraryExercise(name: "Crunches", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Cable Crunch", muscle: .core, type: .weightReps),
        LibraryExercise(name: "Hanging Leg Raise", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Hanging Knee Raise", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Sit-Ups", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Russian Twist", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Ab Wheel Rollout", muscle: .core, type: .weightReps),
        LibraryExercise(name: "Mountain Climbers", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Bicycle Crunch", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Dead Bug", muscle: .core, type: .bodyweightReps),
        LibraryExercise(name: "Pallof Press", muscle: .core, type: .weightReps),
        LibraryExercise(name: "Woodchopper", muscle: .core, type: .weightReps),
        LibraryExercise(name: "Hollow Hold", muscle: .core, type: .duration),
        LibraryExercise(name: "Dragon Flag", muscle: .core, type: .bodyweightReps),
    ]

    private static let byName: [String: LibraryExercise] = Dictionary(all.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

    static func entry(for name: String) -> LibraryExercise? { byName[name.lowercased()] }

    /// Everything the picker can offer: catalog exercises with video first, then the text-only library.
    static func suggestions() -> [String] {
        var seen = Set<String>()
        func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
        return (ExerciseCatalog.all.map { $0.displayName } + all.map { $0.name }).filter { seen.insert(key($0)).inserted }
    }
}
