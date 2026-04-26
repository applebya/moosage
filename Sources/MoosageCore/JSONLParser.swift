import Foundation

public enum JSONLParser {
    private struct RawLine: Decodable {
        let type: String?
        let timestamp: String?
        let requestId: String?
        let message: RawMessage?
    }

    private struct RawMessage: Decodable {
        let id: String?
        let model: String?
        let usage: RawUsage?
    }

    private struct RawUsage: Decodable {
        let input_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
        let output_tokens: Int?
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

    public static func parseTimestamp(_ s: String) -> Date? {
        if let d = isoWithFractional.date(from: s) { return d }
        if let d = isoPlain.date(from: s) { return d }
        return nil
    }

    public static func parse(line: String) -> UsageEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }

        let raw: RawLine
        do {
            raw = try JSONDecoder().decode(RawLine.self, from: data)
        } catch {
            return nil
        }

        guard let usage = raw.message?.usage else { return nil }
        guard let timestampString = raw.timestamp,
              let timestamp = parseTimestamp(timestampString) else { return nil }

        let model = raw.message?.model ?? "unknown"

        return UsageEntry(
            timestamp: timestamp,
            model: model,
            inputTokens: usage.input_tokens ?? 0,
            cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadTokens: usage.cache_read_input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
            messageId: raw.message?.id,
            requestId: raw.requestId
        )
    }
}
