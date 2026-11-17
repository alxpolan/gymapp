import Foundation

// Keep this file identical in the app and in the GymnioWidgets extension.
// The extension process can't call into the app's AppStore, so a "log this set" tap on the
// Live Activity just drops the request here; the app drains it the next time it's foregrounded
// and runs it through the normal addEntry path (paywall/free-limit checks included).
struct PendingLiveActivitySet: Codable {
    let id: UUID
    let exercise: String
    let weightKg: Double
    let reps: Int
}

enum PendingLiveActivityStore {
    private static let appGroupID = "group.com.fringelo.gymnio"
    private static let key = "pending_live_activity_sets"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// Called from the widget extension when the Live Activity's log button is tapped.
    static func enqueue(exercise: String, weightKg: Double, reps: Int) {
        guard let defaults else { return }
        var list = current(defaults)
        list.append(PendingLiveActivitySet(id: UUID(), exercise: exercise, weightKg: weightKg, reps: reps))
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: key) }
    }

    /// Called from the app on foreground: returns and clears whatever queued up while it wasn't running.
    static func drain() -> [PendingLiveActivitySet] {
        guard let defaults else { return [] }
        let list = current(defaults)
        if !list.isEmpty { defaults.removeObject(forKey: key) }
        return list
    }

    private static func current(_ defaults: UserDefaults) -> [PendingLiveActivitySet] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([PendingLiveActivitySet].self, from: data) else { return [] }
        return list
    }
}
