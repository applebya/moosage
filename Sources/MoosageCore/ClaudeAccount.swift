import Foundation

/// Plan/account info derivable from Claude Code's local OAuth credentials.
public struct ClaudeAccount: Equatable {
    public let plan: Plan
    public let rateLimitTier: String
    public let subscriptionType: String
    public let hasExtraUsageEnabled: Bool?
    public let email: String?

    public init(plan: Plan, rateLimitTier: String, subscriptionType: String, hasExtraUsageEnabled: Bool?, email: String?) {
        self.plan = plan
        self.rateLimitTier = rateLimitTier
        self.subscriptionType = subscriptionType
        self.hasExtraUsageEnabled = hasExtraUsageEnabled
        self.email = email
    }

    /// Map Anthropic's `rate_limit_tier` strings to our internal Plan enum.
    public static func plan(forTier tier: String) -> Plan {
        switch tier {
        case "default_claude_max_20x": return .max20x
        case "default_claude_max_5x":  return .max5x
        default:                       return .pro // Pro and other lower tiers
        }
    }
}
