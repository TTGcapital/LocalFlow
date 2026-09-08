# LocalFlow 0.2

Personal native macOS dictation and meeting notes. Installed at `~/Applications/LocalFlow.app`.

## Dictation

- **Hold** your shortcut while speaking; **release** to transcribe and paste.
- **Double-tap quickly** (within 0.32 seconds) for hands-free recording. Press once to finish.
- A single quick tap ends after the double-tap window. Very short recordings show a helpful error.
- Keyboard autorepeat does not toggle recording repeatedly.
- In Settings, choose a keyboard combination, Mouse 4, or Mouse 5. Your existing shortcut is retained.
- Floating microphone/note buttons start hands-free recording. Click Stop to finish.
- After about 0.75 seconds of silence, LocalFlow transcribes the completed phrase in the background while the microphone keeps recording. The widget shows how many phrases are ready. Stop processes only the uncommitted tail and then pastes the joined result.

The floating control shows microphone activity, silence, processing stage, elapsed processing time, and Cancel. It moves to the left edge of the screen containing the mouse and follows active desktop changes. It does not chase every mouse movement within one screen.

## Languages

Choose **English**, **Română**, or **Multilingual · English + Romanian** in Settings or the widget’s EN/RO/ML menu. Multilingual is selected when upgrading to 0.2.

The installed local Whisper large-v3-turbo model supports Romanian and English. Multilingual detects language separately for phrases divided by pauses and decodes each phrase in its detected language. Detection is restricted to English and Romanian so an accented English phrase cannot switch the transcript to an unrelated alphabet. A short natural pause when switching languages helps. Recognition, especially fast code-switching without pauses, is not guaranteed perfect.

Speech runs on this Mac using whisper.cpp and the downloaded models. A localhost-only speech process keeps the large model loaded during use; a compact detector routes English and Romanian. Dictation does not use Claude, Apple’s speech-model download service, or a paid API. Startup/model/GPU warmup can be slower than subsequent phrases.

Notetaker shows a live conversation window while recording. It labels the microphone as **You** and computer audio as **Meeting participants**, provides **Summarize so far**, and keeps a chat grounded in that meeting’s captured transcript. It cannot reliably name individual remote speakers. Live text uses the compact multilingual Whisper model for responsiveness; stopping the note runs the larger model over the saved recording for the final transcript.

## Paste permissions

Enable **LocalFlow** in System Settings → Privacy & Security → **Accessibility**. The app shows permission status and automatically refreshes the mouse shortcut when access is granted. Also allow the microphone on first use.

The app captures the active field, restores focus, tries supported Accessibility text insertion, and falls back to Command V after shortcut modifiers lift. If permission is missing or focus cannot be restored, the transcript stays copied and a visible error explains what to do. Transcription and clipboard copy do not require Accessibility.

This personal build is ad-hoc signed with a stable designated requirement so macOS can retain its Accessibility grant across local rebuilds. If macOS still shows a stale permission, remove the old entry and add the installed app again. No developer signing identity was available on this Mac.

## Notetaker and writing tools

Record a note or import audio/video, then transcribe. Settings can include computer audio alongside the microphone. macOS asks for Screen & System Audio Recording permission; no video is saved. Use headphones to avoid echo. Original tracks and mixed audio are retained.

Each entry supports playback, editable transcripts, audio/Markdown export, Claude meeting insights, writing styles, and a custom transformer. Scratchpad, dictionary corrections, whole-phrase snippets, and library search are included.

Claude uses the existing official `~/.local/bin/claude` CLI and requires Claude subscription authentication. It removes inherited API credentials, uses safe mode with tools and MCP disabled, and does not read OAuth tokens directly. Only requested Claude actions or explicitly enabled automatic note insights send transcript text to Claude. Claude’s subscription limits and any paid extra-usage settings still apply.

## Recovery and storage

`~/Library/Application Support/LocalFlow/archive.json` stores notes and preferences; `Audio/` stores recordings; `Models/` contains the local speech models. Saves are atomic. A corrupt library is not overwritten. Removing an entry keeps its audio files.

Audio conversion and language detection are cancellable, and local inference requests respect task cancellation. The app stops its localhost speech processes during normal quit. Empty or silent audio is rejected, and original audio remains available for retry.

`diagnostics.json` records permission/model availability only, not transcript contents.

## Build

Requires macOS 26, Xcode/Command Line Tools, `/opt/homebrew/bin/ffmpeg`, `/opt/homebrew/bin/whisper-cli` (Homebrew `whisper-cpp`), and the large final plus compact live Whisper models in LocalFlow’s data folder. These are installed on this laptop.

```sh
./build.sh
xcrun swiftc -swift-version 5 -parse-as-library Sources/Core.swift Sources/CorrectionSuggestion.swift Sources/LocalProcess.swift Sources/WhisperServer.swift Sources/WhisperTranscription.swift Sources/ShortcutGesture.swift Sources/UsageSummary.swift Sources/MeetingWindowMatcher.swift Tests/Interaction.swift -o build/interaction -framework Speech -framework AVFoundation
./build/interaction
xcrun swiftc -swift-version 5 -parse-as-library Sources/Core.swift Sources/LocalProcess.swift Sources/WhisperServer.swift Sources/WhisperTranscription.swift Sources/StreamingDictationTranscription.swift Tests/StreamingBenchmark.swift -o build/streaming-benchmark -framework Speech -framework AVFoundation
./build/streaming-benchmark build/bilingual.wav
```

See VALIDATION.md for checks and manual testing limits. Individual remote-speaker identification, cloud sharing/team accounts, and connector management are not implemented.

## Widget, system settings, and insights

The widget provides language, dictation, new note, and scratchpad actions. Option M toggles Notetaker. Dictation mutes Mac output by default while leaving the microphone selected and restores previous mute/volume state on stop, failure, or normal quit. Notetaker does not mute output. Changing output devices during dictation mutes the newly selected output too, if macOS exposes mute or volume controls for it.

Settings include Mac input-device selection, launch at login, Dock and idle-widget visibility, completion sounds, scratchpad resume/new-note behavior, notepad opening, maximum note length, and Markdown/text note import. Changing the input selector changes the Mac-wide input setting. Optional Mac-calendar connection shows upcoming meetings, schedules local reminders, and can display the next meeting in the menu bar. Calendar and notification permissions are requested only when connecting.

Insights displays actual dictation word counts, measured words per minute, activity, and app usage. The optional Claude writing profile analyzes recent transcript text, not acoustic voice characteristics. Questions across notes use the latest 20 transcribed notes, at most 10,000 characters each, and save answers in local chat history. Dictionary terms can be supplied as model vocabulary hints.

Automatic call suggestions, live meeting transcript, correction-learning prompts, and final meeting summaries are implemented. Automatic call-end detection, screen tiling, hiding windows from screen share, cloud sharing/team accounts, and connector management are not implemented. The personal app does not offer referral, marketing-notification, or billing pages.

### Desktop widget and meeting suggestions
The widget now retracts into a subtle edge handle when idle. Move the pointer near it to reveal the controls; dictation and transcription keep it expanded. Choose its behavior in Settings → System.

Settings → Notifications controls local Zoom/Google Meet meeting-window suggestions and occasional usage tips. Allow macOS notifications and Accessibility for window detection. Suggestions use the focused window title and can include pre-join screens; they never start recording automatically. The Start note notification action starts Notetaker after you choose it. Calendar reminders remain under Settings → Notetaker.
