import Foundation

// The contract between LocalFlow's portable logic and the operating system.
//
// Every capability the app needs from the OS is declared here, with no Apple or
// Windows types in any signature — only Foundation values, closures and
// async/throws. `Platform/macOS` implements these with AppKit, Carbon,
// AVFoundation, ScreenCaptureKit and CoreAudio; a `Platform/Windows` folder
// would implement the same protocols with Win32, WASAPI and UI Automation.
//
// Rule for contributors: if a signature below mentions a platform type, the
// abstraction is wrong. Fix the signature, not the implementation.

// MARK: - Permissions

enum PermissionState { case granted, denied, notDetermined }

protocol MicrophonePermission {
    var microphoneState: PermissionState { get }
    func requestMicrophoneAccess() async -> Bool
}

/// Permission to observe global input and write text into other applications.
/// macOS calls this Accessibility; Windows grants it without a prompt, so the
/// Windows implementation reports `.granted` and never calls back.
protocol AutomationPermission {
    var isAutomationTrusted: Bool { get }
    func promptForAutomationTrust()
    /// macOS has no change notification and must poll; Windows fires once.
    func observeTrustChanges(_ onChange: @escaping (Bool) -> Void)
}

// MARK: - Audio capture and playback

protocol MicrophoneRecorder: AnyObject {
    func start(writingTo url: URL) throws
    /// Returns the final duration in seconds, or nil if nothing was recorded.
    func stop() -> Double?
    var isRecording: Bool { get }
    /// Seconds recorded so far. Drives both the max-length watchdog and the
    /// phrase-boundary heuristic, so it must keep advancing during a recording.
    var elapsed: Double { get }
    /// Normalized 0...1 input level for the waveform. Already smoothed, so the
    /// caller does not need to know about decibels.
    func currentLevel() -> Float
}

protocol AudioPlayback: AnyObject {
    func play(fileAt url: URL) throws
    func stop()
}

/// Capture of what the computer is playing, for the Notetaker.
///
/// macOS routes this through ScreenCaptureKit, which is why it needs a screen
/// recording permission and a dummy video stream. Windows uses WASAPI loopback
/// and needs neither, so no display or window filter appears in this contract.
///
/// The destination is fixed at construction rather than passed to `start`.
/// That is not a stylistic choice: the capture callback writes samples as they
/// arrive, so the file has to exist before the stream opens, and a capture
/// object is bound to one recording for its life. An earlier draft of this
/// protocol had `start(writingTo:)` and could not be implemented.
protocol SystemAudioCapture: AnyObject {
    init(destination: URL)
    func start() async throws
    func stop() async throws
}

protocol AudioMixdown {
    /// Combines the microphone and system tracks into one file for the archive.
    static func mix(microphone: URL, system: URL, destination: URL) async throws
}

/// Reading and slicing recorded audio, for chunked transcription.
protocol PCMFileTools {
    func duration(of url: URL) throws -> Double
    func extractRange(source: URL, destination: URL, start: Double, end: Double) throws
    func convert(source: URL, destination: URL) async throws
}

// MARK: - Output devices

struct AudioDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

protocol AudioDevices {
    var inputs: [AudioDevice] { get }
    var defaultInputID: String { get }
    func setDefaultInput(_ id: String) -> Bool
}

/// Silences the speakers while dictating so the microphone does not pick up
/// playback, then restores exactly what was there before.
///
/// `@MainActor` because the macOS implementation keeps the saved per-device
/// state as mutable class properties touched from the UI and from a timer;
/// without the annotation the conformance does not compile under strict
/// concurrency. A Windows implementation is free to do less work on the main
/// thread, but it must satisfy the same isolation.
@MainActor
protocol OutputMuting: AnyObject {
    var isEngaged: Bool { get }
    func mute() throws
    /// Re-applies the mute if the default output device changed mid-recording.
    /// Called on a timer while recording, so it must be cheap and idempotent.
    func refreshForCurrentDevice() throws
    func restore()
}

// MARK: - Global input

/// A keyboard shortcut, described in terms a human recognizes rather than in
/// platform virtual-key codes.
///
/// This deliberately replaces the raw Carbon keycode and modifier bitmask that
/// LocalFlow persisted before: those numbers mean nothing on Windows, and they
/// were being written into the otherwise portable archive.
struct KeyChord: Codable, Equatable {
    /// "Space", "M", "F13" — a name, not a scancode.
    var key: String
    var control = false
    var alt = false
    var shift = false
    var command = false

    init(key: String, control: Bool = false, alt: Bool = false, shift: Bool = false, command: Bool = false) {
        self.key = key
        self.control = control
        self.alt = alt
        self.shift = shift
        self.command = command
    }

