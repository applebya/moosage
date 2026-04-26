#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh

# Stop running instance if any
osascript -e 'tell application "ClaudeUsage" to quit' 2>/dev/null || true
sleep 1

rm -rf /Applications/ClaudeUsage.app
cp -R build/ClaudeUsage.app /Applications/

open /Applications/ClaudeUsage.app
echo "✅ Installed. Toggle 'Launch at login' from the menu to start on boot."
