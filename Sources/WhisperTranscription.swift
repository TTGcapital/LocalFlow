import Foundation
import AVFoundation

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
actor WhisperTranscription {
    static let model = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LocalFlow/Models/ggml-large-v3-turbo-q5_0.bin")
    static let accurateModel = model
    static let detectorModel = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LocalFlow/Models/ggml-base-q5_1.bin")
    private let selectedModel: URL
    private let server: WhisperServer?
    private let detector: WhisperServer?
    init(model: URL? = nil, server: WhisperServer? = nil, detector: WhisperServer? = nil) {
        selectedModel = model ?? Self.model
        self.server = server
        self.detector = detector
    }
    func transcribe(_ source: URL, locale: String, hints: [String] = [], progress: @escaping @Sendable (String) async -> Void) async throws -> String {
        guard FileManager.default.fileExists(atPath: selectedModel.path) else { throw flowError("The multilingual speech model is missing. Re-run LocalFlow setup.") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LocalFlow-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wav = directory.appendingPathComponent("audio.wav")
        await progress("Preparing audio…")
        let log = try await LocalProcess().run(URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"), arguments: ["-nostdin", "-hide_banner", "-y", "-i", source.path, "-vn", "-ac", "1", "-ar", "16000", "-af", "silencedetect=noise=-38dB:d=0.4", "-c:a", "pcm_s16le", wav.path], timeout: 60)
        let file = try AVAudioFile(forReading: wav)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration >= 0.25 else { throw flowError("That recording was too short. Hold the shortcut while speaking, then release it.") }
        var silences: [(Double, Double)] = []
        var silenceStart: Double?
        for line in log.components(separatedBy: .newlines) {
            if let range = line.range(of: "silence_start: ") { silenceStart = Double(line[range.upperBound...].split(separator: " ").first ?? "") }
            if let range = line.range(of: "silence_end: "), let start = silenceStart, let end = Double(line[range.upperBound...].split(separator: " ").first ?? "") { silences.append((start, end)); silenceStart = nil }
        }
        if let start = silenceStart { silences.append((start, duration)) }
        let silentDuration = silences.reduce(0) { $0 + $1.1 - $1.0 }
        guard duration - silentDuration > 0.2 else { throw flowError("No speech detected. Your audio is saved.") }
        let multilingual = locale == "auto"
        // Split at real pauses so a language switch gets its own route. The
        // compact detector is restricted to English/Romanian before the large
        // model runs, preventing unrelated scripts on short accented clips.
        let planned = multilingual ? SpeechSegmentation.chunks(duration: duration, silences: silences) : [SpeechChunk(start: 0, end: duration)]
        let chunks = planned.filter { chunk in
            let silence = silences.reduce(0.0) { total, span in total + max(0, min(chunk.end, span.1) - max(chunk.start, span.0)) }
            return chunk.end - chunk.start - silence > 0.2
        }
        guard !chunks.isEmpty else { throw flowError("No speech detected. Your audio is saved.") }
        let inputs: [URL]
        if chunks.count == 1, chunks[0] == SpeechChunk(start: 0, end: duration) {
            // ffmpeg has already closed and finalized this WAV.
            inputs = [wav]
        } else {
            inputs = try chunks.enumerated().map { index, chunk in
                try Task.checkCancellation()
                let target = directory.appendingPathComponent("part-\(index).wav")
                try Self.writeChunk(source: wav, destination: target, chunk: chunk)
                return target
            }
        }
        await progress(multilingual ? "Transcribing locally · English + Romanian…" : "Transcribing locally · \(locale.hasPrefix("ro") ? "Romanian" : "English")…")
        var routes = Array(repeating: locale.hasPrefix("ro") ? "ro" : "en", count: inputs.count)
        if multilingual {
            await progress("Detecting English / Romanian phrases…")
            if let detector {
                for index in inputs.indices {
                    try Task.checkCancellation()
                    let detection = try await detector.detectLanguage(file: inputs[index])
                    routes[index] = detection.language == "ro" && detection.confidence >= 0.95 ? "ro" : "en"
                }
            } else if FileManager.default.fileExists(atPath: Self.detectorModel.path) {
                var arguments = ["-m", Self.detectorModel.path, "-l", "auto", "-dl", "-ac", "256", "-t", "4", "-bs", "1", "-bo", "1"]
                for input in inputs { arguments += ["-f", input.path] }
                let detectionLog = try await LocalProcess().run(URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"), arguments: arguments, timeout: max(30, min(300, duration + 20)))
                let detections = LanguageRouting.detections(in: detectionLog)
                for index in routes.indices where index < detections.count {
                    let detection = detections[index]
                    routes[index] = detection.language == "ro" && detection.confidence >= 0.95 ? "ro" : "en"
                }
            }
        }
        var texts = Array(repeating: "", count: inputs.count)
        for language in ["en", "ro"] {
            let indices = routes.indices.filter { routes[$0] == language }
            guard !indices.isEmpty else { continue }
            await progress("Transcribing \(language == "ro" ? "Romanian" : "English") locally…")
            if let server {
                for index in indices {
                    try Task.checkCancellation()
                    texts[index] = try await server.transcribe(file: inputs[index], language: language, hints: hints)
                }
                continue
            }
            var arguments = ["-m", selectedModel.path, "-l", language, "-otxt", "-nt", "-np", "-t", "6", "-bs", "1", "-bo", "1", "-nf", "-sns"]
            if !hints.isEmpty { arguments += ["--prompt", hints.prefix(50).map { String($0.prefix(80)) }.joined(separator: ", ")] }
            var outputs: [(Int, URL)] = []
            for index in indices {
                let output = directory.appendingPathComponent("final-\(index)")
                arguments += ["-f", inputs[index].path, "-of", output.path]
                outputs.append((index, output.appendingPathExtension("txt")))
            }
            _ = try await LocalProcess().run(URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"), arguments: arguments, timeout: max(45, min(1800, duration * 1.5 + 30)))
            for (index, output) in outputs {
                texts[index] = try String(contentsOf: output, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let result = texts.filter { !$0.isEmpty && $0 != "[BLANK_AUDIO]" }.joined(separator: " ")
        guard !result.isEmpty else { throw flowError("No speech detected. Your audio is saved.") }
        return result
    }

    private static func writeChunk(source: URL, destination: URL, chunk: SpeechChunk) throws {
        let reader = try AVAudioFile(forReading: source)
        reader.framePosition = AVAudioFramePosition(chunk.start * 16000)
        let writer = try AVAudioFile(forWriting: destination, settings: reader.fileFormat.settings)
        var remaining = AVAudioFramePosition((chunk.end - chunk.start) * 16000)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: 16000) else {
            throw flowError("Could not allocate the audio buffer.")
        }
        while remaining > 0 {
            try reader.read(into: buffer, frameCount: AVAudioFrameCount(min(16000, remaining)))
            if buffer.frameLength == 0 { break }
            try writer.write(from: buffer)
            remaining -= Int64(buffer.frameLength)
        }
    }
}
