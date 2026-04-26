#!/usr/bin/env bash
set -euo pipefail

osascript -e 'tell application "ClaudeUsage" to quit' 2>/dev/null || true
sleep 1

# Best-effort: unregister login item (requires the .app to still exist)
if [ -d /Applications/ClaudeUsage.app ]; then
  /usr/bin/swift - <<'SWIFT' 2>/dev/null || true
import ServiceManagement
if SMAppService.mainApp.status == .enabled {
    try? SMAppService.mainApp.unregister()
}
SWIFT
fi

rm -rf /Applications/ClaudeUsage.app
defaults delete com.applebya.claudeusage 2>/dev/null || true

echo "✅ Uninstalled."
