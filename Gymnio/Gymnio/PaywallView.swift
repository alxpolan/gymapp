import SwiftUI
import RevenueCat
import RevenueCatUI
import PostHog

// MARK: - Store paywall

struct PaywallView: View {
    let source: String

    @EnvironmentObject var premium: PremiumManager
    @Environment(\.dismiss) private var dismiss

    @State private var appearDate = Date()
    @State private var offering: Offering?
    @State private var offeringLoaded = false

    var body: some View {
        Group {
            if !offeringLoaded {
                ProgressView()
            } else if let offering {
                RevenueCatUI.PaywallView(
                    offering: offering,
                    displayCloseButton: true,
                    performPurchase: { package in await PremiumManager.shared.purchase(package, source: source) },
                    performRestore: { await PremiumManager.shared.restore() }
                )
            } else {
                RevenueCatUI.PaywallView(
                    displayCloseButton: true,
                    performPurchase: { package in await PremiumManager.shared.purchase(package, source: source) },
                    performRestore: { await PremiumManager.shared.restore() }
                )
            }
        }
        .onPurchaseCompleted { _, _ in dismiss() }
        .task {
            offering = await premium.offering(for: source)
            offeringLoaded = true
            appearDate = Date()
            PostHogSDK.shared.capture("paywall_viewed", properties: [
                "source": source,
                "offering": offering?.identifier ?? "none"
            ])
        }
        .onDisappear {
            PostHogSDK.shared.capture("paywall_closed", properties: [
                "source": source,
                "time_on_paywall_ms": Int(Date().timeIntervalSince(appearDate) * 1000)
            ])
        }
    }
}
