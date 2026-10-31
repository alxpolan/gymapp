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
            RestBar()
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
    var rpe: Double?
    var isRecord = false
}

struct ExerciseBlock: View {
    let exercise: String
    @EnvironmentObject var store: AppStore
    @State private var drafts: [SetDraft] = []
    @State private var showVideo = false
    @State private var showEditor = false
    @State private var showPlates = false

    private var type: ExerciseType { store.exerciseType(for: exercise) }
    private var previous: [WorkoutEntry] { store.previousSets(for: exercise).filter { !$0.isWarmup } }
    private var canLinkNext: Bool {
        guard let list = store.activeWorkout?.exercises, let idx = list.firstIndex(of: exercise) else { return false }
        return idx < list.count - 1
    }
    private var inSuperset: Bool { store.isLinkedToNext(exercise) || store.isLinkedToPrevious(exercise) }
    private var hasVideo: Bool { ExerciseCatalog.videoURL(for: exercise) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if inSuperset {
                Label(store.t("workout.superset"), systemImage: "link")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(.gymAccent)
            }
            titleRow

            TextField(store.t("workout.exerciseNote"), text: noteBinding, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.gymTextSecondary)
                .lineLimit(1...3)

            HStack(spacing: 8) {
                header(store.t("workout.set"), width: 28)
                header(store.t("workout.previous"), width: nil)
                if type.usesWeight { header(store.unitLabel.uppercased(), width: 72) }
                header(repsHeader, width: 72)
                Color.clear.frame(width: 38, height: 1)
            }

            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                SetRow(label: setLabel(index),
                       previousText: previousText(index),
                       type: type,
                       draft: $drafts[index],
                       onToggle: { toggle(index) },
                       onRemove: { removeDraft(index) })
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
        .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous), selected: inSuperset)
        .task { loadDrafts() }
        .sheet(isPresented: $showVideo) {
            if let url = ExerciseCatalog.videoURL(for: exercise) {
                ExerciseVideoView(url: url).padding(16)
            }
        }
        .sheet(isPresented: $showEditor) { ExerciseMetaEditor(exercise: exercise).environmentObject(store) }
        .sheet(isPresented: $showPlates) {
            PlateCalculatorView(initialWeight: Double(drafts.first(where: { $0.entryId == nil && $0.kind == nil })?.weight
                .replacingOccurrences(of: ",", with: ".") ?? "") ?? 0)
                .environmentObject(store)
        }
    }

    private var repsHeader: String {
        type == .duration ? store.t("workout.seconds").uppercased() : store.t("detail.reps").uppercased()
    }

    private var titleRow: some View {
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
                if hasVideo {
                    Button { showVideo = true } label: { Label(store.t("workout.video"), systemImage: "play.circle") }
                }
                if type == .weightReps {
                    Button(action: addWarmups) { Label(store.t("workout.warmups"), systemImage: "flame") }
                    Button { showPlates = true } label: { Label(store.t("plates.title"), systemImage: "circle.grid.2x1") }
                }
                if canLinkNext {
                    Button { store.toggleSupersetWithNext(exercise) } label: {
                        Label(store.t(store.isLinkedToNext(exercise) ? "workout.superset.unlink" : "workout.superset.link"),
                              systemImage: "link")
                    }
                }
                Button { showEditor = true } label: { Label(store.t("meta.edit"), systemImage: "slider.horizontal.3") }
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
            SetDraft(weight: formatWeightValue(store.displayWeight(entry.weight)), reps: "\(entry.reps)",
                     entryId: entry.id, kind: entry.kind, rpe: entry.rpe)
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
            return SetDraft(weight: formatWeightValue(store.displayWeight(p.weight)), reps: "\(p.reps)")
        }
        if let last = drafts.last(where: { $0.entryId != nil && $0.kind != .warmup }) ?? drafts.last(where: { $0.kind != .warmup }) {
            return SetDraft(weight: last.weight, reps: last.reps)
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
        return store.shortSetText(previous[workingIndex])
    }

    private func removeDraft(_ index: Int) {
        guard drafts.indices.contains(index) else { return }
        if let id = drafts[index].entryId { store.deleteEntry(id: id) }
        drafts.remove(at: index)
        if drafts.isEmpty { drafts.append(nextDraft()) }
    }

    /// Three lighter sets (50 / 70 / 85 %) before the first open working set.
    private func addWarmups() {
        guard let target = drafts.first(where: { $0.entryId == nil && $0.kind == nil }),
              let weight = Double(target.weight.replacingOccurrences(of: ",", with: ".")), weight > 0 else { return }
        let step = store.weightUnit == "lbs" ? 5.0 : 2.5
        let plan: [(Double, Int)] = [(0.5, 8), (0.7, 5), (0.85, 3)]
        let rows = plan.map { pct, reps -> SetDraft in
            let w = max((weight * pct / step).rounded() * step, step)
            return SetDraft(weight: formatWeightValue(w), reps: "\(reps)", kind: .warmup)
        }
        let insertAt = drafts.firstIndex(where: { $0.entryId == nil }) ?? drafts.count
        drafts.insert(contentsOf: rows, at: insertAt)
    }

    private func toggle(_ index: Int) {
        guard drafts.indices.contains(index) else { return }
        if let id = drafts[index].entryId {
            store.deleteEntry(id: id)
            drafts[index].entryId = nil
            drafts[index].isRecord = false
            return
        }
        let weightText = drafts[index].weight.replacingOccurrences(of: ",", with: ".")
        let weight = type.usesWeight || !weightText.isEmpty ? (Double(weightText) ?? (type.usesWeight ? -1 : 0)) : 0
        guard weight >= 0, let reps = Int(drafts[index].reps), reps > 0 else { return }
        let kg = store.toKg(weight)
        let isRecord = drafts[index].kind != .warmup && beatsRecord(weightKg: kg, reps: reps)
        let saved = store.addEntry(exercise: exercise, weight: kg, reps: reps, date: Date(),
                                   workoutId: store.activeWorkout?.id, kind: drafts[index].kind,
                                   rpe: drafts[index].rpe, source: "workout", presentPaywall: false)
        guard saved else { return }
        drafts[index].entryId = store.entries.last?.id
        drafts[index].isRecord = isRecord
        if isRecord {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            PostHogSDK.shared.capture("pr_in_workout", properties: ["exercise": exercise])
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if drafts[index].kind != .warmup && !store.isLinkedToNext(exercise) {
            RestTimerManager.shared.start(exercise: exercise, store: store)
        }
        if index == drafts.count - 1 { drafts.append(nextDraft()) }
    }

    /// True when this set is better than anything logged for the exercise before this training.
    private func beatsRecord(weightKg: Double, reps: Int) -> Bool {
        let activeId = store.activeWorkout?.id
        let earlier = store.workingEntries.filter { $0.exercise == exercise && $0.workoutId != activeId }
        guard !earlier.isEmpty else { return false }
        func score(_ w: Double, _ r: Int) -> Double {
            type == .weightReps ? AdvancedAnalytics.estimatedOneRepMax(weight: w, reps: r) : Double(r) + w * 1000
        }
        let best = earlier.map { score($0.weight, $0.reps) }.max() ?? 0
        let sameWorkout = store.entriesForActive(exercise: exercise).filter { !$0.isWarmup }.map { score($0.weight, $0.reps) }.max() ?? 0
        let candidate = score(weightKg, reps)
        return candidate > best && candidate > sameWorkout
    }
}

