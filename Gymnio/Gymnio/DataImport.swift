import Foundation

/// Reads the CSV written by `DataExport` (date,exercise,weight_<unit>,reps,volume_<unit>) back into entries.
enum DataImport {

    struct Result {
        let imported: Int
        let skipped: Int
    }

    enum ImportError: Error { case unreadable, noRows }

    static func importCSV(from url: URL, store: AppStore) throws -> Result {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { throw ImportError.unreadable }

        let rows = parse(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        guard rows.count > 1 else { throw ImportError.noRows }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        if header.contains("exercise_title") && header.contains("start_time") {
            return try importWorkoutExport(rows: rows, header: header, format: .hevy, store: store)
        }
        if header.contains("exercise name") && header.contains("set order") {
            return try importWorkoutExport(rows: rows, header: header, format: .strong, store: store)
        }
        guard let dateIdx = header.firstIndex(of: "date"),
              let exerciseIdx = header.firstIndex(of: "exercise"),
              let repsIdx = header.firstIndex(of: "reps"),
              let weightIdx = header.firstIndex(where: { $0.hasPrefix("weight") }) else { throw ImportError.unreadable }
        let isLbs = header[weightIdx].hasSuffix("lbs")

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let calendar = Calendar.current

        var known = Set(store.entries.map { key($0.exercise, $0.date, $0.weight, $0.reps, calendar) })
        var imported = 0, skipped = 0

        for row in rows.dropFirst() {
            guard row.indices.contains(dateIdx), row.indices.contains(exerciseIdx),
                  row.indices.contains(weightIdx), row.indices.contains(repsIdx),
                  let date = iso.date(from: row[dateIdx]),
                  let weight = Double(row[weightIdx].replacingOccurrences(of: ",", with: ".")),
                  let reps = Int(row[repsIdx]), reps > 0, weight >= 0 else { skipped += 1; continue }
            let name = row[exerciseIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { skipped += 1; continue }
            let kg = isLbs ? weight / 2.20462 : weight
            let id = key(name, date, kg, reps, calendar)
            guard !known.contains(id) else { skipped += 1; continue }
            known.insert(id)
            store.importEntry(WorkoutEntry.create(exercise: name, weight: kg, reps: reps, date: date))
            imported += 1
        }
        store.finishImport()
        return Result(imported: imported, skipped: skipped)
    }

    // MARK: - Hevy and Strong exports

    private enum Format { case hevy, strong }

    private static let dateFormats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "d MMM yyyy, HH:mm", "dd MMM yyyy, HH:mm",
                                      "MMM d, yyyy, h:mm a", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"]

    private static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            f.dateFormat = format
            if let date = f.date(from: text.trimmingCharacters(in: .whitespaces)) { return date }
        }
        return nil
    }

    /// Imports whole trainings (with warm-up/drop/failure sets and RPE) from a Hevy or Strong export.
    private static func importWorkoutExport(rows: [[String]], header: [String], format: Format, store: AppStore) throws -> Result {
        func column(_ names: [String]) -> Int? { names.compactMap { header.firstIndex(of: $0) }.first }
        guard let dateIdx = column(format == .hevy ? ["start_time"] : ["date"]),
              let exerciseIdx = column(format == .hevy ? ["exercise_title"] : ["exercise name"]),
              let repsIdx = column(["reps"]) else { throw ImportError.unreadable }
        let weightIdx = column(format == .hevy ? ["weight_kg", "weight_lbs"] : ["weight"])
        let typeIdx = column(format == .hevy ? ["set_type"] : ["set order"])
        let secondsIdx = column(format == .hevy ? ["duration_seconds"] : ["seconds"])
        let rpeIdx = column(["rpe"])
        let titleIdx = column(format == .hevy ? ["title"] : ["workout name"])
        let weightIsKg = format == .hevy ? header.contains("weight_kg") || !header.contains("weight_lbs") : store.weightUnit == "kg"

        var known = Set(store.entries.map { Int($0.date.timeIntervalSince1970 / 60) })
        var workoutIds: [String: String] = [:]
        var imported = 0, skipped = 0

        func value(_ row: [String], _ idx: Int?) -> String {
            guard let idx, row.indices.contains(idx) else { return "" }
            return row[idx].trimmingCharacters(in: .whitespaces)
        }

        for row in rows.dropFirst() {
            let rawType = value(row, typeIdx).lowercased()
            if rawType == "rest timer" { continue }
            let dateText = value(row, dateIdx)
            let name = value(row, exerciseIdx)
            guard let date = parseDate(dateText), !name.isEmpty else { skipped += 1; continue }
            let minute = Int(date.timeIntervalSince1970 / 60)
            let workoutKey = dateText + "|" + value(row, titleIdx)
            if workoutIds[workoutKey] == nil {
                guard !known.contains(minute) else { skipped += 1; continue }
                workoutIds[workoutKey] = "imp-" + UUID().uuidString
                known.insert(minute)
            }
            let reps = Int(value(row, repsIdx).replacingOccurrences(of: ",", with: ".").split(separator: ".").first ?? "")
                ?? Int(value(row, secondsIdx).split(separator: ".").first ?? "") ?? 0
            let weightValue = Double(value(row, weightIdx).replacingOccurrences(of: ",", with: ".")) ?? 0
            guard reps > 0, weightValue >= 0 else { skipped += 1; continue }
            let kg = weightIsKg ? weightValue : weightValue / 2.20462
            let kind: SetKind?
            switch rawType {
            case "warmup", "w": kind = .warmup
            case "dropset", "d": kind = .drop
            case "failure", "f": kind = .failure
            default: kind = nil
            }
            let rpe = Double(value(row, rpeIdx).replacingOccurrences(of: ",", with: "."))
            store.importEntry(WorkoutEntry.create(exercise: name, weight: kg, reps: reps, date: date,
                                                  workoutId: workoutIds[workoutKey], kind: kind, rpe: (rpe ?? 0) > 0 ? rpe : nil))
            imported += 1
        }
        store.finishImport()
        return Result(imported: imported, skipped: skipped)
    }

    // Same set on the same day counts as a duplicate (weights are compared at the CSV's 2-decimal precision).
    private static func key(_ exercise: String, _ date: Date, _ kg: Double, _ reps: Int, _ calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date).timeIntervalSince1970
        return "\(exercise.lowercased())|\(Int(day))|\(Int((kg * 100).rounded()))|\(reps)"
    }

    /// Minimal CSV parser with quoted fields and escaped quotes.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = text.replacingOccurrences(of: "\r\n", with: "\n").makeIterator()
        var pending: Character?

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return chars.next()
        }

        while let c = next() {
            if inQuotes {
                if c == "\"" {
                    if let n = next() {
                        if n == "\"" { field.append("\"") } else { inQuotes = false; pending = n }
                    } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n":
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                default: field.append(c)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
