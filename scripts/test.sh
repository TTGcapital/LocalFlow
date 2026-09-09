#!/bin/zsh
# Builds and runs the macOS test suite. No speech models, microphone, or
# network access required, so this is the check to run before opening a PR.
#
# For the portable half of the app, run `swift test` as well — that suite is
# the one that also runs on Windows in CI.
set -euo pipefail
cd "${0:A:h}/.."

mkdir -p build

# Globbed rather than listed: an explicit file list silently goes stale every
# time Sources/Core gains a file.
xcrun swiftc -swift-version 5 -parse-as-library \
  Sources/Core/*.swift \
  Sources/WhisperTranscription.swift \
  Tests/Interaction.swift \
  -o build/interaction \
  -framework Speech -framework AVFoundation
./build/interaction
