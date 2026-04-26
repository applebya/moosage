import Foundation
import Security

/// Reads the Claude Code OAuth credentials from the macOS Keychain
/// (entry name: `Claude Code-credentials`) and optionally fetches a
/// fresher account snapshot from `api.anthropic.com/api/oauth/profile`.
///
/// Live 5h utilization, weekly utilization, and extras-balance live
/// behind Cloudflare on `claude.ai` and need session cookies — the
/// CLI's OAuth scope does not include them. We surface what we can.
public final class ClaudeOAuthClient {
    public struct Credentials: Equatable {
        public let accessToken: String
        public let subscriptionType: String
        public let rateLimitTier: String
        public let expiresAt: Date

        public var isExpired: Bool { expiresAt < Date() }
    }

    public static let serviceName = "Claude Code-credentials"

    public init() {}

    /// Read credentials directly from Keychain. Returns nil if Claude Code
    /// isn't logged in, the user denied access, or the entry is malformed.
    public func loadCredentials() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        struct Wrapper: Decodable {
            let claudeAiOauth: OAuth?
            struct OAuth: Decodable {
                let accessToken: String
                let subscriptionType: String?
                let rateLimitTier: String?
                let expiresAt: TimeInterval?
            }
        }
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data),
              let oauth = wrapper.claudeAiOauth else { return nil }

        return Credentials(
            accessToken: oauth.accessToken,
            subscriptionType: oauth.subscriptionType ?? "unknown",
            rateLimitTier: oauth.rateLimitTier ?? "default_claude_pro",
            expiresAt: Date(timeIntervalSince1970: (oauth.expiresAt ?? 0) / 1000.0)
        )
    }

    /// Build a `ClaudeAccount` from cached Keychain data alone — no network.
    public func cachedAccount() -> ClaudeAccount? {
        guard let creds = loadCredentials() else { return nil }
        return ClaudeAccount(
            plan: ClaudeAccount.plan(forTier: creds.rateLimitTier),
            rateLimitTier: creds.rateLimitTier,
            subscriptionType: creds.subscriptionType,
            hasExtraUsageEnabled: nil,
            email: nil
        )
    }

    /// Fetch the live profile from api.anthropic.com. Returns nil on any
    /// failure (network down, expired token, scope insufficient).
    public func fetchProfile() async -> ClaudeAccount? {
        guard let creds = loadCredentials(), !creds.isExpired else { return nil }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/profile")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("Moosage/0.3 (macOS menu bar)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        struct Response: Decodable {
            let account: Account?
            let organization: Organization?
            struct Account: Decodable {
                let email: String?
                let has_claude_max: Bool?
                let has_claude_pro: Bool?
            }
            struct Organization: Decodable {
                let rate_limit_tier: String?
                let organization_type: String?
                let has_extra_usage_enabled: Bool?
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(Response.self, from: data)

            let tier = decoded.organization?.rate_limit_tier ?? creds.rateLimitTier
            return ClaudeAccount(
                plan: ClaudeAccount.plan(forTier: tier),
                rateLimitTier: tier,
                subscriptionType: decoded.organization?.organization_type ?? creds.subscriptionType,
                hasExtraUsageEnabled: decoded.organization?.has_extra_usage_enabled,
                email: decoded.account?.email
            )
        } catch {
            return nil
        }
    }
}
