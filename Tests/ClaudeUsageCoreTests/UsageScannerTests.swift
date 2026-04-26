import XCTest
@testable import ClaudeUsageCore

final class UsageScannerTests: XCTestCase {
    func testScansNestedJsonlFilesAndSkipsOthers() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let nested = tmp.appendingPathComponent("project-a", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let validLine = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7","usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}"#

        try (validLine + "\n").write(
            to: nested.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        // unrelated file — should be skipped
        try "ignore me".write(
            to: nested.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entries = UsageScanner.scan(root: tmp)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].messageId, "m")
    }

    func testScannerProducesSortedOutput() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let lineLater = #"{"type":"assistant","timestamp":"2026-04-26T10:00:00.000Z","sessionId":"s","requestId":"r2","message":{"id":"m2","model":"claude-opus-4-7","usage":{"input_tokens":1,"output_tokens":1}}}"#
        let lineEarly = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r1","message":{"id":"m1","model":"claude-opus-4-7","usage":{"input_tokens":1,"output_tokens":1}}}"#

        // Two separate files, "alphabetic" order would put later first.
        try (lineLater + "\n").write(
            to: tmp.appendingPathComponent("a.jsonl"),
            atomically: true, encoding: .utf8
        )
        try (lineEarly + "\n").write(
            to: tmp.appendingPathComponent("b.jsonl"),
            atomically: true, encoding: .utf8
        )

        let entries = UsageScanner.scan(root: tmp)
        XCTAssertEqual(entries.count, 2)
        XCTAssertLessThan(entries[0].timestamp, entries[1].timestamp)
        XCTAssertEqual(entries[0].messageId, "m1")
    }

    func testScannerHandlesMissingDirectory() {
        let tmp = URL(fileURLWithPath: "/var/folders/zzz-does-not-exist-\(UUID().uuidString)")
        XCTAssertEqual(UsageScanner.scan(root: tmp), [])
    }

    func testStreamingHandlesLargeFile() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("big.jsonl")

        var lines: [String] = []
        for i in 0..<2_000 {
            // Stagger timestamps within a single 5h block to keep the parser exercised.
            let secs = i % 60
            let mins = (i / 60) % 60
            let ts = String(format: "2026-04-26T08:%02d:%02d.000Z", mins, secs)
            lines.append(#"{"type":"assistant","timestamp":"\#(ts)","sessionId":"s","requestId":"r\#(i)","message":{"id":"m\#(i)","model":"claude-opus-4-7","usage":{"input_tokens":1,"output_tokens":1}}}"#)
        }
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)

        let entries = UsageScanner.parseFile(at: file)
        XCTAssertEqual(entries.count, 2_000)
    }

    func testParseFileSkipsMalformedAndNonAssistantLines() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        guard let bundleURL = Bundle.module.url(
            forResource: "malformed",
            withExtension: "jsonl",
            subdirectory: "Fixtures"
        ) else {
            return XCTFail("missing malformed fixture")
        }

        let entries = UsageScanner.parseFile(at: bundleURL)
        // Only the single assistant line with usage should survive.
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].messageId, "msg_ok")
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
