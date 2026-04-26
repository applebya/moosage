# Contributing

Welcome — Moosage is small, friendly, and hackable. Anything in [ROADMAP.md](ROADMAP.md) is fair game; so is anything you spot that's wrong.

## Quick start

```bash
git clone https://github.com/applebya/moosage.git
cd moosage
swift test               # 38 tests, runs in <1s
./Scripts/verify.sh      # full pipeline (tests + build + sign + smoke launch)
./Scripts/install.sh     # if you want to actually run it locally
```

You need macOS 13+ and the Swift command-line toolchain (`xcode-select --install`).

## How to ship a change

1. Open or comment on an issue describing what you're going to do (especially for non-trivial work — saves wasted effort if someone else is mid-PR or if the maintainer has a different design in mind).
2. Fork, branch off `main`.
3. Make the change. Keep the diff focused.
4. `swift test` must pass. `./Scripts/verify.sh` must pass clean.
5. Conventional-commit-style messages preferred (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
6. Open a PR. Fill out the template. Link the issue.

CI runs `swift test` + `swift build` on every PR — let it pass before asking for review.

## Code conventions

**Style:** standard Swift. 4-space indent, `final class` by default, value types where they fit, `let` over `var`. No SwiftLint config yet — if you want one, that's a welcome PR.

**Concurrency:** the app is `@MainActor`-heavy. Providers expose a sync `snapshot(now:)` method called from main; if you add a provider that needs heavy I/O, do the work inside the snapshot call but be aware of the 5s polling cadence and keep it well under that.

**Tests:** new logic in `Sources/MoosageCore/` should come with tests in `Tests/MoosageCoreTests/`. Anything UI-only in `Sources/MoosageApp/` is harder to unit test — prioritize keeping logic out of SwiftUI views and into `MoosageCore` so it stays testable.

**Fixtures:** anonymized JSONL fixtures live in `Tests/MoosageCoreTests/Fixtures/`. If you add a new provider, add a small representative fixture there.

**Comments:** explain _why_, not _what_. The code already says what it does.

**Public API:** anything `public` in `MoosageCore` is part of the surface a new provider implementer will see. Mark only what genuinely needs to be public; default to internal.

## Adding a new provider

The high-level recipe is in [ROADMAP.md item #4](ROADMAP.md#4-more-providers). The shortest version:

```swift
public final class FooProvider: UsageProvider {
    public let id = "foo"
    public let displayName = "Foo CLI"
    public let letter = "F"
    public let watchedPaths: [URL] = [/* whatever Foo writes to */]

    public func snapshot(now: Date) -> ProviderSnapshot {
        // 1. Read your provider's local files
        // 2. Compute primary fill ratio + reset time + (optional) weekly + plan
        // 3. Return ProviderSnapshot(...)
    }
}
```

Then in `Sources/MoosageApp/UsageStore.swift`:

```swift
let fooProvider: FooProvider
private var providers: [UsageProvider] { [claudeProvider, codexProvider, fooProvider] }
```

…and add a `providerColumn(snap: store.fooSnapshot, …)` to `PopoverView`.

If the menu bar gets too busy, we'll revisit the layout — three providers is fine, six is probably not.

## Reporting bugs

Use the bug template in [.github/ISSUE_TEMPLATE/](. github/ISSUE_TEMPLATE/). Include:

- macOS version (`sw_vers`)
- Swift version (`swift --version`)
- Output of `./Scripts/verify.sh` if relevant
- Anonymized snippet of the JSONL line that broke things, if applicable

## Reporting security issues

Don't open a public issue for security stuff. Email `andrewappleby22@gmail.com` directly. The threat surface here is small (local file reads + one Anthropic API call), but if you spot something, please tell me before telling Reddit.

## License

By contributing you agree your contributions are licensed under the project's MIT license. No CLA, no signed agreement.

## Code of conduct

Be a decent person. The project is small enough that rigorous formal CoCs would be cosplay; the basics apply: don't be cruel, don't harass, don't ship code that punches down. If you have a problem with someone in the project, email me.

🐮
