import Foundation
@main struct Smoke {
    static func main() async throws {
        setbuf(stdout, nil)
        switch CommandLine.arguments.dropFirst().first {
        case "claude":
            let bridge = ClaudeBridge()
            print(try await bridge.status())
            let result = try await bridge.transform(text: "We agreed to ship the prototype on Friday. Sebastian will test dictation tomorrow.", instruction: "Extract the decision and action item as two concise bullet points.")
            guard result.lowercased().contains("friday"), result.lowercased().contains("sebastian") else { throw flowError("Summary omitted expected information") }
            print("PASS: Claude summary returned expected decision and owner")
        case "cleanup":
            let bridge = ClaudeBridge()
            print(try await bridge.status())
            let raw = "Hey, can you send me the report by Tuesday, oh no, sorry, by Thursday. I want to, um, I want to review it before the, uh, before the client meeting. Also please cc John, sorry I mean Jane, on the email."
            guard let cleaned = try await bridge.cleanDictation(raw) else { throw flowError("Cleanup result was rejected by the guard") }
            print(cleaned)
            let lower = cleaned.lowercased()
            guard lower.contains("thursday"), !lower.contains("tuesday"), lower.contains("jane"), !lower.contains("john"), !lower.contains("sorry"), !lower.contains(" um") else { throw flowError("Cleanup did not apply the spoken self-corrections") }
            print("PASS: Claude cleanup applied spoken self-corrections and dropped fillers")
        case "mix":
            let input = URL(fileURLWithPath: CommandLine.arguments[2])
            let output = input.deletingLastPathComponent().appendingPathComponent("mixed-test-\(UUID()).m4a")
            try await MeetingAudio.mix(microphone: input, system: input, destination: output)
            let result = try await Transcription().transcribe(output, locale: "en-US") { print($0) }
            guard result.lowercased().contains("friday") else { throw flowError("Mixed audio transcription missing content") }
            print("PASS: mixed audio export and transcription")
        case "speech":
            let result = try await Transcription().transcribe(URL(fileURLWithPath: CommandLine.arguments[2]), locale: "en-US") { print($0) }
            print(result)
            guard result.lowercased().contains("meeting"), result.lowercased().contains("friday") else { throw flowError("Transcription missing expected words") }
            print("PASS: local file transcription")
        default:
            precondition(expand("My email is ready", rules: "my email => hello@example.com") == "hello@example.com is ready")
            precondition(expand("the cat and catalog", rules: "cat => dog") == "the dog and catalog")
            precondition(expand("cost", rules: "cost => $5") == "$5")
            precondition(expand("keep me", rules: "invalid\n => bad") == "keep me")
            let archive = Archive(entries: [Entry(title: "Test", kind: "Notetaker", transcript: "A note")], preferences: Preferences())
            let decoded = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
            precondition(decoded.entries == archive.entries)
            let old = "{\"id\":\"B95BF835-2CCA-4C77-B048-111ECE620591\",\"title\":\"Old\",\"kind\":\"Dictation\",\"date\":0,\"transcript\":\"hello\",\"insights\":\"\"}"
            _ = try JSONDecoder().decode(Entry.self, from: Data(old.utf8))
            print("PASS: phrase boundaries, case folding, literal replacements, malformed rules, archive round-trip and missing optional audio")
        }
    }
}
