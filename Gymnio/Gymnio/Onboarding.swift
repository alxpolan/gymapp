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
