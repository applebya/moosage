import XCTest
@testable import ClaudeUsageCore

final class JSONLParserTests: XCTestCase {
    func testParsesRealAssistantLine() throws {
        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:01.000Z","sessionId":"s","requestId":"req_001","message":{"id":"msg_001","model":"claude-opus-4-7","role":"assistant","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000,"output_tokens":50}}}"#
        let entry = try XCTUnwrap(JSONLParser.parse(line: line))
        XCTAssertEqual(entry.model, "claude-opus-4-7")
        XCTAssertEqual(entry.inputTokens, 100)
        XCTAssertEqual(entry.cacheReadTokens, 1000)
        XCTAssertEqual(entry.cacheCreationTokens, 0)
        XCTAssertEqual(entry.outputTokens, 50)
        XCTAssertEqual(entry.totalTokens, 1150)
        XCTAssertEqual(entry.messageId, "msg_001")
        XCTAssertEqual(entry.requestId, "req_001")
        XCTAssertEqual(entry.dedupKey, "msg_001:req_001")
    }

    func testReturnsNilForEmptyAndWhitespace() {
        XCTAssertNil(JSONLParser.parse(line: ""))
        XCTAssertNil(JSONLParser.parse(line: "   "))
        XCTAssertNil(JSONLParser.parse(line: "\n"))
    }

    func testReturnsNilWhenMessageMissingUsage() {
        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7"}}"#
        XCTAssertNil(JSONLParser.parse(line: line))
    }

    func testReturnsNilForMalformedJSON() {
        XCTAssertNil(JSONLParser.parse(line: "{not json"))
        XCTAssertNil(JSONLParser.parse(line: "{\"type\":\"assistant\""))
    }

    func testReturnsNilForOtherEventTypes() {
        let line = #"{"type":"permission-mode","permissionMode":"plan","sessionId":"s"}"#
        XCTAssertNil(JSONLParser.parse(line: line))
    }

    func testParsesISOWithFractionalSeconds() {
        let s = "2026-04-26T08:14:22.123Z"
        let d = JSONLParser.parseTimestamp(s)
        XCTAssertNotNil(d)
    }

    func testParsesISOWithoutFractionalSeconds() {
        let s = "2026-04-26T08:14:22Z"
        let d = JSONLParser.parseTimestamp(s)
        XCTAssertNotNil(d)
    }

    func testMissingOptionalTokenFieldsDefaultToZero() throws {
        let line = #"{"type":"assistant","timestamp":"2026-04-26T08:00:00.000Z","sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-opus-4-7","usage":{"output_tokens":42}}}"#
        let entry = try XCTUnwrap(JSONLParser.parse(line: line))
        XCTAssertEqual(entry.inputTokens, 0)
        XCTAssertEqual(entry.cacheCreationTokens, 0)
        XCTAssertEqual(entry.cacheReadTokens, 0)
        XCTAssertEqual(entry.outputTokens, 42)
        XCTAssertEqual(entry.totalTokens, 42)
    }

    func testTimestampWithoutTypeFieldStillParsesIfUsagePresent() throws {
        // Schema is liberal: as long as message.usage and timestamp exist, parse it.
        let line = #"{"timestamp":"2026-04-26T08:00:00.000Z","requestId":"r","message":{"id":"m","model":"haiku-4-5","usage":{"input_tokens":1,"output_tokens":1}}}"#
        let entry = try XCTUnwrap(JSONLParser.parse(line: line))
        XCTAssertEqual(entry.model, "haiku-4-5")
    }
}
