#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh

# Stop running instance if any (try both old and new names during transition)
osascript -e 'tell application "Moosage" to quit' 2>/dev/null || true
osascript -e 'tell application "ClaudeUsage" to quit' 2>/dev/null || true
sleep 1

rm -rf /Applications/Moosage.app /Applications/ClaudeUsage.app
cp -R build/Moosage.app /Applications/

open /Applications/Moosage.app
echo "✅ Installed Moosage 🐮. Toggle 'Launch at login' from the menu to start on boot."
