import Foundation
import HealthKit

/// Optional Apple Health sync: writes finished workouts and body weight, reads body weight.
nonisolated final class HealthManager: @unchecked Sendable {
    static let shared = HealthManager()
    private let store = HKHealthStore()
    private let enabledKey = "@health_sync"

    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) && isAvailable }

    func setEnabled(_ on: Bool, completion: @escaping (Bool) -> Void) {
        guard on else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            completion(false)
            return
        }
        guard isAvailable else { completion(false); return }
        let write: Set<HKSampleType> = [HKObjectType.workoutType(), bodyMass]
        let read: Set<HKObjectType> = [bodyMass]
        store.requestAuthorization(toShare: write, read: read) { granted, _ in
            UserDefaults.standard.set(granted, forKey: self.enabledKey)
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func saveWorkout(start: Date, end: Date) {
        guard isEnabled, end > start else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        builder.beginCollection(withStart: start) { ok, _ in
            guard ok else { return }
            builder.endCollection(withEnd: end) { ok, _ in
                guard ok else { return }
                builder.finishWorkout { _, _ in }
            }
        }
    }

    func saveBodyWeight(kg: Double, date: Date) {
        guard isEnabled else { return }
        let sample = HKQuantitySample(type: bodyMass, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        store.save(sample) { _, _ in }
    }

    /// Recent body weight samples (kg), newest first.
    func recentBodyWeights(limit: Int = 60, completion: @escaping ([(date: Date, kg: Double)]) -> Void) {
        guard isEnabled else { completion([]); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: bodyMass, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
            let result = (samples as? [HKQuantitySample])?.map {
                (date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            } ?? []
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(query)
    }
}
