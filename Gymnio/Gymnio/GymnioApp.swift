
import SwiftUI
import PostHog
import RevenueCat

private let posthogProjectToken = "phc_sHgt5mebzfYAbx2XAwRGyaVKJ4ToEj96XTgUdZTambdT"
private let posthogHost = "https://eu.i.posthog.com"

@main
struct GymnioApp: App {
    @StateObject private var store = AppStore.shared
    @StateObject private var premium = PremiumManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let config = PostHogConfig(apiKey: posthogProjectToken, host: posthogHost)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = false
        config.sessionReplayConfig.maskAllImages = false
        config.flushAt = 1
        config.flushIntervalSeconds = 10
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(["app_name": "Gymnio"])

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: PremiumManager.revenueCatAPIKey)
        PremiumManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(premium)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                PostHogSDK.shared.flush()
            }
        }
    }
}
