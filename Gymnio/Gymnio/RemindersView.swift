import SwiftUI
import UserNotifications
import PostHog

// MARK: - Model

struct ReminderDay: Codable, Identifiable {
    var id: Int { weekday }
    var weekday: Int
    var enabled: Bool
    var hour: Int
    var minute: Int

    var timeDate: Date {
        get {
            var c = DateComponents(); c.hour = hour; c.minute = minute
            return Calendar.current.date(from: c) ?? Date()
        }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour   = c.hour   ?? 18
            minute = c.minute ?? 0
        }
    }
}

// MARK: - RemindersView

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    @State private var masterEnabled = false
    @State private var days: [ReminderDay] = Self.defaultDays()

    private let storageKey = "reminder_schedule_v2"
    private let masterKey  = "daily_reminder_enabled"

    private static func defaultDays() -> [ReminderDay] {
        let schedule: [(Int, Bool)] = [
            (2, true), (3, true), (4, true), (5, true), (6, true), (7, false), (1, false)
        ]
        return schedule.map { ReminderDay(weekday: $0.0, enabled: $0.1, hour: 18, minute: 0) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    GlassCard {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: Color.gymWarning,
                            label: store.t("reminders.title")
                        ) {
                            Toggle("", isOn: $masterEnabled)
                                .labelsHidden()
                                .onChangeCompat(of: masterEnabled) { _ in save() }
                        }
                    }

                    if masterEnabled {
                        SettingsSectionTitle(
                            title: store.t("reminders.schedule")
                        )

                        GlassCard {
                            VStack(spacing: 0) {
                                ForEach(days.indices, id: \.self) { i in
                                    ReminderDayRow(
                                        day: $days[i],
                                        label: dayName(days[i].weekday)
                                    )
                                    .onChangeCompat(of: days[i].enabled) { _ in save() }
                                    .onChangeCompat(of: days[i].hour)    { _ in save() }
                                    .onChangeCompat(of: days[i].minute)  { _ in save() }

                                    if i < days.count - 1 {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            }
                        }

                        let active = days.filter { $0.enabled }
                        if !active.isEmpty {
                            GlassCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.statBlue)
                                    Text(summaryText(active))
                                        .font(.system(size: 13))
                                        .secondaryText()
                                        .lineSpacing(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(store.t("reminders.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: load)
    }

    // MARK: - Persistence

    private func load() {
        masterEnabled = UserDefaults.standard.bool(forKey: masterKey)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ReminderDay].self, from: data) {
            days = saved
        }
    }

    private func save() {
        UserDefaults.standard.set(masterEnabled, forKey: masterKey)
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if masterEnabled {
            NotificationManager.shared.requestPermissions()
        }
        NotificationManager.shared.scheduleReminders(masterEnabled ? days : [])
        PostHogSDK.shared.capture("reminders_updated", properties: [
            "enabled": masterEnabled,
            "active_days": days.filter { $0.enabled }.count
        ])
    }

    // MARK: - Helpers

    private func dayName(_ weekday: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = store.locale
        // weekday: 1 = Sunday … 7 = Saturday, matching `shortStandaloneWeekdaySymbols`.
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : ""
    }

    private func summaryText(_ active: [ReminderDay]) -> String {
        let names = active.map { dayName($0.weekday) }.joined(separator: ", ")
        return String(format: store.t("reminders.active"), names)
    }
}

// MARK: - Day Row

struct ReminderDayRow: View {
    @Binding var day: ReminderDay
    let label: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(day.enabled ? Color.statBlue : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )

            Toggle("", isOn: $day.enabled)
                .labelsHidden()
                .frame(width: 51)

            Spacer()

            if day.enabled {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { day.timeDate },
                        set: { day.timeDate = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .foregroundColor(Color.tint(scheme))
            } else {
                Text(String(format: "%02d:%02d", day.hour, day.minute))
                    .font(.system(size: 15))
                    .secondaryText()
            }
        }
        .padding(.vertical, 10)
    }
}
