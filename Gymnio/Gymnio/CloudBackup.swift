import SwiftUI

/// Automatic backup of all data to the user's iCloud Drive, so a lost or new phone does not mean lost training.
/// It is a backup (restore on demand), not live sync between devices.
enum CloudBackup {
    static let enabledKey = "@icloud_backup"
    static let lastKey = "@icloud_backup_last"

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var lastBackup: Date? {
        let t = UserDefaults.standard.double(forKey: lastKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func setEnabled(_ on: Bool) { UserDefaults.standard.set(on, forKey: enabledKey) }

    // MARK: File access (off the main thread: the iCloud container lookup can be slow)

    nonisolated private static func containerFile() -> URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("gymnio-backup.json")
    }

    nonisolated private static func write(_ data: Data) -> Bool {
        guard let url = containerFile() else { return false }
        do { try data.write(to: url, options: .atomic); return true } catch { return false }
    }

    nonisolated private static func read() -> Data? {
        guard let url = containerFile() else { return nil }
        var result: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            result = try? Data(contentsOf: readable)
        }
        return result
    }

    nonisolated private static func exists() -> Bool {
        guard let url = containerFile() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
            || FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent(".gymnio-backup.json.icloud").path)
    }

    // MARK: API

    /// Writes a fresh backup when enabled and the last one is older than six hours. Never overwrites with empty data.
    static func backupIfNeeded(store: AppStore, force: Bool = false) async {
        guard isEnabled, !store.entries.isEmpty else { return }
        if !force, let last = lastBackup, Date().timeIntervalSince(last) < 6 * 3600 { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store.makeBackup()) else { return }
        let ok = await Task.detached { write(data) }.value
        if ok { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastKey) }
    }

    static func backupExists() async -> Bool {
        await Task.detached { exists() }.value
    }

    /// Merges the iCloud backup into the app. Returns false when there is none or it cannot be read.
    static func restore(store: AppStore) async -> Bool {
        guard let data = await Task.detached(operation: { read() }).value else { return false }
        return store.restoreBackup(data: data)
    }
}

// MARK: - Settings row

struct CloudBackupRow: View {
    @EnvironmentObject var store: AppStore
    @State private var on = CloudBackup.isEnabled
    @State private var message: String?

    private var lastText: String {
        guard let last = CloudBackup.lastBackup else { return store.t("icloud.never") }
        let f = RelativeDateTimeFormatter()
        f.locale = store.locale
        return f.localizedString(for: last, relativeTo: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { on }, set: { value in
                on = value
                CloudBackup.setEnabled(value)
                if value { Task { await CloudBackup.backupIfNeeded(store: store, force: true) } }
            })) {
                SettingsRow(icon: "icloud.fill", iconColor: Color.gymAccent, label: store.t("icloud.title")) { EmptyView() }
            }
            .tint(.gymAccent)

            if on {
                Text(store.t("icloud.last") + " " + lastText)
                    .font(.system(size: 12))
                    .foregroundColor(.gymTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 44)
                    .padding(.bottom, 6)
            }

            Divider().padding(.leading, 44)

            Button {
                Task {
                    let ok = await CloudBackup.restore(store: store)
                    message = store.t(ok ? "backup.restored" : "icloud.none")
                }
            } label: {
                SettingsRow(icon: "icloud.and.arrow.down", iconColor: Color.gymAccent, label: store.t("icloud.restore")) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(store.t("common.done"), role: .cancel) {}
        }
    }
}

// MARK: - Train tab: offer the backup on a fresh install

struct CloudRestoreBanner: View {
    @EnvironmentObject var store: AppStore
    @State private var available = false
    @State private var restored = false

    var body: some View {
        Group {
            if available && !restored && store.workouts.isEmpty {
                Card(leftAccent: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.t("icloud.found.title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gymText)
                        Text(store.t("icloud.found.subtitle"))
                            .font(.system(size: 14))
                            .foregroundColor(.gymTextSecondary)
                        AccentButton(label: store.t("icloud.restore"), disabled: false) {
                            Task { restored = await CloudBackup.restore(store: store) }
                        }
                    }
                }
            }
        }
        .task {
            guard store.workouts.isEmpty, CloudBackup.isEnabled else { return }
            available = await CloudBackup.backupExists()
        }
    }
}
