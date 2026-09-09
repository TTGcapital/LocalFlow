import XCTest
@testable import LocalFlowCore

/// Tests for the portable half of LocalFlow. These run on every platform Swift
/// supports, including Windows, which is the point: they are how a Windows
/// build is verified before a Windows UI exists.
///
/// `Tests/Interaction.swift` still covers the same ground on macOS as part of
/// the app build. That overlap is deliberate for now — see issue #7. As the
/// platform layer grows, the shared assertions belong here and the macOS suite
/// should keep only what needs AppKit.
final class CoreTests: XCTestCase {

    // MARK: Text expansion

    func testExpansionReplacesWholeWordsOnly() {
        XCTAssertEqual(expand("My email is ready", rules: "my email => hello@example.com"),
                       "hello@example.com is ready")
        XCTAssertEqual(expand("the cat and catalog", rules: "cat => dog"),
                       "the dog and catalog",
                       "a rule must not fire inside a longer word")
        XCTAssertEqual(expand("cost", rules: "cost => $5"), "$5",
                       "a replacement containing $ must not be read as a capture group")
        XCTAssertEqual(expand("keep me", rules: "invalid\n => bad"), "keep me",
                       "a malformed rule is skipped rather than corrupting the text")
    }

    // MARK: Dictation cleanup guard

    func testCleanupRejectsAnswersInsteadOfRewrites() {
        let raw = "um so I think we should uh ship on Thursday no wait Friday"
        XCTAssertNil(DictationCleanup.accept(raw: raw, cleaned: "   "))
        XCTAssertNil(DictationCleanup.accept(raw: raw, cleaned: "Here is the cleaned text: ship Friday."))
        XCTAssertNil(DictationCleanup.accept(raw: raw, cleaned: "I can't help with that request."))
        XCTAssertNil(DictationCleanup.accept(raw: raw, cleaned: String(repeating: "Friday works. ", count: 20)),
                     "output that grew this much means the model answered the transcript")
        XCTAssertEqual(DictationCleanup.accept(raw: "hi", cleaned: "Hi, how are you doing today?"),
                       "Hi, how are you doing today?",
                       "short input may legitimately grow")
    }

    // MARK: Portable shortcut

    func testChordParsesFromDisplayLabel() {
        XCTAssertEqual(KeyChord(displayLabel: "⌃⇧Space"),
                       KeyChord(key: "Space", control: true, shift: true))
        XCTAssertEqual(KeyChord(displayLabel: "⌃⌥⇧⌘M"),
                       KeyChord(key: "M", control: true, alt: true, shift: true, command: true))
        XCTAssertEqual(KeyChord(displayLabel: "⌥F13")?.key, "F13")
    }

    func testChordRejectsLabelsThatCannotTravel() {
        XCTAssertNil(KeyChord(displayLabel: "M"), "a bare key is not a global shortcut")
        XCTAssertNil(KeyChord(displayLabel: "⌃Key 42"), "\"Key 42\" is a raw macOS keycode")
        XCTAssertNil(KeyChord(displayLabel: "⌃⇧"), "modifiers with no key")
    }

    // MARK: Archive compatibility

    func testArchiveWrittenBeforeKeyChordStillDecodes() throws {
        let old = #"{"locale":"auto","snippets":"","dictionary":"","style":"x","scratchpad":"","autoInsights":false,"autoPaste":true,"captureSystem":false,"transformer":"x","shortcutLabel":"⌃⇧Space"}"#
        let decoded = try JSONDecoder().decode(Preferences.self, from: Data(old.utf8))
        XCTAssertNil(decoded.shortcutChord)
        XCTAssertEqual(decoded.shortcutLabel, "⌃⇧Space")
        XCTAssertNil(decoded.cleanDictation, "an absent opt-in must not default to on")
    }

    func testEntryKeepsTheLiteralTranscriptThroughARoundTrip() throws {
        var entry = Entry(title: "Test", kind: "Dictation", transcript: "Send it by Thursday.")
        entry.rawTranscript = "um send it by uh Thursday"
        let decoded = try JSONDecoder().decode(Entry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(decoded.rawTranscript, "um send it by uh Thursday")
        XCTAssertEqual(decoded.transcript, "Send it by Thursday.")
    }

    // MARK: Meeting detection

    /// Note for the Windows port: this matcher compiles anywhere, but the data
    /// it matches on is macOS bundle identifiers. Windows reports process names
    /// ("Zoom.exe", "chrome.exe"), so the identifier set needs a platform-aware
    /// table before the Notetaker's meeting detection works there. See issue #7.
    func testMeetingMatcherIgnoresAppHomeScreens() {
        XCTAssertTrue(MeetingWindowMatcher.matches(bundle: "us.zoom.xos", title: "Zoom Meeting"))
        XCTAssertFalse(MeetingWindowMatcher.matches(bundle: "us.zoom.xos", title: "Zoom Workplace"),
                       "the app's own home window is not a call")
        XCTAssertTrue(MeetingWindowMatcher.matches(bundle: "com.google.Chrome", title: "Meet – abc-defg-hij"))
        XCTAssertFalse(MeetingWindowMatcher.matches(bundle: "com.google.Chrome", title: "Google Meet"),
                       "the Meet landing page is not a call")
        XCTAssertFalse(MeetingWindowMatcher.matches(bundle: "com.apple.TextEdit", title: "Meet – abc-defg-hij"),
                       "a matching title in an unrelated app must not count")
    }

    // MARK: Speech segmentation

    func testChunksStayWithinTheMaximumLength() {
        let chunks = SpeechSegmentation.chunks(duration: 60, silences: [(20, 21), (40, 41)], maximum: 24)
        XCTAssertFalse(chunks.isEmpty)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.end - chunk.start, 24.0 + .ulpOfOne,
                                     "a chunk longer than the maximum would blow the model's context")
            XCTAssertLessThan(chunk.start, chunk.end)
        }
        XCTAssertEqual(chunks.first?.start, 0, "the first chunk starts at the beginning of the recording")
        XCTAssertEqual(chunks.last?.end, 60, "the last chunk reaches the end, so no speech is dropped")
    }

    func testPausesTooShortToBeSentenceBreaksAreIgnored() {
        // A 0.2s gap is a breath, not a boundary. Splitting there produced
        // one-second clips whose language detection jumped to other scripts.
        let chunks = SpeechSegmentation.chunks(duration: 30, silences: [(10, 10.2)], maximum: 24)
        XCTAssertEqual(chunks.count, 2, "30s with no usable boundary still splits only to respect the maximum")
        XCTAssertEqual(chunks.first?.end, 24)
    }
}
