import Foundation

/// Unified, UI-facing usage snapshot common to every provider.
public struct ProviderSnapshot: Equatable {
    public let providerId: String          // "claude" / "codex"
    public let providerName: String        // "Claude Code" / "Codex"
    public let providerLetter: String      // "C" / "O" — shown in menu bar

    /// 5-hour window utilization, 0…1 clamped.
    public let primaryFillRatio: Double
    public let primaryResetTime: Date?
    public let primaryUsedTokens: Int?
    public let primaryLimitTokens: Int?

    /// Optional second metric — Codex weekly bucket; nil for providers that don't expose one.
    public let weeklyFillRatio: Double?
    public let weeklyResetTime: Date?

    /// Plan label if known (e.g. "Max 5×", "ChatGPT Plus"). nil → user-set / unknown.
    public let planName: String?

    /// True if this provider has no recent activity (data may be stale).
    public let isStale: Bool

    public let lastActivity: Date?
    public let tokensByModel: [String: Int]
    public let generatedAt: Date

    public init(
        providerId: String,
        providerName: String,
        providerLetter: String,
        primaryFillRatio: Double,
        primaryResetTime: Date?,
        primaryUsedTokens: Int?,
        primaryLimitTokens: Int?,
        weeklyFillRatio: Double? = nil,
        weeklyResetTime: Date? = nil,
        planName: String? = nil,
        isStale: Bool = false,
        lastActivity: Date? = nil,
        tokensByModel: [String: Int] = [:],
        generatedAt: Date
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.providerLetter = providerLetter
        self.primaryFillRatio = min(max(primaryFillRatio, 0), 1)
        self.primaryResetTime = primaryResetTime
        self.primaryUsedTokens = primaryUsedTokens
        self.primaryLimitTokens = primaryLimitTokens
        self.weeklyFillRatio = weeklyFillRatio.map { min(max($0, 0), 1) }
        self.weeklyResetTime = weeklyResetTime
        self.planName = planName
        self.isStale = isStale
        self.lastActivity = lastActivity
        self.tokensByModel = tokensByModel
        self.generatedAt = generatedAt
    }

    /// Empty/no-data placeholder.
    public static func empty(providerId: String, providerName: String, providerLetter: String, generatedAt: Date) -> ProviderSnapshot {
        ProviderSnapshot(
            providerId: providerId,
            providerName: providerName,
            providerLetter: providerLetter,
            primaryFillRatio: 0,
            primaryResetTime: nil,
            primaryUsedTokens: nil,
            primaryLimitTokens: nil,
            isStale: true,
            generatedAt: generatedAt
        )
    }
}
