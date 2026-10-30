import SwiftUI

struct CoachInsight: Identifiable {
    enum Kind { case celebration, warning, suggestion, info }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let systemImage: String

    var tint: Color {
        switch kind {
        case .celebration: return Color(hex: "34C759")
        case .warning:     return Color(hex: "FF9500")
        case .suggestion:  return Color(hex: "5B8DEF")
        case .info:        return Color(hex: "A06BFF")
        }
    }
}

/// All coach copy lives in the string catalog (`coach.*`), so it follows the in-app language.
enum Coach {

    private static func step(_ store: AppStore) -> Double { store.weightUnit == "lbs" ? 5 : 2.5 }

    private static func fmt(_ store: AppStore, _ kg: Double) -> String {
        "\(formatWeightValue(store.displayWeight(kg))) \(store.unitLabel)"
    }

    private static func fmtDisplay(_ store: AppStore, _ display: Double) -> String {
        "\(formatWeightValue(display)) \(store.unitLabel)"
    }

    // MARK: - Weekly recap

    static func weeklyRecap(store: AppStore) -> CoachInsight? {
        let entries = store.entries
        guard !entries.isEmpty else { return nil }
        var cal = Calendar.current
        cal.firstWeekday = 2
        let now = Date()
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) ?? thisWeek.start

        let thisWeekEntries = entries.filter { $0.date >= thisWeek.start && $0.date < thisWeek.end }
        let lastWeekEntries = entries.filter { $0.date >= lastWeekStart && $0.date < thisWeek.start }

        let sessions = Set(thisWeekEntries.map { cal.startOfDay(for: $0.date) }).count
        let thisVol = thisWeekEntries.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        let lastVol = lastWeekEntries.reduce(0.0) { $0 + $1.weight * Double($1.reps) }

        if thisWeekEntries.isEmpty {
            return CoachInsight(kind: .suggestion,
                                title: store.t("coach.week.empty.title"),
                                message: store.t("coach.week.empty.msg"),
                                systemImage: "sparkles")
        }

        let sessionsWord = store.t(sessions == 1 ? "coach.session.one" : "coach.session.other")
        var message = String(format: store.t("coach.week.msg"), sessions, sessionsWord, fmt(store, thisVol))

        if lastVol > 0 {
            let change = (thisVol - lastVol) / lastVol
            let pct = Int((abs(change) * 100).rounded())
            if change > 0.05 {
                message += String(format: store.t("coach.week.up"), pct)
            } else if change < -0.05 {
                message += String(format: store.t("coach.week.down"), pct)
            } else {
                message += store.t("coach.week.same")
            }
        }

