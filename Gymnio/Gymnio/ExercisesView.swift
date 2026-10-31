import SwiftUI

struct ExercisesView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var groups: [ExerciseGroup] = []

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ScreenTitle(text: store.t("nav.exercises"))
                        Spacer()
                        GlassCircleButton(icon: "plus") { store.showAddExercise = true }
                    }
                    .padding(.bottom, 4)

                    if groups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 48))
                                .foregroundColor(.gymLine)
                            Text(store.t("exercises.empty"))
                                .font(.system(size: 16))
                                .secondaryText()
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.horizontal, 32)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(groups) { group in
                                NavigationLink(destination: ExerciseDetailView(exerciseName: group.exercise)) {
                                    ExerciseCard(group: group)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: reload)
        .onChangeCompat(of: store.exercises) { _ in reload() }
    }

    private func reload() {
        store.reload()
        groups = store.groupedExercises()
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    let group: ExerciseGroup
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ExerciseThumb(name: group.exercise, size: 52)
                    Text(group.exercise)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.gymText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if group.entries.isEmpty {
                    Text(store.t("exercises.noEntries"))
                        .font(.system(size: 13))
                        .italic()
                        .secondaryText()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 0) {
                        ExerciseStat(value: formatWeightValue(store.displayWeight(group.lastWeight)), label: store.unitLabel)
                        ExerciseStat(value: "\(group.lastReps)", label: store.t("common.reps"))
                        ExerciseStat(value: "\(group.entries.count)", label: store.t("exercises.entries"))
                    }
                    if let date = group.lastDate {
                        Text(store.t("exercises.lastDate") + ": " + fmt(date))
                            .font(.system(size: 12))
                            .secondaryText()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = store.locale
        f.dateStyle = .short
        return f.string(from: date)
    }
}

struct ExerciseStat: View {
    let value: String
    let label: String
    @Environment(\.colorScheme) var scheme
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .gymNumber(20, weight: .bold)
                .foregroundColor(Color.gymText)
            Text(label)
                .font(.system(size: 12))
                .secondaryText()
        }
        .frame(maxWidth: .infinity)
    }
}
