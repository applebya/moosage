import Foundation

/// A parsed Codex `event_msg` of subtype `token_count`.
/// Codex writes one of these after every turn to `~/.codex/sessions/.../*.jsonl`,
/// containing authoritative rate-limit state from OpenAI's backend.
public struct CodexUsageEvent: Equatable {
    public let timestamp: Date
    public let totalTokens: Int
    public let lastTotalTokens: Int

    /// 5-hour rolling window.
    public let primary: CodexBucket?
    /// Weekly window.
    public let secondary: CodexBucket?

    public let credits: CodexCredits?
    public let planType: String?

    public init(
        timestamp: Date,
        totalTokens: Int,
        lastTotalTokens: Int,
        primary: CodexBucket?,
        secondary: CodexBucket?,
        credits: CodexCredits?,
        planType: String?
    ) {
        self.timestamp = timestamp
        self.totalTokens = totalTokens
        self.lastTotalTokens = lastTotalTokens
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
    }
}

public struct CodexBucket: Equatable {
    public let usedPercent: Double      // 0…100
    public let windowMinutes: Int
    public let resetsAt: Date
    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct CodexCredits: Equatable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: Double?
    public init(hasCredits: Bool, unlimited: Bool, balance: Double?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}
