import SwiftUI
import PostHog
import UniformTypeIdentifiers

/// Everything the user created, as one file they can keep in Files / iCloud Drive and restore on a new phone.
struct GymnioBackup: Codable {
    var version = 1
    var exportedAt = Date()
    var exercises: [String]
    var entries: [WorkoutEntry]
    var routines: [Routine]
    var exerciseNotes: [String: String]
    var exerciseMeta: [String: ExerciseMeta]
    var bodyWeights: [BodyWeightEntry]
    var workoutNotes: [String: String]
    /// Own exercise photos by file name.
    var photos: [String: Data]
}

extension AppStore {
    func writeBackupFile() -> URL? {
        let backup = makeBackup()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(backup) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gymnio-backup-\(f.string(from: Date())).json")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    /// Returns false when the file is not a Gymnio backup.
    func restoreBackup(from url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(GymnioBackup.self, from: data) else { return false }
        mergeBackup(backup)
        PostHogSDK.shared.capture("backup_restored", properties: ["entries": backup.entries.count])
        return true
    }
}

// MARK: - Settings rows

struct BackupRows: View {
    @EnvironmentObject var store: AppStore
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                Button {
                    shareURL = store.writeBackupFile()
                    showShare = shareURL != nil
                } label: {
                    SettingsRow(icon: "externaldrive.fill", iconColor: Color.gymAccent, label: store.t("settings.backup")) { chevron }
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 44)

                Button { showImporter = true } label: {
                    SettingsRow(icon: "arrow.counterclockwise", iconColor: Color.gymAccent, label: store.t("settings.restore")) { chevron }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL { ShareSheet(items: [shareURL], isPresented: $showShare) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                message = store.t(store.restoreBackup(from: url) ? "backup.restored" : "backup.failed")
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(store.t("common.done"), role: .cancel) {}
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
    }
}
