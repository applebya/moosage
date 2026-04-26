import XCTest
@testable import MoosageCore

final class BlockBuilderTests: XCTestCase {
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func date(_ s: String) -> Date {
        iso.date(from: s)!
    }

    private func entry(
        _ ts: String,
        model: String = "claude-opus-4-7",
        input: Int = 100,
        output: Int = 50,
        msgId: String? = nil,
        reqId: String? = nil
    ) -> UsageEntry {
        UsageEntry(
            timestamp: date(ts),
            model: model,
            inputTokens: input,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            outputTokens: output,
            messageId: msgId,
            requestId: reqId
        )
    }

    func testEmptyInputProducesEmptyArray() {
        XCTAssertEqual(BlockBuilder.buildBlocks(from: []), [])
    }

    func testSingleEntryProducesSingleBlock() {
        let e = entry("2026-04-26T08:00:00.000Z", input: 200, output: 100)
        let blocks = BlockBuilder.buildBlocks(from: [e])
        XCTAssertEqual(blocks.count, 1)
        let b = blocks[0]
        XCTAssertEqual(b.startTime, date("2026-04-26T08:00:00.000Z"))
        XCTAssertEqual(b.endTime, date("2026-04-26T13:00:00.000Z"))
        XCTAssertEqual(b.totalTokens, 300)
        XCTAssertEqual(b.entryCount, 1)
        XCTAssertEqual(b.tokensByModel["claude-opus-4-7"], 300)
    }

    func testTwoEntriesOneHourApartProduceOneBlock() {
        let entries = [
            entry("2026-04-26T08:00:00.000Z", input: 100, output: 50),
            entry("2026-04-26T09:00:00.000Z", input: 200, output: 100),
        ]
        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].totalTokens, 450)
        XCTAssertEqual(blocks[0].entryCount, 2)
    }

    func testTwoEntriesSixHoursApartProduceTwoBlocks() {
        let entries = [
            entry("2026-04-26T08:00:00.000Z", input: 100, output: 50),
            entry("2026-04-26T14:00:00.000Z", input: 200, output: 100),
        ]
        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].entryCount, 1)
        XCTAssertEqual(blocks[1].entryCount, 1)
        XCTAssertEqual(blocks[0].startTime, date("2026-04-26T08:00:00.000Z"))
        XCTAssertEqual(blocks[1].startTime, date("2026-04-26T14:00:00.000Z"))
    }

    func testCrossingBlockBoundaryFromFixture() throws {
        let url = try fixtureURL(named: "crossing_block_boundary")
        let entries = UsageScanner.parseFile(at: url)
        XCTAssertEqual(entries.count, 4)

        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 2)

        // First block: 08:00 + 10:00 entries
        XCTAssertEqual(blocks[0].startTime, date("2026-04-26T08:00:00.000Z"))
        XCTAssertEqual(blocks[0].endTime, date("2026-04-26T13:00:00.000Z"))
        XCTAssertEqual(blocks[0].entryCount, 2)
        XCTAssertEqual(blocks[0].totalTokens, 100 + 50 + 200 + 80)

        // Second block: 13:30 + 14:00 entries (13:30 is 5.5h after 08:00 → new block)
        XCTAssertEqual(blocks[1].startTime, date("2026-04-26T13:30:00.000Z"))
        XCTAssertEqual(blocks[1].endTime, date("2026-04-26T18:30:00.000Z"))
        XCTAssertEqual(blocks[1].entryCount, 2)
        XCTAssertEqual(blocks[1].totalTokens, 300 + 120 + 400 + 160)
    }

    func testDuplicatesAreDedupedFromFixture() throws {
        let url = try fixtureURL(named: "duplicates")
        let entries = UsageScanner.parseFile(at: url)
        XCTAssertEqual(entries.count, 3) // raw parse keeps all 3

        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 1)
        // After dedup: only msg_x once + msg_y → 2 entries
        XCTAssertEqual(blocks[0].entryCount, 2)
        XCTAssertEqual(blocks[0].totalTokens, 100 + 50 + 200 + 80)
    }

    func testCurrentBlockReturnsActiveBlock() {
        let e = entry("2026-04-26T08:00:00.000Z")
        let blocks = BlockBuilder.buildBlocks(from: [e])
        XCTAssertEqual(
            BlockBuilder.currentBlock(in: blocks, now: date("2026-04-26T10:00:00.000Z")),
            blocks[0]
        )
    }

    func testCurrentBlockReturnsNilWhenLastBlockEnded() {
        let e = entry("2026-04-26T08:00:00.000Z")
        let blocks = BlockBuilder.buildBlocks(from: [e])
        XCTAssertNil(
            BlockBuilder.currentBlock(in: blocks, now: date("2026-04-26T14:00:00.000Z"))
        )
    }

    func testTokensByModelAggregates() {
        let entries = [
            entry("2026-04-26T08:00:00.000Z", model: "opus", input: 100, output: 50),
            entry("2026-04-26T08:30:00.000Z", model: "sonnet", input: 200, output: 80),
            entry("2026-04-26T09:00:00.000Z", model: "opus", input: 50, output: 25),
        ]
        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].tokensByModel["opus"], 225)
        XCTAssertEqual(blocks[0].tokensByModel["sonnet"], 280)
    }

    func testUnsortedInputIsHandled() {
        let entries = [
            entry("2026-04-26T09:00:00.000Z", input: 200, output: 100),
            entry("2026-04-26T08:00:00.000Z", input: 100, output: 50),
        ]
        let blocks = BlockBuilder.buildBlocks(from: entries)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].startTime, date("2026-04-26T08:00:00.000Z"))
    }

    private func fixtureURL(named: String) throws -> URL {
        let url = Bundle.module.url(
            forResource: named,
            withExtension: "jsonl",
            subdirectory: "Fixtures"
        )
        return try XCTUnwrap(url, "missing fixture \(named).jsonl")
    }
}
