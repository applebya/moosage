import Foundation

/// Codex usage from `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`.
///
/// Unlike Claude Code, Codex writes the *authoritative* rate-limit block
/// straight into each session JSONL after every turn. We just find the
/// newest session file and read its most recent `token_count` event.
public final class CodexProvider: UsageProvider {
    public let id = "codex"
    public let displayName = "Codex"
    public let letter = "O"
    public let watchedPaths: [URL]

    private let root: URL

    public static var defaultRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    public init(root: URL = CodexProvider.defaultRoot) {
        self.root = root
        self.watchedPaths = [root]
    }

    public func snapshot(now: Date) -> ProviderSnapshot {
        guard let event = latestEvent() else {
            return .empty(
                providerId: id,
                providerName: displayName,
                providerLetter: letter,
                generatedAt: now
            )
        }

        let primaryRatio = (event.primary?.usedPercent ?? 0) / 100.0
        let weeklyRatio = (event.secondary?.usedPercent).map { $0 / 100.0 }
        let isStale = now.timeIntervalSince(event.timestamp) > 60 * 60 // >1h

        return ProviderSnapshot(
            providerId: id,
            providerName: displayName,
            providerLetter: letter,
            primaryFillRatio: primaryRatio,
            primaryResetTime: event.primary?.resetsAt,
            primaryUsedTokens: event.totalTokens,
            primaryLimitTokens: nil, // Codex doesn't publish a token cap, only a %
            weeklyFillRatio: weeklyRatio,
            weeklyResetTime: event.secondary?.resetsAt,
            planName: prettyPlanName(event.planType, credits: event.credits),
            isStale: isStale,
            lastActivity: event.timestamp,
            tokensByModel: [:],
            generatedAt: now
        )
    }

    /// Walk session dir, find newest JSONL by mtime, return its latest token_count event.
    func latestEvent() -> CodexUsageEvent? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var newest: (URL, Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let mtime else { continue }
            if newest == nil || mtime > newest!.1 {
                newest = (url, mtime)
            }
        }

        guard let (file, _) = newest else { return nil }
        return latestEvent(in: file)
    }

    /// Reads `file` and returns the last `token_count` event in it. We scan
    /// the whole file because rate_limits change as the session progresses;
    /// the *last* one is current.
    func latestEvent(in file: URL) -> CodexUsageEvent? {
        guard let data = try? Data(contentsOf: file),
              let text = String(data: data, encoding: .utf8) else { return nil }

        var latest: CodexUsageEvent?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let event = CodexJSONLParser.parse(line: String(line)) {
                latest = event
            }
        }
        return latest
    }

    private func prettyPlanName(_ raw: String?, credits: CodexCredits?) -> String? {
        if let raw, !raw.isEmpty {
            switch raw.lowercased() {
            case "plus":  return "ChatGPT Plus"
            case "pro":   return "ChatGPT Pro"
            case "team":  return "ChatGPT Team"
            case "enterprise": return "ChatGPT Enterprise"
            case "edu":   return "ChatGPT Edu"
            default:      return "ChatGPT \(raw.capitalized)"
            }
        }
        if credits?.unlimited == true { return "Codex (unlimited)" }
        if credits?.hasCredits == true { return "Codex (credits)" }
        return nil
    }
}
