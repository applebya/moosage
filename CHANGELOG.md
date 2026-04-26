# Changelog

All notable changes to Moosage are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project tries to follow [Semantic Versioning](https://semver.org/) once it has a real release.

## Unreleased

Nothing yet — open a PR and add to this section.

## [0.2.0] — 2026-04-26

### Added

- **Codex CLI provider** reading authoritative rate-limit data from `~/.codex/sessions/**/*.jsonl`'s `event_msg.token_count.rate_limits` payload. No estimation — uses OpenAI's own numbers.
- **Plan auto-detect for Claude Code** via the macOS Keychain entry `Claude Code-credentials` (cached fields) plus a 5-minute refresh against `https://api.anthropic.com/api/oauth/profile` for live tier changes.
- `UsageProvider` protocol with `ProviderSnapshot` as the unified UI-facing struct — adding a new agent provider is now a single file in `MoosageCore`.
- Real loading state: the popover shows a spinner until the first refresh completes, the menu bar shows a placeholder. No more misleading 0% bars on launch.
- `ROADMAP.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, issue/PR templates, GitHub Actions CI.

### Changed

- **Renamed** ClaudeUsage → Moosage 🐮. Bundle id is now `com.applebya.moosage`. Sources moved from `Sources/ClaudeUsage*` to `Sources/Moosage*`. Test target similarly. Old `ClaudeUsage.app` is removed by `install.sh` if found.
- **Menu bar** now shows two side-by-side mini batteries (`[C 94%] [O 18%]`) instead of one battery + reset time. Reset time moved to the popover.
- **Battery icon** uses SF Symbols (`battery.0` … `battery.100`) instead of a custom `GeometryReader`-based shape — the previous shape collapsed to zero size inside `MenuBarExtra` labels and only the letter showed.
- **Popover layout** is now horizontal (Claude left, Codex right) at 540pt wide, instead of vertically stacked.
- **Battery colors** now reflect "used", not "remaining": default tint <75%, **yellow ≥75%**, **red ≥90%**.
- **Refresh cadence** dropped from 30s to 5s polling, plus a recursive `FSEventStream` (was a top-level `DispatchSource` that missed writes inside per-project subdirectories).
- **Plan caps** recalibrated against observed Claude.ai data (Max 5×: 88M → 94M; Pro/Max 20× scaled by the same ratio).

### Limitations honest-listed

- Live Claude % and extras balance still come from a Cloudflare-gated endpoint that needs session cookies — the OAuth scope on the Claude Code credential isn't sufficient. See ROADMAP item #1.
- Reset times can drift up to ~10 minutes from claude.ai's because we anchor at the first observed event in JSONL while Anthropic likely uses request-arrival on their backend.

## [0.1.0] — 2026-04-26

Initial release as `ClaudeUsage`.

- Custom-drawn battery icon + reset time in menu bar
- Single-Claude-only popover with plan dropdown
- 5h-block estimation from `~/.claude/projects/**/*.jsonl`
- `Scripts/install.sh`, `verify.sh`, `uninstall.sh`
- Manual plan limits with three presets

(Same day as v0.2 — the rename happened mid-evening.)