// MARK: - A single set row

private struct SetRow: View {
    let label: String
    let previousText: String
    let type: ExerciseType
    @Binding var draft: SetDraft
    let onToggle: () -> Void
    let onRemove: () -> Void

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
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Menu {
                    Button { draft.kind = nil } label: { Label(store.t("setkind.normal"), systemImage: draft.kind == nil ? "checkmark" : "circle") }
                    ForEach(SetKind.allCases, id: \.self) { kind in
                        Button { draft.kind = kind } label: {
                            Label(store.t(kind.titleKey), systemImage: draft.kind == kind ? "checkmark" : "circle")
                        }
                    }
                    Menu {
                        Button { draft.rpe = nil } label: { Text(store.t("rpe.none")) }
                        ForEach([6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0], id: \.self) { value in
                            Button { draft.rpe = value } label: { Text("RPE " + formatWeightValue(value)) }
                        }
                    } label: { Label("RPE", systemImage: "gauge.medium") }
                    Button(role: .destructive, action: onRemove) { Label(store.t("workout.removeSet"), systemImage: "trash") }
                } label: {
                    Text(label)
                        .gymNumber(15, weight: .bold)
                        .foregroundColor(draft.kind != nil ? kindColor : (done ? .gymAccent : .gymTextSecondary))
                        .frame(width: 28, height: 38)
                }

