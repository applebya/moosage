# Moosage 🐮

> Your Claude Code and Codex CLI usage, mooed at you from the macOS menu bar.

Two batteries. One menu bar item. Zero context switches into a settings page to find out you've already burned through your 5-hour window again.

```
[C 94%] [O 18%]
```

That's Claude Code on the left (94% of your 5h block) and Codex on the right (18%). Click and a small popover shows the rest — plan, exact tokens, reset times, weekly limits, last activity, and a switch to launch on login.

## Why

You're paying for the plans. You'd like to know how close you are to the limit. The official answer is "open `claude.ai/settings/usage` in a browser" or "stare at the Codex CLI scrollback until you spot the rate limit line." Neither of these is a great way to live.

Moosage is the little battery indicator your menu bar already does for _actual_ batteries — except the thing being depleted is your token budget instead of your laptop's lithium.

## Install

You'll need macOS 13+ and the Swift toolchain (`xcode-select --install` is enough — no Xcode app required).

```bash
git clone https://github.com/applebya/moosage.git ~/dev/moosage
cd ~/dev/moosage
./Scripts/install.sh
```

That builds a universal `Moosage.app`, drops it in `/Applications`, and launches it. Click the icon → toggle **Launch at login** → confirm under **System Settings → General → Login Items**. You're done.

To uninstall: `./Scripts/uninstall.sh` (it asks no questions, takes no prisoners).

## What you get

**Menu bar** — two tiny SF-symbol batteries with one-letter tags. Default tint until 75%, yellow at 75–89%, red at 90% and above. Stale providers (no recent calls) are dimmed so you don't panic when Codex shows 0%.

**Popover** — Claude on the left, Codex on the right, side by side because you have a wide monitor.

| Per-provider     | Claude Code                                   | Codex                                 |
| ---------------- | --------------------------------------------- | ------------------------------------- |
| Plan name        | ✅ auto-detected from Keychain OAuth          | ✅ from session JSONL                 |
| Current 5-hour % | ✅ estimated from token sum                   | ✅ authoritative (OpenAI computes it) |
| Reset time       | ✅                                            | ✅                                    |
| Weekly %         | ❌ (see [limitations](#what-doesnt-work-yet)) | ✅                                    |
| Extras balance   | ❌ (see [limitations](#what-doesnt-work-yet)) | ✅ if applicable                      |

**No telemetry. No analytics. No phoning home.** Moosage talks to:

- `~/.claude/projects/**/*.jsonl` (read only)
- `~/.codex/sessions/**/*.jsonl` (read only)
- macOS Keychain entry `Claude Code-credentials` (read only — for plan auto-detect)
- `https://api.anthropic.com/api/oauth/profile` every 5 minutes (just to refresh your plan tier; you can turn this off in code if you really want)

That's it.

## How it works under the hood

Two providers, both reading local files written by their respective CLIs.

**Claude (estimated)** — Walk every JSONL under `~/.claude/projects/`, extract assistant messages with a `usage` block, dedupe by `(message.id, requestId)`, group into 5-hour rolling windows (the `ccusage` algorithm), divide by a per-plan token cap. Plan tier comes from your Keychain OAuth credential so the cap is right without you touching a dropdown.

**Codex (authoritative)** — Codex very kindly writes the _real_ rate-limit block into every session JSONL after every turn:

```jsonc
"rate_limits": {
  "primary":   { "used_percent": 78.0, "window_minutes": 300,   "resets_at": ... },
  "secondary": { "used_percent": 15.0, "window_minutes": 10080, "resets_at": ... },
  "credits":   { "has_credits": true, "unlimited": false, "balance": 42.50 },
  "plan_type": "plus"
}
```

So for Codex we don't estimate anything — we just find the newest session file and read its latest `token_count` event. Thanks OpenAI, that's actually useful.

The app polls every 5 seconds and also runs a recursive `FSEventStream` watcher so changes are reflected within ~1 second of being written.

## What doesn't work (yet)

**Live Claude session % and extras balance** require Claude.ai's web session cookie because the public OAuth scope (`user:profile`, `user:inference`, etc.) doesn't grant org-level usage reads, and the relevant endpoint sits behind Cloudflare. Plumbing Chrome cookie extraction into a Swift app is doable but fragile — Chrome's app-bound encryption keeps moving the goalposts. **PRs welcome.**

Until then: Claude % is an estimate against a calibrated cap. Has been within ~1–2% of what claude.ai shows for me.

**Cost in dollars** — there's no metered overage on a Pro/Max plan; you hit the cap and wait. If you turn on extras (it's an account setting), Anthropic bills via Stripe and the balance lives behind that same Cloudflare-gated endpoint.

## Develop

```bash
swift test               # 38 tests, runs in ~0.4s
swift build              # debug
./Scripts/build-app.sh   # universal release → build/Moosage.app
./Scripts/verify.sh      # tests + build + sign + smoke launch
```

Layout:

```
Sources/
├── MoosageCore/          ← pure logic, fully testable, no SwiftUI
│   ├── UsageProvider     (protocol)
│   ├── ClaudeProvider    (JSONL token sum + Keychain OAuth)
│   ├── CodexProvider     (latest token_count event)
│   ├── ClaudeOAuthClient (Keychain + api.anthropic.com)
│   └── …                 (parsers, scanners, snapshot type, plan limits)
└── MoosageApp/           ← SwiftUI MenuBarExtra glue
    ├── MoosageApp        (@main)
    ├── UsageStore        (poll + FSEvents + provider orchestration)
    ├── MenuBarLabel      (two batteries)
    ├── PopoverView       (two columns)
    ├── BatteryIconView   (SF Symbols)
    └── LaunchAtLogin     (SMAppService)
Tests/MoosageCoreTests/   ← XCTest with anonymized JSONL fixtures
```

Adding a new provider (e.g. **Cursor**, **Aider**, **Continue**) is mostly:

1. Implement `UsageProvider` for it (read whatever local files it leaves you)
2. Add to `UsageStore.providers`
3. Drop a panel into `PopoverView`
4. Pick a one-letter menu-bar tag

If your favorite agent doesn't write _anything_ to disk that exposes usage, file an issue on the agent's repo asking for it. Codex got this right; the bar is achievable.

## Contributing

This was hacked together in a single coding session. There are sharp edges. PRs are very welcome — especially:

- Chrome cookie extraction → live Claude % & extras
- More providers (Cursor / Aider / Continue / etc.)
- Better menu-bar layout for users with many menu-bar items competing for space
- A real app icon (currently the dock icon is hidden by `LSUIElement=true`, but the `.app` bundle has nothing for the Finder; an `.icns` would be nice)
- Localization
- Anything that makes the cow more central to the experience

How:

1. Fork & clone
2. Make a branch
3. `swift test` should still pass; `./Scripts/verify.sh` should be clean
4. Commit with a useful message and open a PR

No CLA, no contributor license. Just don't push secrets and we're good.

## License

MIT — do whatever. See [LICENSE](LICENSE).

## Credits

- The 5-hour rolling-window dedup algorithm is essentially [`ccusage`](https://github.com/ryoppippi/ccusage)'s, ported to Swift.
- Codex's well-designed `rate_limits` JSONL block did 80% of that side's work for me.
- The cow emoji is doing a lot of branding lifting and I appreciate it.

---

🐮 _moo_
