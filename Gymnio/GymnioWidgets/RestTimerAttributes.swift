import ActivityKit
import Foundation

// Keep this file identical in the app and in the GymnioWidgets extension.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
    }

    var exerciseName: String
    /// Localized by the app, so the extension follows the in-app language.
    var restLabel: String
    var overLabel: String
}
