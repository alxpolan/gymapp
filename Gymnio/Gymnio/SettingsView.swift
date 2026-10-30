import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.colorScheme) var scheme
    @State private var showPaywall = false
    @State private var shareURL: URL?
    @State private var showShare = false

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
                        SettingsRow(icon: "bolt.fill", iconColor: Color(hex: "A06BFF"),
                                    label: store.t("pro.active.title")) {
                            ProBadge()
                        }
                    }
                } else {
                    UpgradeCTACard(source: "settings")
                }

                GlassCard {
                    Button {
                        if premium.isPro {
                            shareURL = DataExport.writeTempFile(store: store)
                            showShare = shareURL != nil
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        SettingsRow(icon: "square.and.arrow.up", iconColor: Color(hex: "34c759"),
                                    label: store.t("settings.export")) {
                            if premium.isPro {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                            } else {
                                ProBadge()
                            }
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

                        SettingsRow(icon: "scalemass.fill", iconColor: Color(hex: "34c759"), label: store.t("settings.unit")) {
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

                        SettingsRow(icon: "timer", iconColor: Color(hex: "5B8DEF"), label: store.t("settings.rest")) {
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
                            SettingsRow(icon: "bell.fill", iconColor: Color(hex: "FF9500"), label: store.t("settings.notifications")) {
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
                        SettingsLinkRow(icon: "doc.text.fill", iconColor: Color(hex: "34c759"),
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
