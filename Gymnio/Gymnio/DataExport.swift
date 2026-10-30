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

    static var debugLastError: String?

    static func writeTempFile(store: AppStore) -> URL? {
        let content = csv(store: store)
        let name = "gymnio-export.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try content.data(using: .utf8)?.write(to: url, options: .atomic)
            debugLastError = nil
            return url
        } catch {
            debugLastError = "\(error)"
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

private func shareDebugLog(_ msg: String) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("share_debug.log")
    let line = "\(Date()) \(msg)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let fh = try? FileHandle(forWritingTo: url) {
        fh.seekToEndOfFile()
        fh.write(data)
        try? fh.close()
    } else {
        try? data.write(to: url)
    }
}

private final class ActivityHostController: UIViewController {
    var items: [Any] = []
    var onComplete: (() -> Void)?
    private var didPresent = false
    private let debugLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        shareDebugLog("viewDidLoad")
        view.backgroundColor = .red
        debugLabel.text = "viewDidLoad"
        debugLabel.frame = CGRect(x: 20, y: 100, width: 350, height: 40)
        debugLabel.textColor = .white
        view.addSubview(debugLabel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shareDebugLog("viewWillAppear, parent=\(String(describing: parent)), presentingVC=\(String(describing: presentingViewController))")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shareDebugLog("viewDidAppear, didPresent=\(didPresent)")
        guard !didPresent else { return }
        didPresent = true
        view.backgroundColor = .green
        debugLabel.text = "viewDidAppear, presenting..."
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        activityVC.completionWithItemsHandler = { [weak self] activityType, completed, _, error in
            shareDebugLog("completionWithItemsHandler activityType=\(String(describing: activityType)) completed=\(completed) error=\(String(describing: error))")
            self?.onComplete?()
        }
        shareDebugLog("about to call present()")
        present(activityVC, animated: false) { [weak self] in
            shareDebugLog("present completion handler fired")
            self?.view.backgroundColor = .blue
            self?.debugLabel.text = "present completion fired"
        }
        shareDebugLog("present() call returned (synchronously)")
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
