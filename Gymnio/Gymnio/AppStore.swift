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
    @Published var showOnboarding: Bool = false
    @Published var restSeconds: Int = 90
    @Published var quickLogRequest: QuickLogRequest?

    static let supportedLanguages = [
        "de", "en", "fr", "es", "it", "pt", "nl",
        "da", "sv", "nb", "fi", "is",
        "tr", "uk", "ru", "pl", "cs", "sk", "hu", "ro", "bg", "el",
        "hr", "sr", "sl", "et", "lv", "lt", "ca",
        "ja", "ko"
    ]

    private let languageKey     = "@language_override"
    private let homeSettingsKey = "homeViewSettings"
    private let themeKey        = "@theme_mode"
    private let weightUnitKey   = "@weight_unit"
    private let restSecondsKey  = "@rest_seconds"
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
            language = detected
            languageOverride = detected
            defaults.set(detected, forKey: languageKey)
        }
        if let data = defaults.data(forKey: homeSettingsKey),
           let s = try? JSONDecoder().decode(HomeViewSettings.self, from: data) {
            homeSettings = s
        }
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

    private var deviceLanguage: String {
        let raw = Locale.current.language.languageCode?.identifier ?? "en"
        let code = ["no": "nb", "nn": "nb"][raw] ?? raw
        return Self.supportedLanguages.contains(code) ? code : "en"
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

    /// Returns false when the free entry limit blocked the save.
    @discardableResult
    func addEntry(exercise: String, weight: Double, reps: Int, date: Date,
                  source: String = "detail", presentPaywall: Bool = true) -> Bool {
        let premium = PremiumManager.shared
        if PremiumManager.isEntryLimitReached(entryCount: entries.count, limit: premium.freeEntryLimit, isPro: premium.isPro, suppressedRegion: premium.isPaywallSuppressedRegion) {
            if presentPaywall { paywallRequest = PaywallRequest(source: "entry_limit") }
            return false
        }
        let isFirstEntry = entries.isEmpty && !defaults.bool(forKey: firstEntryKey)
        let entry = WorkoutEntry.create(exercise: exercise, weight: weight, reps: reps, date: date)
        storage.saveEntry(entry)
        entries = storage.getAllEntries()
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

    func displayWeight(_ kg: Double) -> Double {
        weightUnit == "lbs" ? kg * 2.20462 : kg
    }

    func toKg(_ value: Double) -> Double {
        weightUnit == "lbs" ? value / 2.20462 : value
    }

    var unitLabel: String { weightUnit }

    /// Locale for dates and numbers, following the in-app language.
    var locale: Locale { Locale(identifier: language) }

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

// MARK: - Quick log request

struct QuickLogRequest: Identifiable {
    let id = UUID()
    let exercise: String
}

// MARK: - Paywall request

struct PaywallRequest: Identifiable {
    let id = UUID()
    let source: String
}
