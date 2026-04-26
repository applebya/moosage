#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶ swift build (release, universal)"
swift build -c release --arch arm64 --arch x86_64

APP="build/Moosage.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MoosageApp"
cp "$BIN" "$APP/Contents/MacOS/Moosage"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"
echo "✅ Built $APP"
