import Foundation
import SwiftUI
import Combine
import PostHog

final class AppStore: ObservableObject {
    static let shared = AppStore()

    private let storage = WorkoutStorage.shared
    private let defaults = UserDefaults.standard

    @Published var exercises: [String] = []
    @Published var entries: [WorkoutEntry] = []
    @Published var language: String = "en"
    @Published var languageOverride: String = "auto"
    @Published var themeMode: String = "system"
    @Published var weightUnit: String = "kg"
    @Published var showAddExercise: Bool = false
    @Published var forceMorningGreeting: Bool = false
    @Published var paywallRequest: PaywallRequest?
    @Published var showOnboarding: Bool = false
    @Published var restSeconds: Int = 90
    @Published var activeWorkout: ActiveWorkout?
    @Published var showActiveWorkout: Bool = false
    @Published var reviewPending: Bool = false
    @Published var routines: [Routine] = []
    @Published var weeklyGoal: Int = 3
    @Published var exerciseMeta: [String: ExerciseMeta] = [:]
    @Published var bodyWeights: [BodyWeightEntry] = []
    @Published var exerciseNotes: [String: String] = [:]
    var lastWorkoutDuration: TimeInterval = 0

    static let supportedLanguages = [
        "de", "en", "fr", "es", "it", "pt", "nl",
        "da", "sv", "nb", "fi", "is",
        "tr", "uk", "ru", "pl", "cs", "sk", "hu", "ro", "bg", "el",
        "hr", "sr", "sl", "et", "lv", "lt", "ca",
        "ja", "ko",
        "hi", "id", "vi", "th", "ar",
        "he", "zh-Hans", "zh-Hant", "ms", "fil", "bn"
    ]

    /// Languages written right to left.
    static let rightToLeftLanguages: Set<String> = ["ar", "he", "fa", "ur"]

    var layoutDirection: LayoutDirection { Self.rightToLeftLanguages.contains(language) ? .rightToLeft : .leftToRight }

    private let languageKey     = "@language_override"
    private let themeKey        = "@theme_mode"
    private let weightUnitKey   = "@weight_unit"
    private let restSecondsKey  = "@rest_seconds"
    private let activeWorkoutKey = "@active_workout"
    private let routinesKey     = "@routines"
    private let workoutRoutinesKey = "@workout_routines"
    private let freeSetsUsedKey = "@free_sets_used"
    private let weeklyGoalKey   = "@weekly_goal"
    private let exerciseMetaKey = "@exercise_meta"
    private let bodyWeightKey   = "@body_weights"
    private let exerciseNotesKey = "@exercise_notes"
    private let workoutNotesKey = "@workout_notes"
    private let onboardingKey   = "@onboarding_done"
    private let goalKey         = "@onboarding_goal"
    private let firstOpenKey    = "@first_open_at"
    private let firstExerciseKey = "@first_exercise_logged"
    private let firstEntryKey   = "@first_entry_logged"

    init() {
        configureForUITestsIfNeeded()
        loadAll()
    }

    // MARK: - Load

