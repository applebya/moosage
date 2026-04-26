import Foundation

public struct UsageSnapshot: Equatable {
    public let plan: Plan
    public let block: SessionBlock?
    public let generatedAt: Date

    public init(plan: Plan, block: SessionBlock?, generatedAt: Date) {
        self.plan = plan
        self.block = block
        self.generatedAt = generatedAt
    }

    public var fillRatio: Double {
        guard let block else { return 0 }
        let limit = Double(plan.tokensPer5hBlock)
        guard limit > 0 else { return 0 }
        let raw = Double(block.totalTokens) / limit
        return min(max(raw, 0), 1)
    }

    public var resetTime: Date? { block?.endTime }

    public var resetTimeShort: String {
        guard let resetTime else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "ha"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f.string(from: resetTime)
    }
}
