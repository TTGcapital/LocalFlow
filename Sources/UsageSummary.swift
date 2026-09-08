import Foundation

struct UsageSummary {
    let entries: [Entry]
    var dictations: [Entry] { entries.filter { $0.kind == "Dictation" && !$0.transcript.isEmpty } }
    var totalWords: Int { dictations.reduce(0) { $0 + Self.words($1.transcript) } }
    static func words(_ text: String) -> Int { text.split(whereSeparator: { $0.isWhitespace }).count }
    var wordsPerMinute: Int? {
        let measured = dictations.filter { ($0.duration ?? 0) > 0 }
        let seconds = measured.reduce(0) { $0 + ($1.duration ?? 0) }
        guard seconds > 0 else { return nil }
        return Int(Double(measured.reduce(0) { $0 + Self.words($1.transcript) }) * 60 / seconds)
    }
    var activeDays: Set<Date> { Set(dictations.map { Calendar.current.startOfDay(for: $0.date) }) }
    var currentStreak: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if !activeDays.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var streak = 0
        while activeDays.contains(day) { streak += 1; day = calendar.date(byAdding: .day, value: -1, to: day)! }
        return streak
    }
    var apps: [(String, Int)] {
        Dictionary(grouping: dictations, by: { $0.applicationName ?? "Earlier recordings" }).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
}

