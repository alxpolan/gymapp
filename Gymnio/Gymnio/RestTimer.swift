import Foundation
import Combine
import ActivityKit
import UserNotifications
import PostHog

/// Starts the rest countdown after a set: a Live Activity (Lock Screen / Dynamic Island) on iOS 16.2+,
/// plus a local "rest over" notification on every supported version.
final class RestTimerManager: ObservableObject {
    static let shared = RestTimerManager()
    private init() {}

    private let notificationID = "rest_timer_end"
    private var endTask: Task<Void, Never>?
    private let swapper = ActivitySwapper()
    private var lastExercise = ""
    /// When the running countdown ends (nil = no rest running). Drives the in-app rest bar.
    @Published private(set) var endDate: Date?

    func start(exercise: String, store: AppStore, seconds override: Int? = nil) {
        let seconds = override ?? store.restDuration(for: exercise)
        guard seconds > 0 else { return }
        reset()
        lastExercise = exercise

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(seconds))
        endDate = end
        scheduleNotification(seconds: seconds, store: store)

        if #available(iOS 16.2, *) {
            // Serialized replacement: newer requests overwrite pending ones and
            // every runner ends stale activities before requesting, so rapid sets
            // converge on exactly one Live Activity instead of one per set.
            Task { [self] in
                await swapper.submit {
                    await self.endAll()
                    self.startActivity(exercise: exercise, start: start, end: end, store: store)
                }
            }
        }
        PostHogSDK.shared.capture("rest_timer_started", properties: ["seconds": seconds])
    }

    /// Adds or removes seconds from the running countdown.
    func adjust(by delta: Int, store: AppStore) {
        guard let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded()) + delta
        if remaining <= 0 { cancel() } else { start(exercise: lastExercise, store: store, seconds: remaining) }
    }

    func cancel() {
        reset()
        endDate = nil
        if #available(iOS 16.2, *) {
            Task { [self] in await swapper.submit { await self.endAll() } }
        }
    }

    private func reset() {
        endTask?.cancel()
        endTask = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    /// Call when the app becomes active: removes finished activities the app could not end in the background.
    func endExpired() {
        if #available(iOS 16.2, *) {
            Task {
                for activity in Activity<RestTimerAttributes>.activities
                where activity.content.state.endDate <= Date() {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    // MARK: - Notification

    private func scheduleNotification(seconds: Int, store: AppStore) {
        let content = UNMutableNotificationContent()
        content.title = store.t("notification.rest.title")
        content.body = store.t("notification.rest.body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Live Activity

    @available(iOS 16.2, *)
    private func startActivity(exercise: String, start: Date, end: Date, store: AppStore) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RestTimerAttributes(
            exerciseName: exercise,
            restLabel: store.t("liveactivity.rest"),
            overLabel: store.t("liveactivity.rest.over")
        )
        let state = RestTimerAttributes.ContentState(startDate: start, endDate: end)
        let content = ActivityContent(state: state, staleDate: end)
        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            // Ends itself shortly after the countdown while the app is alive; otherwise `endExpired()` cleans up.
            let delay = end.timeIntervalSinceNow + 8
            endTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(delay, 0) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        } catch {
            PostHogSDK.shared.capture("rest_timer_activity_failed", properties: ["error": error.localizedDescription])
        }
    }

    @available(iOS 16.2, *)
    private func endAll() async {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Serializes Live Activity replacement. Newer requests overwrite pending ones
/// and a single drainer runs them one at a time, so no stale end-call can kill
/// the winner after the fact and rapid starts converge on one activity.
private actor ActivitySwapper {
    private var pending: (() async -> Void)?
    private var draining = false

    func submit(_ work: @escaping () async -> Void) {
        pending = work
        guard !draining else { return }
        draining = true
        Task { await drain() }
    }

    private func drain() async {
        while let work = pending {
            pending = nil
            await work()
        }
        draining = false
    }
}
