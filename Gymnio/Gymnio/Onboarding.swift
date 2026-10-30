import SwiftUI
import PostHog

// MARK: - Starter exercises (from the video catalog, weighted lifts only)

struct StarterExercise: Identifiable {
    let fileBase: String
    let defaultKg: Double
    var id: String { fileBase }

    /// Catalog display name, so the exercise video shows up right away.
    var name: String {
        ExerciseCatalog.all.first { $0.fileBase == fileBase }?.displayName ?? fileBase
    }

    static let all: [StarterExercise] = [
        StarterExercise(fileBase: "bench_press", defaultKg: 40),
        StarterExercise(fileBase: "squat", defaultKg: 50),
        StarterExercise(fileBase: "romanian_deadlift", defaultKg: 50),
        StarterExercise(fileBase: "leg_press", defaultKg: 80),
        StarterExercise(fileBase: "incline_dumbbell_press", defaultKg: 20),
        StarterExercise(fileBase: "hip_thrust", defaultKg: 40),
        StarterExercise(fileBase: "lunges", defaultKg: 20),
        StarterExercise(fileBase: "step_ups", defaultKg: 10)
    ]

    /// Orders and trims the chips by the goal picked in onboarding.
    static func ordered(for goal: String) -> [StarterExercise] {
        let order: [String]
        switch goal {
        case "strength": order = ["squat", "bench_press", "romanian_deadlift", "leg_press", "hip_thrust", "lunges"]
        case "muscle":   order = ["bench_press", "incline_dumbbell_press", "squat", "leg_press", "hip_thrust", "romanian_deadlift"]
        default:         order = ["squat", "lunges", "bench_press", "leg_press", "hip_thrust", "step_ups"]
        }
        return order.compactMap { base in all.first { $0.fileBase == base } }
    }
}

