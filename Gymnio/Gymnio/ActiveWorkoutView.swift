import SwiftUI
import PostHog

// MARK: - Formatting

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(Int(seconds), 0)
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = false
    @State private var showDiscard = false
    @State private var summary: Workout?
    @State private var note = ""

    private var exercises: [String] { store.activeWorkout?.exercises ?? [] }

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            if let summary {
                WorkoutSummaryView(workout: summary) { dismiss() }
            } else {
                content
            }
        }
        .task { note = store.activeWorkout?.note ?? "" }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet { name in store.addExerciseToActive(name) }
                .environmentObject(store)
        }
        .confirmationDialog(store.t("workout.discard.title"), isPresented: $showDiscard, titleVisibility: .visible) {
            Button(store.t("workout.discard.confirm"), role: .destructive) {
                store.discardWorkout()
                dismiss()
            }
            Button(store.t("workout.keep"), role: .cancel) {}
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if exercises.isEmpty {
                        EmptyWorkoutPrompt(onPick: { store.addExerciseToActive($0) }, onBrowse: { showPicker = true })
                    } else {
                        ForEach(exercises, id: \.self) { name in
                            ExerciseBlock(exercise: name)
                        }
                        Button { showPicker = true } label: {
                            Label(store.t("workout.addExercise"), systemImage: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gymAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        TextField(store.t("workout.note"), text: $note, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(.gymText)
                            .lineLimit(2...5)
                            .padding(14)
                            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChangeCompat(of: note) { store.setActiveNote($0) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymText)
                    .frame(width: 40, height: 40)
                    .flatSurface(Circle())
            }
            VStack(alignment: .leading, spacing: 0) {
                if let start = store.activeWorkout?.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(formatDuration(context.date.timeIntervalSince(start)))
                            .gymNumber(22)
                            .foregroundColor(.gymText)
                    }
                }
                Text(store.t("workout.title"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gymTextSecondary)
            }
            Spacer()
            Button(action: finish) {
                Text(store.t("workout.finish"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymOnAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.gymAccent))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func finish() {
        let sets = store.workouts.first { $0.id == store.activeWorkout?.id }?.entries.count ?? 0
        if sets == 0 {
            showDiscard = true
        } else {
            summary = store.finishWorkout()
        }
    }
}

// MARK: - Empty state with suggestions

private struct EmptyWorkoutPrompt: View {
    let onPick: (String) -> Void
    let onBrowse: () -> Void
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t("workout.empty.title"))
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.gymText)
            Text(store.t("workout.empty.subtitle"))
                .font(.system(size: 15))
                .foregroundColor(.gymTextSecondary)

            VStack(spacing: 8) {
                ForEach(StarterExercise.ordered(for: store.goal).prefix(5)) { starter in
                    Button {
                        PostHogSDK.shared.capture("starter_exercise_tapped", properties: ["exercise": starter.fileBase])
                        onPick(starter.name)
                    } label: {
                        HStack {
                            Text(starter.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.gymText)
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.gymAccent)
                        }
                        .padding(16)
                        .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onBrowse) {
                Text(store.t("picker.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymAccent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }
}

// MARK: - One exercise with its sets

private struct SetDraft: Identifiable {
    let id = UUID()
    var weight = ""
    var reps = ""
    var entryId: String?
    var kind: SetKind?
}

struct ExerciseBlock: View {
    let exercise: String
    @EnvironmentObject var store: AppStore
    @State private var drafts: [SetDraft] = []
    @State private var showVideo = false

    private var previous: [WorkoutEntry] { store.previousSets(for: exercise).filter { !$0.isWarmup } }
    private var hasVideo: Bool { ExerciseCatalog.videoURL(for: exercise) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button { if hasVideo { showVideo = true } } label: {
                    ExerciseThumb(name: exercise, size: 48)
                        .overlay(alignment: .bottomTrailing) {
                            if hasVideo {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gymOnAccent)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(Color.gymAccent))
                                    .offset(x: 3, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                Text(exercise)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.gymText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    if ExerciseCatalog.videoURL(for: exercise) != nil {
                        Button { showVideo = true } label: { Label(store.t("workout.video"), systemImage: "play.circle") }
                    }
                    Button(role: .destructive) { store.removeExerciseFromActive(exercise) } label: {
                        Label(store.t("workout.removeExercise"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.gymTextSecondary)
                        .frame(width: 36, height: 30)
                }
            }

            TextField(store.t("workout.exerciseNote"), text: noteBinding, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.gymTextSecondary)
                .lineLimit(1...3)

            HStack(spacing: 8) {
                header(store.t("workout.set"), width: 28)
                header(store.t("workout.previous"), width: nil)
                header(store.unitLabel.uppercased(), width: 72)
                header(store.t("detail.reps").uppercased(), width: 72)
                Color.clear.frame(width: 38, height: 1)
            }

            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                SetRow(index: index + 1,
                       label: setLabel(index),
                       previousText: previousText(index),
                       draft: $drafts[index],
                       onToggle: { toggle(index) })
            }

            Button { drafts.append(nextDraft()) } label: {
                Text(store.t("workout.addSet"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.gymSurfaceRaised))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task { loadDrafts() }
        .sheet(isPresented: $showVideo) {
            if let url = ExerciseCatalog.videoURL(for: exercise) {
                ExerciseVideoView(url: url).padding(16)
            }
        }
    }

    private var noteBinding: Binding<String> {
        Binding(get: { store.exerciseNotes[exercise] ?? "" },
                set: { store.setExerciseNote($0, for: exercise) })
    }

    private func header(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundColor(.gymTextSecondary)
            .frame(width: width, alignment: width == nil ? .leading : .center)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    // MARK: Drafts

    private func loadDrafts() {
        guard drafts.isEmpty else { return }
        drafts = store.entriesForActive(exercise: exercise).map { entry in
            SetDraft(weight: formatWeightValue(store.displayWeight(entry.weight)), reps: "\(entry.reps)", entryId: entry.id, kind: entry.kind)
        }
        drafts.append(nextDraft())
        let planned = store.activeWorkout?.plannedSets[exercise] ?? 0
        while drafts.count < planned { drafts.append(nextDraft()) }
    }

    /// Next empty row, prefilled from the same set last time or from the previous set of this training.
    private func nextDraft() -> SetDraft {
        let index = drafts.filter { $0.kind != .warmup }.count
        if index < previous.count {
            let p = previous[index]
            return SetDraft(weight: formatWeightValue(store.displayWeight(p.weight)), reps: "\(p.reps)", entryId: nil)
        }
        if let last = drafts.last(where: { $0.entryId != nil }) ?? drafts.last {
            return SetDraft(weight: last.weight, reps: last.reps, entryId: nil)
        }
        return SetDraft()
    }

    /// Number of the set among the working sets; warm-ups and other types show their letter instead.
    private func setLabel(_ index: Int) -> String {
        if let kind = drafts[index].kind { return kind.letter }
        return "\(drafts[..<index].filter { $0.kind != .warmup }.count + 1)"
    }

    private func previousText(_ index: Int) -> String {
        guard drafts.indices.contains(index), drafts[index].kind != .warmup else { return "–" }
        let workingIndex = drafts[..<index].filter { $0.kind != .warmup }.count
        guard workingIndex < previous.count else { return "–" }
        let p = previous[workingIndex]
        return "\(formatWeightValue(store.displayWeight(p.weight))) × \(p.reps)"
    }

    private func toggle(_ index: Int) {
        guard drafts.indices.contains(index) else { return }
        if let id = drafts[index].entryId {
            store.deleteEntry(id: id)
            drafts[index].entryId = nil
            return
        }
        let weightText = drafts[index].weight.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(weightText), weight >= 0,
              let reps = Int(drafts[index].reps), reps > 0 else { return }
        let saved = store.addEntry(exercise: exercise, weight: store.toKg(weight), reps: reps, date: Date(),
                                   workoutId: store.activeWorkout?.id, kind: drafts[index].kind, source: "workout", presentPaywall: false)
        guard saved else { return }
        drafts[index].entryId = store.entries.last?.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if drafts[index].kind != .warmup { RestTimerManager.shared.start(exercise: exercise, store: store) }
        if index == drafts.count - 1 { drafts.append(nextDraft()) }
    }
}

// MARK: - A single set row

private struct SetRow: View {
    let index: Int
    let label: String
    let previousText: String
    @Binding var draft: SetDraft
    let onToggle: () -> Void

    @EnvironmentObject private var store: AppStore
    private var done: Bool { draft.entryId != nil }
    private var kindColor: Color {
        switch draft.kind {
        case .warmup: return .gymWarning
        case .drop: return .gymPositive
        case .failure: return Color(hex: "FF6B6B")
        case nil: return .gymTextSecondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button { draft.kind = nil } label: { Label(store.t("setkind.normal"), systemImage: draft.kind == nil ? "checkmark" : "circle") }
                ForEach(SetKind.allCases, id: \.self) { kind in
                    Button { draft.kind = kind } label: {
                        Label(store.t(kind.titleKey), systemImage: draft.kind == kind ? "checkmark" : "circle")
                    }
                }
            } label: {
                Text(label)
                    .gymNumber(15, weight: .bold)
                    .foregroundColor(draft.kind != nil ? kindColor : (done ? .gymAccent : .gymTextSecondary))
                    .frame(width: 28, height: 38)
            }
            .disabled(done)
            Text(previousText)
                .gymNumber(13, weight: .medium)
                .foregroundColor(.gymTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            field($draft.weight, keyboard: .decimalPad)
            field($draft.reps, keyboard: .numberPad)
            Button(action: onToggle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(done ? .gymOnAccent : .gymTextSecondary)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(done ? Color.gymAccent : Color.gymSurfaceRaised))
            }
            .buttonStyle(.plain)
        }
        .opacity(done ? 0.85 : 1)
    }

    private func field(_ text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .gymNumber(17, weight: .bold)
            .foregroundColor(.gymText)
            .frame(width: 72, height: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.gymSurfaceRaised))
            .disabled(done)
    }
}

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    let onPick: (String) -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var mine: [String] {
        store.exercises.filter { query.isEmpty || $0.lowercased().contains(query.lowercased()) }
    }

    private var library: [CatalogExercise] {
        ExerciseCatalog.all.filter { item in
            !store.exercises.contains(where: { $0.lowercased() == item.displayName.lowercased() })
            && (query.isEmpty || item.displayName.lowercased().contains(query.lowercased()))
        }
    }

    private var canCreate: Bool {
        !query.isEmpty
        && !store.exercises.contains(where: { $0.lowercased() == query.lowercased() })
        && !ExerciseCatalog.all.contains(where: { $0.displayName.lowercased() == query.lowercased() })
    }

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text(store.t("picker.title"))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.gymText)
                    Spacer()
                    Button(store.t("common.done")) { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymAccent)
                }

                TextField(store.t("add.search"), text: $search)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.gymSurfaceRaised))
                    .foregroundColor(.gymText)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        if canCreate {
                            row(title: String(format: store.t("picker.custom"), query), icon: "plus.circle.fill", pick: query)
                        }
                        if !mine.isEmpty {
                            SectionLabel(text: store.t("picker.yours")).padding(.top, 8)
                            ForEach(mine, id: \.self) { name in row(title: name, icon: "dumbbell", pick: name) }
                        }
                        if !library.isEmpty {
                            SectionLabel(text: store.t("picker.library")).padding(.top, 8)
                            ForEach(library) { item in
                                row(title: item.displayName,
                                    icon: ExerciseCatalog.videoURL(for: item.displayName) != nil ? "play.circle.fill" : "dumbbell",
                                    pick: item.displayName)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func row(title: String, icon: String, pick name: String) -> some View {
        Button {
            onPick(name)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if icon == "plus.circle.fill" {
                    Image(systemName: icon).foregroundColor(.gymAccent).frame(width: 44, height: 44)
                } else {
                    ExerciseThumb(name: name, size: 44)
                }
                Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.gymText)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary

struct WorkoutSummaryView: View {
    let workout: Workout
    let onDone: () -> Void

    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @State private var remindersOn = false

    /// Exercises where this training beat the best estimated 1RM from earlier trainings.
    private var records: [(exercise: String, oneRM: Double)] {
        let earlier = store.workingEntries.filter { $0.workoutId != workout.id && $0.date < workout.start }
        return workout.exercises.compactMap { name in
            let before = earlier.filter { $0.exercise == name }
                .map { AdvancedAnalytics.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            let now = workout.sets(for: name).filter { !$0.isWarmup }
                .map { AdvancedAnalytics.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return before > 0 && now > before ? (name, now) : nil
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.t("summary.title"))
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(.gymText)
                    .padding(.top, 24)

                Card {
                    HStack(alignment: .top, spacing: 12) {
                        StatNumber(value: formatDuration(store.lastWorkoutDuration),
                                   label: store.t("summary.duration"))
                        StatNumber(value: "\(workout.setCount)", label: store.t("summary.sets"))
                        StatNumber(value: "\(formatWeightValue(store.displayWeight(workout.volumeKg).rounded())) \(store.unitLabel)",
                                   label: store.t("summary.volume"))
                    }
                }

                if !records.isEmpty {
                    SectionLabel(text: store.t("summary.records"))
                    Card(leftAccent: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(records, id: \.exercise) { record in
                                HStack {
                                    RecordBadge()
                                    Text(record.exercise)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gymText)
                                    Spacer()
                                    Text("\(formatWeightValue(store.displayWeight(record.oneRM))) \(store.unitLabel)")
                                        .gymNumber(15, weight: .bold)
                                        .foregroundColor(.gymAccent)
                                }
                            }
                        }
                    }
                }

                SectionLabel(text: store.t("home.stats.exercises"))
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(workout.exercises, id: \.self) { name in
                            HStack(alignment: .top, spacing: 12) {
                                ExerciseThumb(name: name, size: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name).font(.system(size: 16, weight: .bold)).foregroundColor(.gymText)
                                Text(workout.sets(for: name)
                                    .map { "\(formatWeightValue(store.displayWeight($0.weight))) × \($0.reps)" }
                                    .joined(separator: "   "))
                                    .gymNumber(14, weight: .medium)
                                    .foregroundColor(.gymTextSecondary)
                            }
                            }
                        }
                    }
                }

                if let note = store.note(for: workout.id) {
                    Card {
                        Text(note).font(.system(size: 15)).foregroundColor(.gymText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                SaveAsRoutineButton(workout: workout).frame(maxWidth: .infinity)

                WeeklyRecapCard()

                if store.completedWorkoutCount == 1 {
                    Button(action: enableReminders) {
                        Label(store.t(remindersOn ? "quicklog.remind.on" : "quicklog.remind"),
                              systemImage: remindersOn ? "bell.fill" : "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymAccent)
                    }
                    .disabled(remindersOn)
                }

                if !premium.isPro { UpgradeCTACard(source: "workout_summary") }

                AccentButton(label: store.t("common.done"), disabled: false, action: onDone)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
        }
    }

    private func enableReminders() {
        NotificationManager.shared.enableDefaultReminders { granted in
            remindersOn = granted
            PostHogSDK.shared.capture("reminder_soft_ask", properties: ["granted": granted])
        }
    }
}
