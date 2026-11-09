import SwiftUI
import UniformTypeIdentifiers

enum DataExport {

    static func csv(store: AppStore) -> String {
        let unit = store.unitLabel
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        var lines = ["date,exercise,weight_\(unit),reps,volume_\(unit)"]
        for entry in store.entries.sorted(by: { WorkoutEntry.chronological($0, $1) }) {
            let date = iso.string(from: entry.date)
            let weight = store.displayWeight(entry.weight)
            let volume = weight * Double(entry.reps)
            let name = escape(entry.exercise)
            lines.append(String(format: "%@,%@,%.2f,%d,%.2f", date, name, weight, entry.reps, volume))
        }
        return lines.joined(separator: "\n")
    }

    static func writeTempFile(store: AppStore) -> URL? {
        let content = csv(store: store)
        let name = "gymnio-export.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try content.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

private final class ActivityHostController: UIViewController {
    var items: [Any] = []
    var onComplete: (() -> Void)?
    private var didPresent = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresent else { return }
        didPresent = true
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.onComplete?()
        }
        present(activityVC, animated: true)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = ActivityHostController()
        vc.items = items
        vc.onComplete = { isPresented = false }
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}
