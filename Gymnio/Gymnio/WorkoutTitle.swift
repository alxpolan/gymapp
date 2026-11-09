import Foundation
import SwiftUI

/// Strava-style auto-generated names ("Morning Weight Training", "Evening HIIT") for finished workouts.
/// Purely derived from the workout's start time and exercise mix, so it can always be recomputed —
/// only a user-chosen rename needs to be persisted (see `AppStore.workoutTitles`).
enum WorkoutTitle {

    enum TimeOfDay: String {
        case morning, afternoon, evening, night
        var key: String { "autotitle.time.\(rawValue)" }

        static func of(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
            switch calendar.component(.hour, from: date) {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }

    enum Kind: String {
        case strength, hiit, legDay = "legday", upper, fullBody = "fullbody"
        var key: String { "autotitle.type.\(rawValue)" }

        static func of(_ workout: Workout, store: AppStore) -> Kind {
            let working = workout.workingEntries
            guard !working.isEmpty else { return .strength }

            let durationCount = working.filter { store.exerciseType(for: $0.exercise) == .duration }.count
            if Double(durationCount) / Double(working.count) >= 0.5 { return .hiit }

            var counts: [MuscleGroup: Int] = [:]
            for entry in working {
                let group = MuscleGroup.classify(entry.exercise)
                guard group != .other else { continue }
                counts[group, default: 0] += 1
            }
            let total = counts.values.reduce(0, +)
            guard total > 0 else { return .strength }

            let legs = counts[.legs] ?? 0
            if Double(legs) / Double(total) > 0.5 { return .legDay }

            let upperGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .arms]
            let upperCount = upperGroups.reduce(0) { $0 + (counts[$1] ?? 0) }
            if Double(upperCount) / Double(total) >= 0.6 { return .upper }

            if counts.keys.count >= 3 { return .fullBody }
            return .strength
        }
    }

    /// The default title for a finished workout, before any user rename.
    static func generate(for workout: Workout, store: AppStore) -> String {
        let time = store.t(TimeOfDay.of(workout.start).key)
        let type = store.t(Kind.of(workout, store: store).key)
        return store.t("autotitle.format", time, type)
    }
}

/// The workout's title (generated or renamed), tap to rename in place.
struct EditableWorkoutTitle: View {
    let workout: Workout
    var font: Font = .system(size: 26, weight: .heavy)

    @EnvironmentObject var store: AppStore
    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        if isEditing {
            TextField(store.title(for: workout), text: $text)
                .font(font)
                .foregroundColor(.gymText)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onAppear { focused = true }
        } else {
            Button {
                text = store.title(for: workout)
                isEditing = true
            } label: {
                HStack(spacing: 8) {
                    Text(store.title(for: workout))
                        .font(font)
                        .foregroundColor(.gymText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gymTextSecondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func commit() {
        store.renameWorkout(workout, to: text)
        isEditing = false
    }
}
