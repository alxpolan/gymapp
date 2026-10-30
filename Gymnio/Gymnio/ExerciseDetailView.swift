import SwiftUI
import Charts

struct ExerciseDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var exerciseName: String

    @State private var entries: [WorkoutEntry] = []
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var chartIndex = 0
    @State private var deleteTarget: String?
    @State private var showDeleteAlert = false
    @State private var showDeleteExerciseAlert = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    init(exerciseName: String) {
        _exerciseName = State(initialValue: exerciseName)
    }

    enum Field { case weight, reps }

    private var weightValue: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var repsValue: Int? { Int(repsText) }
    private var isFilled: Bool { weightValue != nil && repsValue != nil }
    private var maxWeight: Double { entries.map { $0.weight }.max() ?? 0 }
    private var maxReps: Int { entries.map { $0.reps }.max() ?? 0 }
    private var bestOneRM: Double { AdvancedAnalytics.bestOneRepMax(entries: entries) }
    private var currentGroup: ExerciseGroup {
        ExerciseGroup(exercise: exerciseName, entries: entries.sorted(by: { WorkoutEntry.chronological($0, $1) }))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    Text(exerciseName)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(Color.gymText)
                        .padding(.top, -16)
                        .padding(.bottom, 8)

                    if let videoURL = ExerciseCatalog.videoURL(for: exerciseName) {
                        ExerciseVideoView(url: videoURL)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.t("detail.new_entry"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.gymText)

                            HStack(spacing: 12) {
                                DetailInput(label: "\(store.t("detail.weight")) (\(store.unitLabel))",
                                            text: $weightText, kb: .decimalPad,
                                            focused: $focusedField, field: .weight)
                                DetailInput(label: store.t("detail.reps"),
                                            text: $repsText, kb: .numberPad,
                                            focused: $focusedField, field: .reps)
                            }

                            Button { showDatePicker.toggle(); focusedField = nil } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar").secondaryText()
                                    Text(fmtShort(selectedDate))
                                        .font(.system(size: 14))
                                        .secondaryText()
                                }
                            }

                            if showDatePicker {
                                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                Button(store.t("detail.done")) { showDatePicker = false }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.tint(scheme))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            AccentButton(label: store.t("detail.add"), disabled: !isFilled, action: addEntry)
                        }
                    }

                    if !entries.isEmpty {
                        GlassCard {
                            HStack(spacing: 0) {
                                SummaryItem(value: "\(entries.count)", label: store.t("detail.stats.total"))
                                SummaryItem(value: "\(formatWeightValue(store.displayWeight(maxWeight))) \(store.unitLabel)", label: store.t("detail.stats.maxWeight"))
                                SummaryItem(value: "\(maxReps)", label: store.t("detail.stats.maxReps"))
                                SummaryItem(value: "\(formatWeightValue(store.displayWeight(bestOneRM))) \(store.unitLabel)", label: store.t("detail.stats.e1rm"))
                            }
                        }

                        ProGate(titleKey: "prolock.title", subtitleKey: "prolock.coach", source: "feature_coach") {
                            NextSetCoachCard(group: currentGroup)
                        }
                    }

                    if entries.count >= 3 {
                        let chronological = entries.sorted(by: { WorkoutEntry.chronological($0, $1) })
                        let charts: [(String, String, [ChartDataPoint])] = [
                            (store.t("detail.chart.weight"), store.unitLabel,
                             Analytics.weightChartData(entries: chronological).map(convertWeight)),
                            (store.t("detail.chart.reps"), store.t("detail.stats.count"),
                             Analytics.repsChartData(entries: chronological)),
                            (store.t("detail.chart.volume"),
                             "\(store.unitLabel) × \(store.t("common.reps"))",
                             Analytics.volumeChartData(entries: chronological).map(convertWeight))
                        ]

                        VStack(spacing: 6) {
                            TabView(selection: $chartIndex) {
                                ForEach(Array(charts.enumerated()), id: \.offset) { i, c in
                                    DetailChartCard(title: c.0, unit: c.1, data: c.2)
                                        .tag(i)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(height: 220)

                            PaginationDots(total: 3, current: chartIndex)
                                .frame(maxWidth: .infinity)
                        }
                    } else if !entries.isEmpty {
                        LockedChartCard(current: entries.count, required: 3)
                    }

                    if !entries.isEmpty {
                        Text(store.t("detail.history.title"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.gymText)

                        ForEach(entries) { entry in
                            EntryCard(entry: entry, isPB: entry.weight == maxWeight) {
                                deleteTarget = entry.id; showDeleteAlert = true
                            }
                        }
                    } else {
                        Text(store.t("detail.history.empty"))
                            .font(.system(size: 15))
                            .secondaryText()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameText = exerciseName
                        showRenameAlert = true
                    } label: {
                        Label(store.t("exercises.rename.title"), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteExerciseAlert = true
                    } label: {
                        Label(store.t("exercises.delete.title"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
            }
        }
        .onTapGesture { focusedField = nil }
        .onAppear(perform: reload)
        .alert(store.t("detail.delete.title"), isPresented: $showDeleteAlert) {
            Button(store.t("common.delete"), role: .destructive) {
                if let id = deleteTarget { store.deleteEntry(id: id); reload() }
            }
            Button(store.t("common.cancel"), role: .cancel) {}
        } message: { Text(store.t("detail.delete.message")) }
        .alert(store.t("exercises.delete.title"), isPresented: $showDeleteExerciseAlert) {
            Button(store.t("common.delete"), role: .destructive) {
                store.deleteExercise(exerciseName)
                dismiss()
            }
            Button(store.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: store.t("exercises.delete.message"), exerciseName))
        }
        .alert(store.t("exercises.rename.title"), isPresented: $showRenameAlert) {
            TextField(store.t("exercises.rename.placeholder"), text: $renameText)
            Button(store.t("common.cancel"), role: .cancel) {}
            Button(store.t("common.save")) { performRename() }
        }
    }

    private func performRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != exerciseName else { return }
        store.renameExercise(exerciseName, to: trimmed)
        exerciseName = trimmed
        reload()
    }

    private func reload() { entries = store.entriesForExercise(exerciseName).sorted(by: { WorkoutEntry.reverseChronological($0, $1) }) }

    private func convertWeight(_ pt: ChartDataPoint) -> ChartDataPoint {
        ChartDataPoint(index: pt.index, value: store.displayWeight(pt.value), label: pt.label)
    }

    private func addEntry() {
        guard let w = weightValue, let r = repsValue, w > 0, r > 0 else { return }
        if store.addEntry(exercise: exerciseName, weight: store.toKg(w), reps: r, date: selectedDate) {
            RestTimerManager.shared.start(exercise: exerciseName, store: store)
        }
        weightText = ""; repsText = ""; selectedDate = Date()
        focusedField = nil; showDatePicker = false
        reload()
    }

    private func fmtShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = store.locale
        f.dateStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Detail Input

struct DetailInput: View {
    let label: String
    @Binding var text: String
    let kb: UIKeyboardType
    var focused: FocusState<ExerciseDetailView.Field?>.Binding
    let field: ExerciseDetailView.Field
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .secondaryText()
            TextField("0", text: $text)
                .keyboardType(kb)
                .focused(focused, equals: field)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(Color.gymText)
                .padding(14)
                .background(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(scheme == .dark
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.1), lineWidth: 0.5))
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Summary Item

struct SummaryItem: View {
    let value: String
    let label: String
    @Environment(\.colorScheme) var scheme
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.gymText)
            Text(label)
                .font(.system(size: 12))
                .secondaryText()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail Chart Card

struct DetailChartCard: View {
    let title: String
    let unit: String
    let data: [ChartDataPoint]
    @Environment(\.colorScheme) var scheme
    @State private var selectedIndex: Int? = nil

    private var selectedPoint: ChartDataPoint? {
        guard let sel = selectedIndex else { return nil }
        return data.min(by: { abs($0.index - sel) < abs($1.index - sel) })
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.gymText)
                if data.count >= 2 {
                    Chart(data) { pt in
                        LineMark(x: .value("i", pt.index), y: .value("v", pt.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme))
                            .lineStyle(StrokeStyle(lineWidth: 5))
                        AreaMark(x: .value("i", pt.index), y: .value("v", pt.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.tint(scheme).opacity(0.1))
                        if let sel = selectedPoint {
                            RuleMark(x: .value("i", sel.index))
                                .foregroundStyle(Color.tint(scheme).opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                            PointMark(x: .value("i", sel.index), y: .value("v", sel.value))
                                .foregroundStyle(Color.tint(scheme))
                                .symbolSize(50)
                                .annotation(position: .top, spacing: 6) {
                                    Text("\(formatWeightValue(sel.value)) \(unit)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                                }
                        }
                    }
                    .chartSelectionCompat($selectedIndex)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartBackground { _ in Color.clear }
                    .frame(height: 120)
                }
                Text(selectedPoint.map { pt in "\(formatWeightValue(pt.value)) \(unit) • \(pt.label)" } ?? unit)
                    .font(.system(size: 14))
                    .secondaryText()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
            }
        }
    }
}

// MARK: - Entry Card

struct EntryCard: View {
    let entry: WorkoutEntry
    let isPB: Bool
    let onDelete: () -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(formatWeightValue(store.displayWeight(entry.weight))) \(store.unitLabel)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.gymText)
                        Text("× \(entry.reps) \(store.t("common.reps"))")
                            .font(.system(size: 15))
                            .secondaryText()
                        if isPB {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(scheme == .dark ? Color(hex: "fbbf24").opacity(0.2) : Color(hex: "fef3c7"))
                                .frame(width: 26, height: 22)
                                .overlay(
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(scheme == .dark ? Color(hex: "fbbf24") : Color(hex: "92400e"))
                                )
                        }
                    }
                    Text(fmtDate(entry.date))
                        .font(.system(size: 12))
                        .secondaryText()
                }
                Spacer()
                if isPB {
                    RecordShareButton(entry: entry)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "FF3B30"))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fmtDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = store.locale
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Locked Chart Card

struct LockedChartCard: View {
    let current: Int
    let required: Int
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                ZStack {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.tint(scheme).opacity(0.15))
                                .frame(height: 6)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .blur(radius: 3)

                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.gymTextSecondary)
                        Text(String(format: store.t("detail.charts.locked"), required, current, required))
                            .font(.system(size: 14, weight: .medium))
                            .secondaryText()
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }
}
