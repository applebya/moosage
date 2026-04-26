import XCTest
@testable import MoosageCore

final class ProviderSnapshotTests: XCTestCase {
    func testFillRatioClampsToZeroOne() {
        let high = ProviderSnapshot(
            providerId: "x", providerName: "X", providerLetter: "X",
            primaryFillRatio: 5.0,
            primaryResetTime: Date(), primaryUsedTokens: nil, primaryLimitTokens: nil,
            generatedAt: Date()
        )
        XCTAssertEqual(high.primaryFillRatio, 1.0)

        let low = ProviderSnapshot(
            providerId: "x", providerName: "X", providerLetter: "X",
            primaryFillRatio: -0.5,
            primaryResetTime: Date(), primaryUsedTokens: nil, primaryLimitTokens: nil,
            generatedAt: Date()
        )
        XCTAssertEqual(low.primaryFillRatio, 0.0)
    }

    func testWeeklyFillRatioClampsAndPropagates() {
        let snap = ProviderSnapshot(
            providerId: "x", providerName: "X", providerLetter: "X",
            primaryFillRatio: 0.5,
            primaryResetTime: Date(), primaryUsedTokens: nil, primaryLimitTokens: nil,
            weeklyFillRatio: 1.7,
            generatedAt: Date()
        )
        XCTAssertEqual(snap.weeklyFillRatio, 1.0)
    }

    func testEmptyHelperProducesStaleEmptySnapshot() {
        let now = Date()
        let snap = ProviderSnapshot.empty(
            providerId: "claude", providerName: "Claude Code", providerLetter: "C",
            generatedAt: now
        )
        XCTAssertEqual(snap.providerId, "claude")
        XCTAssertEqual(snap.providerLetter, "C")
        XCTAssertEqual(snap.primaryFillRatio, 0)
        XCTAssertNil(snap.primaryResetTime)
        XCTAssertTrue(snap.isStale)
    }
}
