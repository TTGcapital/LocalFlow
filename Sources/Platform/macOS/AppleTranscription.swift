import AVFoundation
import Foundation
import Speech

actor Transcription {
    func transcribe(_ url: URL, locale: String, progress: @escaping @Sendable (String) async -> Void) async throws -> String {
        let initialFile = try AVAudioFile(forReading: url)
        guard initialFile.length > 0 else { throw flowError("The recording contains no audio frames. Please record again.") }
        await progress("Checking the local speech model…")
        guard SpeechTranscriber.isAvailable else { throw flowError("Apple transcription is unavailable on this Mac.") }
        guard let language = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: locale)) else { throw flowError("This language is not supported by Apple's local speech model. Choose another language in Settings. Your recording is saved.") }
        let transcriber = SpeechTranscriber(locale: language, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            await progress("Downloading Apple's speech model for the first use…")
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let reader = Task<String, Error> {
            var chunks: [String] = []
            for try await result in transcriber.results {
                chunks.append(String(result.text.characters))
                await progress("Transcribing on your Mac…")
            }
            return chunks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let file = try AVAudioFile(forReading: url)
                try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
                let text = try await reader.value
                try Task.checkCancellation()
                guard !text.isEmpty else { throw flowError("No speech detected. The audio is saved; you can play it or retry transcription.") }
                return text
            } catch {
                reader.cancel()
                await analyzer.cancelAndFinishNow()
                throw error
            }
        } onCancel: {
            reader.cancel()
            Task { await analyzer.cancelAndFinishNow() }
        }
    }
}
