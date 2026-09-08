# Contributing to LocalFlow

Thanks for taking the time. LocalFlow is a small, dependency-light macOS app, and
it is deliberately easy to get running — you should be building and testing it
within a few minutes.

## Ground rules

- **Local-first is not negotiable.** Speech audio must never leave the machine.
  A change that sends microphone audio, transcripts, or usage data to a remote
  service without an explicit, user-initiated action will not be merged.
- **No telemetry.** No analytics SDKs, no crash reporters that phone home, no
  "anonymous" pings.
- **No new runtime dependencies without discussion.** The app builds with
  `swiftc` and the system frameworks. If your change needs a package manager,
  open an issue first.
- **Claude is optional.** Anything that requires the `claude` CLI must degrade
  gracefully when it is absent.

## Set up

    xcode-select --install
    brew install ffmpeg whisper-cpp
    git clone https://github.com/girzsebastian/LocalFlow.git
    cd LocalFlow
    ./scripts/download-models.sh   # one time, ~1.5 GB

You need macOS 26 or newer and an Apple Silicon Mac. The build scripts currently
assume Homebrew at `/opt/homebrew/bin`; making them portable to Intel is a
welcome contribution.

## Build and run

    ./build.sh
    ditto build/LocalFlow.app /Applications/LocalFlow.app
    open /Applications/LocalFlow.app

`build.sh` prints the path of the bundle it produced. It pins the ad-hoc
signature to a stable designated requirement so macOS does not drop your
Accessibility grant on every rebuild — if you change the signing line, expect to
re-grant Accessibility after each build.

## Test

    ./scripts/test.sh

This is the offline suite. It needs no models, no microphone, and no network, it
runs in seconds, and **it must pass before you open a pull request.** CI runs the
same script on every push.

The remaining suites under `Tests/` exercise real audio, real models, or the
Claude CLI, so they are run by hand:

    xcrun swiftc -swift-version 5 -parse-as-library Sources/*.swift Tests/Multilingual.swift -o build/multilingual -framework SwiftUI -framework AppKit -framework AVFoundation -framework Speech -framework Carbon -framework ScreenCaptureKit -framework CoreAudio -framework ServiceManagement -framework EventKit -framework UserNotifications
    ./build/multilingual

To check the Claude paths against a real signed-in `claude` CLI, build the smoke
suite without the app entry point and run `./build/smoke claude` for meeting
insights or `./build/smoke cleanup` for dictation cleanup:

    xcrun swiftc -swift-version 5 -parse-as-library Sources/Core.swift Sources/LocalProcess.swift Sources/WhisperServer.swift Sources/WhisperTranscription.swift Sources/MeetingAudio.swift Tests/Smoke.swift -o build/smoke -framework AVFoundation -framework Speech
    ./build/smoke cleanup

Anything that can only be checked by a human — permission prompts, the floating
widget, mouse buttons, an actual call — belongs in [VALIDATION.md](VALIDATION.md).
Please add what you verified there, and be honest about what you did *not* check.

## Code style

Match the file you are editing. In practice that means:

- Swift 5 language mode, four-space indentation, no trailing whitespace.
- Types and files stay in the flat `Sources/` layout — one clear concern per file.
- Comments explain *why*, not *what*. The existing comment in `build.sh` about
  the designated requirement is the model to follow: it records a non-obvious
  reason a future reader would otherwise undo.
- No force-unwrapping in code paths a user can reach.
- User-facing strings are plain and specific. LocalFlow tells the user what
  failed and what to do; it does not say "Something went wrong".

## Pull requests

1. Branch off `main`.
2. Keep the change focused. One behaviour per PR.
3. Run `./scripts/test.sh`.
4. Describe what you changed, and say explicitly what you tested on which Mac
   and which macOS version.
5. If your change touches permissions, audio capture, or anything that leaves
   the machine, call that out in the description.

Small PRs get reviewed fast. Large architectural changes are much better started
as an issue.

## Good places to start

- Intel Mac and non-`/opt/homebrew` support in `build.sh` and
  `scripts/download-models.sh`.
- Additional languages beyond English and Romanian in the language router.
- A Homebrew cask so `brew install --cask localflow` works.
- Accessibility of the main window: VoiceOver labels, keyboard navigation.
- Anything in the **Status** section of the README that is still marked planned.

Issues tagged [`good first issue`](https://github.com/girzsebastian/LocalFlow/labels/good%20first%20issue)
are scoped small on purpose.

## Reporting bugs

Use the issue templates. A dictation bug is much easier to fix with the macOS
version, the Mac model, the language mode, and whether Accessibility was granted.
Never paste a transcript containing anything private — LocalFlow exists so that
text stays yours.

## Security

Do not open a public issue for a security problem. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
