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

enum Coach {

    private static func isDE(_ store: AppStore) -> Bool { store.language == "de" }

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
        let de = isDE(store)

        var message: String
        if thisWeekEntries.isEmpty {
            message = de
                ? "Diese Woche noch kein Training. Ein kurzer Satz zählt auch – leg heute los und halte deine Serie am Leben."
                : "No sets logged yet this week. Even one set counts — get one in today and keep your streak alive."
            return CoachInsight(kind: .suggestion,
                                title: de ? "Wochen-Check" : "Weekly check-in",
                                message: message, systemImage: "sparkles")
        }

        let sessionsWord = de ? (sessions == 1 ? "Einheit" : "Einheiten") : (sessions == 1 ? "session" : "sessions")
        message = de
            ? "Diese Woche: \(sessions) \(sessionsWord) und \(fmt(store, thisVol)) bewegt."
            : "This week you logged \(sessions) \(sessionsWord) and moved \(fmt(store, thisVol)) of total volume."

        if lastVol > 0 {
            let change = (thisVol - lastVol) / lastVol
            let pct = Int((abs(change) * 100).rounded())
            if change > 0.05 {
                message += de
                    ? " Das sind \(pct)% mehr als letzte Woche – starke Steigerung! 🔥"
                    : " That's \(pct)% more than last week — great progressive overload! 🔥"
            } else if change < -0.05 {
                message += de
                    ? " Das ist \(pct)% weniger als letzte Woche. Vielleicht eine bewusste Deload-Woche?"
                    : " That's \(pct)% less than last week. A planned deload, or time to push again?"
            } else {
                message += de ? " Ungefähr gleiches Volumen wie letzte Woche – schön konstant."
                              : " Roughly the same volume as last week — nice and consistent."
            }
        }

