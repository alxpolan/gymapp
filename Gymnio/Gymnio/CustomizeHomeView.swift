import SwiftUI

struct CustomizeHomeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var scheme
    @State private var settings = HomeViewSettings()

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                GlassCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.statBlue)
                        Text(store.t("customize.info"))
                            .font(.system(size: 14))
                            .secondaryText()
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                GlassCard {
                    VStack(spacing: 0) {
                        CustomizeToggleRow(
                            icon: "arrow.up.circle.fill", iconColor: .statBlue,
                            label: String(localized: "customize.progression"),
                            isOn: $settings.showProgressionAlert
                        )
                        Divider().padding(.leading, 44)
                        CustomizeToggleRow(
                            icon: "chart.bar.fill", iconColor: .statTeal,
                            label: String(localized: "customize.stats"),
                            isOn: $settings.showStats
                        )
                        Divider().padding(.leading, 44)
                        CustomizeToggleRow(
                            icon: "chart.line.uptrend.xyaxis", iconColor: Color.gymWarning,
                            label: String(localized: "customize.charts"),
                            isOn: $settings.showCharts
                        )
                        Divider().padding(.leading, 44)
                        CustomizeToggleRow(
                            icon: "list.number", iconColor: .statRed,
                            label: String(localized: "customize.top"),
                            isOn: $settings.showTopExercises
                        )
                    }
                }

                GlassCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "fbbf24"))
                        Text(store.t("customize.tip"))
                            .font(.system(size: 14))
                            .secondaryText()
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        }
        .navigationTitle(String(localized: "customize.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { settings = store.homeSettings }
        .onChangeCompat(of: settings) { newValue in
            store.saveHomeSettings(newValue)
        }
    }
}

struct CustomizeToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(scheme == .dark ? .white : Color(hex: "1a1a1a"))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.vertical, 10)
    }
}
