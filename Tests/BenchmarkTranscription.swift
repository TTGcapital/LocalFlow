import Foundation

@main struct BenchmarkTranscription {
    static func main() async throws {
        guard CommandLine.arguments.count >= 3 else { fatalError("usage: benchmark audio small|large") }
        let model = CommandLine.arguments[2] == "large" ? WhisperTranscription.accurateModel : WhisperTranscription.model
        let started = Date()
        let locale = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "auto"
        let server = WhisperServer(model: model)
        let detector = WhisperServer(model: WhisperTranscription.detectorModel, portOffset: 1, audioContext: 256, detectsOnly: true)
        let text: String
        do {
            text = try await WhisperTranscription(model: model, server: server, detector: detector).transcribe(URL(fileURLWithPath: CommandLine.arguments[1]), locale: locale) { message in
                print(String(format: "PHASE %.2f %@", Date().timeIntervalSince(started), message))
            }
        } catch {
            await server.stop()
            await detector.stop()
            throw error
        }
        print(String(format: "ELAPSED %.2f", Date().timeIntervalSince(started)))
        print(text)
        await server.stop()
        await detector.stop()
    }
}
