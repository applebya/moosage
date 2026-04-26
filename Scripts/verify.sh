#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶ swift test"
swift test

echo "▶ swift build (debug)"
swift build

echo "▶ build .app"
./Scripts/build-app.sh

echo "▶ codesign verify"
codesign --verify --verbose=2 build/ClaudeUsage.app

echo "▶ Info.plist sanity"
plutil -lint build/ClaudeUsage.app/Contents/Info.plist
LSUI=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" build/ClaudeUsage.app/Contents/Info.plist 2>/dev/null)
if [ "$LSUI" != "true" ]; then
  echo "❌ LSUIElement missing or false (got: '$LSUI')"
  exit 1
fi
echo "  LSUIElement OK (true)"

echo "▶ launch & wait 5s"
open build/ClaudeUsage.app
sleep 5
if pgrep -x ClaudeUsage > /dev/null; then
  echo "  process running"
else
  echo "❌ ClaudeUsage process not found after launch"
  exit 1
fi
osascript -e 'tell application "ClaudeUsage" to quit' 2>/dev/null || true
sleep 1

echo "✅ All checks passed."
