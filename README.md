# Moosage 🐮

A native macOS menu bar app that tracks your **Claude Code** _and_ **Codex CLI** usage in one place. Two batteries, one cohesive UI, no terminal needed.

- 🔋🔋 Two side-by-side battery icons in the menu bar — `[C 94%] [O 18%]` — colored independently (default → yellow ≥75% → red ≥90%)
- 🖱 Click for a unified popover: per-provider plan, current 5h window, weekly bar (Codex), reset time, last activity
- 🚀 Launch at login (`SMAppService`), no dock icon
- 🪶 Single signed Swift binary, no runtime, no third-party deps

## Quickstart

Requires macOS 13+ and Swift 5.9+ (Xcode Command Line Tools).

```bash
cd ~/dev/claude-usage
./Scripts/verify.sh   # tests + build + smoke launch (must pass clean)
./Scripts/install.sh  # copies to /Applications and launches
```

Click the menu bar icon → toggle **Launch at login** → confirm under
**System Settings → General → Login Items**.

## How usage is computed

Two providers, both reading local JSONL files written by their respective CLIs.

### Claude Code (estimated)

Source: `~/.claude/projects/<slug>/<session>.jsonl`. Each line carries a `usage` block.

1. Walk every `.jsonl`, collect assistant events with `message.usage`.
2. Dedupe by `(message.id, requestId)` — the same message can appear in multiple files when sessions resume.
3. Group events into 5h rolling blocks (matches `ccusage`'s algorithm).
4. **Fill = currentBlockTokens / planLimit** — the limit is a community estimate per plan, calibrated against observed Claude.ai data.

The plan dropdown lives in the popover (Pro / Max 5× / Max 20×). Defaults:

| Plan    | Tokens / 5h block |
| ------- | ----------------- |
| Pro     | 20,000,000        |
| Max 5×  | 94,000,000        |
| Max 20× | 235,000,000       |

These remain approximations — Anthropic doesn't publish an exact cap.

### Codex (authoritative)

Source: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. After every turn, Codex writes an `event_msg` with `payload.type == "token_count"` containing the **real** rate-limit state from OpenAI's backend:

```jsonc
"rate_limits": {
  "primary":   { "used_percent": 78.0, "window_minutes": 300,   "resets_at": ... },
  "secondary": { "used_percent": 15.0, "window_minutes": 10080, "resets_at": ... },
  "credits":   { "has_credits": true, "unlimited": false, "balance": 42.50 },
  "plan_type": "plus"
}
```

So for Codex we don't estimate — we just read the latest event from the newest session file.

## Manual checklist after install

- [ ] Two batteries (`C` and `O`) appear in the menu bar
- [ ] Click opens popover; both providers visible with plan + reset
- [ ] Numbers match `~/.claude` and Codex respectively
- [ ] Toggling "Launch at login" reflects in System Settings → General → Login Items
- [ ] Reboot → app returns to menu bar automatically

## Development

```bash
swift test          # runs MoosageCoreTests
swift build         # debug build of both targets
./Scripts/build-app.sh   # universal release build → build/Moosage.app
./Scripts/verify.sh      # full pipeline (tests + build + sign + smoke)
```

Architecture:

- `Sources/MoosageCore/` — pure logic, fully testable
  - **Providers**: `UsageProvider` protocol, `ClaudeProvider`, `CodexProvider`
  - **Snapshot**: `ProviderSnapshot` (unified UI-facing struct)
  - **Claude path**: `JSONLParser`, `UsageScanner`, `BlockBuilder`, `SessionBlock`, `PlanLimits`
  - **Codex path**: `CodexJSONLParser`, `CodexEvent`
- `Sources/MoosageApp/` — SwiftUI `MenuBarExtra` glue
  - `BatteryIconView`, `MenuBarLabel`, `PopoverView`, `UsageStore` (poll + FSEvents), `LaunchAtLogin`
- `Tests/MoosageCoreTests/` — XCTest with anonymized JSONL fixtures

## Roadmap

- **Phase 2 (planned):** Claude network mode — read OAuth from Keychain, hit `claude.ai`'s usage endpoint for true plan/credits/weekly numbers (matching what Codex provides for free locally)
- **Cost display:** "Plan value used" — tokens × public API rates → "you'd have spent $X at metered API rates"

## Out of scope (current)

- Apple notarization / Developer ID signing (ad-hoc is fine for personal install)
- Auto-update channel
- Charts / history view
- Dock icon, full app window (`LSUIElement=true` blocks both — by design)

## Uninstall

```bash
./Scripts/uninstall.sh
```

## Privacy

All Phase 1 processing happens locally. Moosage reads `~/.claude/projects/` and `~/.codex/sessions/` and writes nothing outside `UserDefaults` for the chosen Claude plan. No network calls.

(Phase 2 will add an opt-in network mode for Claude that pulls from `claude.ai`'s usage endpoint using your existing OAuth token.)