        return CoachInsight(kind: .info,
                            title: de ? "Dein Wochenrückblick" : "Your weekly recap",
                            message: message, systemImage: "sparkles")
    }

    // MARK: - Prioritized insights feed

    static func insights(store: AppStore, limit: Int = 4) -> [CoachInsight] {
        let groups = store.groupedExercises().filter { !$0.entries.isEmpty }
        guard !groups.isEmpty else { return [] }
        let de = isDE(store)
        var out: [CoachInsight] = []

        if let pr = recentPRInsight(store: store, groups: groups) { out.append(pr) }

        let trends = AdvancedAnalytics.progressTrends(groups: groups)
        if let plateau = trends.first(where: { $0.category == .declining }) {
            out.append(CoachInsight(
                kind: .warning,
                title: de ? "Plateau erkannt" : "Plateau spotted",
                message: de
                    ? "Bei \(plateau.exercise) sinkt deine geschätzte 1RM zuletzt. Versuch mehr Erholung, etwas weniger Gewicht mit sauberer Technik – oder wechsle das Rep-Schema."
                    : "Your estimated 1RM on \(plateau.exercise) has been slipping. Try extra recovery, a slight weight drop with crisp form, or switch up the rep scheme.",
                systemImage: "exclamationmark.triangle.fill"))
        }

        if let imbalance = imbalanceInsight(store: store, groups: groups) { out.append(imbalance) }

        let progress = Analytics.progressionAlerts(groups: groups)
        if let alert = progress.first {
            let suggested = store.displayWeight(alert.currentWeight) + step(store)
            out.append(CoachInsight(
                kind: .suggestion,
                title: de ? "Bereit für mehr" : "Ready to level up",
                message: de
                    ? "\(alert.exercise) liegt seit 5 Sätzen bei \(fmt(store, alert.currentWeight)). Zeit für \(fmtDisplay(store, suggested)) im nächsten Training."
                    : "\(alert.exercise) has held \(fmt(store, alert.currentWeight)) for 5 sets. Go for \(fmtDisplay(store, suggested)) next session.",
                systemImage: "arrow.up.circle.fill"))
        }

        if out.count < limit {
            let streak = AdvancedAnalytics.streakInfo(entries: store.entries)
            if streak.currentWeekStreak >= 2 {
                out.append(CoachInsight(
                    kind: .celebration,
                    title: de ? "Serie läuft" : "Streak going strong",
                    message: de
                        ? "\(streak.currentWeekStreak) Wochen in Folge trainiert. Konstanz schlägt Intensität – bleib dran!"
                        : "\(streak.currentWeekStreak) weeks trained in a row. Consistency beats intensity — keep it rolling!",
                    systemImage: "flame.fill"))
            }
        }

        return Array(out.prefix(limit))
    }

    private static func recentPRInsight(store: AppStore, groups: [ExerciseGroup]) -> CoachInsight? {
        let de = isDE(store)
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
            title: de ? "Neuer Rekord! 🏆" : "New record! 🏆",
            message: de
                ? "Deine beste geschätzte 1RM bei \(best.exercise) liegt jetzt bei \(fmt(store, best.oneRM)). Weiter so!"
                : "Your best estimated 1RM on \(best.exercise) is now \(fmt(store, best.oneRM)). Big work!",
            systemImage: "trophy.fill")
    }

    private static func imbalanceInsight(store: AppStore, groups: [ExerciseGroup]) -> CoachInsight? {
        let de = isDE(store)
        let dist = AdvancedAnalytics.muscleDistribution(groups: groups)
        guard dist.count >= 2, let top = dist.first, top.group != .other, top.share > 0.55 else { return nil }
        let groupName = muscleName(top.group, de: de)
        return CoachInsight(
            kind: .info,
            title: de ? "Balance-Tipp" : "Balance tip",
            message: de
                ? "\(Int(top.share * 100))% deines Volumens geht in \(groupName). Ein paar Sätze für vernachlässigte Muskelgruppen beugen Dysbalancen vor."
                : "\(Int(top.share * 100))% of your volume is \(groupName). Adding sets for under-trained groups helps prevent imbalances.",
            systemImage: "scalemass.fill")
    }

    // MARK: - Next-set recommendation (per exercise)

    static func nextSetSuggestion(store: AppStore, group: ExerciseGroup) -> CoachInsight? {
        guard !group.entries.isEmpty else { return nil }
        let de = isDE(store)
        let cal = Calendar.current
        let sorted = group.entries.sorted(by: WorkoutEntry.chronological)

        guard let lastDate = sorted.last?.date else { return nil }
        let lastDay = cal.startOfDay(for: lastDate)
        let lastSession = sorted.filter { cal.isDate($0.date, inSameDayAs: lastDay) }
        guard let topSet = lastSession.max(by: { $0.weight < $1.weight }) else { return nil }

        let title = de ? "Empfehlung fürs nächste Mal" : "Next-session recommendation"

        let sessionsAtWeight = Set(sorted.filter { $0.weight >= topSet.weight }
            .map { cal.startOfDay(for: $0.date) }).count

        let message: String
        if topSet.reps >= 8 && sessionsAtWeight >= 2 {
            let suggested = store.displayWeight(topSet.weight) + step(store)
            message = de
                ? "Du hast \(fmt(store, topSet.weight)) für \(topSet.reps) Wdh. gemeistert. Probier \(fmtDisplay(store, suggested)) × 6–8."
                : "You handled \(fmt(store, topSet.weight)) for \(topSet.reps) reps. Try \(fmtDisplay(store, suggested)) × 6–8 next."
        } else if topSet.reps < 8 {
            message = de
                ? "Bleib bei \(fmt(store, topSet.weight)) und ziel auf \(topSet.reps + 1)+ Wdh., bevor du das Gewicht erhöhst."
                : "Stay at \(fmt(store, topSet.weight)) and aim for \(topSet.reps + 1)+ reps before adding weight."
        } else {
            let suggested = store.displayWeight(topSet.weight) + step(store)
            message = de
                ? "Solide Basis bei \(fmt(store, topSet.weight)). Wenn sich \(topSet.reps) Wdh. leicht anfühlen, teste \(fmtDisplay(store, suggested))."
                : "Solid base at \(fmt(store, topSet.weight)). If \(topSet.reps) reps felt easy, test \(fmtDisplay(store, suggested))."
        }
        return CoachInsight(kind: .suggestion, title: title, message: message, systemImage: "wand.and.stars")
    }

    // MARK: - Technique tip (per exercise, curated on-device)

    static func formTip(store: AppStore, exercise: String) -> String? {
        let de = isDE(store)
        let group = MuscleGroup.classify(exercise)
        let tips = tipBank(de: de)[group] ?? tipBank(de: de)[.other]!
        guard !tips.isEmpty else { return nil }
        let idx = abs(exercise.lowercased().hashValue) % tips.count
        return tips[idx]
    }

    // MARK: - Localized helpers

    static func muscleName(_ group: MuscleGroup, de: Bool) -> String {
        switch group {
        case .chest:     return de ? "Brust" : "chest"
        case .back:      return de ? "Rücken" : "back"
        case .legs:      return de ? "Beine" : "legs"
        case .shoulders: return de ? "Schultern" : "shoulders"
        case .arms:      return de ? "Arme" : "arms"
        case .core:      return de ? "Core" : "core"
        case .other:     return de ? "sonstige Übungen" : "other work"
        }
    }

    private static func tipBank(de: Bool) -> [MuscleGroup: [String]] {
        if de {
            return [
                .chest: ["Schulterblätter zusammen und nach unten – stabile Brücke schützt die Schultern.",
                         "Ellbogen ca. 45° zum Körper, nicht bis zum Anschlag ausfahren.",
                         "Kontrolliert ablassen (2–3 Sek.), explosiv drücken."],
                .back: ["Zieh mit den Ellbogen, nicht mit den Händen – denk an die Rückenmuskeln.",
                        "Kurz oben halten und den Rücken bewusst anspannen.",
                        "Neutrale Wirbelsäule, kein Schwung aus dem unteren Rücken."],
                .legs: ["Knie in Richtung der Zehen führen, nicht nach innen kippen.",
                        "Tief genug gehen: Hüfte mindestens auf Kniehöhe.",
                        "Druck über die ganze Fußsohle, Fersen bleiben am Boden."],
                .shoulders: ["Nicht ins Hohlkreuz ausweichen – Core anspannen.",
                             "Bei Seitheben Ellbogen leicht gebeugt, bis Schulterhöhe.",
                             "Bewegung kontrollieren statt Gewicht schwingen."],
                .arms: ["Ellbogen bleiben fixiert an der Seite – nur der Unterarm bewegt sich.",
                        "Volle Streckung und Kontraktion für maximale Reichweite.",
                        "Kein Schwung – die Muskeln arbeiten lassen."],
                .core: ["Qualität vor Wiederholungen – bewusst anspannen.",
                        "Gleichmäßig atmen, nicht die Luft anhalten.",
                        "Unteren Rücken neutral halten, Bewegung aus dem Rumpf."],
                .other: ["Sauberer Bewegungsablauf schlägt mehr Gewicht.",
                         "Wärm dich mit leichten Sätzen auf.",
                         "Progressiv steigern – kleine Schritte, konstant."]
            ]
        }
        return [
            .chest: ["Pull your shoulder blades back and down — a stable base protects the shoulders.",
                     "Keep elbows ~45° to your torso and stop just short of lockout.",
                     "Lower under control (2–3s), press explosively."],
            .back: ["Pull with your elbows, not your hands — think about the back muscles.",
                    "Pause briefly at the top and squeeze the back.",
                    "Keep a neutral spine; don't heave with the lower back."],
            .legs: ["Track your knees over your toes — don't let them cave in.",
                    "Hit depth: hips at least to knee level.",
                    "Drive through the whole foot, heels planted."],
            .shoulders: ["Brace your core so you don't arch the lower back.",
                         "On lateral raises keep a slight elbow bend, up to shoulder height.",
                         "Control the weight instead of swinging it."],
            .arms: ["Keep elbows pinned to your sides — only the forearm moves.",
                    "Use a full stretch and squeeze for maximum range.",
                    "No swinging — let the muscle do the work."],
            .core: ["Quality over reps — brace deliberately.",
                    "Breathe steadily, don't hold your breath.",
                    "Keep the lower back neutral; move from the core."],
            .other: ["Clean technique beats heavier weight.",
                     "Warm up with a few lighter sets first.",
                     "Progress in small, steady steps."]
        ]
    }
}