    func loadAll() {
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
        themeMode = defaults.string(forKey: themeKey) ?? "system"
        if let stored = defaults.string(forKey: weightUnitKey) {
            weightUnit = stored
        } else {
            weightUnit = Locale.current.measurementSystem == .us ? "lbs" : "kg"
        }
        if let stored = defaults.string(forKey: languageKey) {
            language = stored
            languageOverride = stored
        } else {
            let detected = deviceLanguage
            // Not stored: without a manual choice the app keeps following the device language.
            language = detected
            languageOverride = detected
        }
        activeWorkout = defaults.data(forKey: activeWorkoutKey).flatMap { try? JSONDecoder().decode(ActiveWorkout.self, from: $0) }
        routines = defaults.data(forKey: routinesKey).flatMap { try? JSONDecoder().decode([Routine].self, from: $0) } ?? []
        exerciseMeta = defaults.data(forKey: exerciseMetaKey).flatMap { try? JSONDecoder().decode([String: ExerciseMeta].self, from: $0) } ?? [:]
        if defaults.object(forKey: weeklyGoalKey) != nil { weeklyGoal = defaults.integer(forKey: weeklyGoalKey) }
        applyMuscleOverrides()
        bodyWeights = defaults.data(forKey: bodyWeightKey).flatMap { try? JSONDecoder().decode([BodyWeightEntry].self, from: $0) } ?? []
        exerciseNotes = defaults.data(forKey: exerciseNotesKey).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        if defaults.object(forKey: restSecondsKey) != nil {
            restSeconds = defaults.integer(forKey: restSecondsKey)
        }
        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: firstOpenKey)
        }
        // Existing users with data skip onboarding; UI tests never see it.
        let isUITest = ProcessInfo.processInfo.arguments.contains("-ui_testing")
        if !defaults.bool(forKey: onboardingKey) {
            if isUITest || !exercises.isEmpty || !entries.isEmpty {
                defaults.set(true, forKey: onboardingKey)
            } else {
                showOnboarding = true
                PostHogSDK.shared.capture("onboarding_started")
            }
        }
    }

    // MARK: - Analytics: person properties and return events

    /// Call when the app becomes active: refreshes PostHog person properties and fires D1/D7/D30 return events once.
    func trackSessionStart() {
        let days = daysSinceInstall
        PostHogSDK.shared.identify(PostHogSDK.shared.getDistinctId(), userProperties: [
            "entries_count": entries.count,
            "exercise_count": exercises.count,
            "is_pro": PremiumManager.shared.isPro,
            "days_since_install": days,
            "language": language,
            "weight_unit": weightUnit,
            "goal": goal
        ])
        for day in [1, 7, 30] where days == day {
            let key = "@retention_d\(day)_sent"
            guard !defaults.bool(forKey: key) else { continue }
            defaults.set(true, forKey: key)
            PostHogSDK.shared.capture("retention_d\(day)", properties: [
                "entries_count": entries.count,
                "is_pro": PremiumManager.shared.isPro
            ])
        }
    }

    private var daysSinceInstall: Int {
        let first = defaults.double(forKey: firstOpenKey)
        guard first > 0 else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: first))
        let today = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: start, to: today).day ?? 0
    }

    // MARK: - Onboarding

    var goal: String { defaults.string(forKey: goalKey) ?? "" }

    func completeOnboarding(goal: String, unit: String) {
        defaults.set(goal, forKey: goalKey)
        defaults.set(true, forKey: onboardingKey)
        setWeightUnit(unit)
        PostHogSDK.shared.register(["goal": goal])
        PostHogSDK.shared.capture("onboarding_completed", properties: [
            "goal": goal,
            "unit": unit,
            "time_since_install_s": secondsSinceInstall
        ])
        showOnboarding = false
    }

    private var secondsSinceInstall: Int {
        let first = defaults.double(forKey: firstOpenKey)
        return first > 0 ? max(Int(Date().timeIntervalSince1970 - first), 0) : 0
    }

    func reload() {
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
    }

    // MARK: - Language

    func t(_ key: String) -> String {
        let missing = "\u{1}"
        let value = NSLocalizedString(key, bundle: localizedBundle, value: missing, comment: "")
        guard value == missing else { return value }
        // Not translated in this language yet: fall back to English, then the key.
        let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init) ?? .main
        return NSLocalizedString(key, bundle: english, value: key, comment: "")
    }

    func setLanguageOverride(_ lang: String) {
        language = lang
        languageOverride = lang
        defaults.set(lang, forKey: languageKey)
    }

    private var localizedBundle: Bundle {
        Bundle.main.path(forResource: language, ofType: "lproj")
            .flatMap(Bundle.init) ?? .main
    }

    /// The first of the user's preferred languages that the app supports (English if none).
    private var deviceLanguage: String {
        for identifier in Locale.preferredLanguages {
            let language = Locale(identifier: identifier).language
            let raw = language.languageCode?.identifier ?? ""
            if raw == "zh" {
                let region = language.region?.identifier ?? ""
                let traditional = language.script?.identifier == "Hant" || ["TW", "HK", "MO"].contains(region)
                return traditional ? "zh-Hant" : "zh-Hans"
            }
            let code = ["no": "nb", "nn": "nb", "iw": "he", "tl": "fil"][raw] ?? raw
            if Self.supportedLanguages.contains(code) { return code }
        }
        return "en"
    }

    // MARK: - Exercises

    func addExercise(_ name: String, source: String = "manual") {
        storage.addExercise(name)
        exercises = storage.getExercises()
        PostHogSDK.shared.capture("exercise_added", properties: ["source": source])
        if !defaults.bool(forKey: firstExerciseKey) {
            defaults.set(true, forKey: firstExerciseKey)
            PostHogSDK.shared.capture("first_exercise_added", properties: [
                "source": source,
                "time_since_install_s": secondsSinceInstall
            ])
        }
    }

    func deleteExercise(_ name: String) {
        if exerciseMeta[name] != nil {
            setExerciseMeta(nil, photo: nil, for: name, removePhoto: true)
            exerciseMeta.removeValue(forKey: name)
            persistMeta()
        }
        storage.deleteExercise(name)
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
        PostHogSDK.shared.capture("exercise_deleted")
    }

    func renameExercise(_ oldName: String, to newName: String) {
        if let meta = exerciseMeta.removeValue(forKey: oldName) { exerciseMeta[newName] = meta; persistMeta() }
        if let note = exerciseNotes.removeValue(forKey: oldName) { setExerciseNote(note, for: newName) }
        storage.renameExercise(oldName, to: newName)
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
        PostHogSDK.shared.capture("exercise_renamed")
    }

    // MARK: - Own exercise details (muscle group, photo)

    private var photosFolder: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ExercisePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func muscleGroup(for exercise: String) -> MuscleGroup { MuscleGroup.classify(exercise) }

    func exerciseType(for exercise: String) -> ExerciseType {
        if let raw = exerciseMeta[exercise]?.type, let type = ExerciseType(rawValue: raw) { return type }
        return defaultExerciseType(for: exercise)
    }

    /// The type guessed from the name, used when the user did not choose one.
    func defaultExerciseType(for exercise: String) -> ExerciseType {
        if let known = ExerciseLibrary.entry(for: exercise) { return known.type }
        let name = exercise.lowercased()
        if ["plank", "hang", "hold", "wall sit", "planke"].contains(where: { name.contains($0) }) { return .duration }
        if ["push-up", "pushup", "pull-up", "pullup", "chin-up", "chinup", "sit-up", "situp", "liegestütz", "klimmzug"]
            .contains(where: { name.contains($0) }) { return .bodyweightReps }
        return .weightReps
    }

    /// "80 kg × 5", "12 reps" or "45 s", depending on how the exercise is logged.
    func setText(_ entry: WorkoutEntry) -> String {
        switch exerciseType(for: entry.exercise) {
        case .weightReps: return "\(formatWeightValue(displayWeight(entry.weight, for: entry.exercise))) \(unitLabel(for: entry.exercise)) × \(entry.reps)"
        case .bodyweightReps:
            return entry.weight > 0 ? "+\(formatWeightValue(displayWeight(entry.weight, for: entry.exercise))) \(unitLabel(for: entry.exercise)) × \(entry.reps)" : "\(entry.reps) \(t("common.reps"))"
        case .duration: return "\(entry.reps) s"
        }
    }

    /// Short form without unit for the "previous" column.
    func shortSetText(_ entry: WorkoutEntry) -> String {
        switch exerciseType(for: entry.exercise) {
        case .weightReps: return "\(formatWeightValue(displayWeight(entry.weight, for: entry.exercise))) × \(entry.reps)"
        case .bodyweightReps: return entry.weight > 0 ? "+\(formatWeightValue(displayWeight(entry.weight, for: entry.exercise))) × \(entry.reps)" : "\(entry.reps)"
        case .duration: return "\(entry.reps) s"
        }
    }

    func restDuration(for exercise: String) -> Int { exerciseMeta[exercise]?.restSeconds ?? restSeconds }

    func setExerciseType(_ type: ExerciseType?, rest: Int?, unit: String? = nil, for exercise: String) {
        var meta = exerciseMeta[exercise] ?? ExerciseMeta()
        meta.type = type?.rawValue
        meta.restSeconds = rest
        meta.unit = unit
        if meta.muscle == nil && meta.photo == nil && meta.type == nil && meta.restSeconds == nil && meta.unit == nil {
            exerciseMeta.removeValue(forKey: exercise)
        } else { exerciseMeta[exercise] = meta }
        persistMeta()
    }

    func photo(for exercise: String) -> UIImage? {
        guard let file = exerciseMeta[exercise]?.photo else { return nil }
        return UIImage(contentsOfFile: photosFolder.appendingPathComponent(file).path)
    }

    /// Saves the chosen muscle group and/or photo. `removePhoto` deletes the stored picture.
    func setExerciseMeta(_ muscle: MuscleGroup?, photo: UIImage?, for exercise: String, removePhoto: Bool = false) {
        var meta = exerciseMeta[exercise] ?? ExerciseMeta()
        meta.muscle = muscle?.rawValue
        if let photo, let data = Self.downscaled(photo).jpegData(compressionQuality: 0.8) {
            if let old = meta.photo { try? FileManager.default.removeItem(at: photosFolder.appendingPathComponent(old)) }
            let file = UUID().uuidString + ".jpg"
            try? data.write(to: photosFolder.appendingPathComponent(file))
            meta.photo = file
        } else if removePhoto, let old = meta.photo {
            try? FileManager.default.removeItem(at: photosFolder.appendingPathComponent(old))
            meta.photo = nil
        }
        if meta.muscle == nil && meta.photo == nil && meta.type == nil && meta.restSeconds == nil && meta.unit == nil { exerciseMeta.removeValue(forKey: exercise) } else { exerciseMeta[exercise] = meta }
        persistMeta()
    }

    private func persistMeta() {
        if let data = try? JSONEncoder().encode(exerciseMeta) { defaults.set(data, forKey: exerciseMetaKey) }
        applyMuscleOverrides()
    }

    private func applyMuscleOverrides() {
        MuscleGroup.overrides = exerciseMeta.reduce(into: [:]) { result, item in
            if let raw = item.value.muscle, let group = MuscleGroup(rawValue: raw) { result[item.key] = group }
        }
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat = 640) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    // MARK: - Body weight

    func addBodyWeight(kg: Double, date: Date = Date(), syncToHealth: Bool = true) {
        bodyWeights.append(BodyWeightEntry(id: UUID().uuidString, date: date, kg: kg))
        bodyWeights.sort { $0.date < $1.date }
        persistBodyWeights()
        if syncToHealth { HealthManager.shared.saveBodyWeight(kg: kg, date: date) }
        PostHogSDK.shared.capture("bodyweight_logged")
    }

    /// Merges body weight from Apple Health (only when sync is on); skips values that are already known.
    func importBodyWeightFromHealth() {
        HealthManager.shared.recentBodyWeights { [weak self] samples in
            guard let self, !samples.isEmpty else { return }
            let known = Set(self.bodyWeights.map { Int($0.date.timeIntervalSince1970 / 60) })
            var added = false
            for sample in samples where !known.contains(Int(sample.date.timeIntervalSince1970 / 60)) {
                self.bodyWeights.append(BodyWeightEntry(id: UUID().uuidString, date: sample.date, kg: sample.kg))
                added = true
            }
            if added {
                self.bodyWeights.sort { $0.date < $1.date }
                self.persistBodyWeights()
            }
        }
    }

    private func persistBodyWeights() {
        if let data = try? JSONEncoder().encode(bodyWeights) { defaults.set(data, forKey: bodyWeightKey) }
    }

    // MARK: - Backup

    func makeBackup() -> GymnioBackup {
        var photos: [String: Data] = [:]
        for meta in exerciseMeta.values {
            if let file = meta.photo, let data = try? Data(contentsOf: photosFolder.appendingPathComponent(file)) { photos[file] = data }
        }
        return GymnioBackup(exercises: exercises, entries: entries, routines: routines, exerciseNotes: exerciseNotes,
                            exerciseMeta: exerciseMeta, bodyWeights: bodyWeights, workoutNotes: workoutNotes, photos: photos)
    }

    /// Adds what is missing; never removes or overwrites existing data.
    func mergeBackup(_ backup: GymnioBackup) {
        let knownEntries = Set(entries.map { $0.id })
        for name in backup.exercises { storage.addExercise(name) }
        for entry in backup.entries where !knownEntries.contains(entry.id) { storage.saveEntry(entry) }
        exercises = storage.getExercises()
        entries = storage.getAllEntries()

        let knownRoutines = Set(routines.map { $0.id })
        routines.append(contentsOf: backup.routines.filter { !knownRoutines.contains($0.id) })
        persistRoutines()

        for (name, note) in backup.exerciseNotes where exerciseNotes[name] == nil { setExerciseNote(note, for: name) }
        for (name, meta) in backup.exerciseMeta where exerciseMeta[name] == nil {
            if let file = meta.photo, let data = backup.photos[file] {
                try? data.write(to: photosFolder.appendingPathComponent(file))
            }
            exerciseMeta[name] = meta
        }
        persistMeta()

        let knownWeights = Set(bodyWeights.map { $0.id })
        bodyWeights.append(contentsOf: backup.bodyWeights.filter { !knownWeights.contains($0.id) })
        bodyWeights.sort { $0.date < $1.date }
        persistBodyWeights()

        var notes = workoutNotes
        for (id, note) in backup.workoutNotes where notes[id] == nil { notes[id] = note }
        workoutNotes = notes
    }

    func setWeeklyGoal(_ goal: Int) {
        weeklyGoal = min(max(goal, 1), 7)
        defaults.set(weeklyGoal, forKey: weeklyGoalKey)
        PostHogSDK.shared.capture("weekly_goal_set", properties: ["goal": weeklyGoal])
    }

    // MARK: - Routines

    /// Routines a free user may keep; more needs Pro.
    static let freeRoutineLimit = 3

    var canAddRoutine: Bool {
        PremiumManager.shared.isPro || PremiumManager.shared.isPaywallSuppressedRegion || routines.count < Self.freeRoutineLimit
    }

    /// Returns false (and shows the paywall) when a free user is at the routine limit.
    @discardableResult
    func saveRoutine(_ routine: Routine, source: String = "editor") -> Bool {
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = routine
        } else {
            guard canAddRoutine else {
                paywallRequest = PaywallRequest(source: "feature_routines")
                return false
            }
            routines.append(routine)
            PostHogSDK.shared.capture("routine_created", properties: ["source": source, "exercises": routine.exercises.count])
        }
        persistRoutines()
        return true
    }

    func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
        persistRoutines()
        PostHogSDK.shared.capture("routine_deleted")
    }

    /// A routine built from a finished training (same exercises, same number of working sets).
    func routine(from workout: Workout, name: String) -> Routine {
        Routine(id: UUID().uuidString, name: name,
                exercises: workout.exercises.map { ex in
                    RoutineExercise(name: ex, sets: max(workout.sets(for: ex).filter { !$0.isWarmup }.count, 1))
                })
    }

    func startRoutine(_ routine: Routine) {
        guard startWorkout(source: "routine") else { return }
        if var active = activeWorkout { active.routineId = routine.id; setActiveWorkout(active) }
        for ex in routine.exercises { addExerciseToActive(ex.name, plannedSets: ex.sets) }
        PostHogSDK.shared.capture("routine_started", properties: ["exercises": routine.exercises.count])
        showActiveWorkout = true
    }

    /// Moves a routine up (-1) or down (+1) in the list.
    func moveRoutine(_ routine: Routine, by delta: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        let target = idx + delta
        guard routines.indices.contains(target) else { return }
        routines.swapAt(idx, target)
        persistRoutines()
    }

    private var workoutRoutines: [String: String] {
        get { defaults.dictionary(forKey: workoutRoutinesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: workoutRoutinesKey) }
    }

    /// The routine a finished training was started from (if it still exists).
    func linkedRoutine(for workoutId: String) -> Routine? {
        guard let id = workoutRoutines[workoutId] else { return nil }
        return routines.first { $0.id == id }
    }

    /// True when the training differs from its routine (other exercises or number of working sets).
    func routineDiffers(_ routine: Routine, from workout: Workout) -> Bool {
        let done = workout.exercises.map { RoutineExercise(name: $0, sets: max(workout.sets(for: $0).filter { !$0.isWarmup }.count, 1)) }
        return done != routine.exercises
    }

    /// Overwrites the routine with what was actually trained ("save changes to the template").
    func updateRoutine(_ routine: Routine, from workout: Workout) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[idx].exercises = workout.exercises.map {
            RoutineExercise(name: $0, sets: max(workout.sets(for: $0).filter { !$0.isWarmup }.count, 1))
        }
        persistRoutines()
        PostHogSDK.shared.capture("routine_updated_from_workout")
    }

    private func persistRoutines() {
        if let data = try? JSONEncoder().encode(routines) { defaults.set(data, forKey: routinesKey) }
    }

    // MARK: - Notes

    /// Sticky note per exercise (seat height, grip, cues). Empty text removes it.
    func setExerciseNote(_ text: String, for exercise: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { exerciseNotes.removeValue(forKey: exercise) } else { exerciseNotes[exercise] = trimmed }
        if let data = try? JSONEncoder().encode(exerciseNotes) { defaults.set(data, forKey: exerciseNotesKey) }
    }

    /// Links this exercise with the next one (superset) or unlinks it.
    func toggleSupersetWithNext(_ exercise: String) {
        guard var active = activeWorkout, let idx = active.exercises.firstIndex(of: exercise),
              idx < active.exercises.count - 1 else { return }
        if active.linkedToNext.contains(exercise) { active.linkedToNext.removeAll { $0 == exercise } } else { active.linkedToNext.append(exercise) }
        setActiveWorkout(active)
    }

    func isLinkedToNext(_ exercise: String) -> Bool { activeWorkout?.linkedToNext.contains(exercise) ?? false }

    func isLinkedToPrevious(_ exercise: String) -> Bool {
        guard let active = activeWorkout, let idx = active.exercises.firstIndex(of: exercise), idx > 0 else { return false }
        return active.linkedToNext.contains(active.exercises[idx - 1])
    }

    func setActiveNote(_ text: String) {
        guard var active = activeWorkout else { return }
        active.note = text
        setActiveWorkout(active)
    }

    private var workoutNotes: [String: String] {
        get { defaults.data(forKey: workoutNotesKey).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:] }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: workoutNotesKey) } }
    }

    func note(for workoutId: String) -> String? { workoutNotes[workoutId] }

    // MARK: - Entries

    // MARK: - Workouts

    var workouts: [Workout] { Workout.group(entries) }

    /// Trainings that count against the free limit (the one being logged right now does not).
    var completedWorkoutCount: Int { workouts.filter { $0.id != activeWorkout?.id }.count }

    /// Working sets a free user has logged so far (never refunded by deleting).
    var freeSetsUsed: Int { defaults.integer(forKey: freeSetsUsedKey) }

    private var isFreeSetLimitReached: Bool {
        let premium = PremiumManager.shared
        return PremiumManager.isSetLimitReached(setsUsed: freeSetsUsed, limit: premium.freeSetLimit,
                                                isPro: premium.isPro, suppressedRegion: premium.isPaywallSuppressedRegion,
                                                statusKnown: premium.entitlementResolved)
    }

    private func isFreeLimitReached() -> Bool {
        let premium = PremiumManager.shared
        if premium.freeSetLimit > 0 { return isFreeSetLimitReached }
        return PremiumManager.isWorkoutLimitReached(workoutCount: completedWorkoutCount, limit: premium.freeWorkoutLimit,
                                                    isPro: premium.isPro, suppressedRegion: premium.isPaywallSuppressedRegion,
                                                    statusKnown: premium.entitlementResolved)
    }

    /// Starts a training. Returns false (and shows the paywall) when a free user used up the free trainings.
    @discardableResult
    func startWorkout(source: String = "train") -> Bool {
        if activeWorkout != nil { return true }
        if isFreeLimitReached() {
            paywallRequest = PaywallRequest(source: "entry_limit")
            return false
        }
        setActiveWorkout(ActiveWorkout(id: UUID().uuidString, startedAt: Date(), exercises: []))
        PostHogSDK.shared.capture("workout_started", properties: ["source": source, "workout_number": completedWorkoutCount + 1])
        return true
    }

    /// Starts (or resumes) a training and opens the logging screen.
    func beginWorkout(source: String = "train") {
        if startWorkout(source: source) { showActiveWorkout = true }
    }

    /// The sets of this exercise from the most recent earlier training (for the "previous" column).
    func previousSets(for exercise: String) -> [WorkoutEntry] {
        workouts.first { $0.id != activeWorkout?.id && !$0.sets(for: exercise).isEmpty }?.sets(for: exercise) ?? []
    }

    func addExerciseToActive(_ name: String, plannedSets: Int? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard var active = activeWorkout, !trimmed.isEmpty,
              !active.exercises.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        if !exercises.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            addExercise(trimmed, source: "workout")
        }
        active.exercises.append(trimmed)
        if let plannedSets { active.plannedSets[trimmed] = plannedSets }
        setActiveWorkout(active)
    }

    /// Starts a new training with the same exercises as an earlier one.
    func repeatWorkout(_ workout: Workout) {
        guard startWorkout(source: "repeat") else { return }
        for name in workout.exercises { addExerciseToActive(name) }
        showActiveWorkout = true
    }

    /// Moves a whole training to another day/time (the sets keep their spacing).
    func moveWorkout(_ workout: Workout, to newStart: Date) {
        let delta = newStart.timeIntervalSince(workout.start)
        guard abs(delta) > 1 else { return }
        for var entry in workout.entries {
            entry.date = entry.date.addingTimeInterval(delta)
            storage.updateEntry(entry)
        }
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_date_changed")
    }

    func deleteWorkout(_ workout: Workout) {
        for entry in workout.entries { storage.deleteEntry(id: entry.id) }
        var notes = workoutNotes
        notes.removeValue(forKey: workout.id)
        workoutNotes = notes
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_deleted", properties: ["sets": workout.setCount])
    }

    func removeExerciseFromActive(_ name: String) {
        guard var active = activeWorkout else { return }
        active.exercises.removeAll { $0 == name }
        for entry in entries where entry.workoutId == active.id && entry.exercise == name {
            storage.deleteEntry(id: entry.id)
        }
        entries = storage.getAllEntries()
        setActiveWorkout(active)
    }

    func entriesForActive(exercise: String) -> [WorkoutEntry] {
        guard let active = activeWorkout else { return [] }
        return entries.filter { $0.workoutId == active.id && $0.exercise == exercise }
            .sorted(by: { WorkoutEntry.chronological($0, $1) })
    }

    /// Ends the training and returns it for the summary (nil when nothing was logged).
    @discardableResult
    func finishWorkout() -> Workout? {
        guard let active = activeWorkout else { return nil }
        let finished = workouts.first { $0.id == active.id }
        lastWorkoutDuration = Date().timeIntervalSince(active.startedAt)
        if let routineId = active.routineId {
            var map = workoutRoutines
            map[active.id] = routineId
            workoutRoutines = map
        }
        if let note = active.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            var notes = workoutNotes
            notes[active.id] = note
            workoutNotes = notes
        }
        setActiveWorkout(nil)
        RestTimerManager.shared.cancel()
        HealthManager.shared.saveWorkout(start: active.startedAt, end: Date())
        // The right moment to ask for a rating: right after the first finished training.
        if completedWorkoutCount == 1 && !defaults.bool(forKey: "review_requested_at_10") { reviewPending = true }
        if let finished {
            PostHogSDK.shared.capture("workout_finished", properties: [
                "sets": finished.setCount,
                "exercises": finished.exercises.count,
                "duration_s": Int(Date().timeIntervalSince(active.startedAt)),
                "workout_number": completedWorkoutCount
            ])
        }
        return finished
    }

    func discardWorkout() {
        guard let active = activeWorkout else { return }
        for entry in entries where entry.workoutId == active.id { storage.deleteEntry(id: entry.id) }
        entries = storage.getAllEntries()
        setActiveWorkout(nil)
        RestTimerManager.shared.cancel()
        PostHogSDK.shared.capture("workout_discarded")
    }

    private func setActiveWorkout(_ workout: ActiveWorkout?) {
        activeWorkout = workout
        if let workout, let data = try? JSONEncoder().encode(workout) {
            defaults.set(data, forKey: activeWorkoutKey)
        } else {
            defaults.removeObject(forKey: activeWorkoutKey)
        }
    }

    // MARK: - Entries

    /// Returns false when the free limit blocked the save. Sets that belong to a workout are never blocked mid-training;
    /// a quick entry outside a workout counts as (part of) that day's training.
    @discardableResult
    func addEntry(exercise: String, weight: Double, reps: Int, date: Date, workoutId: String? = nil,
                  kind: SetKind? = nil, rpe: Double? = nil, source: String = "detail", presentPaywall: Bool = true) -> Bool {
        // Free users get a few sets, then the paywall; it never interrupts before they felt the value.
        if kind != .warmup && isFreeSetLimitReached {
            paywallRequest = PaywallRequest(source: "entry_limit")
            PostHogSDK.shared.capture("set_limit_paywall_blocked", properties: ["sets_used": freeSetsUsed])
            return false
        }
        if workoutId == nil && PremiumManager.shared.freeSetLimit == 0 {
            let startsNewDay = !workouts.contains { Calendar.current.isDate($0.start, inSameDayAs: date) }
            if startsNewDay && isFreeLimitReached() {
                if presentPaywall { paywallRequest = PaywallRequest(source: "entry_limit") }
                return false
            }
        }
        let isFirstEntry = entries.isEmpty && !defaults.bool(forKey: firstEntryKey)
        let entry = WorkoutEntry.create(exercise: exercise, weight: weight, reps: reps, date: date, workoutId: workoutId, kind: kind, rpe: rpe)
        storage.saveEntry(entry)
        entries = storage.getAllEntries()
        if kind != .warmup && PremiumManager.shared.entitlementResolved && !PremiumManager.shared.isPro {
            defaults.set(freeSetsUsed + 1, forKey: freeSetsUsedKey)
            // The moment right after the last free set: the user just felt what the app does.
            let limit = PremiumManager.shared.freeSetLimit
            if limit > 0 && freeSetsUsed == limit && !PremiumManager.shared.isPaywallSuppressedRegion {
                paywallRequest = PaywallRequest(source: "first_value")
                PostHogSDK.shared.capture("first_value_paywall_shown", properties: ["sets": limit])
            }
        }
        PostHogSDK.shared.capture("workout_entry_added", properties: [
            "weight": weight,
            "reps": reps,
            "unit": weightUnit,
            "source": source
        ])
        if isFirstEntry {
            defaults.set(true, forKey: firstEntryKey)
            PostHogSDK.shared.capture("first_entry_added", properties: [
                "source": source,
                "time_to_first_entry_s": secondsSinceInstall,
                "goal": goal
            ])
        }
        checkMilestones()
        return true
    }

    /// Changes a logged set (used when correcting a past training).
    func updateEntry(_ entry: WorkoutEntry) {
        storage.updateEntry(entry)
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_entry_edited")
    }

    func deleteEntry(id: String) {
        storage.deleteEntry(id: id)
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_entry_deleted")
    }

    // MARK: - Import

    func importEntry(_ entry: WorkoutEntry) {
        storage.addExercise(entry.exercise)
        storage.saveEntry(entry)
    }

    func finishImport() {
        exercises = storage.getExercises()
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("data_imported", properties: ["entries": entries.count])
    }

    // MARK: - Settings

    func setThemeMode(_ mode: String) {
        themeMode = mode
        defaults.set(mode, forKey: themeKey)
        PostHogSDK.shared.capture("theme_changed", properties: ["mode": mode])
    }

    func setRestSeconds(_ seconds: Int) {
        restSeconds = seconds
        defaults.set(seconds, forKey: restSecondsKey)
        PostHogSDK.shared.capture("rest_timer_changed", properties: ["seconds": seconds])
        if seconds == 0 { RestTimerManager.shared.cancel() }
    }

    func setWeightUnit(_ unit: String) {
        weightUnit = unit
        defaults.set(unit, forKey: weightUnitKey)
        PostHogSDK.shared.capture("weight_unit_changed", properties: ["unit": unit])
    }

    // MARK: - Weight conversion

    /// Unit of one exercise: its own choice, otherwise the global setting.
    func unit(for exercise: String) -> String { exerciseMeta[exercise]?.unit ?? weightUnit }
    func unitLabel(for exercise: String) -> String { unit(for: exercise) }
    func displayWeight(_ kg: Double, for exercise: String) -> Double { unit(for: exercise) == "lbs" ? kg * 2.20462 : kg }
    func toKg(_ value: Double, for exercise: String) -> Double { unit(for: exercise) == "lbs" ? value / 2.20462 : value }

    func displayWeight(_ kg: Double) -> Double {
        weightUnit == "lbs" ? kg * 2.20462 : kg
    }

    func toKg(_ value: Double) -> Double {
        weightUnit == "lbs" ? value / 2.20462 : value
    }

    var unitLabel: String { weightUnit }

    /// Locale for dates and numbers, following the in-app language.
    var locale: Locale { Locale(identifier: language == "ar" ? "ar-u-nu-latn" : language) }

    // MARK: - Derived data

    func entriesForExercise(_ name: String) -> [WorkoutEntry] {
        workingEntries.filter { $0.exercise == name }.sorted(by: { WorkoutEntry.chronological($0, $1) })
    }

    /// All sets without warm-ups: the basis for records, trends and volume.
    var workingEntries: [WorkoutEntry] { entries.filter { !$0.isWarmup } }

    func groupedExercises() -> [ExerciseGroup] {
        storage.groupByExercise().map { ExerciseGroup(exercise: $0.exercise, entries: $0.entries.filter { !$0.isWarmup }) }
    }

    // MARK: - Review prompt

    static func shouldRequestReview(entryCount: Int, distinctDays: Int, alreadyAsked: Bool) -> Bool {
        guard !alreadyAsked else { return false }
        return entryCount >= 2 || distinctDays >= 2
    }

    // MARK: - Milestones

    private func checkMilestones() {
        let count = entries.count
        if [10, 25, 50, 100, 200].contains(count) {
            NotificationManager.shared.sendCelebrationNotification(entryCount: count)
            PostHogSDK.shared.capture("milestone_reached", properties: ["entry_count": count])
        }
        // Fallback if the soft ask after the first entry was never shown (e.g. entry via detail view).
        if count == 3 {
            NotificationManager.shared.requestPermissions()
        }
    }

    // MARK: - Theme

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - UI tests

    private func configureForUITestsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui_testing") else { return }
        storage.resetAll()
        defaults.removeObject(forKey: languageKey)
        defaults.removeObject(forKey: activeWorkoutKey)
        defaults.removeObject(forKey: themeKey)
        for key in [workoutRoutinesKey, freeSetsUsedKey, routinesKey, exerciseMetaKey, bodyWeightKey, exerciseNotesKey, workoutNotesKey, weeklyGoalKey] {
            defaults.removeObject(forKey: key)
        }
        defaults.set("system", forKey: themeKey)
        if args.contains("-ui_test_force_morning") { forceMorningGreeting = true }
        if let langIdx = args.firstIndex(of: "-ui_test_language"), args.indices.contains(langIdx + 1) {
            let lang = args[langIdx + 1]
            if Self.supportedLanguages.contains(lang) {
                language = lang
                languageOverride = lang
                defaults.set(lang, forKey: languageKey)
            }
        }
        if args.contains("-ui_test_seed_demo_data") { seedDemoDataForUITests(activeWorkoutDemo: args.contains("-ui_test_active_workout")) }
    }

    /// Three months of realistic training (push / pull / legs, progressive overload), routines, body weight and,
    /// with `-ui_test_active_workout`, a training in progress. Exercise names stay English so the demo videos match.
    private func seedDemoDataForUITests(activeWorkoutDemo: Bool) {
        let calendar = Calendar.current
        let isDE = (Locale.preferredLanguages.first ?? "en").hasPrefix("de")
        typealias Plan = (name: String, sets: Int, base: Double, step: Double, reps: Int)
        let push: [Plan] = [("Bench Press", 4, 70, 1.25, 6), ("Incline Dumbbell Press", 3, 24, 0.5, 10),
                            ("Dumbbell Fly", 3, 12, 0.25, 12), ("Dips", 3, 0, 0, 10)]
        let pull: [Plan] = [("Barbell Row", 4, 60, 1.25, 8), ("Lat Pulldown", 3, 55, 1, 10), ("Face Pull", 3, 25, 0.5, 15)]
        let legs: [Plan] = [("Squat", 4, 90, 2.5, 6), ("Leg Press", 3, 160, 5, 10),
                            ("Romanian Deadlift", 3, 80, 2.5, 8), ("Standing Calf Raise", 4, 60, 2.5, 12)]
        let days = [push, pull, legs]
        let names = isDE ? ["Push", "Pull", "Beine"] : ["Push", "Pull", "Legs"]

        for plan in days.flatMap({ $0 }) { storage.addExercise(plan.name) }

        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return }
        var seeded: [WorkoutEntry] = []
        for week in stride(from: 9, through: 0, by: -1) {
            for (slot, offset) in [0, 2, 4].enumerated() {
                guard let day = calendar.date(byAdding: .day, value: offset - 7 * week, to: weekStart),
                      let start = calendar.date(bySettingHour: 18, minute: 10, second: 0, of: day),
                      start < Date().addingTimeInterval(-3_600) else { continue }
                let workoutId = "demo-\(week)-\(slot)"
                var time = start
                for (index, item) in days[slot].enumerated() {
                    let weight = item.base + item.step * Double(9 - week)
                    if index == 0 {
                        seeded.append(WorkoutEntry.create(exercise: item.name, weight: (weight * 0.5 / 2.5).rounded() * 2.5,
                                                          reps: 10, date: time, workoutId: workoutId, kind: .warmup))
                        time = time.addingTimeInterval(150)
                    }
                    for _ in 0..<item.sets {
                        seeded.append(WorkoutEntry.create(exercise: item.name, weight: weight, reps: item.reps,
                                                          date: time, workoutId: workoutId))
                        time = time.addingTimeInterval(170)
                    }
                }
            }
        }

        storage.saveEntries(seeded)

        let routines = zip(names, days).enumerated().map { index, pair in
            Routine(id: "demo-routine-\(index)", name: pair.0,
                    exercises: pair.1.map { RoutineExercise(name: $0.name, sets: $0.sets) })
        }
        if let data = try? JSONEncoder().encode(routines) { defaults.set(data, forKey: routinesKey) }

        let weights: [Double] = [82.4, 82.1, 82.0, 81.7, 81.6, 81.2, 81.3, 80.9, 80.8, 80.6, 80.7, 80.4]
        let bodyWeights = weights.enumerated().compactMap { index, kg -> BodyWeightEntry? in
            guard let date = calendar.date(byAdding: .day, value: -7 * (weights.count - 1 - index), to: Date()) else { return nil }
            return BodyWeightEntry(id: "demo-bw-\(index)", date: date, kg: kg)
        }
        if let data = try? JSONEncoder().encode(bodyWeights) { defaults.set(data, forKey: bodyWeightKey) }
        defaults.set(3, forKey: weeklyGoalKey)

        if activeWorkoutDemo {
            let started = Date().addingTimeInterval(-23 * 60)
            var active = ActiveWorkout(id: "demo-active", startedAt: started, exercises: ["Bench Press", "Incline Dumbbell Press"])
            active.plannedSets = ["Bench Press": 4, "Incline Dumbbell Press": 3]
            if let data = try? JSONEncoder().encode(active) { defaults.set(data, forKey: activeWorkoutKey) }
            let logged: [(Double, Int, SetKind?)] = [(40, 10, .warmup), (80, 6, nil), (80, 6, nil)]
            for (offset, set) in logged.enumerated() {
                storage.saveEntry(WorkoutEntry.create(exercise: "Bench Press", weight: set.0, reps: set.1,
                                                      date: started.addingTimeInterval(Double(offset) * 170 + 60),
                                                      workoutId: "demo-active", kind: set.2))
            }
            showActiveWorkout = true
        }
    }
}

// MARK: - Paywall request

struct PaywallRequest: Identifiable {
    let id = UUID()
    let source: String
}
