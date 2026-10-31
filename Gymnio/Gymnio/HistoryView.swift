import SwiftUI

// MARK: - History tab (calendar + trainings)

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var month = Date()
    @State private var selectedDay: Date?

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = store.locale
        return c
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = store.locale
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f.string(from: month)
    }

    private var trainedDays: Set<Date> {
        Set(store.workouts.map { calendar.startOfDay(for: $0.start) })
    }

    private var visibleWorkouts: [Workout] {
        store.workouts.filter { workout in
            if let day = selectedDay { return calendar.isDate(workout.start, inSameDayAs: day) }
            return calendar.isDate(workout.start, equalTo: month, toGranularity: .month)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gymBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(text: store.t("nav.history"))
                        calendarCard

                        if visibleWorkouts.isEmpty {
                            Text(store.t("history.empty"))
                                .font(.system(size: 15))
                                .foregroundColor(.gymTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(visibleWorkouts) { workout in
                                NavigationLink(value: workout.id) {
                                    WorkoutRowCard(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { id in WorkoutDetailView(workoutId: id) }
        }
    }

    // MARK: Calendar

    private var calendarCard: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    Text(monthTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.gymText)
                    Spacer()
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                }
                .foregroundColor(.gymText)

                HStack(spacing: 0) {
                    ForEach(weekdayHeaders, id: \.offset) { item in
                        Text(item.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gymTextSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let cells = monthCells()
                let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }
            }
        }
    }

    private var weekdayHeaders: [(offset: Int, symbol: String)] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { (offset: $0, symbol: symbols[($0 + first) % 7]) }
    }

    private func dayCell(_ day: Date) -> some View {
        let start = calendar.startOfDay(for: day)
        let trained = trainedDays.contains(start)
        let selected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDay = selected ? nil : (trained ? day : nil)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .gymNumber(15, weight: isToday ? .heavy : .medium)
                    .foregroundColor(selected ? .gymOnAccent : .gymText)
                Circle()
                    .fill(trained ? (selected ? Color.gymOnAccent : Color.gymAccent) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Color.gymAccent : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isToday && !selected ? Color.gymText.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func monthCells() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for day in days {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        month = calendar.date(byAdding: .month, value: delta, to: month) ?? month
        selectedDay = nil
    }
}

// MARK: - Workout detail

struct WorkoutDetailView: View {
    let workoutId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    private var workout: Workout? { store.workouts.first { $0.id == workoutId } }

    private var titleText: String {
        guard let workout else { return "" }
        let f = DateFormatter()
        f.locale = store.locale
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: workout.start)
    }

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            if let workout {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(titleText)
                            .font(.system(size: 26, weight: .heavy))
                            .tracking(-0.4)
                            .foregroundColor(.gymText)

                        Card {
                            HStack(alignment: .top, spacing: 12) {
                                StatNumber(value: "\(workout.setCount)", label: store.t("summary.sets"))
                                StatNumber(value: "\(workout.exercises.count)", label: store.t("home.stats.exercises"))
                                StatNumber(value: "\(formatWeightValue(store.displayWeight(workout.volumeKg).rounded())) \(store.unitLabel)",
                                           label: store.t("summary.volume"))
                            }
                        }

                        if let note = store.note(for: workout.id) {
                            Card {
                                Text(note)
                                    .font(.system(size: 15))
                                    .foregroundColor(.gymText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        ForEach(workout.exercises, id: \.self) { name in
                            Card {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        ExerciseThumb(name: name, size: 40)
                                        Text(name)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.gymText)
                                    }
                                    let sets = workout.sets(for: name)
                                    let best = sets.filter { !$0.isWarmup }.map { $0.weight }.max() ?? 0
                                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                        HStack {
                                            Text(set.kind?.letter ?? "\(sets[..<index].filter { !$0.isWarmup }.count + 1)")
                                                .gymNumber(14, weight: .bold)
                                                .foregroundColor(.gymTextSecondary)
                                                .frame(width: 24, alignment: .leading)
                                            Text("\(formatWeightValue(store.displayWeight(set.weight))) \(store.unitLabel) × \(set.reps)")
                                                .gymNumber(16, weight: .semibold)
                                                .foregroundColor(.gymText)
                                            Spacer()
                                            if !set.isWarmup && set.weight == best && sets.count > 1 { RecordBadge() }
                                        }
                                    }
                                }
                            }
                        }

                        AccentButton(label: store.t("detail.repeat"), disabled: false) {
                            store.repeatWorkout(workout)
                        }
                        .padding(.top, 4)

                        SaveAsRoutineButton(workout: workout)
                            .frame(maxWidth: .infinity)

                        Button(role: .destructive) { showDelete = true } label: {
                            Text(store.t("history.deleteWorkout"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.gymDestructive)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(store.t("history.deleteWorkout"), isPresented: $showDelete, titleVisibility: .visible) {
            Button(store.t("common.delete"), role: .destructive) {
                if let workout { store.deleteWorkout(workout) }
                dismiss()
            }
            Button(store.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(store.t("history.delete.message"))
        }
    }
}
