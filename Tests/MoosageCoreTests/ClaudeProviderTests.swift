import XCTest
@testable import MoosageCore

final class ClaudeProviderTests: XCTestCase {
    func testEmptyDirectoryProducesEmptySnapshot() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let provider = ClaudeProvider(root: tmp, plan: .max5x)
        let snap = provider.snapshot(now: Date())

        XCTAssertEqual(snap.providerId, "claude")
        XCTAssertEqual(snap.providerLetter, "C")
        XCTAssertEqual(snap.primaryFillRatio, 0)
        XCTAssertNil(snap.primaryResetTime)
        XCTAssertNil(snap.primaryUsedTokens)
        // Plan label still surfaces from the configured plan even with no data.
        XCTAssertEqual(snap.planName, "Max 5×")
    }

    func testSnapshotComputesFillAgainstPlanCap() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Single assistant entry with known token count.
        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7","usage":{"input_tokens":1000000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":500000}}}"#
        let file = tmp.appendingPathComponent("session.jsonl")
        try line.write(to: file, atomically: true, encoding: .utf8)

        // Pro cap = 20M; 1.5M used = 7.5%
        let provider = ClaudeProvider(root: tmp, plan: .pro)
        // Pick a `now` that's inside the 5h window starting at the activity timestamp.
        let activity = ISO8601DateFormatter().date(from: "2026-04-26T08:00:00Z")!
        let snap = provider.snapshot(now: activity.addingTimeInterval(60 * 60))
        XCTAssertEqual(snap.primaryUsedTokens, 1_500_000)
        XCTAssertEqual(snap.primaryLimitTokens, 20_000_000)
        XCTAssertEqual(snap.primaryFillRatio, 0.075, accuracy: 0.001)
    }

    func testAccountOverridesUserPlan() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7","usage":{"input_tokens":47000000,"output_tokens":0}}}"#
        try line.write(
            to: tmp.appendingPathComponent("session.jsonl"),
            atomically: true, encoding: .utf8
        )

        let acct = ClaudeAccount(
            plan: .max20x, rateLimitTier: "default_claude_max_20x",
            subscriptionType: "max", hasExtraUsageEnabled: nil, email: nil
        )
        // User picked Pro (20M cap), but account says Max 20× (235M) — account wins.
        let provider = ClaudeProvider(root: tmp, plan: .pro, account: acct)
        let activity = ISO8601DateFormatter().date(from: "2026-04-26T08:00:00Z")!
        let snap = provider.snapshot(now: activity.addingTimeInterval(60 * 60))
        XCTAssertEqual(snap.primaryLimitTokens, 235_000_000)
        XCTAssertEqual(snap.primaryFillRatio, 47_000_000.0 / 235_000_000.0, accuracy: 0.001)
        XCTAssertTrue(snap.planName?.contains("auto") == true, "should mark auto-detected")
    }

    func testStaleAfterOneHourSinceLastActivity() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7","usage":{"input_tokens":100,"output_tokens":50}}}"#
        try line.write(
            to: tmp.appendingPathComponent("session.jsonl"),
            atomically: true, encoding: .utf8
        )

        let provider = ClaudeProvider(root: tmp, plan: .max5x)
        let activityDate = ISO8601DateFormatter().date(from: "2026-04-26T08:00:00Z")!
        // Within block window (≤5h) but more than 1h since last activity → stale.
        let now = activityDate.addingTimeInterval(2 * 3600)
        let snap = provider.snapshot(now: now)
        XCTAssertTrue(snap.isStale, "should be stale after 1h since last activity")
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
