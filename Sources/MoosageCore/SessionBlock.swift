import Foundation

public struct SessionBlock: Equatable {
    public let startTime: Date
    public let endTime: Date
    public let lastActivity: Date
    public let totalTokens: Int
    public let tokensByModel: [String: Int]
    public let entryCount: Int

    public init(
        startTime: Date,
        endTime: Date,
        lastActivity: Date,
        totalTokens: Int,
        tokensByModel: [String: Int],
        entryCount: Int
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.lastActivity = lastActivity
        self.totalTokens = totalTokens
        self.tokensByModel = tokensByModel
        self.entryCount = entryCount
    }

    public func remaining(now: Date) -> TimeInterval {
        endTime.timeIntervalSince(now)
    }

    public func contains(_ date: Date) -> Bool {
        date >= startTime && date < endTime
    }
}
