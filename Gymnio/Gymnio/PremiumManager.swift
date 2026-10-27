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

    @Published private(set) var packages: [Package] = []
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

    // MARK: - Loading

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
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

    func purchase(_ package: Package) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                PostHogSDK.shared.capture("pro_purchase_cancelled", properties: ["package": package.identifier])
            } else {
                apply(customerInfo: result.customerInfo)
                PostHogSDK.shared.capture("pro_purchase_success", properties: ["package": package.identifier])
            }
        } catch {
            lastError = error.localizedDescription
            PostHogSDK.shared.capture("pro_purchase_failed", properties: ["package": package.identifier])
        }
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            PostHogSDK.shared.capture("pro_restore")
        } catch {
            lastError = error.localizedDescription
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
