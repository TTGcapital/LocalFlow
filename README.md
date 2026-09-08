# LocalFlow

### A free, local Wispr Flow alternative for macOS

LocalFlow turns your voice into text in any Mac app. Hold a shortcut, speak, release, and the transcript is inserted where your cursor is. It also records meetings, separates your microphone from computer audio, creates summaries, and lets you chat with the saved discussion.

There is no transcription subscription and no account required. Speech recognition runs locally with Whisper on Apple Silicon. Claude is optional and is used only for the writing and meeting features you choose to run.

[![macOS](https://img.shields.io/badge/macOS-26%2B-111827?logo=apple)](https://www.apple.com/macos/) [![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](https://www.swift.org/) [![Whisper](https://img.shields.io/badge/speech-Whisper.cpp-6b46c1)](https://github.com/ggerganov/whisper.cpp) [![Local first](https://img.shields.io/badge/data-local--first-0f766e)](#privacy)

## Why LocalFlow exists

Wispr Flow made system-wide voice typing feel natural, but a subscription is not a good fit for everyone and some workflows need local audio. LocalFlow is an open project built around the same useful idea: a small floating control, a global push-to-talk shortcut, automatic paste into the focused app, personal vocabulary, and a meeting workspace.

It is designed for people searching for a **Wispr Flow alternative**, **WisprFlow alternative for Mac**, **offline voice typing**, or a **private local dictation app**.

## What it does

### Dictation

- Hold a configurable keyboard or mouse shortcut to speak; release to finish.
- Double-tap the shortcut for hands-free mode, then press it once to stop.
- After a short pause, completed phrases are transcribed in the background while you continue speaking. Stop only waits for the unprocessed tail.
- Inserts text into the active field, with clipboard fallback when macOS Accessibility insertion is unavailable.
- Mutes Mac output while dictating and restores the previous output state afterward.
- English, Romanian, or multilingual English + Romanian mode.
- Personal dictionary, reusable snippets, styles, transforms, scratchpad, and correction suggestions.

### Notetaker

- Record your microphone and, with permission, computer audio from Zoom, Google Meet, or another call.
- See a live conversation with **You** and **Meeting participants** source labels.
- Ask Claude for a summary, decisions, action items, or answers grounded in the captured meeting.
- Keep audio, transcript, meeting segments, summaries, and chat history in the local library.

### A Wispr Flow-style workspace

The app includes a floating widget, language control, dictionary, snippets, styles, transforms, scratchpad, insights, notifications, calendar reminders, and settings for shortcuts, audio, privacy, and Notetaker behavior.

## LocalFlow compared with Wispr Flow

| Capability | LocalFlow | Wispr Flow |
| --- | --- | --- |
| System-wide dictation | Yes | Yes |
| Push-to-talk and toggle modes | Yes | Yes |
| Automatic paste at the cursor | Yes | Yes |
| Background phrase transcription | Yes | Yes |
| English + Romanian multilingual mode | Yes | Yes |
| Notetaker with meeting audio | Yes | Yes |
| Dictionary, snippets, styles, transforms | Yes | Yes |
| Local Whisper transcription | Yes | Service-dependent |
| Transcription subscription | No | Plan-dependent |
| Claude-powered summaries and meeting chat | Optional local Claude CLI | Service-dependent |
| Team accounts and cloud sharing | Not yet | Yes |

## How it works

    Global shortcut
          ↓
    Floating widget → CAF microphone recording → pause detector
                                      ↓
              compact English/Romanian detector
                                      ↓
                         Whisper large-v3-turbo
                                      ↓
                    dictionary and snippets → paste

Notetaker stores local audio and transcript segments. Claude is an optional final step for requested summaries, transforms, and meeting questions.

## Install on macOS

The repository currently builds a local Apple Silicon app. A signed and notarized public release is not available yet.

### 1. Install prerequisites

    xcode-select --install
    brew install ffmpeg whisper-cpp

The build scripts currently expect Apple Silicon Homebrew at **/opt/homebrew/bin**.

### 2. Download the speech models

    git clone https://github.com/girzsebastian/LocalFlow.git
    cd LocalFlow
    ./scripts/download-models.sh

The script downloads the quantized Whisper models from the [whisper.cpp model repository](https://huggingface.co/ggerganov/whisper.cpp), verifies their SHA-256 checksums, and stores them under **~/Library/Application Support/LocalFlow/Models/**.

### 3. Build and install

    ./build.sh
    ditto build/LocalFlow.app /Applications/LocalFlow.app
    open /Applications/LocalFlow.app

On first launch, allow Microphone access. Add LocalFlow under **System Settings → Privacy & Security → Accessibility** so the global shortcut and automatic paste can work. The first launch may show an unidentified-developer warning because development builds are ad-hoc signed; use **Open Anyway** in Privacy & Security.

### 4. Use it

1. Choose a shortcut in Settings, or select Mouse 4 / Mouse 5.
2. Put the cursor in any text field.
3. Hold the shortcut, speak, and release.
4. For long thoughts, pause naturally. Completed phrases will be ready before you stop.

## Privacy

Speech audio is processed on the Mac by Whisper.cpp. LocalFlow does not require a transcription account, does not send microphone audio to a transcription API, and does not include telemetry. The local Whisper server binds to **127.0.0.1** only.

Claude is an optional separate path. It uses the existing **claude** CLI login for requested summaries, transforms, and meeting questions. Read the prompt and choose the Claude action before sending transcript text to it.

## Architecture

| Area | Implementation |
| --- | --- |
| App and widget | SwiftUI + AppKit |
| Global shortcuts | Carbon hotkeys and AppKit mouse monitoring |
| Audio capture | AVAudioRecorder, linear PCM CAF |
| System audio | ScreenCaptureKit |
| Speech recognition | whisper.cpp **whisper-server** with Metal |
| Language routing | Compact Whisper detect-only server, English/Romanian constrained |
| Text insertion | Accessibility API with clipboard paste fallback |
| Meeting intelligence | Claude CLI, only when requested or enabled |
| Storage | Local JSON archive and audio files |

## Project layout

    Sources/App.swift                         App state and recording lifecycle
    Sources/FloatingControl.swift             Floating widget and waveform
    Sources/WhisperTranscription.swift        Audio preparation and language routing
    Sources/WhisperServer.swift               Localhost Whisper model process
    Sources/StreamingDictationTranscription.swift  Pause-based phrase pipeline
    Sources/LiveNotetaker.swift               Live transcript, summary, and meeting chat
    Sources/PreferencesView.swift             Settings and configuration
    Sources/PasteDestination.swift             Focused-app text insertion
    Tests/Interaction.swift                   Shortcut, routing, archive, and process checks
    build.sh                                  Native macOS app build and ad-hoc signing

## Performance

On an Apple M2 Pro test machine:

- A bilingual English/Romanian sample completed in 4.93 seconds and preserved both languages.
- A 118-second real dictation completed from scratch in 19.69 seconds.
- Two phrase-level background requests completed in 4.65 seconds.

The first model warm-up is slower. Actual timing depends on the Mac, recording length, pauses, and whether the background queue has already processed the phrases.

## Troubleshooting

**The shortcut does nothing**

Confirm LocalFlow is enabled under Accessibility, then restart the app. Secure Input fields such as password prompts can block global keyboard monitoring.

**The transcript is copied but not inserted**

The text remains in the clipboard. Re-enable Accessibility and try again; the widget explains the current failure without opening the main window.

**The app says the model is missing**

Run **./scripts/download-models.sh** again and verify that both model files are under **~/Library/Application Support/LocalFlow/Models/**.

**The first dictation is slow**

The local Whisper processes are loading their models. Later phrases reuse the warm processes.

## Development

    ./build.sh
    xcrun swiftc -swift-version 5 -parse-as-library Sources/Core.swift Sources/CorrectionSuggestion.swift Sources/LocalProcess.swift Sources/WhisperServer.swift Sources/WhisperTranscription.swift Sources/ShortcutGesture.swift Sources/UsageSummary.swift Sources/MeetingWindowMatcher.swift Tests/Interaction.swift -o build/interaction -framework Speech -framework AVFoundation
    ./build/interaction

See [VALIDATION.md](VALIDATION.md) for the tested flows and known manual checks. Contributions are welcome once a project license is selected.

## Status

LocalFlow is an active personal project. The core dictation and Notetaker flows are usable; automatic call-end detection, cloud team accounts, connector management, screen-share hiding, and signed distribution are still planned.

## License

No license has been selected yet. Until one is added, the repository is public for inspection and personal testing; reuse and redistribution are not granted by default.

