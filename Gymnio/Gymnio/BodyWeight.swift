import SwiftUI
import Charts

struct BodyWeightEntry: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var kg: Double
}

// MARK: - Progress card

struct BodyWeightCard: View {
    @EnvironmentObject var store: AppStore
    @State private var showInput = false
    @State private var input = ""

    private var recent: [BodyWeightEntry] { Array(store.bodyWeights.suffix(30)) }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let last = store.bodyWeights.last {
                            Text("\(formatWeightValue((store.displayWeight(last.kg) * 10).rounded() / 10)) \(store.unitLabel)")
                                .gymNumber(30)
                                .foregroundColor(.gymText)
                            if let change = change {
                                Text("\(change > 0 ? "+" : "")\(formatWeightValue((store.displayWeight(change) * 10).rounded() / 10)) \(store.unitLabel) · 30 \(store.t("bodyweight.days"))")
                                    .gymNumber(13, weight: .medium)
                                    .foregroundColor(.gymTextSecondary)
                            }
                        } else {
                            Text(store.t("bodyweight.empty"))
                                .font(.system(size: 15))
                                .foregroundColor(.gymTextSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        input = ""
                        showInput = true
                    } label: {
                        Label(store.t("bodyweight.log"), systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gymAccent)
                    }
                }

                if recent.count >= 2 {
                    Chart(recent) { entry in
                        LineMark(x: .value("d", entry.date), y: .value("w", store.displayWeight(entry.kg)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.gymAccent)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(x: .value("d", entry.date), y: .value("w", store.displayWeight(entry.kg)))
                            .foregroundStyle(Color.gymAccent)
                            .symbolSize(24)
                    }
                    .chartYScale(domain: yRange)
                    .frame(height: 120)
                }
            }
        }
        .alert(store.t("bodyweight.log"), isPresented: $showInput) {
            TextField(store.unitLabel, text: $input).keyboardType(.decimalPad)
            Button(store.t("common.cancel"), role: .cancel) {}
            Button(store.t("common.save")) {
                if let value = Double(input.replacingOccurrences(of: ",", with: ".")), value > 0 {
                    store.addBodyWeight(kg: store.toKg(value))
                }
            }
        }
        .task { store.importBodyWeightFromHealth() }
    }

    /// Axis range around the data (iOS 16 has no automatic non-zero domain).
    private var yRange: ClosedRange<Double> {
        let values = recent.map { store.displayWeight($0.kg) }
        let low = values.min() ?? 0, high = values.max() ?? 1
        let pad = max((high - low) * 0.2, 1)
        return (low - pad)...(high + pad)
    }

    /// Difference between the latest value and the first one in the last 30 days.
    private var change: Double? {
        guard let last = store.bodyWeights.last else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        guard let first = store.bodyWeights.first(where: { $0.date >= cutoff }), first.id != last.id else { return nil }
        return last.kg - first.kg
    }
}

// MARK: - Settings toggle

struct HealthSyncRow: View {
    @EnvironmentObject var store: AppStore
    @State private var on = HealthManager.shared.isEnabled

    var body: some View {
        if HealthManager.shared.isAvailable {
            Toggle(isOn: Binding(get: { on }, set: { newValue in
                HealthManager.shared.setEnabled(newValue) { granted in
                    on = granted
                    if granted { store.importBodyWeightFromHealth() }
                }
            })) {
                SettingsRow(icon: "heart.fill", iconColor: Color(hex: "FF6B6B"), label: store.t("settings.health")) { EmptyView() }
            }
            .tint(.gymAccent)
        }
    }
}
