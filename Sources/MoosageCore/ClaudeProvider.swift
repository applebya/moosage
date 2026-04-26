import Foundation

/// Claude Code usage from `~/.claude/projects/**/*.jsonl`.
///
/// We sum the per-message `usage` blocks into 5-hour rolling windows
/// (matching `ccusage`'s algorithm) and divide by a calibrated cap that
/// the user can override by switching plan from the popover.
public final class ClaudeProvider: UsageProvider {
    public let id = "claude"
    public let displayName = "Claude Code"
    public let letter = "C"
    public let watchedPaths: [URL]

    /// Mutable — set from the host on user input. Reading from a background
    /// task is safe because the field is overwritten atomically and read-after-write
    /// drift only changes which limit denominator we use for the next snapshot.
    public var plan: Plan

    private let root: URL

    public init(root: URL = UsageScanner.defaultRoot, plan: Plan) {
        self.root = root
        self.plan = plan
        self.watchedPaths = [root]
    }

    public func snapshot(now: Date) -> ProviderSnapshot {
        let entries = UsageScanner.scan(root: root)
        let blocks = BlockBuilder.buildBlocks(from: entries)
        let block = BlockBuilder.currentBlock(in: blocks, now: now)
        let limit = plan.tokensPer5hBlock

        guard let block else {
            return .empty(
                providerId: id,
                providerName: displayName,
                providerLetter: letter,
                generatedAt: now
            )
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
            planName: plan.displayName,
            isStale: isStale,
            lastActivity: block.lastActivity,
            tokensByModel: block.tokensByModel,
            generatedAt: now
        )
    }
}