                HStack(spacing: 6) {
                    Text(previousText)
                        .gymNumber(13, weight: .medium)
                        .foregroundColor(.gymTextSecondary)
                    if draft.isRecord { RecordBadge() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if type.usesWeight { field($draft.weight, keyboard: .decimalPad) }
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
            if let rpe = draft.rpe {
                Text("RPE " + formatWeightValue(rpe))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gymTextSecondary)
                    .padding(.leading, 36)
            }
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
                                    .map { store.shortSetText($0) }
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

// MARK: - Rest countdown bar

struct RestBar: View {
    @ObservedObject private var timer = RestTimerManager.shared
    @EnvironmentObject var store: AppStore

    var body: some View {
        if let end = timer.endDate {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = Int(end.timeIntervalSince(context.date).rounded(.up))
                if remaining > -3 {
                    HStack(spacing: 12) {
                        Image(systemName: "timer").foregroundColor(.gymAccent)
                        Text(remaining > 0 ? formatDuration(TimeInterval(remaining)) : store.t("liveactivity.rest.over"))
                            .gymNumber(22)
                            .foregroundColor(.gymText)
                        Spacer()
                        stepButton("−15") { timer.adjust(by: -15, store: store) }
                        stepButton("+15") { timer.adjust(by: 15, store: store) }
                        Button { timer.cancel() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.gymTextSecondary)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.gymSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gymAccent, lineWidth: 1.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gymText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.gymSurfaceRaised))
        }
    }
}

// MARK: - Plate calculator

struct PlateCalculatorView: View {
    @State var target: Double
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var targetText = ""
    @State private var barText = ""

    init(initialWeight: Double) { _target = State(initialValue: initialWeight) }

    private var isLbs: Bool { store.weightUnit == "lbs" }
    private var plates: [Double] { isLbs ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25] }
    private var bar: Double { Double(barText.replacingOccurrences(of: ",", with: ".")) ?? (isLbs ? 45 : 20) }

    private var perSide: [Double] {
        var remaining = ((Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0) - bar) / 2
        var result: [Double] = []
        guard remaining > 0 else { return [] }
        for plate in plates {
            while remaining + 0.001 >= plate {
                result.append(plate)
                remaining -= plate
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(store.t("plates.title")).font(.system(size: 22, weight: .heavy)).foregroundColor(.gymText)
                    Spacer()
                    Button(store.t("common.done")) { dismiss() }.foregroundColor(.gymAccent)
                }
                HStack(spacing: 12) {
                    labeled(store.t("plates.target"), text: $targetText)
                    labeled(store.t("plates.bar"), text: $barText)
                }
                SectionLabel(text: store.t("plates.perSide"))
                if perSide.isEmpty {
                    Text("–").foregroundColor(.gymTextSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(perSide.enumerated()), id: \.offset) { _, plate in
                                Text(formatWeightValue(plate))
                                    .gymNumber(16, weight: .bold)
                                    .foregroundColor(.gymOnAccent)
                                    .frame(width: 34, height: 34 + CGFloat(plate / (isLbs ? 45 : 25)) * 40)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gymAccent))
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .task {
            targetText = target > 0 ? formatWeightValue(target) : ""
            barText = formatWeightValue(isLbs ? 45 : 20)
        }
    }

    private func labeled(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "\(title) (\(store.unitLabel))")
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .gymNumber(20, weight: .bold)
                .foregroundColor(.gymText)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.gymSurfaceRaised))
        }
    }
}
