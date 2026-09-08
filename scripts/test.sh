#!/bin/zsh
# Builds and runs the offline test suite. No speech models, microphone, or
# network access required, so this is the check to run before opening a PR.
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build
xcrun swiftc -swift-version 5 -parse-as-library \
  Sources/Core.swift \
  Sources/CorrectionSuggestion.swift \
  Sources/LocalProcess.swift \
  Sources/WhisperServer.swift \
  Sources/WhisperTranscription.swift \
  Sources/ShortcutGesture.swift \
  Sources/UsageSummary.swift \
  Sources/MeetingWindowMatcher.swift \
  Tests/Interaction.swift \
  -o build/interaction \
  -framework Speech -framework AVFoundation
./build/interaction
