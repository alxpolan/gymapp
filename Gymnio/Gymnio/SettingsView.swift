import SwiftUI
import RevenueCat
import RevenueCatUI
import PostHog
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.colorScheme) var scheme
    @State private var showPaywall = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showCustomerCenter = false
    @State private var showImporter = false
    @State private var importMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Gymnio Pro
                SettingsSectionTitle(title: store.t("settings.section.pro"))
                if premium.isPro {
                    GlassCard {
                        SettingsRow(icon: "bolt.fill", iconColor: Color.gymAccent,
                                    label: store.t("pro.active.title")) {
                            ProBadge()
                        }
                    }
                } else {
                    UpgradeCTACard(source: "settings")
                }

                GlassCard {
                    VStack(spacing: 0) {
                        if premium.isPro {
                            Button {
                                PostHogSDK.shared.capture("customer_center_opened")
                                showCustomerCenter = true
                            } label: {
                                SettingsRow(icon: "creditcard.fill", iconColor: Color.gymAccent,
                                            label: store.t("settings.manage")) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 44)
                        }

                        Button {
                            PostHogSDK.shared.capture("redeem_code_tapped")
                            Purchases.shared.presentCodeRedemptionSheet()
                        } label: {
                            SettingsRow(icon: "gift.fill", iconColor: Color.gymWarning,
                                        label: store.t("settings.redeem")) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                GlassCard {
                    Button {
                        shareURL = DataExport.writeTempFile(store: store)
                        showShare = shareURL != nil
                    } label: {
                        SettingsRow(icon: "square.and.arrow.up", iconColor: Color.gymPositive,
                                    label: store.t("settings.export")) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                GlassCard { HealthSyncRow() }

                GlassCard { CloudBackupRow() }

                BackupRows()

                GlassCard {
                    Button { showImporter = true } label: {
                        SettingsRow(icon: "square.and.arrow.down", iconColor: Color.gymAccent,
                                    label: store.t("settings.import")) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                SettingsSectionTitle(title: store.t("settings.section.preferences"))

                GlassCard {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "globe", iconColor: .statBlue, label: store.t("settings.language")) {
                            Picker("", selection: Binding(
                                get: { store.languageOverride },
                                set: { store.setLanguageOverride($0) }
                            )) {
                                ForEach(AppStore.supportedLanguages, id: \.self) { code in
                                    Text(store.t("settings.language." + code)).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.statBlue)
                        }

                        Divider().padding(.leading, 44)

                        SettingsRow(icon: "moon.fill", iconColor: Color(hex: "8e44ad"), label: store.t("settings.theme")) {
                            Picker("", selection: Binding(
                                get: { store.themeMode },
                                set: { store.setThemeMode($0) }
                            )) {
                                Text(store.t("settings.theme.system")).tag("system")
                                Text(store.t("settings.theme.light")).tag("light")
                                Text(store.t("settings.theme.dark")).tag("dark")
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.statBlue)
                        }

                        Divider().padding(.leading, 44)

                        Divider().padding(.leading, 44)

                        SettingsRow(icon: "scalemass.fill", iconColor: Color.gymPositive, label: store.t("settings.unit")) {
                            Picker("", selection: Binding(
                                get: { store.weightUnit },
                                set: { store.setWeightUnit($0) }
                            )) {
                                Text("kg").tag("kg")
                                Text("lbs").tag("lbs")
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.statBlue)
                        }

                        Divider().padding(.leading, 44)

                        SettingsRow(icon: "timer", iconColor: Color.gymAccent, label: store.t("settings.rest")) {
                            Picker("", selection: Binding(
                                get: { store.restSeconds },
                                set: { store.setRestSeconds($0) }
                            )) {
                                Text(store.t("settings.rest.off")).tag(0)
                                ForEach([60, 90, 120, 180], id: \.self) { seconds in
                                    Text("\(seconds) s").tag(seconds)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.statBlue)
                        }

                        Divider().padding(.leading, 44)

                        NavigationLink(destination: RemindersView()) {
                            SettingsRow(icon: "bell.fill", iconColor: Color.gymWarning, label: store.t("settings.notifications")) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionTitle(title: store.t("settings.section.links"))

                GlassCard {
                    VStack(spacing: 0) {
                        SettingsLinkRow(icon: "lock.shield.fill", iconColor: .statBlue,
                                        label: store.t("settings.privacy"),
                                        url: "https://gymnio.fringelo.com/privacy-policy/")
                        Divider().padding(.leading, 44)
                        SettingsLinkRow(icon: "doc.text.fill", iconColor: Color.gymPositive,
                                        label: store.t("settings.terms"),
                                        url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                    }
                }

                SettingsSectionTitle(title: store.t("settings.section.about"))

                GlassCard {
                    VStack(spacing: 0) {
                        SettingsLinkRow(icon: "chevron.left.forwardslash.chevron.right",
                                        iconColor: scheme == .dark ? Color(hex: "2c2c2e") : Color(hex: "1a1a1a"),
                                        label: store.t("settings.github"),
                                        url: "https://github.com/alexmen656/gymapp")
                        Divider().padding(.leading, 44)
                        SettingsRow(icon: "info.circle.fill", iconColor: .statBlue, label: "Gymnio") {
                            Text("v\(appVersion)")
                                .font(.system(size: 15))
                                .secondaryText()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        }
        .navigationTitle(store.t("settings.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) { PaywallView(source: "settings") }
        .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                if let summary = try? DataImport.importCSV(from: url, store: store) {
                    importMessage = String(format: store.t("settings.import.done"), summary.imported)
                } else {
                    importMessage = store.t("settings.import.error")
                }
            case .failure:
                importMessage = store.t("settings.import.error")
            }
        }
        .alert(store.t("settings.import"), isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button(store.t("common.done"), role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL], isPresented: $showShare)
            } else {
                VStack(spacing: 12) {
                    Text("DEBUG: shareURL nil").font(.title)
                    Text("entries=\(store.entries.count)")
                    Text("error=\(DataExport.debugLastError ?? "none")")
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
