import ActivityKit
import AppIntents

/// Runs when the "Log set" button on the rest Live Activity is tapped. It executes in the widget
/// extension's process — it has no access to AppStore — so it just restarts the countdown on the
/// activity it already has a handle to, and drops the set in a shared queue for the app to apply
/// through its normal addEntry path (paywall/free-limit checks included) next time it's foregrounded.
@available(iOS 17.0, *)
struct LogSetFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log set"

    @Parameter(title: "Exercise")
    var exercise: String
    @Parameter(title: "Weight in kg")
    var weightKg: Double
    @Parameter(title: "Reps")
    var reps: Int

    init() {
        exercise = ""
        weightKg = 0
        reps = 0
    }

    init(exercise: String, weightKg: Double, reps: Int) {
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
    }

    func perform() async throws -> some IntentResult {
        PendingLiveActivityStore.enqueue(exercise: exercise, weightKg: weightKg, reps: reps)

        if let activity = Activity<RestTimerAttributes>.activities.first {
            let duration = max(activity.content.state.endDate.timeIntervalSince(activity.content.state.startDate), 1)
            var state = activity.content.state
            state.startDate = Date()
            state.endDate = state.startDate.addingTimeInterval(duration)
            await activity.update(ActivityContent(state: state, staleDate: state.endDate))
        }
        return .result()
    }
}
