import Foundation
import Combine
import RevenueCat
import SwiftUI
import PostHog

@MainActor
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    static let revenueCatAPIKey = "appl_oHLkiQEDhlOYMGMfQLTfuesBoKx"
    static let entitlementID = "pro"
    static let freeEntryLimitFlag = "free_entry_limit"
    static let defaultFreeEntryLimit = 30

    @Published private(set) var packages: [Package] = []
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseInFlight: Bool = false
    @Published var lastError: String?

    private let uiTestForcePro = ProcessInfo.processInfo.arguments.contains("-ui_test_pro")
    private var streamTask: Task<Void, Never>?

    private init() {
        if uiTestForcePro { isPro = true }
    }

    func start() {
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                self.apply(customerInfo: info)
            }
        }
        Task {
            await refresh()
            await loadOfferings()
        }
    }

    deinit { streamTask?.cancel() }

    // MARK: - Package accessors (by RevenueCat package type)

    var annual: Package?   { packages.first { $0.packageType == .annual } }
    var monthly: Package?  { packages.first { $0.packageType == .monthly } }
    var lifetime: Package? { packages.first { $0.packageType == .lifetime } }

    var annualSavingPercent: Int? {
        guard let m = monthly?.storeProduct.price, let y = annual?.storeProduct.price, m > 0 else { return nil }
        let perMonth = y / 12
        let saving = (m - perMonth) / m
        let pct = Int((saving as NSDecimalNumber).doubleValue * 100)
        return pct > 0 ? pct : nil
    }

    func monthlyEquivalentString(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }
        let product = package.storeProduct
        let perMonth = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? .current
        return formatter.string(from: perMonth as NSDecimalNumber)
    }

    // MARK: - Paywall rules

    var freeEntryLimit: Int {
        let raw = PostHogSDK.shared.getFeatureFlag(Self.freeEntryLimitFlag)
        if let number = raw as? NSNumber { return max(number.intValue, 0) }
        if let text = raw as? String, let value = Int(text) { return max(value, 0) }
        return Self.defaultFreeEntryLimit
    }

    var isPaywallSuppressedRegion: Bool {
        Locale.current.region?.identifier == "RU"
    }

    // MARK: - Loading

    func loadOfferings(source: String? = nil) async {
        do {
            let offerings = try await Purchases.shared.offerings()
            var resolved = offerings.current
            if let source, let named = offerings.offering(identifier: "paywall_" + source) {
                resolved = named
            }
            currentOffering = resolved
            if let current = resolved {
                let order: [PackageType] = [.annual, .monthly, .lifetime]
                packages = current.availablePackages.sorted { a, b in
                    (order.firstIndex(of: a.packageType) ?? 99) < (order.firstIndex(of: b.packageType) ?? 99)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Purchase / restore

    nonisolated static func isEntryLimitReached(entryCount: Int, limit: Int, isPro: Bool, suppressedRegion: Bool) -> Bool {
        guard !isPro && !suppressedRegion else { return false }
        return entryCount >= limit
    }

    @discardableResult
    func purchase(_ package: Package, source: String) async -> (userCancelled: Bool, error: Error?) {
        let tapDate = Date()
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        PostHogSDK.shared.capture("paywall_subscribe_tapped", properties: [
            "source": source,
            "package": package.identifier
        ])
        do {
            let result = try await Purchases.shared.purchase(package: package)
            let elapsedMs = Int(Date().timeIntervalSince(tapDate) * 1000)
            if result.userCancelled {
                PostHogSDK.shared.capture("purchase_cancelled", properties: [
                    "source": source,
                    "package": package.identifier,
                    "time_since_tap_ms": elapsedMs
                ])
                return (true, nil)
            } else {
                apply(customerInfo: result.customerInfo)
                PostHogSDK.shared.capture("purchase_completed", properties: [
                    "source": source,
                    "package": package.identifier,
                    "time_since_tap_ms": elapsedMs
                ])
                return (false, nil)
            }
        } catch {
            lastError = error.localizedDescription
            let elapsedMs = Int(Date().timeIntervalSince(tapDate) * 1000)
            PostHogSDK.shared.capture("purchase_failed", properties: [
                "source": source,
                "package": package.identifier,
                "error": error.localizedDescription,
                "time_since_tap_ms": elapsedMs
            ])
            return (false, error)
        }
    }

    @discardableResult
    func restore() async -> (success: Bool, error: Error?) {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            PostHogSDK.shared.capture("pro_restore")
            return (true, nil)
        } catch {
            lastError = error.localizedDescription
            return (false, error)
        }
    }

    // MARK: - Entitlements

    func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        if uiTestForcePro { isPro = true; return }
        isPro = customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }
}
