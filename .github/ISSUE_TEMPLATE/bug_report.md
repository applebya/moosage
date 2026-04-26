---
name: Bug report
about: Something is rendering wrong, crashing, or showing incorrect numbers
labels: bug
---

## What happened

<!-- One or two sentences. -->

## What I expected

<!-- What you thought would happen instead. -->

## How to reproduce

1.
2.
3.

## Screenshot

<!-- Especially helpful for menu bar / popover layout issues. -->

## Environment

- macOS version (`sw_vers -productVersion`):
- Swift version (`swift --version | head -1`):
- Moosage version (from `Info.plist` CFBundleShortVersionString, or `git describe --always`):
- Provider in question (Claude / Codex / both):

## Anonymized JSONL snippet (if a parser bug)

<!-- Strip session IDs, request IDs, message IDs. We just need the shape. -->

```jsonc

```

## `./Scripts/verify.sh` output (if relevant)

```

```
