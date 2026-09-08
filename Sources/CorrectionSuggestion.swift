import Foundation

struct CorrectionSuggestion: Equatable {
    let original: String
    let corrected: String
}

enum CorrectionWordDiff {
    private struct Token {
        let value: String
        let range: NSRange
    }

    private static func tokens(in text: String) -> [Token] {
        let ns = text as NSString
        let pattern = #"[\p{L}\p{N}][\p{L}\p{N}'’-]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            Token(value: ns.substring(with: $0.range), range: $0.range)
        }
    }

    static func suggestion(baseline: String, edited: String, insertedRange: NSRange) -> CorrectionSuggestion? {
        guard baseline != edited else { return nil }
        let before = tokens(in: baseline), after = tokens(in: edited)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix].value == after[prefix].value { prefix += 1 }
        var suffix = 0
        while suffix < min(before.count - prefix, after.count - prefix),
              before[before.count - suffix - 1].value == after[after.count - suffix - 1].value { suffix += 1 }

        let oldEnd = before.count - suffix, newEnd = after.count - suffix
        guard prefix < oldEnd, prefix < newEnd else { return nil }
        let old = Array(before[prefix..<oldEnd]), new = Array(after[prefix..<newEnd])
        guard old.count <= 3, new.count <= 3 else { return nil }
        let changedRange = NSRange(location: old.first!.range.location,
                                   length: NSMaxRange(old.last!.range) - old.first!.range.location)
        guard NSIntersectionRange(changedRange, insertedRange).length > 0 else { return nil }
        let original = old.map(\.value).joined(separator: " ")
        let corrected = new.map(\.value).joined(separator: " ")
        guard original != corrected, original.count <= 80, corrected.count <= 80 else { return nil }
        return CorrectionSuggestion(original: original, corrected: corrected)
    }
}
