import Foundation

/// Claude Code usage from `~/.claude/projects/**/*.jsonl`.
///
/// We sum the per-message `usage` blocks into 5-hour rolling windows
/// (matching `ccusage`'s algorithm) and divide by a calibrated cap that
/// depends on plan. Plan auto-detects from Claude Code's OAuth credentials
/// in the macOS Keychain when available; the user can still override.
public final class ClaudeProvider: UsageProvider {
    public let id = "claude"
    public let displayName = "Claude Code"
    public let letter = "C"
    public let watchedPaths: [URL]

    /// Mutable — set from the host on user input. Reading from a background
    /// task is safe because the field is overwritten atomically and read-after-write
    /// drift only changes which limit denominator we use for the next snapshot.
    public var plan: Plan

    /// Snapshot of the OAuth-derived account, if available. Refreshed
    /// out-of-band by the host every few minutes.
    public var account: ClaudeAccount?

    private let root: URL

    public init(root: URL = UsageScanner.defaultRoot, plan: Plan, account: ClaudeAccount? = nil) {
        self.root = root
        self.plan = plan
        self.account = account
        self.watchedPaths = [root]
    }

    public func snapshot(now: Date) -> ProviderSnapshot {
        let entries = UsageScanner.scan(root: root)
        let blocks = BlockBuilder.buildBlocks(from: entries)
        let block = BlockBuilder.currentBlock(in: blocks, now: now)
        let effectivePlan = account?.plan ?? plan
        let limit = effectivePlan.tokensPer5hBlock

        guard let block else {
            var empty = ProviderSnapshot.empty(
                providerId: id,
                providerName: displayName,
                providerLetter: letter,
                generatedAt: now
            )
            empty = ProviderSnapshot(
                providerId: empty.providerId,
                providerName: empty.providerName,
                providerLetter: empty.providerLetter,
                primaryFillRatio: 0,
                primaryResetTime: nil,
                primaryUsedTokens: nil,
                primaryLimitTokens: nil,
                planName: planLabel(effectivePlan),
                isStale: empty.isStale,
                generatedAt: now
            )
            return empty
        }

        let used = block.totalTokens
        let ratio = Double(used) / Double(limit)
        let lastActivityAge = now.timeIntervalSince(block.lastActivity)
        let isStale = lastActivityAge > 60 * 60 // >1h since last call

        return ProviderSnapshot(
            providerId: id,
            providerName: displayName,
            providerLetter: letter,
            primaryFillRatio: ratio,
            primaryResetTime: block.endTime,
            primaryUsedTokens: used,
            primaryLimitTokens: limit,
            weeklyFillRatio: nil,
            weeklyResetTime: nil,
            planName: planLabel(effectivePlan),
            isStale: isStale,
            lastActivity: block.lastActivity,
            tokensByModel: block.tokensByModel,
            generatedAt: now
        )
    }

    private func planLabel(_ plan: Plan) -> String {
        if account != nil {
            return "\(plan.displayName) · auto"
        }
        return plan.displayName
    }
}
