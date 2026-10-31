import SwiftUI
import RevenueCat
import PostHog

struct CoachInsight: Identifiable {
    enum Kind { case celebration, warning, suggestion, info }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let systemImage: String

    var tint: Color {
        switch kind {
        case .celebration: return Color.gymPositive
        case .warning:     return Color.gymWarning
        case .suggestion:  return Color.gymAccent
        case .info:        return Color.gymTextSecondary
        }
    }
}

enum CoachError: Error { case unavailable, proRequired, rateLimited }

/// The AI coach: sends a compact summary of the user's sets to the Gymnio coach backend (Fringelo)
/// and shows what the language model answers. Nothing is generated locally and there is no offline fallback text.
final class CoachService {
    static let shared = CoachService()
    private init() {}

    private let baseURL = URL(string: "https://cs-95.apps.fringelo.com")!
    /// Optional shared secret, read from the Info.plist key `CoachClientToken` so it never lives in the repository.
    /// The backend rate-limits per user and can verify the Pro entitlement with RevenueCat.
    private var clientToken: String {
        Bundle.main.object(forInfoDictionaryKey: "CoachClientToken") as? String ?? ""
    }
    private let defaults = UserDefaults.standard

    // MARK: - Public API

    func weeklyRecap(store: AppStore) async throws -> CoachInsight? {
        guard !store.entries.isEmpty else { return nil }
        let reply: Reply = try await load(kind: "recap",
                                          cacheKey: "recap.\(store.language).\(weekKey())",
                                          signature: "\(store.entries.count)", ttl: 6 * 3600,
                                          data: recapData(store: store), store: store)
        return CoachInsight(kind: .info, title: reply.title, message: reply.message, systemImage: "sparkles")
    }

    func insights(store: AppStore) async throws -> [CoachInsight] {
        guard !store.entries.isEmpty else { return [] }
        let feed: Feed = try await load(kind: "insights",
                                        cacheKey: "insights.\(store.language)",
                                        signature: "\(store.entries.count)", ttl: 12 * 3600,
                                        data: insightsData(store: store), store: store)
        return feed.items.map { item in
            let style = Self.style(for: item.kind)
            return CoachInsight(kind: style.kind, title: item.title, message: item.message, systemImage: style.icon)
        }
    }

    func nextSet(store: AppStore, group: ExerciseGroup) async throws -> CoachInsight? {
        guard let last = group.entries.sorted(by: { WorkoutEntry.chronological($0, $1) }).last else { return nil }
        let reply: Reply = try await load(kind: "next_set",
                                          cacheKey: "next.\(store.language).\(group.exercise.lowercased())",
                                          signature: last.id, ttl: 24 * 3600,
                                          data: nextSetData(store: store, group: group), store: store)
        return CoachInsight(kind: .suggestion, title: reply.title, message: reply.message, systemImage: "wand.and.stars")
    }

    // MARK: - Replies

    private struct Reply: Decodable {
        let title: String
        let message: String
    }

    private struct Feed: Decodable {
        struct Item: Decodable {
            let kind: String
            let title: String
            let message: String
        }
        let items: [Item]
    }

    private static func style(for kind: String) -> (kind: CoachInsight.Kind, icon: String) {
        switch kind {
        case "celebration": return (.celebration, "trophy.fill")
        case "warning":     return (.warning, "exclamationmark.triangle.fill")
        case "suggestion":  return (.suggestion, "arrow.up.circle.fill")
        default:            return (.info, "sparkles")
        }
    }

    // MARK: - Request + cache

    private struct Cached: Codable {
        let at: Date
        let signature: String
        let body: Data
    }

