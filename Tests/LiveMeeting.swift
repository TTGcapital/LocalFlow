import Foundation

@main struct LiveMeetingTest {
    static func main() async throws {
        guard CommandLine.arguments.count >= 3 else { fatalError("usage: live-meeting audio expected-word") }
        let result = try await LiveMeetingTranscription().transcribe(
            source: URL(fileURLWithPath: CommandLine.arguments[1]), start: 0, duration: 20,
            locale: "auto", hints: [])
        guard case .speech(let text) = result else { fatalError("No live speech") }
        for word in CommandLine.arguments.dropFirst(2) {
            precondition(text.localizedCaseInsensitiveContains(word), "Missing \(word): \(text)")
        }
        print("PASS: compact live meeting model: \(text)")
    }
}
