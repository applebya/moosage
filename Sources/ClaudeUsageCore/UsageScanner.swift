import Foundation

public enum UsageScanner {
    public static var defaultRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    public static func scan(root: URL) -> [UsageEntry] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [UsageEntry] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            entries.append(contentsOf: parseFile(at: fileURL))
        }

        entries.sort { $0.timestamp < $1.timestamp }
        return entries
    }

    static func parseFile(at url: URL) -> [UsageEntry] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }

        var results: [UsageEntry] = []
        var buffer = Data()
        let chunkSize = 64 * 1024
        let newline: UInt8 = 0x0A

        while autoreleasepool(invoking: { () -> Bool in
            let chunk = handle.availableData
            if chunk.isEmpty { return false }
            buffer.append(chunk)

            while let nlIndex = buffer.firstIndex(of: newline) {
                let lineData = buffer.subdata(in: 0..<nlIndex)
                buffer.removeSubrange(0...nlIndex)
                if let line = String(data: lineData, encoding: .utf8),
                   let entry = JSONLParser.parse(line: line) {
                    results.append(entry)
                }
            }

            // continue if there might be more
            return chunk.count >= chunkSize || !buffer.isEmpty
        }) {}

        // Flush trailing line without newline
        if !buffer.isEmpty,
           let line = String(data: buffer, encoding: .utf8),
           let entry = JSONLParser.parse(line: line) {
            results.append(entry)
        }

        return results
    }
}
