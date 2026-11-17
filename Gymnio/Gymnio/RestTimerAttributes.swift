import ActivityKit
import Foundation

// Keep this file identical in the app and in the GymnioWidgets extension.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        /// Weight (kg) and reps for the set after this rest, precomputed by the app the same way
        /// the active-workout screen prefills a row. Nil hides the log button — e.g. a brand-new
        /// exercise with no known weight yet, where only the app can ask for one.
        var nextSetWeightKg: Double?
        var nextSetReps: Int?
        /// Already formatted for display ("60 kg × 8"), so the widget needs no unit/locale logic.
        var nextSetDisplay: String?
    }

    var exerciseName: String
    /// Localized by the app, so the extension follows the in-app language.
    var restLabel: String
    var overLabel: String
    var logLabel: String
}
