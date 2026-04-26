import XCTest
@testable import MoosageCore

final class PlanLimitsTests: XCTestCase {
    func testEachPlanHasPositiveLimit() {
        for plan in Plan.allCases {
            XCTAssertGreaterThan(plan.tokensPer5hBlock, 0, "\(plan) should have positive limit")
        }
    }

    func testFillRatioClampsAtOne() {
        let block = SessionBlock(
            startTime: Date(),
            endTime: Date().addingTimeInterval(5 * 3600),
            lastActivity: Date(),
            totalTokens: 999_999_999_999,
            tokensByModel: [:],
            entryCount: 1
        )
        let snap = UsageSnapshot(plan: .pro, block: block, generatedAt: Date())
        XCTAssertEqual(snap.fillRatio, 1.0, accuracy: 0.0001)
    }

    func testFillRatioIsZeroWithoutBlock() {
        let snap = UsageSnapshot(plan: .max5x, block: nil, generatedAt: Date())
        XCTAssertEqual(snap.fillRatio, 0)
    }

    func testFillRatioInRange() {
        let block = SessionBlock(
            startTime: Date(),
            endTime: Date().addingTimeInterval(5 * 3600),
            lastActivity: Date(),
            totalTokens: Plan.max5x.tokensPer5hBlock / 2,
            tokensByModel: [:],
            entryCount: 1
        )
        let snap = UsageSnapshot(plan: .max5x, block: block, generatedAt: Date())
        XCTAssertEqual(snap.fillRatio, 0.5, accuracy: 0.0001)
    }

    func testResetTimeMatchesBlockEnd() {
        let end = Date().addingTimeInterval(5 * 3600)
        let block = SessionBlock(
            startTime: Date(),
            endTime: end,
            lastActivity: Date(),
            totalTokens: 0,
            tokensByModel: [:],
            entryCount: 0
        )
        let snap = UsageSnapshot(plan: .max20x, block: block, generatedAt: Date())
        XCTAssertEqual(snap.resetTime, end)
    }

    func testPlanCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(Plan.max20x)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        XCTAssertEqual(decoded, .max20x)
    }
}
