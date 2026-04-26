import Foundation

public enum BlockBuilder {
    public static let blockDuration: TimeInterval = 5 * 60 * 60

    public static func buildBlocks(from entries: [UsageEntry]) -> [SessionBlock] {
        guard !entries.isEmpty else { return [] }

        // Sort defensively; UsageScanner already sorts but callers may pass arbitrary input.
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }

        // Dedupe by (messageId, requestId) — first occurrence wins.
        var seenKeys = Set<String>()
        var deduped: [UsageEntry] = []
        deduped.reserveCapacity(sorted.count)
        for entry in sorted {
            if let key = entry.dedupKey {
                if seenKeys.contains(key) { continue }
                seenKeys.insert(key)
            }
            deduped.append(entry)
        }

        var blocks: [SessionBlock] = []
        var currentStart: Date?
        var currentLast: Date?
        var currentTotal = 0
        var currentByModel: [String: Int] = [:]
        var currentCount = 0

        func flush() {
            guard let start = currentStart, let last = currentLast else { return }
            blocks.append(SessionBlock(
                startTime: start,
                endTime: start.addingTimeInterval(blockDuration),
                lastActivity: last,
                totalTokens: currentTotal,
                tokensByModel: currentByModel,
                entryCount: currentCount
            ))
            currentStart = nil
            currentLast = nil
            currentTotal = 0
            currentByModel = [:]
            currentCount = 0
        }

        for entry in deduped {
            if let start = currentStart, let last = currentLast {
                let pastWindow = entry.timestamp.timeIntervalSince(start) >= blockDuration
                let bigGap = entry.timestamp.timeIntervalSince(last) >= blockDuration
                if pastWindow || bigGap {
                    flush()
                }
            }
            if currentStart == nil {
                currentStart = entry.timestamp
            }
            currentLast = entry.timestamp
            currentTotal += entry.totalTokens
            currentByModel[entry.model, default: 0] += entry.totalTokens
            currentCount += 1
        }
        flush()

        return blocks
    }

    public static func currentBlock(in blocks: [SessionBlock], now: Date) -> SessionBlock? {
        blocks.first { $0.contains(now) }
    }
}
