# Validation — 2026-09-07

Passed:
- Native SwiftUI/AppKit app compilation against the installed macOS 26 SDK.
- Ad-hoc app signing and bundle plist validation.
- Whole-phrase snippet/correction matching, case folding, literal replacements, malformed-rule handling.
- Archive round-trip and decoding entries with missing optional audio properties.
- Actual Apple SpeechTranscriber test with an English Samantha voice: “This is a meeting note. We agreed to launch the project on Friday.” Both sentences returned correctly.
- Actual two-track audio mixing to M4A followed by successful local transcription.
- Actual Claude CLI call using the existing Claude Max subscription login. Correct decision and action owner extracted from a synthetic meeting transcript.
- Earlier installed app launched and its process was verified running.

Remaining manual checks:
- Grant microphone permission and record your own voice.
- Grant Accessibility permission, select your shortcut, and verify paste into a harmless text field.
- Test the floating meter and chosen mouse button with your mouse software.
- Grant Screen & System Audio Recording permission and test an actual call with headphones.

Desktop Accessibility inspection and screen capture were denied by macOS in this session, so the floating UI and actual Wispr Flow settings were not visually inspected. The provided screenshot was used to design the floating control. Synthetic tests do not establish real meeting accuracy, echo handling, or live microphone capture quality.

## 0.2 update

Passed:
- Hold/release, key-repeat suppression, double-tap latch, stopping a latched recording, single-tap expiry.
- Phrase boundaries and bounded phrase lengths for multilingual transcription.
- Real child-process timeout, cancellation, and a successful subsequent process.
- Romanian-only synthetic transcription including diacritics: 2.2 seconds on a warm run.
- Mixed English/Romanian synthetic recording preserved both languages, including “Friday”, “ședință”, and “proiectul”: 6.6 seconds on a warm run. Initial GPU/model warmup took 33.2 seconds.
- Silence rejected before model inference.

A reduced Whisper encoder-window experiment failed mixed-language accuracy and was reverted. The installed backend retains the model’s default encoder window.

App diagnostics established missing Accessibility permission and microphone authorization not yet granted for the rebuilt app. No valid code-signing identity was present. System permission grants, actual cursor insertion, and physical mouse/multi-screen interaction still require desktop testing. The app now displays the permission state and watches for changes.

Additional checks:
- Real MacBook Pro Speakers output was muted and restored to its original unmuted state. MacBook Pro Microphone remained selected.
- Usage metrics exclude meeting notes and do not fabricate durations for older entries.
- Calendar reminders/permissions, startup registration, live mouse interactions, and clipboard insertion remain manual desktop checks. These are not claimed as end-to-end verified.
- Existing archive decoding remains compatible with new optional fields.

## Widget, settings and notifications update
- Idle widget retracts after 0.9 seconds to a 5-point edge handle; pointer proximity expands it. Recording, processing and errors keep controls visible. Panel bounds shrink so idle controls do not intercept a large desktop area.
- Settings now have General, System, Notetaker, Notifications, Claude and Data & Privacy subnavigation. Widget visibility has subtle/always/recording-only options.
- Local notification actions can start a note; calendar reminders use the same action. Optional focused-window title matching suggests notes for Zoom meeting windows and Google Meet in supported browsers. This is a heuristic, including possible pre-join pages, not confirmed call detection. Requires Accessibility and notification permission. No window titles are persisted.
- Meeting prompts limited to once per app per 30 minutes; optional dictionary/snippet tips limited to once per week after three dictations.
- Native hover behavior, notification delivery/actions and detection during a real call still require interactive verification with macOS permissions. No claim of end-to-end call detection validation.

## Interaction, correction learning and live Notetaker
- Sidebar, settings navigation and recording rows use full-row hit regions. Main/settings rows show a hover background.
- Main-window error alerts were removed. Errors remain in the floating widget; cancellation creates a five-second widget message. Notification actions no longer intentionally open the main window.
- Post-paste correction detection observes the same accessible text field briefly and offers a dictionary rule for eight seconds. It is opt-in at the prompt and can be disabled in General settings. Pure tests cover `chersid → Kerrsid` and reject plain appended text.
- A verified compact multilingual Whisper model (`ggml-base-q5_1.bin`, SHA-1 `a3733eda680ef76256db5fc5dd9de8629e62c5e7`) supplies live Notetaker segments. A bilingual synthetic test returned both the English meeting phrase and Romanian project phrase.
- Live speaker labels identify audio source: `You` for the microphone and `Meeting participants` for computer audio. They do not identify individual remote people. Summary/chat use only the captured meeting context through Claude.
- Reading concurrently growing microphone/system CAF files, the ScreenCaptureKit permission prompt, and the complete live-meeting UI still require an interactive real-call test on this Mac.

## Incremental dictation and multilingual speed

- Dictation now records uncompressed CAF so completed intervals can be read before recording ends. A growing CAF integration check successfully extracted a one-second WAV while the writer was still active.
- A 0.75-second pause commits the preceding phrase to background transcription. Stop cancels any uncommitted request and processes only the remaining tail; committed phrases are joined in capture order.
- The large Whisper server and compact detector remain loaded on localhost during use and stop on normal app termination. The detector uses a 256-frame context and detect-only mode.
- The supplied 10.69-second bilingual sample completed in 4.93 seconds and preserved both English and Romanian: `Friday`, `Bună ziua`, `ședință`, and `proiectul`.
- The user's 118.42-second problematic recording completed from scratch in 19.69 seconds. The result contained no Cyrillic, Arabic, CJK, or Korean script. Background phrase completion should reduce the wait after Stop further.
- Two phrase-level requests through the same incremental path completed in 4.65 seconds and retained English in the first phrase and Romanian in the second.
- These timings were measured on this MacBook Pro under the current load. They are performance observations, not a hard deadline for every recording or system load.
