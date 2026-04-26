# ClaudeUsage

A native macOS menu bar app that shows your current Claude Code 5-hour window usage as a battery icon.

- 🔋 Battery-style icon fills with current 5-hour block usage
- ⏰ Shows next reset time (e.g. `1AM`) next to the icon
- 🖱 Click to expand: tokens used, model breakdown, time-to-reset
- 🚀 Launch at login (`SMAppService`), no dock icon, no terminal needed
- 🪶 Single signed Swift binary, no runtime, no network calls — only reads `~/.claude/projects/`

## Quickstart

Requires macOS 13+ and Swift 5.9+ (Xcode Command Line Tools).

```bash
git clone <this repo> ~/dev/claude-usage
cd ~/dev/claude-usage
./Scripts/verify.sh   # tests + build + smoke launch (must pass clean)
./Scripts/install.sh  # copies to /Applications and launches
```

Click the menu bar icon → toggle **Launch at login** → confirm under
**System Settings → General → Login Items**.

## How usage is computed

Claude Code logs every assistant message under `~/.claude/projects/<slug>/<session>.jsonl`.
Each line carries a `usage` block. ClaudeUsage:

1. Walks every `.jsonl` and collects assistant events with `message.usage`.
2. Dedupes by `(message.id, requestId)` (same message can appear in multiple files when sessions resume).
3. Groups events into 5-hour rolling blocks: a new block starts when an event is `>5h` after the current block's start, OR there's a `>5h` gap between consecutive events.
4. The "current block" is the one whose `[startTime, startTime + 5h)` contains _now_.
5. Fill = `currentBlockTokens / planLimit`.

## Plan limits (community estimates)

The "fill" denominator depends on your plan. Defaults are conservative community estimates and **user-overridable** — switch from the popover dropdown:

| Plan    | Tokens / 5h block (estimate) |
| ------- | ---------------------------- |
| Pro     | 19,000,000                   |
| Max 5×  | 88,000,000                   |
| Max 20× | 220,000,000                  |

Anthropic doesn't publish an exact per-block token cap, so these are approximations. If they drift, edit `Sources/ClaudeUsageCore/PlanLimits.swift`.

## Manual checklist after install

- [ ] Icon appears in menu bar
- [ ] Click opens popover; numbers match `wc -l ~/.claude/projects/**/*.jsonl` ballpark
- [ ] Reset time displayed correctly
- [ ] Battery fills proportionally to usage
- [ ] Toggling "Launch at login" reflects in System Settings → General → Login Items
- [ ] Reboot → app returns to menu bar automatically

## Development

```bash
swift test          # runs all 30 ClaudeUsageCoreTests
swift build         # debug build of both targets
./Scripts/build-app.sh   # universal release build → build/ClaudeUsage.app
./Scripts/verify.sh      # full pipeline (tests + build + sign + smoke)
```

Architecture:

- `Sources/ClaudeUsageCore/` — pure logic, fully testable
  - `JSONLParser`, `UsageScanner`, `BlockBuilder`, `SessionBlock`, `PlanLimits`, `UsageSnapshot`
- `Sources/ClaudeUsageApp/` — SwiftUI `MenuBarExtra` glue
  - `BatteryIconView`, `MenuBarLabel`, `PopoverView`, `UsageStore` (poll + FSEvents), `LaunchAtLogin`
- `Tests/ClaudeUsageCoreTests/` — XCTest with anonymized JSONL fixtures

## Out of scope (v0.1)

- Apple notarization / Developer ID signing (ad-hoc is fine for personal install)
- Weekly-limit tracking — separate from the 5h block
- Auto-update channel
- Charts / history view
- Dock icon, full app window (`LSUIElement=true` blocks both — by design)

## Uninstall

```bash
./Scripts/uninstall.sh
```

## Privacy

All processing happens locally. ClaudeUsage reads `~/.claude/projects/` and writes nothing outside `UserDefaults` for the chosen plan. No network calls, ever.
