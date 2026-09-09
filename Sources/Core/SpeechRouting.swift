import Foundation

struct SpeechChunk: Equatable { let start: Double; let end: Double }
struct LanguageDetection: Equatable { let language: String; let confidence: Double }
enum LanguageRouting {
    static func detections(in log: String) -> [LanguageDetection] {
        guard let regex = try? NSRegularExpression(pattern: #"auto-detected language: ([a-z]+) \(p = ([0-9.]+)\)"#) else { return [] }
        let ns = log as NSString
        return regex.matches(in: log, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges == 3, let confidence = Double(ns.substring(with: match.range(at: 2))) else { return nil }
            return LanguageDetection(language: ns.substring(with: match.range(at: 1)), confidence: confidence)
        }
    }
    static func needsEnglishRetry(_ detection: LanguageDetection?, text: String) -> Bool {
        if containsUnsupportedScript(text) { return true }
        guard let detection else { return false }
        if detection.language == "en" { return false }
        if detection.language == "ro" { return detection.confidence < 0.95 }
        return true
    }
    static func containsUnsupportedScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0400...0x052F, 0x0600...0x06FF, 0x3040...0x30FF, 0x3400...0x9FFF, 0xAC00...0xD7AF: true
            default: false
            }
        }
    }
}
struct SpeechSegmentation {
    static func chunks(duration: Double, silences: [(Double, Double)], maximum: Double = 24) -> [SpeechChunk] {
        var boundaries = [0.0]
        // Very short pauses created one-to-two-second clips. Automatic language
        // detection on those clips can jump to unrelated languages and scripts.
        for (start, end) in silences where end - start >= 0.65 {
            let middle = (start + end) / 2
            if middle - (boundaries.last ?? 0) >= 2.5 && duration - middle >= 1.0 { boundaries.append(middle) }
        }
        boundaries.append(duration)
        var result: [SpeechChunk] = []
        for pair in zip(boundaries, boundaries.dropFirst()) {
            var start = pair.0
            while pair.1 - start > maximum { result.append(SpeechChunk(start: start, end: start + maximum)); start += maximum }
            if pair.1 - start > 0.15 { result.append(SpeechChunk(start: start, end: pair.1)) }
        }
        return result
    }
}
