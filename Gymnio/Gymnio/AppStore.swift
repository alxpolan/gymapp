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
    @Published var homeSettings: HomeViewSettings = HomeViewSettings()
    @Published var themeMode: String = "system"
    @Published var weightUnit: String = "kg"
    @Published var showAddExercise: Bool = false
    @Published var forceMorningGreeting: Bool = false
    @Published var paywallRequest: PaywallRequest?

    static let supportedLanguages = ["de", "en", "es", "fr", "it", "ja", "ko", "nl", "pt"]

    private let languageKey     = "@language_override"
    private let homeSettingsKey = "homeViewSettings"
    private let themeKey        = "@theme_mode"
    private let weightUnitKey   = "@weight_unit"

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
            language = detected
            languageOverride = detected
            defaults.set(detected, forKey: languageKey)
        }
        if let data = defaults.data(forKey: homeSettingsKey),
           let s = try? JSONDecoder().decode(HomeViewSettings.self, from: data) {
            homeSettings = s
        }
    }

    func reload() {
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
    }

    // MARK: - Language

    func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: localizedBundle, comment: "")
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

    private var deviceLanguage: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Self.supportedLanguages.contains(code) ? code : "en"
    }

    // MARK: - Exercises

    func addExercise(_ name: String) {
        storage.addExercise(name)
        exercises = storage.getExercises()
        PostHogSDK.shared.capture("exercise_added")
    }

    func deleteExercise(_ name: String) {
        storage.deleteExercise(name)
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
        PostHogSDK.shared.capture("exercise_deleted")
    }

    func renameExercise(_ oldName: String, to newName: String) {
        storage.renameExercise(oldName, to: newName)
        exercises = storage.getExercises()
        entries   = storage.getAllEntries()
        PostHogSDK.shared.capture("exercise_renamed")
    }

    // MARK: - Entries

    func addEntry(exercise: String, weight: Double, reps: Int, date: Date) {
        let premium = PremiumManager.shared
        if !premium.isPro && !premium.isPaywallSuppressedRegion && entries.count >= premium.freeEntryLimit {
            paywallRequest = PaywallRequest(source: "entry_limit")
            return
        }
        let entry = WorkoutEntry.create(exercise: exercise, weight: weight, reps: reps, date: date)
        storage.saveEntry(entry)
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_entry_added", properties: [
            "weight": weight,
            "reps": reps,
            "unit": weightUnit
        ])
        checkMilestones()
    }

    func deleteEntry(id: String) {
        storage.deleteEntry(id: id)
        entries = storage.getAllEntries()
        PostHogSDK.shared.capture("workout_entry_deleted")
    }

    // MARK: - Settings

    func setThemeMode(_ mode: String) {
        themeMode = mode
        defaults.set(mode, forKey: themeKey)
        PostHogSDK.shared.capture("theme_changed", properties: ["mode": mode])
    }

    func setWeightUnit(_ unit: String) {
        weightUnit = unit
        defaults.set(unit, forKey: weightUnitKey)
        PostHogSDK.shared.capture("weight_unit_changed", properties: ["unit": unit])
    }

    // MARK: - Weight conversion

    func displayWeight(_ kg: Double) -> Double {
        weightUnit == "lbs" ? kg * 2.20462 : kg
    }

    func toKg(_ value: Double) -> Double {
        weightUnit == "lbs" ? value / 2.20462 : value
    }

    var unitLabel: String { weightUnit }

    func saveHomeSettings(_ s: HomeViewSettings) {
        homeSettings = s
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: homeSettingsKey)
        }
    }

    // MARK: - Derived data

    func entriesForExercise(_ name: String) -> [WorkoutEntry] {
        entries.filter { $0.exercise == name }.sorted(by: WorkoutEntry.chronological)
    }

    func groupedExercises() -> [ExerciseGroup] {
        storage.groupByExercise()
    }

    // MARK: - Milestones

    private func checkMilestones() {
        let count = entries.count
        if [10, 25, 50, 100, 200].contains(count) {
            NotificationManager.shared.sendCelebrationNotification(entryCount: count)
            PostHogSDK.shared.capture("milestone_reached", properties: ["entry_count": count])
        }
        if count == 5 {
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
        defaults.removeObject(forKey: homeSettingsKey)
        defaults.removeObject(forKey: themeKey)
        defaults.set("system", forKey: themeKey)
        if args.contains("-ui_test_force_morning") { forceMorningGreeting = true }
        var uiTestLang = "en"
        if let langIdx = args.firstIndex(of: "-ui_test_language"), args.indices.contains(langIdx + 1) {
            let lang = args[langIdx + 1]
            if Self.supportedLanguages.contains(lang) {
                uiTestLang = lang
                language = lang
                languageOverride = lang
                defaults.set(lang, forKey: languageKey)
            }
        }
        if args.contains("-ui_test_seed_demo_data") { seedDemoDataForUITests(language: uiTestLang) }
    }

    private func seedDemoDataForUITests(language: String = "de") {
        let baseDate = Date()
        let calendar = Calendar.current
        let isDE = language == "de"
        let demo: [(exercise: String, weights: [Double], reps: [Int])] = [
            (isDE ? "Bankdrücken" : "Bench Press", [70, 75, 80, 80, 80, 80, 80], [8, 8, 6, 6, 6, 6, 6]),
            (isDE ? "Kniebeuge"   : "Squat",       [95, 100, 102.5, 105, 107.5, 110], [10, 8, 8, 6, 6, 5]),
            (isDE ? "Kreuzheben"  : "Deadlift",    [110, 115, 120, 125, 130], [6, 5, 5, 4, 3])
        ]
        for item in demo {
            storage.addExercise(item.exercise)
            for idx in item.weights.indices {
                let offset = -(item.weights.count - idx)
                let date = calendar.date(byAdding: .day, value: offset, to: baseDate) ?? baseDate
                storage.saveEntry(WorkoutEntry.create(exercise: item.exercise, weight: item.weights[idx], reps: item.reps[idx], date: date))
            }
        }
    }
}

// MARK: - Paywall request

struct PaywallRequest: Identifiable {
    let id = UUID()
    let source: String
}