// MARK: - Onboarding (goal + unit)

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    @State private var goal = "strength"
    @State private var unit: String

    init(defaultUnit: String) {
        _unit = State(initialValue: defaultUnit)
    }

    private var goals: [(id: String, key: String, icon: String)] {
        [("strength", "onboarding.goal.strength", "bolt.fill"),
         ("muscle", "onboarding.goal.muscle", SymbolCompat.strength),
         ("fitness", "onboarding.goal.fitness", "heart.fill")]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 24)

                Text(store.t("onboarding.title"))
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(Color.gymText)

                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("onboarding.goal.question"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.gymText)

                    ForEach(goals, id: \.id) { item in
                        Button { goal = item.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .frame(width: 28)
                                Text(store.t(item.key))
                                    .font(.system(size: 17, weight: .semibold))
                                Spacer()
                                if goal == item.id {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .foregroundColor(goal == item.id ? Color.tint(scheme) : (Color.gymText))
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous), selected: goal == item.id)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("settings.unit"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.gymText)
                    Picker("", selection: $unit) {
                        Text("kg").tag("kg")
                        Text("lbs").tag("lbs")
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                AccentButton(label: store.t("paywall.cta.continue"), disabled: false) {
                    store.completeOnboarding(goal: goal, unit: unit)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Starter chips (empty home state)

struct StarterExercisesCard: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t("starter.title"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.gymText)
            Text(store.t("starter.subtitle"))
                .font(.system(size: 15))
                .secondaryText()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(StarterExercise.ordered(for: store.goal)) { starter in
                    Button { start(starter) } label: {
                        Text(starter.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.tint(scheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 8)
                            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                PostHogSDK.shared.capture("starter_custom_tapped")
                store.showAddExercise = true
            } label: {
                Label(store.t("starter.custom"), systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.tint(scheme))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private func start(_ starter: StarterExercise) {
        let name = starter.name
        PostHogSDK.shared.capture("starter_exercise_tapped", properties: ["exercise": starter.fileBase])
        if !store.exercises.contains(where: { $0.lowercased() == name.lowercased() }) {
            store.addExercise(name, source: "starter")
        }
        store.quickLogRequest = QuickLogRequest(exercise: name)
    }
}

// MARK: - Quick log sheet

struct QuickLogView: View {
    let exercise: String

    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 20
    @State private var reps: Int = 8
    @State private var savedCount = 0
    @State private var firstSaved = false
    @State private var remindersOn = false

    private var step: Double { store.weightUnit == "lbs" ? 5 : 2.5 }
    private var saved: Bool { savedCount > 0 }

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text(exercise)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color.gymText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 28)

                    if !saved, let videoURL = ExerciseCatalog.videoURL(for: exercise) {
                        ExerciseVideoView(url: videoURL)
                    }

                    if saved {
                        savedState
                    } else {
                        inputState
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: prefill)
    }

    // MARK: Input

    private var inputState: some View {
        VStack(spacing: 18) {
            StepperRow(label: "\(store.t("detail.weight")) (\(store.unitLabel))",
                       value: formatWeightValue(weight),
                       minus: { weight = max(weight - step, 0) },
                       plus: { weight += step })
            StepperRow(label: store.t("detail.reps"),
                       value: "\(reps)",
                       minus: { reps = max(reps - 1, 1) },
                       plus: { reps += 1 })

            AccentButton(label: store.t("quicklog.save"), disabled: false, action: save)
                .padding(.top, 6)
        }
    }

    // MARK: Saved

    private var savedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.statTeal)
                .padding(.top, 8)
            Text(store.t(firstSaved ? "quicklog.saved.title" : "quicklog.saved.more"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.gymText)
                .multilineTextAlignment(.center)
            if firstSaved {
                Text(store.t("quicklog.saved.subtitle"))
                    .font(.system(size: 15))
                    .secondaryText()
                    .multilineTextAlignment(.center)
            }

            AccentButton(label: store.t("quicklog.another"), disabled: false) {
                savedCount = 0
                firstSaved = false
            }
            .padding(.top, 6)

            if firstSaved {
                Button(action: enableReminders) {
                    Label(store.t(remindersOn ? "quicklog.remind.on" : "quicklog.remind"),
                          systemImage: remindersOn ? "bell.fill" : "bell")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.tint(scheme))
                }
                .disabled(remindersOn)
            }

            Button(store.t("common.done")) { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .secondaryText()
        }
    }

    // MARK: Actions

    private func prefill() {
        if let last = store.entriesForExercise(exercise).last {
            weight = store.displayWeight(last.weight)
            reps = last.reps
        } else if let starter = StarterExercise.all.first(where: { $0.name.lowercased() == exercise.lowercased() }) {
            let base = starter.defaultKg
            weight = store.weightUnit == "lbs" ? (base * 2.20462 / 5).rounded() * 5 : base
        } else {
            weight = store.weightUnit == "lbs" ? 45 : 20
        }
    }

    private func save() {
        let wasFirst = store.entries.isEmpty
        let ok = store.addEntry(exercise: exercise, weight: store.toKg(weight), reps: reps,
                                date: Date(), source: "quick_log", presentPaywall: false)
        guard ok else {
            // Free limit reached: close this sheet first, then show the paywall.
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                store.paywallRequest = PaywallRequest(source: "entry_limit")
            }
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        RestTimerManager.shared.start(exercise: exercise, store: store)
        PostHogSDK.shared.capture("quick_log_saved", properties: ["first": wasFirst])
        firstSaved = wasFirst
        savedCount += 1
    }

    private func enableReminders() {
        NotificationManager.shared.enableDefaultReminders { granted in
            remindersOn = granted
            PostHogSDK.shared.capture("reminder_soft_ask", properties: ["granted": granted])
        }
    }
}

// MARK: - Stepper row

struct StepperRow: View {
    let label: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .secondaryText()
                HStack {
                    roundButton("minus", action: minus)
                    Spacer()
                    Text(value)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color.gymText)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    roundButton("plus", action: plus)
                }
            }
        }
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.tint(scheme))
                .frame(width: 52, height: 52)
                .flatSurface(Circle())
        }
        .buttonStyle(.plain)
    }
}
