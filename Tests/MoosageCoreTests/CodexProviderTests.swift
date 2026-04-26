import XCTest
@testable import MoosageCore

final class CodexProviderTests: XCTestCase {
    func testReadsLatestRateLimitsFromFixture() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Mirror the on-disk shape: ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl
        let dayDir = tmp.appendingPathComponent("2026/04/26", isDirectory: true)
        try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)
        let fixture = try XCTUnwrap(Bundle.module.url(
            forResource: "codex_session",
            withExtension: "jsonl",
            subdirectory: "Fixtures"
        ))
        let dest = dayDir.appendingPathComponent("rollout.jsonl")
        try FileManager.default.copyItem(at: fixture, to: dest)

        let provider = CodexProvider(root: tmp)
        let now = Date()
        let snap = provider.snapshot(now: now)

        XCTAssertEqual(snap.providerId, "codex")
        XCTAssertEqual(snap.providerLetter, "O")
        // The *last* token_count event in the fixture wins (78% primary).
        XCTAssertEqual(snap.primaryFillRatio, 0.78, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snap.weeklyFillRatio), 0.15, accuracy: 0.001)
        XCTAssertEqual(snap.planName, "ChatGPT Plus")
        XCTAssertEqual(snap.primaryUsedTokens, 2100)
    }

    func testEmptyDirectoryReturnsEmptySnapshot() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexProviderTests-empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let provider = CodexProvider(root: tmp)
        let snap = provider.snapshot(now: Date())
        XCTAssertEqual(snap.primaryFillRatio, 0)
        XCTAssertNil(snap.primaryResetTime)
        XCTAssertTrue(snap.isStale)
    }

    func testPicksNewestFileWhenMultiplePresent() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let oldDir = tmp.appendingPathComponent("2026/04/01")
        let newDir = tmp.appendingPathComponent("2026/04/26")
        try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)

        let oldLine = #"{"timestamp":"2026-04-01T08:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":100},"last_token_usage":{"total_tokens":100}},"rate_limits":{"primary":{"used_percent":10.0,"window_minutes":300,"resets_at":1777968000},"plan_type":"plus"}}}"#
        let newLine = #"{"timestamp":"2026-04-26T08:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":2000},"last_token_usage":{"total_tokens":2000}},"rate_limits":{"primary":{"used_percent":50.0,"window_minutes":300,"resets_at":1777968000},"plan_type":"pro"}}}"#

        let oldFile = oldDir.appendingPathComponent("rollout-old.jsonl")
        let newFile = newDir.appendingPathComponent("rollout-new.jsonl")
        try oldLine.write(to: oldFile, atomically: true, encoding: .utf8)
        try newLine.write(to: newFile, atomically: true, encoding: .utf8)

        // Force older mtime on the old file so the picker is deterministic.
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3600)],
            ofItemAtPath: oldFile.path
        )

        let provider = CodexProvider(root: tmp)
        let snap = provider.snapshot(now: Date(timeIntervalSince1970: 1777968000 - 60))
        XCTAssertEqual(snap.primaryFillRatio, 0.50, accuracy: 0.001)
        XCTAssertEqual(snap.planName, "ChatGPT Pro")
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
