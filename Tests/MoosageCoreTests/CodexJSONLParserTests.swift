import XCTest
@testable import MoosageCore

final class CodexJSONLParserTests: XCTestCase {
    func testParsesTokenCountEvent() throws {
        let line = #"{"timestamp":"2026-04-26T07:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1050},"last_token_usage":{"total_tokens":42}},"rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":1777968000},"secondary":{"used_percent":3.0,"window_minutes":10080,"resets_at":1778572800},"credits":{"has_credits":true,"unlimited":false,"balance":42.50},"plan_type":"plus"}}}"#
        let event = try XCTUnwrap(CodexJSONLParser.parse(line: line))
        XCTAssertEqual(event.totalTokens, 1050)
        XCTAssertEqual(event.lastTotalTokens, 42)
        XCTAssertEqual(event.primary?.usedPercent, 12.5)
        XCTAssertEqual(event.primary?.windowMinutes, 300)
        XCTAssertEqual(event.primary?.resetsAt, Date(timeIntervalSince1970: 1777968000))
        XCTAssertEqual(event.secondary?.usedPercent, 3.0)
        XCTAssertEqual(event.secondary?.windowMinutes, 10080)
        XCTAssertEqual(event.credits?.hasCredits, true)
        XCTAssertEqual(event.credits?.balance, 42.50)
        XCTAssertEqual(event.planType, "plus")
    }

    func testReturnsNilForNonTokenCountEvent() {
        let line = #"{"timestamp":"2026-04-26T07:00:00.000Z","type":"event_msg","payload":{"type":"agent_message"}}"#
        XCTAssertNil(CodexJSONLParser.parse(line: line))
    }

    func testReturnsNilForSessionMeta() {
        let line = #"{"timestamp":"2026-04-26T07:00:00.000Z","type":"session_meta","payload":{"id":"sess-1"}}"#
        XCTAssertNil(CodexJSONLParser.parse(line: line))
    }

    func testReturnsNilForEmptyAndMalformed() {
        XCTAssertNil(CodexJSONLParser.parse(line: ""))
        XCTAssertNil(CodexJSONLParser.parse(line: "  "))
        XCTAssertNil(CodexJSONLParser.parse(line: "{not json"))
    }

    func testHandlesMissingOptionalFields() throws {
        let line = #"{"timestamp":"2026-04-26T07:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":100},"last_token_usage":{"total_tokens":100}},"rate_limits":{"primary":{"used_percent":5.0,"window_minutes":300,"resets_at":1777968000},"plan_type":null}}}"#
        let event = try XCTUnwrap(CodexJSONLParser.parse(line: line))
        XCTAssertNotNil(event.primary)
        XCTAssertNil(event.secondary)
        XCTAssertNil(event.credits)
        XCTAssertNil(event.planType)
    }
}