    private func load<T: Decodable>(kind: String, cacheKey: String, signature: String, ttl: TimeInterval,
                                    data: [String: Any], store: AppStore) async throws -> T {
        let key = "coach.cache." + cacheKey
        let cached = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Cached.self, from: $0) }
        if let cached {
            let age = Date().timeIntervalSince(cached.at)
            // Fresh enough: same data within the TTL, or any data within 30 minutes (keeps the cost down).
            if (cached.signature == signature && age < ttl) || age < 30 * 60,
               let value = try? JSONDecoder().decode(T.self, from: cached.body) {
                return value
            }
        }
        do {
            let body = try await fetch(kind: kind, data: data, store: store)
            let value = try JSONDecoder().decode(T.self, from: body)
            if let encoded = try? JSONEncoder().encode(Cached(at: Date(), signature: signature, body: body)) {
                defaults.set(encoded, forKey: key)
            }
            return value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Offline or backend down: an older answer is better than nothing, but never invented text.
            if let cached, let value = try? JSONDecoder().decode(T.self, from: cached.body) { return value }
            PostHogSDK.shared.capture("coach_failed", properties: ["kind": kind])
            throw (error as? CoachError) ?? CoachError.unavailable
        }
    }

    private func fetch(kind: String, data: [String: Any], store: AppStore) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/coach"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !clientToken.isEmpty { request.setValue(clientToken, forHTTPHeaderField: "X-App-Token") }
        request.setValue(Purchases.shared.appUserID, forHTTPHeaderField: "X-App-User")
        let payload: [String: Any] = ["kind": kind, "locale": store.language, "unit": store.weightUnit, "data": data]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (body, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return body
        case 403: throw CoachError.proRequired
        case 429: throw CoachError.rateLimited
        default:  throw CoachError.unavailable
        }
    }

    // MARK: - Payloads (compact summaries, weights in the user's display unit)

    private func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    private func daysAgo(_ date: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(days, 0)
    }

    private func weekKey() -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return "\(Int(start.timeIntervalSince1970 / 86400))"
    }

    private func recentSets(_ entries: [WorkoutEntry], limit: Int, store: AppStore) -> [[String: Any]] {
        entries.sorted(by: { WorkoutEntry.chronological($0, $1) }).suffix(limit).map { entry in
            ["d": daysAgo(entry.date), "w": round1(store.displayWeight(entry.weight)), "r": entry.reps]
        }
    }

    private func recapData(store: AppStore) -> [String: Any] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 7 * 86400)
        let lastStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) ?? thisWeek.start

        let thisEntries = store.entries.filter { $0.date >= thisWeek.start && $0.date < thisWeek.end }
        let lastEntries = store.entries.filter { $0.date >= lastStart && $0.date < thisWeek.start }

        func stats(_ entries: [WorkoutEntry]) -> [String: Any] {
            let days = Set(entries.map { calendar.startOfDay(for: $0.date) }).count
            let volume = entries.reduce(0.0) { $0 + store.displayWeight($1.weight) * Double($1.reps) }
            return ["sessions": days, "sets": entries.count, "volume": Int(volume.rounded())]
        }

        let byExercise = Dictionary(grouping: thisEntries, by: { $0.exercise })
        let top = byExercise.map { name, list -> (String, Int, Double) in
            (name, list.count, list.reduce(0.0) { $0 + store.displayWeight($1.weight) * Double($1.reps) })
        }
        .sorted(by: { $0.2 > $1.2 })
        .prefix(3)
        .map { ["name": $0.0, "sets": $0.1, "volume": Int($0.2.rounded())] as [String: Any] }

        return [
            "thisWeek": stats(thisEntries),
            "lastWeek": stats(lastEntries),
            "streakWeeks": AdvancedAnalytics.streakInfo(entries: store.workingEntries).currentWeekStreak,
            "top": Array(top)
        ]
    }

    private func insightsData(store: AppStore) -> [String: Any] {
        let groups = store.groupedExercises().filter { !$0.entries.isEmpty }
        let top = Analytics.topExercisesByVolume(groups: groups, limit: 8)
        let exercises: [[String: Any]] = top.map { group in
            let record = AdvancedAnalytics.personalRecord(for: group)
            return [
                "name": group.exercise,
                "sets": group.entries.count,
                "best1RM": round1(store.displayWeight(record?.bestOneRepMax ?? 0)),
                "recent": recentSets(group.entries, limit: 6, store: store)
            ]
        }
        let weekly = AdvancedAnalytics.weeklyVolume(entries: store.workingEntries).map { Int(store.displayWeight($0.value).rounded()) }
        let muscles: [[String: Any]] = AdvancedAnalytics.muscleDistribution(groups: groups).map { item in
            ["group": item.group.rawValue, "share": item.share]
        }
        return [
            "exercises": exercises,
            "weeklyVolume": weekly,
            "streakWeeks": AdvancedAnalytics.streakInfo(entries: store.workingEntries).currentWeekStreak,
            "muscleShare": muscles
        ]
    }

    private func nextSetData(store: AppStore, group: ExerciseGroup) -> [String: Any] {
        ["exercise": group.exercise, "recent": recentSets(group.entries, limit: 12, store: store)]
    }
}
