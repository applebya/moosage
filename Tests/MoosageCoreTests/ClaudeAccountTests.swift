import XCTest
@testable import MoosageCore

final class ClaudeAccountTests: XCTestCase {
    func testTierToPlanMapping() {
        XCTAssertEqual(ClaudeAccount.plan(forTier: "default_claude_max_20x"), .max20x)
        XCTAssertEqual(ClaudeAccount.plan(forTier: "default_claude_max_5x"), .max5x)
        XCTAssertEqual(ClaudeAccount.plan(forTier: "default_claude_pro"), .pro)
    }

    func testUnknownTierFallsBackToPro() {
        XCTAssertEqual(ClaudeAccount.plan(forTier: "default_claude_max_50x"), .pro)
        XCTAssertEqual(ClaudeAccount.plan(forTier: ""), .pro)
        XCTAssertEqual(ClaudeAccount.plan(forTier: "garbage"), .pro)
    }

    func testAccountConstruction() {
        let acct = ClaudeAccount(
            plan: .max5x,
            rateLimitTier: "default_claude_max_5x",
            subscriptionType: "max",
            hasExtraUsageEnabled: true,
            email: "test@example.com"
        )
        XCTAssertEqual(acct.plan, .max5x)
        XCTAssertEqual(acct.rateLimitTier, "default_claude_max_5x")
        XCTAssertEqual(acct.hasExtraUsageEnabled, true)
    }
}
