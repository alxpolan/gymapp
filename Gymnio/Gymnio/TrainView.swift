import SwiftUI
import StoreKit

enum NavDest: Hashable {
    case settings
}

// MARK: - Train tab (start point)

struct TrainView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.requestReview) var requestReview
    @State private var navPath = NavigationPath()

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = store.locale
        return c
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = store.locale
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color.gymBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        primaryAction

                        if !store.workouts.isEmpty {
                            weekCard
                            statsCard
                            lastWorkoutCard
                        }

                        WeeklyRecapCard()
                        freeLeft
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavDest.self) { _ in SettingsView() }
            .navigationDestination(for: String.self) { id in WorkoutDetailView(workoutId: id) }
        }
        .onChangeCompat(of: store.showActiveWorkout) { shown in
            // Rating prompt right after the first finished training, never while logging.
            guard !shown, store.reviewPending else { return }
            store.reviewPending = false
            UserDefaults.standard.set(true, forKey: "review_requested_at_10")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { requestReview() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                ScreenTitle(text: store.t("nav.train"))
                Text(dateText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymTextSecondary)
            }
            Spacer()
            GlassCircleButton(icon: "gearshape.fill") { navPath.append(NavDest.settings) }
        }
    }

    // MARK: Primary action

    @ViewBuilder
    private var primaryAction: some View {
        if let active = store.activeWorkout {
            Card(leftAccent: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t("train.inProgress"))
                                .font(.system(size: 13, weight: .bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundColor(.gymAccent)
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(formatDuration(context.date.timeIntervalSince(active.startedAt)))
                                    .gymNumber(30)
                                    .foregroundColor(.gymText)
                            }
                        }
                        Spacer()
                    }
                    AccentButton(label: store.t("train.resume"), disabled: false) { store.showActiveWorkout = true }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                AccentButton(label: store.t("train.start"), disabled: false) { store.beginWorkout() }
                if store.workouts.isEmpty {
                    Text(store.t("train.firstHint"))
                        .font(.system(size: 14))
                        .foregroundColor(.gymTextSecondary)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: Week

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var weekCard: some View {
        let trainedDays = Set(store.workouts.map { calendar.startOfDay(for: $0.start) })
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: store.t("train.thisWeek"))
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        let trained = trainedDays.contains(calendar.startOfDay(for: day))
                        let isToday = calendar.isDateInToday(day)
                        VStack(spacing: 6) {
                            Text(String(calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: day) - 1]))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gymTextSecondary)
                            ZStack {
                                Circle()
                                    .fill(trained ? Color.gymAccent : Color.gymSurfaceRaised)
                                    .frame(width: 30, height: 30)
                                if isToday {
                                    Circle().stroke(Color.gymText.opacity(0.6), lineWidth: 1.5).frame(width: 36, height: 36)
                                }
                                if trained {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(.gymOnAccent)
                                }
                            }
                            .frame(height: 36)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var statsCard: some View {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeek = store.workouts.filter { $0.start >= weekStart }.count
        let streak = AdvancedAnalytics.streakInfo(entries: store.entries).currentWeekStreak
        return Card {
            HStack(alignment: .top, spacing: 12) {
                StatNumber(value: "\(store.workouts.count)", label: store.t("home.stats.workouts"))
                StatNumber(value: "\(thisWeek)", label: store.t("train.thisWeek"))
                StatNumber(value: "\(streak)", label: store.t("insights.overview.streak"), emphasized: streak >= 2)
            }
        }
    }

    // MARK: Last workout

    @ViewBuilder
    private var lastWorkoutCard: some View {
        if let last = store.workouts.first(where: { $0.id != store.activeWorkout?.id }) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: store.t("train.last"))
                NavigationLink(value: last.id) {
                    WorkoutRowCard(workout: last)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Free limit

    @ViewBuilder
    private var freeLeft: some View {
        if !premium.isPro && !premium.isPaywallSuppressedRegion {
            let left = max(premium.freeWorkoutLimit - store.completedWorkoutCount, 0)
            Button { store.paywallRequest = PaywallRequest(source: "entry_limit") } label: {
                HStack(spacing: 6) {
                    Text(String(format: store.t("train.freeLeft"), left))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gymTextSecondary)
                    ProBadge()
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }
}

// MARK: - Workout row (Train + History)

struct WorkoutRowCard: View {
    let workout: Workout
    @EnvironmentObject var store: AppStore

    private var dateText: String {
        let f = DateFormatter()
        f.locale = store.locale
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: workout.start)
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gymAccent)
                    Text(workout.exercises.joined(separator: " · "))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(workout.setCount) \(store.t("summary.sets").lowercased()) · \(formatWeightValue(store.displayWeight(workout.volumeKg).rounded())) \(store.unitLabel)")
                        .gymNumber(13, weight: .medium)
                        .foregroundColor(.gymTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gymTextSecondary)
                    .padding(.top, 4)
            }
        }
    }
}
