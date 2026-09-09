#!/bin/zsh
# Builds and runs the offline test suite. No speech models, microphone, or
# network access required, so this is the check to run before opening a PR.
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build
xcrun swiftc -swift-version 5 -parse-as-library \
  Sources/Core/Models.swift \
  Sources/Core/PlatformCapabilities.swift \
  Sources/Core/SpeechRouting.swift \
  Sources/Core/AppPaths.swift \
  Sources/Core/ClaudeBridge.swift \
  Sources/Core/CorrectionSuggestion.swift \
  Sources/Core/LocalProcess.swift \
  Sources/Core/WhisperServer.swift \
  Sources/WhisperTranscription.swift \
  Sources/Core/ShortcutGesture.swift \
  Sources/Core/UsageSummary.swift \
  Sources/Core/MeetingWindowMatcher.swift \
  Tests/Interaction.swift \
  -o build/interaction \
  -framework Speech -framework AVFoundation
./build/interaction