    /// Recovers a chord from the display label LocalFlow has always stored
    /// ("⌃⇧Space", "⌃⌥M"), so archives written before this type existed gain a
    /// portable shortcut without the user re-recording it.
    ///
    /// The label is generated by LocalFlow itself in a fixed order — ⌃ ⌥ ⇧ ⌘
    /// then the key name — so parsing it is reliable in a way that parsing
    /// arbitrary user text would not be.
    init?(displayLabel label: String) {
        var rest = Substring(label)
        var control = false, alt = false, shift = false, command = false
        loop: while let symbol = rest.first {
            switch symbol {
            case "⌃": control = true
            case "⌥": alt = true
            case "⇧": shift = true
            case "⌘": command = true
            default: break loop
            }
            rest = rest.dropFirst()
        }
        let name = rest.trimmingCharacters(in: .whitespaces)
        // "Key 42" is the fallback the recorder writes when it cannot name the
        // key; that number is a macOS keycode and means nothing elsewhere.
        guard !name.isEmpty, !name.hasPrefix("Key "), control || alt || command else { return nil }
        self.init(key: name, control: control, alt: alt, shift: shift, command: command)
    }
}

protocol GlobalHotkeys: AnyObject {
    /// Throws when another application already owns the chord.
    func register(id: String, chord: KeyChord, onDown: @escaping () -> Void, onUp: @escaping () -> Void) throws
    func unregister(id: String)
    func unregisterAll()
}

///
/// A failable initializer rather than a `register` call returning `Bool`: the
/// hook either exists for the lifetime of the object or was never created, and
/// macOS cannot install one at all without the Accessibility grant. The caller
/// falls back to a plain event monitor when this returns nil.
///
/// One closure taking `down` rather than separate `onDown`/`onUp` — both
/// platforms deliver press and release through a single low-level callback
/// (`CGEventTap` here, `WH_MOUSE_LL` there), and splitting them in the protocol
/// only forces every implementation to fan one callback into two.
protocol GlobalMouseShortcut: AnyObject {
    /// `button` is a zero-based extra-button index (the side buttons).
    init?(button: Int, action: @escaping @MainActor (Bool) -> Void)
    func stop()
}

// MARK: - Other applications

struct ForegroundApp: Equatable {
    let id: String
    let displayName: String
    let isSelf: Bool
}

protocol ForegroundAppTracker: AnyObject {
    var current: ForegroundApp? { get }
    /// The most recent foreground application that was not LocalFlow itself.
    /// This is the one dictated text goes back into.
    var lastExternal: ForegroundApp? { get }
    func startTracking()
    func stopTracking()
}

struct FocusedWindow: Equatable {
    let appID: String
    let appName: String
    let title: String
}

/// Used only to guess that a call is on screen. Titles are inspected and
/// discarded; implementations must not persist them.
protocol FocusedWindowInspector {
    func focusedWindow() -> FocusedWindow?
}

/// A text field in another application, captured at the moment dictation began.
protocol TextInsertionTarget {
    var appDisplayName: String? { get }
    /// Focuses the captured application and inserts the text. Returns a
    /// user-facing description of what happened, including the clipboard
    /// fallback when direct insertion was not possible.
    func insert(_ text: String) async throws -> String
    func currentText() -> String?
    /// Where the inserted text landed, for detecting the user's later edits.
    /// Offsets are character counts, not platform range types.
    func insertionSnapshot(for inserted: String) async -> (text: String, start: Int, length: Int)?
}

protocol TextInsertionService {
    func captureFocusedTarget(inApp appID: String?) -> TextInsertionTarget?
}

protocol Clipboard {
    func setText(_ text: String)
}

// MARK: - Shell and tools

/// Locates the external binaries LocalFlow shells out to. macOS looks in
/// Homebrew; Windows would look in PATH or a bundled `tools` folder.
protocol ExternalTools {
    /// `tool` is a bare name such as "ffmpeg" or "whisper-cli".
    func url(for tool: String) throws -> URL
}

enum SystemSetting { case automation, microphone, notifications, screenRecording }

protocol ShellLauncher {
    /// Opens an interactive terminal so the user can finish a login flow that
    /// needs a real TTY.
    func launchInteractiveTerminal(command: String, title: String) throws
    func openInDefaultHandler(_ url: URL)
    func openSystemSetting(_ setting: SystemSetting)
}

// MARK: - Shell integration

struct NotificationAction {
    let id: String
    let title: String
}

protocol SystemNotifications: AnyObject {
    func requestPermission() async -> Bool
    func registerCategory(id: String, actions: [NotificationAction])
    func post(id: String, title: String, body: String, categoryID: String?, sound: Bool)
    var onAction: ((_ notificationID: String, _ actionID: String?, _ body: String, _ categoryID: String) -> Void)? { get set }
}

protocol LaunchAtLogin {
    var isEnabled: Bool { get }
    func setEnabled(_ on: Bool) async throws
}

protocol SoundEffects {
    func playCompletionSound()
}

protocol FileDialogs {
    func pickFilesToOpen(extensions: [String], allowsMultiple: Bool) async -> [URL]
    func pickSaveLocation(suggestedName: String) async -> URL?
}
