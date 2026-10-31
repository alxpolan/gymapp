import SwiftUI

// MARK: - Routines on the Train tab

struct RoutinesSection: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Routine?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: store.t("routines.title"))
                Spacer()
                Button(action: create) {
                    Label(store.t("routines.new"), systemImage: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gymAccent)
                }
            }

            if store.routines.isEmpty {
                templates
                Button(action: create) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t("routines.empty.title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gymText)
                        Text(store.t("routines.empty.subtitle"))
                            .font(.system(size: 14))
                            .foregroundColor(.gymTextSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(store.routines) { routine in
                    RoutineCard(routine: routine, lastDone: lastDone(routine), suggested: routine.id == suggestedId,
                                onEdit: { editing = routine })
                }
            }
        }
        .sheet(item: $editing) { routine in
            RoutineEditorView(routine: routine).environmentObject(store)
        }
    }

    /// When any exercise of the routine was last trained.
    private func lastDone(_ routine: Routine) -> Date? {
        let names = Set(routine.exercises.map { $0.name })
        return store.workingEntries.filter { names.contains($0.exercise) }.map { $0.date }.max()
    }

    /// The routine that has waited longest (never done counts as longest), if it is at least two days.
    private var suggestedId: String? {
        guard store.routines.count > 1, store.activeWorkout == nil else { return nil }
        let candidates = store.routines.map { ($0, lastDone($0) ?? .distantPast) }
        guard let pick = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return pick.1 < Date().addingTimeInterval(-2 * 86_400) ? pick.0.id : nil
    }

    /// One-tap starting points for people who have no routine yet.
    private var templates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("routines.templates"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gymTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RoutineTemplate.all) { template in
                        Button {
                            store.saveRoutine(template.routine(name: store.t(template.titleKey)), source: "template")
                        } label: {
                            Label(store.t(template.titleKey), systemImage: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gymAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .flatSurface(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func create() {
        guard store.canAddRoutine else {
            store.paywallRequest = PaywallRequest(source: "feature_routines")
            return
        }
        editing = Routine(id: UUID().uuidString, name: "", exercises: [])
    }
}

struct RoutineCard: View {
    let routine: Routine
    let lastDone: Date?
    let suggested: Bool
    let onEdit: () -> Void
    @EnvironmentObject var store: AppStore
    @State private var confirmDelete = false

    private var lastDoneText: String {
        guard let lastDone else { return store.t("routines.neverDone") }
        let f = RelativeDateTimeFormatter()
        f.locale = store.locale
        f.unitsStyle = .full
        return f.localizedString(for: lastDone, relativeTo: Date())
    }

    var body: some View {
        Card(leftAccent: suggested) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        if suggested {
                            Text(store.t("routines.suggested"))
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundColor(.gymAccent)
                        }
                        Text(routine.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gymText)
                        Text(lastDoneText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gymTextSecondary)
                        Text(routine.exercises.map { $0.name }.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundColor(.gymTextSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Menu {
                        Button(action: onEdit) { Label(store.t("routines.edit"), systemImage: "pencil") }
                        Button {
                            var copy = routine
                            copy.id = UUID().uuidString
                            copy.name = routine.name + " 2"
                            store.saveRoutine(copy, source: "duplicate")
                        } label: { Label(store.t("routines.duplicate"), systemImage: "doc.on.doc") }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label(store.t("common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.gymTextSecondary)
                            .frame(width: 32, height: 28)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(Array(routine.exercises.prefix(5))) { ex in
                        ExerciseThumb(name: ex.name, size: 44)
                    }
                    if routine.exercises.count > 5 {
                        Text("+\(routine.exercises.count - 5)")
                            .gymNumber(14, weight: .bold)
                            .foregroundColor(.gymTextSecondary)
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    store.startRoutine(routine)
                } label: {
                    Text(store.t("routines.start"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.gymOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.gymAccent))
                }
                .disabled(store.activeWorkout != nil)
                .opacity(store.activeWorkout != nil ? 0.4 : 1)
            }
        }
        .confirmationDialog(store.t("routines.delete.title"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(store.t("common.delete"), role: .destructive) { store.deleteRoutine(routine) }
            Button(store.t("common.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - Editor

struct RoutineEditorView: View {
    @State var routine: Routine
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    private func move(_ name: String, by delta: Int) {
        guard let idx = routine.exercises.firstIndex(where: { $0.name == name }) else { return }
        let target = idx + delta
        guard routine.exercises.indices.contains(target) else { return }
        routine.exercises.swapAt(idx, target)
    }

    private var canSave: Bool {
        !routine.name.trimmingCharacters(in: .whitespaces).isEmpty && !routine.exercises.isEmpty
    }

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(store.t("common.cancel")) { dismiss() }
                        .foregroundColor(.gymTextSecondary)
                    Spacer()
                    Button(store.t("common.save")) {
                        routine.name = routine.name.trimmingCharacters(in: .whitespaces)
                        if store.saveRoutine(routine) { dismiss() }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canSave ? .gymAccent : .gymTextSecondary)
                    .disabled(!canSave)
                }
                .font(.system(size: 16))
                .padding(16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(store.t("routines.name"), text: $routine.name)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.gymText)
                            .padding(14)
                            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        ForEach($routine.exercises) { $ex in
                            HStack(spacing: 12) {
                                ExerciseThumb(name: ex.name, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gymText)
                                    Text(String(format: store.t("routines.sets"), ex.sets))
                                        .font(.system(size: 13))
                                        .foregroundColor(.gymTextSecondary)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Button { move(ex.name, by: -1) } label: { Image(systemName: "chevron.up") }
                                    Button { move(ex.name, by: 1) } label: { Image(systemName: "chevron.down") }
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gymTextSecondary)
                                Stepper("", value: $ex.sets, in: 1...12).labelsHidden().fixedSize()
                                Button { routine.exercises.removeAll { $0.name == ex.name } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gymTextSecondary)
                                }
                            }
                            .padding(12)
                            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button { showPicker = true } label: {
                            Label(store.t("workout.addExercise"), systemImage: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gymAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet { name in
                guard !routine.exercises.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
                routine.exercises.append(RoutineExercise(name: name, sets: 3))
            }
            .environmentObject(store)
        }
    }
}

// MARK: - Save a finished training as routine

struct SaveAsRoutineButton: View {
    let workout: Workout
    @EnvironmentObject var store: AppStore
    @State private var saved = false

    var body: some View {
        if store.canAddRoutine || saved {
            Button {
                let number = store.routines.count + 1
                let routine = store.routine(from: workout, name: String(format: store.t("routines.defaultName"), number))
                saved = store.saveRoutine(routine, source: "workout")
            } label: {
                Label(store.t(saved ? "routines.saved" : "routines.saveFromWorkout"),
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymAccent)
            }
            .disabled(saved)
        }
    }
}

// MARK: - Starter templates

struct RoutineTemplate: Identifiable {
    let id: String
    let titleKey: String
    let exercises: [(String, Int)]

    func routine(name: String) -> Routine {
        Routine(id: UUID().uuidString, name: name, exercises: exercises.map { RoutineExercise(name: $0.0, sets: $0.1) })
    }

    static let all: [RoutineTemplate] = [
        RoutineTemplate(id: "push", titleKey: "template.push",
                        exercises: [("Bench Press", 3), ("Incline Dumbbell Press", 3), ("Overhead Press", 3), ("Lateral Raise", 3), ("Tricep Pushdown", 3)]),
        RoutineTemplate(id: "pull", titleKey: "template.pull",
                        exercises: [("Deadlift", 3), ("Lat Pulldown", 3), ("Seated Cable Row", 3), ("Face Pull", 3), ("Barbell Curl", 3)]),
        RoutineTemplate(id: "legs", titleKey: "template.legs",
                        exercises: [("Squat", 4), ("Romanian Deadlift", 3), ("Leg Press", 3), ("Lying Leg Curl", 3), ("Standing Calf Raise", 4)]),
        RoutineTemplate(id: "fullbody", titleKey: "template.fullbody",
                        exercises: [("Squat", 3), ("Bench Press", 3), ("Barbell Row", 3), ("Overhead Press", 2), ("Plank", 2)])
    ]
}
