import Foundation

@main struct StreamingBenchmark {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { fatalError("usage: streaming-benchmark bilingual.wav") }
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let server = WhisperServer()
        let detector = WhisperServer(model: WhisperTranscription.detectorModel, portOffset: 1, audioContext: 256, detectsOnly: true)
        let streaming = StreamingDictationTranscription(server: server, detector: detector)
        let started = Date()
        do {
            let first = try await streaming.transcribe(source: source, start: 0, duration: 4.4, locale: "auto", hints: [])
            let second = try await streaming.transcribe(source: source, start: 4.4, duration: 6.29, locale: "auto", hints: [])
            print(String(format: "ELAPSED %.2f", Date().timeIntervalSince(started)))
            print(first)
            print(second)
        } catch {
            await server.stop(); await detector.stop()
            throw error
        }
        await server.stop(); await detector.stop()
    }
}