        return CoachInsight(kind: .info,
                            title: store.t("coach.week.title"),
                            message: message, systemImage: "sparkles")
    }

    // MARK: - Prioritized insights feed

    static func insights(store: AppStore, limit: Int = 4) -> [CoachInsight] {
        let groups = store.groupedExercises().filter { !$0.entries.isEmpty }
        guard !groups.isEmpty else { return [] }
        var out: [CoachInsight] = []

        if let pr = recentPRInsight(store: store, groups: groups) { out.append(pr) }

        let trends = AdvancedAnalytics.progressTrends(groups: groups)
        if let plateau = trends.first(where: { $0.category == .declining }) {
            out.append(CoachInsight(
                kind: .warning,
                title: store.t("coach.plateau.title"),
                message: String(format: store.t("coach.plateau.msg"), plateau.exercise),
                systemImage: "exclamationmark.triangle.fill"))
        }

        if let imbalance = imbalanceInsight(store: store, groups: groups) { out.append(imbalance) }

        let progress = Analytics.progressionAlerts(groups: groups)
        if let alert = progress.first {
            let suggested = store.displayWeight(alert.currentWeight) + step(store)
            out.append(CoachInsight(
                kind: .suggestion,
                title: store.t("coach.levelup.title"),
                message: String(format: store.t("coach.levelup.msg"),
                                alert.exercise, fmt(store, alert.currentWeight), fmtDisplay(store, suggested)),
                systemImage: "arrow.up.circle.fill"))
        }

        if out.count < limit {
            let streak = AdvancedAnalytics.streakInfo(entries: store.entries)
            if streak.currentWeekStreak >= 2 {
                out.append(CoachInsight(
                    kind: .celebration,
                    title: store.t("coach.streak.title"),
                    message: String(format: store.t("coach.streak.msg"), streak.currentWeekStreak),
                    systemImage: "flame.fill"))
            }
        }

        return Array(out.prefix(limit))
    }

    private static func recentPRInsight(store: AppStore, groups: [ExerciseGroup]) -> CoachInsight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        var best: (exercise: String, oneRM: Double)?
        for group in groups {
            guard let record = AdvancedAnalytics.personalRecord(for: group),
                  let date = record.bestOneRepMaxDate, date >= cutoff else { continue }
            if best == nil || record.bestOneRepMax > best!.oneRM {
                best = (group.exercise, record.bestOneRepMax)
            }
        }
        guard let best else { return nil }
        return CoachInsight(
            kind: .celebration,
            title: store.t("coach.pr.title"),
            message: String(format: store.t("coach.pr.msg"), best.exercise, fmt(store, best.oneRM)),
            systemImage: "trophy.fill")
    }

    private static func imbalanceInsight(store: AppStore, groups: [ExerciseGroup]) -> CoachInsight? {
        let dist = AdvancedAnalytics.muscleDistribution(groups: groups)
        guard dist.count >= 2, let top = dist.first, top.group != .other, top.share > 0.55 else { return nil }
        return CoachInsight(
            kind: .info,
            title: store.t("coach.balance.title"),
            message: String(format: store.t("coach.balance.msg"), Int(top.share * 100), muscleName(top.group, store: store)),
            systemImage: "scalemass.fill")
    }

    // MARK: - Next-set recommendation (per exercise)

    static func nextSetSuggestion(store: AppStore, group: ExerciseGroup) -> CoachInsight? {
        guard !group.entries.isEmpty else { return nil }
        let cal = Calendar.current
        let sorted = group.entries.sorted(by: WorkoutEntry.chronological)

        guard let lastDate = sorted.last?.date else { return nil }
        let lastDay = cal.startOfDay(for: lastDate)
        let lastSession = sorted.filter { cal.isDate($0.date, inSameDayAs: lastDay) }
        guard let topSet = lastSession.max(by: { $0.weight < $1.weight }) else { return nil }

        let sessionsAtWeight = Set(sorted.filter { $0.weight >= topSet.weight }
            .map { cal.startOfDay(for: $0.date) }).count

        let message: String
        if topSet.reps >= 8 && sessionsAtWeight >= 2 {
            let suggested = store.displayWeight(topSet.weight) + step(store)
            message = String(format: store.t("coach.next.up"),
                             fmt(store, topSet.weight), topSet.reps, fmtDisplay(store, suggested))
        } else if topSet.reps < 8 {
            message = String(format: store.t("coach.next.stay"), fmt(store, topSet.weight), topSet.reps + 1)
        } else {
            let suggested = store.displayWeight(topSet.weight) + step(store)
            message = String(format: store.t("coach.next.base"),
                             fmt(store, topSet.weight), topSet.reps, fmtDisplay(store, suggested))
        }
        return CoachInsight(kind: .suggestion, title: store.t("coach.next.title"),
                            message: message, systemImage: "wand.and.stars")
    }

    // MARK: - Technique tip (per exercise, curated on-device)

    static func formTip(store: AppStore, exercise: String) -> String? {
        let group = MuscleGroup.classify(exercise)
        let tipCount = 3
        let idx = abs(exercise.lowercased().hashValue) % tipCount + 1
        return store.t("coach.tip.\(tipKey(group)).\(idx)")
    }

    // MARK: - Localized helpers

    static func muscleName(_ group: MuscleGroup, store: AppStore) -> String {
        store.t("coach.muscle.\(tipKey(group))")
    }

    private static func tipKey(_ group: MuscleGroup) -> String {
        switch group {
        case .chest:     return "chest"
        case .back:      return "back"
        case .legs:      return "legs"
        case .shoulders: return "shoulders"
        case .arms:      return "arms"
        case .core:      return "core"
        case .other:     return "other"
        }
    }
}
