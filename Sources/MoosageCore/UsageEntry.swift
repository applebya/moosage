import Foundation

public struct UsageEntry: Equatable {
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let messageId: String?
    public let requestId: String?

    public init(
        timestamp: Date,
        model: String,
        inputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        outputTokens: Int,
        messageId: String?,
        requestId: String?
    ) {
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.messageId = messageId
        self.requestId = requestId
    }

    public var totalTokens: Int {
        inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens
    }

    public var dedupKey: String? {
        guard let messageId, let requestId else { return nil }
        return "\(messageId):\(requestId)"
    }
}
