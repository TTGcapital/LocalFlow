#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/LocalFlow.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -parse-as-library -O Sources/*.swift Sources/Core/*.swift Sources/Platform/macOS/*.swift -o "$APP/Contents/MacOS/LocalFlow" -framework SwiftUI -framework AppKit -framework AVFoundation -framework Speech -framework Carbon -framework ScreenCaptureKit -framework CoreAudio -framework ServiceManagement -framework EventKit -framework UserNotifications
cp Info.plist "$APP/Contents/Info.plist"
# Keep a stable designated requirement between local builds. Without it, an
# ad-hoc signature defaults to the executable's changing CDHash and macOS can
# leave a stale Accessibility entry enabled for the previous build.
codesign --force --sign - --requirements '=designated => identifier "com.oryntech.localflow"' "$APP"
echo "$APP"
