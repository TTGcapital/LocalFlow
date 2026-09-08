import Foundation
@main struct MultilingualTest {
    static func main() async throws {
        setbuf(stdout, nil)
        let path = CommandLine.arguments[1]
        let language = CommandLine.arguments[2]
        let time = Date()
        let result: String
        do { result = try await WhisperTranscription().transcribe(URL(fileURLWithPath: path), locale: language) { print($0) } }
        catch {
            if CommandLine.arguments.contains("--expect-silence"), error.localizedDescription.contains("No speech detected") { print("PASS: silent recording rejected without running transcription"); return }
            throw error
        }
        guard !CommandLine.arguments.contains("--expect-silence") else { throw flowError("Silence was transcribed") }
        print(result)
        for expected in CommandLine.arguments.dropFirst(3) { guard result.localizedCaseInsensitiveContains(expected) else { throw flowError("Missing expected word: \(expected)") } }
        print("PASS: \(language) transcription in \(String(format: "%.1f", Date().timeIntervalSince(time))) seconds")
    }
}
