import Foundation

public enum CodexJSONLParser {
    private struct RawLine: Decodable {
        let timestamp: String?
        let type: String?
        let payload: RawPayload?
    }
    private struct RawPayload: Decodable {
        let type: String?
        let info: RawInfo?
        let rate_limits: RawRateLimits?
    }
    private struct RawInfo: Decodable {
        let total_token_usage: RawTokenUsage?
        let last_token_usage: RawTokenUsage?
    }
    private struct RawTokenUsage: Decodable {
        let total_tokens: Int?
    }
    private struct RawRateLimits: Decodable {
        let primary: RawBucket?
        let secondary: RawBucket?
        let credits: RawCredits?
        let plan_type: String?
    }
    private struct RawBucket: Decodable {
        let used_percent: Double?
        let window_minutes: Int?
        let resets_at: TimeInterval?
    }
    private struct RawCredits: Decodable {
        let has_credits: Bool?
        let unlimited: Bool?
        let balance: Double?
    }

    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func parse(line: String) -> CodexUsageEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }

        let raw: RawLine
        do { raw = try JSONDecoder().decode(RawLine.self, from: data) } catch { return nil }

        // We only care about token_count payloads — there are many other event types.
        guard raw.type == "event_msg",
              let payload = raw.payload,
              payload.type == "token_count" else { return nil }

        guard let timestampString = raw.timestamp,
              let timestamp = isoWithFractional.date(from: timestampString)
                ?? isoPlain.date(from: timestampString) else { return nil }

        let total = payload.info?.total_token_usage?.total_tokens ?? 0
        let last = payload.info?.last_token_usage?.total_tokens ?? 0

        let primary: CodexBucket? = payload.rate_limits?.primary.flatMap { b in
            guard let pct = b.used_percent, let win = b.window_minutes, let reset = b.resets_at else { return nil }
            return CodexBucket(usedPercent: pct, windowMinutes: win, resetsAt: Date(timeIntervalSince1970: reset))
        }
        let secondary: CodexBucket? = payload.rate_limits?.secondary.flatMap { b in
            guard let pct = b.used_percent, let win = b.window_minutes, let reset = b.resets_at else { return nil }
            return CodexBucket(usedPercent: pct, windowMinutes: win, resetsAt: Date(timeIntervalSince1970: reset))
        }
        let credits: CodexCredits? = payload.rate_limits?.credits.map {
            CodexCredits(hasCredits: $0.has_credits ?? false, unlimited: $0.unlimited ?? false, balance: $0.balance)
        }

        return CodexUsageEvent(
            timestamp: timestamp,
            totalTokens: total,
            lastTotalTokens: last,
            primary: primary,
            secondary: secondary,
            credits: credits,
            planType: payload.rate_limits?.plan_type
        )
    }
}
