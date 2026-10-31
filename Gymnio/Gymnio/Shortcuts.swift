import AppIntents

/// "Hey Siri, start a workout in Gymnio" and the Shortcuts app / Spotlight action.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start workout"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppStore.shared.beginWorkout(source: "siri")
        return .result()
    }
}

struct GymnioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start training with \(.applicationName)"
            ],
            shortTitle: "Start workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
