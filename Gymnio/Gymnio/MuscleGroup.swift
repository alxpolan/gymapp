import SwiftUI

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, other

    var id: String { rawValue }

    var titleKey: String { "muscle.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .chest:     return SymbolCompat.strength
        case .back:      return "figure.rower"
        case .legs:      return "figure.walk"
        case .shoulders: return "figure.arms.open"
        case .arms:      return "dumbbell.fill"
        case .core:      return "figure.core.training"
        case .other:     return "figure.mixed.cardio"
        }
    }

    var color: Color {
        switch self {
        case .chest:     return Color(hex: "FF6B6B")
        case .back:      return Color(hex: "4ECDC4")
        case .legs:      return Color(hex: "5B8DEF")
        case .shoulders: return Color(hex: "FFB020")
        case .arms:      return Color(hex: "A06BFF")
        case .core:      return Color(hex: "34C759")
        case .other:     return Color(hex: "98989F")
        }
    }

    private var keywords: [String] {
        switch self {
        case .chest:
            return ["bench", "chest", "pec", "fly", "press up", "push-up", "pushup", "dip",
                    "bank", "brust", "drücken", "fliegende", "liegestütz"]
        case .back:
            return ["row", "pull", "lat", "deadlift", "back", "chin", "pulldown", "shrug",
                    "rudern", "kreuzheben", "klimmzug", "rücken", "latzug", "nacken"]
        case .legs:
            return ["squat", "leg", "lunge", "calf", "quad", "hamstring", "glute", "hip thrust",
                    "kniebeuge", "bein", "wade", "ausfallschritt", "beinpresse", "beinstrecker", "beinbeuger"]
        case .shoulders:
            return ["shoulder", "ohp", "overhead", "military", "lateral raise", "delt", "arnold",
                    "schulter", "seitheben", "nackendrücken", "frontheben"]
        case .arms:
            return ["curl", "bicep", "tricep", "arm", "hammer", "pushdown", "preacher", "skull",
                    "bizeps", "trizeps", "hantel curl"]
        case .core:
            return ["ab", "core", "plank", "crunch", "sit-up", "situp", "oblique", "leg raise",
                    "bauch", "planke", "unterarmstütz", "rumpf"]
        case .other:
            return []
        }
    }

    static func classify(_ exercise: String) -> MuscleGroup {
        let name = exercise.lowercased()
        for group in [MuscleGroup.legs, .back, .chest, .shoulders, .core, .arms] {
            if group.keywords.contains(where: { name.contains($0) }) {
                return group
            }
        }
        return .other
    }
}
