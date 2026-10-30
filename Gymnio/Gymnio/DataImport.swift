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

        let rows = parse(text)
        guard rows.count > 1 else { throw ImportError.noRows }
        let header = rows[0].map { $0.lowercased() }
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
