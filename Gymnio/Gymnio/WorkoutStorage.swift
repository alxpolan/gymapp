import Foundation

final class WorkoutStorage {
    static let shared = WorkoutStorage()
    private init() {}

    private let entriesKey = "gym_logbook_entries"
    private let exercisesKey = "gym_logbook_exercises"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Exercises

    func getExercises() -> [String] {
        guard let data = defaults.data(forKey: exercisesKey),
              let list = try? decoder.decode([String].self, from: data) else { return [] }
        return list
    }

    func addExercise(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = getExercises()
        guard !list.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        list.append(trimmed)
        list.sort()
        save(exercises: list)
    }

    func resetAll() {
        defaults.removeObject(forKey: entriesKey)
        defaults.removeObject(forKey: exercisesKey)
    }

    func deleteExercise(_ name: String) {
        var list = getExercises()
        list.removeAll { $0.lowercased() == name.lowercased() }
        save(exercises: list)
        var entries = getAllEntries()
        entries.removeAll { $0.exercise.lowercased() == name.lowercased() }
        save(entries: entries)
    }

    func renameExercise(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.lowercased() != oldName.lowercased() else { return }
        var list = getExercises()
        guard !list.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        if let idx = list.firstIndex(where: { $0.lowercased() == oldName.lowercased() }) {
            list[idx] = trimmed
        } else {
            list.append(trimmed)
        }
        list.sort()
        save(exercises: list)

        var entries = getAllEntries()
        for i in entries.indices where entries[i].exercise.lowercased() == oldName.lowercased() {
            entries[i].exercise = trimmed
        }
        save(entries: entries)
    }

    private func save(exercises: [String]) {
        if let data = try? encoder.encode(exercises) { defaults.set(data, forKey: exercisesKey) }
    }

    // MARK: - Entries

    func getAllEntries() -> [WorkoutEntry] {
        guard let data = defaults.data(forKey: entriesKey),
              let entries = try? decoder.decode([WorkoutEntry].self, from: data) else { return [] }
        return entries
    }

    func saveEntry(_ entry: WorkoutEntry) {
        var entries = getAllEntries()
        entries.append(entry)
        save(entries: entries)
    }

    func updateEntry(_ entry: WorkoutEntry) {
        var entries = getAllEntries()
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        save(entries: entries)
    }

    func deleteEntry(id: String) {
        var entries = getAllEntries()
        entries.removeAll { $0.id == id }
        save(entries: entries)
    }

    private func save(entries: [WorkoutEntry]) {
        if let data = try? encoder.encode(entries) { defaults.set(data, forKey: entriesKey) }
    }

    // MARK: - Grouped

    func groupByExercise() -> [ExerciseGroup] {
        let entries = getAllEntries()
        let exercises = getExercises()
        var grouped: [String: [WorkoutEntry]] = [:]
        for e in entries { grouped[e.exercise, default: []].append(e) }
        return exercises.map { ex in
            let sorted = (grouped[ex] ?? []).sorted(by: { WorkoutEntry.chronological($0, $1) })
            return ExerciseGroup(exercise: ex, entries: sorted)
        }
    }
}
