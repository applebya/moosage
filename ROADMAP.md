# Roadmap

Outstanding work, in rough priority order. Items here are explicit asks that haven't shipped yet — pick one and PR it. The README's "What doesn't work yet" section points here.

## Open issues looking for an owner

### 1. Live Claude session % matching `claude.ai/settings/usage`

**Status:** blocked on auth · **Difficulty:** medium-hard · **Impact:** high

The endpoint exists and works — `GET https://claude.ai/api/organizations/{orgId}/usage` returns:

```jsonc
{
  "five_hour":  { "utilization": 100, "resets_at": "..." },
  "seven_day":  { "utilization": 18,  "resets_at": "..." },
  "extra_usage": { "is_enabled": true, "used_credits": 4886, "currency": "CAD" },
  ...
}
```

…but it's behind Cloudflare and requires session cookies. Claude Code's local OAuth bearer (Keychain entry `Claude Code-credentials`) returns 403 against this endpoint because its scope (`user:profile`, `user:inference`, `user:sessions:claude_code`, etc.) doesn't include org-level usage reads.

**Implementation path:**

1. Read `claude.ai` cookies from `~/Library/Application Support/Google/Chrome/Default/Cookies` (SQLite).
2. Decrypt `encrypted_value` using AES-128-CBC with a PBKDF2-derived key from the macOS Keychain entry `Chrome Safe Storage` (or `Chromium Safe Storage`, or the profile-specific equivalent on newer Chrome).
3. Stitch cookies into the `Cookie:` header of a `URLSession` request to `https://claude.ai/api/organizations/{orgId}/usage`.
4. Map the response into a new optional `liveUsage` field on `ProviderSnapshot` (so we can fall back to the JSONL estimate when offline).
5. UI: badge "live" vs "estimated" in the Claude column header.

**Watch out for:**

- Chrome's `app-bound encryption` (Chrome 127+, ~mid-2024) wraps the cookie key further so only the originating app can decrypt — works for Chrome itself, not always for outside readers. Newer Chrome versions may require alternative paths (DPAPI on Windows, LAContext-gated Keychain access on macOS, or just degrading to the older `v10` cookies).
- Safari, Arc, Firefox, Brave each store cookies differently. Start with Chrome only; add others by request.
- This is _invasive_. Make it opt-in via a "Connect Live Claude.ai" toggle in the popover, not silent.

**Files to touch:** add `Sources/MoosageCore/ChromeCookieJar.swift` + `ClaudeWebClient.swift`; modify `ClaudeProvider` to optionally use `ClaudeWebClient` as the source of truth; add a UI toggle in `PopoverView`.

---

### 2. Extras balance display ($X.XX in 24h)

**Status:** blocked on (1) · **Difficulty:** trivial _after_ (1) lands · **Impact:** medium

The `extra_usage.used_credits` field comes back from the same endpoint. Once the live request works, just decode `used_credits` + `currency` and render in the popover. Track 24h delta by storing `(timestamp, used_credits)` snapshots in `~/Library/Caches/com.applebya.moosage/extras-history.json` and diffing the most recent against `now - 24h`.

---

### 3. "Plan value used" cost framing

**Status:** ready to build · **Difficulty:** easy · **Impact:** medium

For users who don't have extras enabled, the literal "extras spent" number is always $0. A more useful framing is: "you used X tokens worth $Y at metered API rates" — i.e. value the plan delivered.

Add `Sources/MoosageCore/Pricing.swift` with per-model rates (Anthropic + OpenAI public pricing tables), compute `inputTokens × inputRate + outputTokens × outputRate` per provider for the current 5h block, render as `~$X` in the popover. Make sure the README is clear it's an estimate of API-equivalent value, not money you actually owe.

---

### 4. More providers

**Status:** ready to build · **Difficulty:** varies per provider · **Impact:** scales with audience

The `UsageProvider` protocol is designed to accept new sources cleanly. Each new provider is roughly:

1. Find where the agent stores per-message usage on disk.
2. Implement the protocol (return a `ProviderSnapshot`).
3. Add to `UsageStore.providers`.
4. Drop a panel in `PopoverView`, pick a one-letter menu-bar tag.

Candidates ranked by likelihood of having usable local data:

- **Aider** — rich JSON-format chat history, includes token counts per message
- **Continue.dev** — local SQLite database with usage info
- **Cursor** — usage UI is server-side, may need similar cookie-extraction path
- **Cline / Roo Code** — VS Code extensions, store data per-workspace

If your favorite agent doesn't write usage to disk anywhere, file an upstream issue asking for it — Codex's `rate_limits` block is a great template.

---

### 5. Custom app icon

**Status:** needs an asset · **Difficulty:** trivial · **Impact:** cosmetic

`LSUIElement=true` hides the dock icon, but the `.app` bundle still needs a Finder icon. Currently it has none, so Finder shows a generic blank app. Drop an `Icon.icns` (cow themed, obviously) into `Resources/` and reference it via `CFBundleIconFile` in `Info.plist`.

---

### 6. Notarization for distribution

**Status:** ready to build · **Difficulty:** medium (needs Apple Developer account) · **Impact:** unblocks "download a .dmg from the GitHub releases page"

Currently we ad-hoc sign — works for personal install via `./Scripts/install.sh`, but Gatekeeper will refuse to launch a downloaded `.dmg`. Notarization needs:

- An Apple Developer account ($99/yr)
- A Developer ID Application certificate
- `xcrun notarytool submit` in `Scripts/build-app.sh` after `codesign`
- Stapled ticket via `xcrun stapler staple`

A GitHub Actions workflow that builds + notarizes + uploads to a release on tag push would make distribution one `git tag v0.X.0 && git push --tags` away.

---

### 7. macOS Tahoe / Liquid Glass adaptation

**Status:** investigative · **Difficulty:** unknown · **Impact:** future-proofing

macOS 26's new `Liquid Glass` material may render the menu bar item differently. Currently we use `MenuBarExtra(.window)` with default rendering — should be tested on macOS 26 to confirm the SF Symbol batteries still read clearly against the new translucent material. May want to switch to `LiquidGlass` background variant if it ships.

---

### 8. Settings panel

**Status:** nice-to-have · **Difficulty:** medium · **Impact:** UX

Currently the only "settings" UI is the launch-at-login toggle and the Claude plan picker (when not auto-detected) inline in the popover. A proper Settings sheet would be the right home for:

- Per-provider enable/disable toggles
- Refresh interval (5s might be too aggressive for some)
- "Connect Live Claude.ai" toggle for (1)
- Color threshold customization (75/90 may not suit everyone)
- Cost framing toggle (3)

Consider `Settings { … }` scene alongside `MenuBarExtra`.

---

## Recently shipped

See [CHANGELOG.md](CHANGELOG.md).
